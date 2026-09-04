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

struct ProfileRepository: Sendable {
    private let directoryURL: URL

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
        guard snapshot.version == GameSnapshot.currentVersion else {
            throw ProfilePersistenceError.unsupportedVersion(snapshot.version)
        }
        return snapshot
    }

    func save(_ snapshot: GameSnapshot) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let data = try Self.encoder.encode(snapshot)
        try data.write(to: url(for: snapshot.profileID), options: .atomic)
    }

    private func url(for profileID: ProfileID) -> URL {
        directoryURL.appending(path: "profile-\(profileID.rawValue).json")
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
