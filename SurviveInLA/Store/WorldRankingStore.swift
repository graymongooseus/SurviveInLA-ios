import Foundation
import Observation
import Network

struct WorldRankingEntry: Decodable, Identifiable, Sendable {
    let runID: UUID
    let rank: Int
    let displayName: String
    let appVersion: String
    let netWorth: Int
    let profileID: Int
    let health: Int
    let experienceCount: Int
    let usedPurchases: Bool
    let completedAt: Date
    let receivedAt: Date
    let ending: String?

    var id: UUID { runID }
    var profileName: String { String(format: "PROFILE %02d", profileID) }

    enum CodingKeys: String, CodingKey {
        case runID = "run_id", rank, displayName = "display_name", appVersion = "app_version"
        case netWorth = "net_worth", profileID = "profile_id", health
        case experienceCount = "experience_count", usedPurchases = "used_purchases"
        case completedAt = "completed_at", receivedAt = "received_at", ending
    }
}

struct WorldRankingResponse: Decodable, Sendable {
    let asOf: Date
    let totalRuns: Int
    let totalPlayers: Int
    let entries: [WorldRankingEntry]

    enum CodingKeys: String, CodingKey {
        case asOf = "as_of", totalRuns = "total_runs", totalPlayers = "total_players", entries
    }

    static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let format = ISO8601DateFormatter()
            format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = format.date(from: value) { return date }
            format.formatOptions = [.withInternetDateTime]
            if let date = format.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ranking date")
        }
        return try decoder.decode(Self.self, from: data)
    }
}

@MainActor
@Observable
final class WorldRankingStore {
    private(set) var result: WorldRankingResponse?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    // Public read-only rankings; browsing never reads or uploads local saves.
    static let endpoint = URL(string: "https://2.24.206.66:18443/v1/rankings?limit=50")!
    private let session: URLSession
    private let endpoint: URL

    init(session: URLSession = .shared, endpoint: URL = WorldRankingStore.endpoint) {
        self.session = session
        self.endpoint = endpoint
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            var request = URLRequest(url: endpoint)
            request.timeoutInterval = 15
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let decoded = try WorldRankingResponse.decode(data)
            try Task.checkCancellation()
            result = decoded
        } catch is CancellationError {
            // Leaving this screen cancels its task; it is not a connection failure.
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            errorMessage = result == nil
                ? "暂时无法连接世界排名，请检查网络后重试。"
                : "刷新未完成，以下保留上次读取的排名。"
        }
    }
}

/// Frozen at completion. Retries never read a newer save or a personal best.
struct RankingSubmission: Codable, Sendable {
    let runID: UUID
    var displayName: String
    let ruleset: String
    let netWorth: Int
    let profileID: Int
    let weeksSurvived: Int
    let ending: String
    let health: Int
    let experienceCount: Int
    let usedPurchases: Bool
    let completedAt: Date
    let appVersion: String

    init?(snapshot: GameSnapshot, displayName: String, appVersion: String) {
        let session = snapshot.session
        guard session.isFinished, session.totalDays == 52, session.day >= 52,
              session.health > 0, session.isDeported || session.isRootedInLosAngeles,
              let record = JourneyRecord(snapshot: snapshot) else { return nil }
        runID = record.id
        self.displayName = displayName
        ruleset = "la-52w-v1"
        netWorth = session.netWorth
        profileID = snapshot.profileID.rawValue
        weeksSurvived = 52
        ending = session.isRootedInLosAngeles ? "rooted" : "deported"
        health = session.health
        experienceCount = session.experienceCount
        usedPurchases = session.log.contains { $0.eventID?.hasPrefix("iap-") == true }
        completedAt = snapshot.updatedAt
        self.appVersion = appVersion
    }

    enum CodingKeys: String, CodingKey {
        case runID = "run_id", displayName = "display_name", ruleset
        case netWorth = "net_worth", profileID = "profile_id", weeksSurvived = "weeks_survived"
        case ending, health, experienceCount = "experience_count", usedPurchases = "used_purchases"
        case completedAt = "completed_at", appVersion = "app_version"
    }
}

struct RankingUpload: Codable, Identifiable, Sendable {
    enum Status: String, Codable, Sendable { case pending, uploaded, rejected }
    let submission: RankingSubmission
    var status: Status = .pending
    var message: String? = nil
    var id: UUID { submission.runID }
}

private struct RankingUploadState: Codable {
    var playerID = "test-" + UUID().uuidString.lowercased()
    var displayName = "洛城旅人" + String(UUID().uuidString.prefix(4))
    var needsNameSync = false
    var uploads: [RankingUpload] = []
}

@MainActor
@Observable
final class RankingUploadStore {
    private var state = RankingUploadState()
    private(set) var isUploading = false
    private(set) var errorMessage: String?
    private var storageIsAvailable = true
    private let fileURL: URL
    private let session: URLSession
    private let baseURL: URL
    @ObservationIgnored private var monitor: NWPathMonitor?

    var displayName: String { state.displayName }
    var playerID: String { state.playerID }
    var uploads: [RankingUpload] { state.uploads }
    var pendingCount: Int { uploads.filter { $0.status == .pending }.count }
    var nameNeedsSync: Bool { state.needsNameSync }
    static var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "unknown") (\(info["CFBundleVersion"] as? String ?? "unknown"))"
    }

    init(fileURL: URL? = nil, session: URLSession = .shared,
         baseURL: URL = URL(string: "https://2.24.206.66:18443")!, monitorNetwork: Bool = true) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "SurviveInLA/ranking-uploads-v1.json")
        self.session = session
        self.baseURL = baseURL
        do {
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                state = try JSONDecoder().decode(RankingUploadState.self, from: Data(contentsOf: self.fileURL))
            } else {
                try persist()
            }
        } catch {
            // Never replace an unreadable queue with an empty one or a different identity.
            storageIsAvailable = false
            errorMessage = "无法读取或保存上传队列，请保留本局并重新启动游戏。"
        }
        if monitorNetwork {
            let monitor = NWPathMonitor()
            self.monitor = monitor
            monitor.pathUpdateHandler = { [weak self] path in
                guard path.status == .satisfied else { return }
                Task { @MainActor [weak self] in await self?.retryPending() }
            }
            monitor.start(queue: DispatchQueue(label: "world-ranking-network"))
        }
    }

    deinit { monitor?.cancel() }

    func upload(for runID: UUID?) -> RankingUpload? {
        state.uploads.first { $0.id == runID }
    }

    /// Synchronous durable outbox write must succeed before a completed slot can restart.
    func enqueue(_ snapshot: GameSnapshot, appVersion: String = RankingUploadStore.appVersion) throws {
        guard let submission = RankingSubmission(snapshot: snapshot, displayName: displayName, appVersion: appVersion),
              upload(for: submission.runID) == nil else { return }
        guard storageIsAvailable else { throw CocoaError(.fileWriteUnknown) }
        state.uploads.append(RankingUpload(submission: submission))
        do { try persist() } catch {
            state.uploads.removeLast()
            errorMessage = "本局尚未存入上传队列，请保留存档并重试。"
            throw error
        }
    }

    func saveDisplayName(_ value: String) {
        let cleaned = value.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalid = cleaned.unicodeScalars.contains {
            switch $0.properties.generalCategory {
            case .control, .format, .surrogate, .privateUse, .unassigned: return true
            default: return false
            }
        }
        guard !cleaned.isEmpty, cleaned.unicodeScalars.count <= 24, !invalid else {
            errorMessage = "昵称需要 1–24 个字符，请勿使用控制字符。"
            return
        }
        let previous = state
        state.displayName = cleaned
        state.needsNameSync = true
        do { try persist(); errorMessage = nil } catch {
            state = previous
            errorMessage = "昵称未能保存，请重试。"
        }
    }

    func retryPending() async {
        guard storageIsAvailable, !isUploading, pendingCount > 0 || state.needsNameSync else { return }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
        do {
            if state.needsNameSync {
                let name = displayName
                let body = try JSONSerialization.data(withJSONObject: ["display_name": name])
                let (_, response) = try await session.data(for: request(path: "v1/player", method: "PUT", body: body))
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                if name == displayName { state.needsNameSync = false }
                try persist()
            }
            // Re-evaluate after each await: another run can finish while an upload is in flight.
            while let index = state.uploads.firstIndex(where: { $0.status == .pending }) {
                var submission = state.uploads[index].submission
                submission.displayName = displayName
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let (data, response) = try await session.data(for: request(
                    path: "v1/runs", method: "POST", body: try encoder.encode(submission)))
                guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                if http.statusCode == 200 || http.statusCode == 201 {
                    struct Receipt: Decodable { let run_id: UUID }
                    let receipt = try JSONDecoder().decode(Receipt.self, from: data)
                    guard receipt.run_id == submission.runID else { throw URLError(.badServerResponse) }
                    state.uploads[index].status = .uploaded
                    state.uploads[index].message = nil
                } else if (400..<500).contains(http.statusCode), ![408, 429].contains(http.statusCode) {
                    state.uploads[index].status = .rejected
                    state.uploads[index].message = "服务器未接受本局（\(http.statusCode)），原成绩仍保留在本机。"
                } else {
                    throw URLError(.badServerResponse)
                }
                do { try persist() } catch {
                    // A lost acknowledgement is safe: replay uses the same immutable run ID and body.
                    state.uploads[index].status = .pending
                    throw error
                }
            }
        } catch {
            errorMessage = "暂未上传成功，成绩已保留；网络恢复或下次打开游戏时重试，也可手动重试。"
        }
    }

    func retryRejected(_ runID: UUID) {
        guard let index = state.uploads.firstIndex(where: { $0.id == runID && $0.status == .rejected }) else { return }
        state.uploads[index].status = .pending
        do { try persist() } catch { state.uploads[index].status = .rejected }
    }

    private func request(path: String, method: String, body: Data) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(playerID, forHTTPHeaderField: "X-Player-ID")
        return request
    }

    private func persist() throws {
        guard storageIsAvailable else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: fileURL, options: .atomic)
    }
}
