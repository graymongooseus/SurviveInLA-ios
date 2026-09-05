import Foundation

enum ProfileID: Int, CaseIterable, Codable, Identifiable, Sendable {
    case one = 1
    case two = 2
    case three = 3

    var id: Int { rawValue }

    var displayName: String {
        "PROFILE \(String(format: "%02d", rawValue))"
    }
}

struct GameSnapshot: Codable, Sendable {
    static let currentVersion = 1

    let version: Int
    let profileID: ProfileID
    let session: GameSession
    let randomCheckpoint: UInt64
    let updatedAt: Date

    init(
        version: Int = Self.currentVersion,
        profileID: ProfileID,
        session: GameSession,
        randomCheckpoint: UInt64,
        updatedAt: Date = .now
    ) {
        self.version = version
        self.profileID = profileID
        self.session = session
        self.randomCheckpoint = randomCheckpoint
        self.updatedAt = updatedAt
    }
}

struct ProfileSlot: Identifiable, Sendable {
    let id: ProfileID
    let snapshot: GameSnapshot?

    var isEmpty: Bool { snapshot == nil }
}

struct CloudProfileRecord: Codable, Sendable {
    let snapshot: GameSnapshot?
    let deletedAt: Date?

    init(snapshot: GameSnapshot) {
        self.snapshot = snapshot
        deletedAt = nil
    }

    init(deletedAt: Date) {
        snapshot = nil
        self.deletedAt = deletedAt
    }
}

struct ProfileRepository: Sendable {
    private let directoryURL: URL

    var isICloudAccountAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            self.directoryURL = applicationSupport.appending(
                path: "SurviveInLA/Profiles",
                directoryHint: .isDirectory
            )
        }
    }

    func load(_ profileID: ProfileID) throws -> GameSnapshot? {
        let fileURL = url(for: profileID)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        let data = try Data(contentsOf: fileURL)
        let snapshot = try Self.decoder.decode(GameSnapshot.self, from: data)
        return try migrated(snapshot)
    }

    func save(_ snapshot: GameSnapshot) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let data = try Self.encoder.encode(snapshot)
        try data.write(to: url(for: snapshot.profileID), options: .atomic)
    }

    func deleteLocal(_ profileID: ProfileID) throws {
        let fileURL = url(for: profileID)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    // Kept separately from the three overwriteable save slots; restarting never erases history.
    func loadJourneyRecords() throws -> [JourneyRecord] {
        let url = directoryURL.appending(path: "journey-records-v1.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try Self.decoder.decode([JourneyRecord].self, from: Data(contentsOf: url))
    }

    func archiveJourney(_ snapshot: GameSnapshot) throws {
        guard let record = JourneyRecord(snapshot: snapshot) else { return }
        var records = try loadJourneyRecords()
        guard !records.contains(where: { $0.id == record.id && $0.profileID == record.profileID }) else { return }
        records.append(record)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Self.encoder.encode(records).write(
            to: directoryURL.appending(path: "journey-records-v1.json"), options: .atomic
        )
    }

    func saveToICloud(_ snapshot: GameSnapshot) throws {
        let record = CloudProfileRecord(snapshot: snapshot)
        let data = try Self.encoder.encode(record)
        NSUbiquitousKeyValueStore.default.set(data, forKey: cloudKey(for: snapshot.profileID))
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func deleteEverywhere(_ profileID: ProfileID, deletedAt: Date = .now) throws {
        try deleteLocal(profileID)
        let record = CloudProfileRecord(deletedAt: deletedAt)
        let data = try Self.encoder.encode(record)
        NSUbiquitousKeyValueStore.default.set(data, forKey: cloudKey(for: profileID))
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    @discardableResult
    func reconcileWithICloud(_ profileID: ProfileID) throws -> GameSnapshot? {
        NSUbiquitousKeyValueStore.default.synchronize()

        let localSnapshot = try load(profileID)
        guard let cloudRecord = try loadICloudRecord(profileID) else {
            if let localSnapshot {
                try saveToICloud(localSnapshot)
            }
            return localSnapshot
        }

        if let deletedAt = cloudRecord.deletedAt {
            if let localSnapshot, localSnapshot.updatedAt > deletedAt {
                try saveToICloud(localSnapshot)
                return localSnapshot
            }

            try deleteLocal(profileID)
            return nil
        }

        guard let cloudSnapshot = cloudRecord.snapshot else { return localSnapshot }

        if let localSnapshot, localSnapshot.updatedAt >= cloudSnapshot.updatedAt {
            try saveToICloud(localSnapshot)
            return localSnapshot
        }

        try save(cloudSnapshot)
        return cloudSnapshot
    }

    private func loadICloudRecord(_ profileID: ProfileID) throws -> CloudProfileRecord? {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: cloudKey(for: profileID)) else {
            return nil
        }

        let record = try Self.decoder.decode(CloudProfileRecord.self, from: data)
        guard let snapshot = record.snapshot else { return record }
        return CloudProfileRecord(snapshot: try migrated(snapshot))
    }

    private func migrated(_ snapshot: GameSnapshot) throws -> GameSnapshot {
        guard snapshot.version == GameSnapshot.currentVersion else {
            throw ProfilePersistenceError.unsupportedVersion(snapshot.version)
        }
        guard snapshot.session.totalDays == 40 else { return snapshot }

        var migratedSession = snapshot.session
        migratedSession.totalDays = 52
        migratedSession.actionThisWeek = nil
        return GameSnapshot(
            version: snapshot.version,
            profileID: snapshot.profileID,
            session: migratedSession,
            randomCheckpoint: snapshot.randomCheckpoint,
            updatedAt: snapshot.updatedAt
        )
    }

    private func url(for profileID: ProfileID) -> URL {
        directoryURL.appending(path: "profile-\(profileID.rawValue).json")
    }

    private func cloudKey(for profileID: ProfileID) -> String {
        "profile-\(profileID.rawValue)-v\(GameSnapshot.currentVersion)"
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

enum ProfilePersistenceError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            "这个存档来自不支持的版本（v\(version)）。"
        }
    }
}

@MainActor
enum DebugLog {
    private static let foregroundMarkerKey = "DebugLog.foregroundRunInProgress"
    private static var checkedPreviousRun = false

    static let fileURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents
            .appending(path: "DebugLogs", directoryHint: .isDirectory)
            .appending(path: "survive-in-la.log")
    }()

    static func appBecameActive() {
        let defaults = UserDefaults.standard
        if !checkedPreviousRun {
            checkedPreviousRun = true
            if defaults.bool(forKey: foregroundMarkerKey) {
                record("app.previous_foreground_run_ended_unexpectedly")
            }
        }
        defaults.set(true, forKey: foregroundMarkerKey)
        record("app.active", "os=\(ProcessInfo.processInfo.operatingSystemVersionString)")
    }

    static func appEnteredBackground() {
        record("app.background")
        UserDefaults.standard.set(false, forKey: foregroundMarkerKey)
    }

    static func record(_ event: String, _ details: String = "") {
        do {
            let directoryURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            let timestamp = ISO8601DateFormatter().string(from: .now)
            let safeDetails = details.replacingOccurrences(of: "\n", with: " ")
            let line = "\(timestamp)\t\(event)\(safeDetails.isEmpty ? "" : "\t\(safeDetails)")\n"
            let data = Data(line.utf8)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: fileURL, options: .atomic)
            }
        } catch {
            print("DebugLog write failed: \(error.localizedDescription)")
        }
    }
}
