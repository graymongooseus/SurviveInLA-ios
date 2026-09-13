import XCTest
@testable import SurviveInLA

private let rankingFixture = """
{"as_of":"2026-09-05T06:00:00.123Z","total_runs":1,"total_players":1,"entries":[
{"run_id":"55eee548-1663-439e-b7e9-616e232b9f6a","rank":1,"display_name":"洛城旅人小林",
"app_version":"1.1 (5)","net_worth":28450,"profile_id":2,"health":38,"experience_count":12,
"used_purchases":true,"completed_at":"2026-09-04T23:00:00Z","received_at":"2026-09-05T06:00:00.001Z"}]}
"""

private final class RankingURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // This public screen must never post a save or require an Apple identity.
        let validRead = request.httpMethod == "GET" && request.httpBody == nil
            && request.value(forHTTPHeaderField: "X-Player-ID") == nil
        let status = validRead && request.url?.path != "/unavailable" ? 200 : 503
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(rankingFixture.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}

final class WorldRankingTests: XCTestCase {
    func testDecodesSubmissionVersionAndBothTimestampFormats() throws {
        let result = try WorldRankingResponse.decode(Data(rankingFixture.utf8))
        let entry = try XCTUnwrap(result.entries.first)
        XCTAssertEqual(entry.displayName, "洛城旅人小林")
        XCTAssertEqual(entry.appVersion, "1.1 (5)")
        XCTAssertEqual(entry.profileName, "PROFILE 02")
        XCTAssertEqual(entry.netWorth, 28_450)
        XCTAssertTrue(entry.usedPurchases)
        XCTAssertLessThan(entry.completedAt, entry.receivedAt)
    }

    func testRejectsBadDatesInsteadOfShowingInventedTimes() {
        let malformed = rankingFixture.replacingOccurrences(of: "2026-09-04T23:00:00Z", with: "not-a-date")
        XCTAssertThrowsError(try WorldRankingResponse.decode(Data(malformed.utf8)))
    }

    @MainActor
    func testReadsPublicRankingsWithoutUploadingAnySave() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RankingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let store = WorldRankingStore(session: session)
        await store.refresh()
        XCTAssertEqual(store.result?.entries.first?.netWorth, 28_450)
        XCTAssertNil(store.errorMessage)
        XCTAssertFalse(store.isLoading)
    }

    @MainActor
    func testServiceFailureShowsRetryStateWithoutFakeResults() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RankingURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let store = WorldRankingStore(session: session, endpoint: URL(string: "https://example.com/unavailable")!)
        await store.refresh()
        XCTAssertNil(store.result)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertFalse(store.isLoading)
    }
}

private final class UploadURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if request.url!.path.contains("offline") {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                body.append(contentsOf: buffer.prefix(count))
            }
        }
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
        var status = 201
        var responseBody: [String: Any] = ["run_id": json["run_id"] ?? "missing"]
        if request.httpMethod == "PUT", json["display_name"] != nil {
            status = 200
            responseBody = json
        } else if request.httpMethod != "POST" || request.value(forHTTPHeaderField: "X-Player-ID")?.hasPrefix("test-") != true {
            status = 400
        } else if request.url!.path.contains("rejected") {
            status = 409
        } else if request.url!.path.contains("wrong-receipt") {
            responseBody = ["run_id": UUID().uuidString]
        } else if request.url!.path.contains("duplicate") {
            status = 200
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: responseBody))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}

final class RankingUploadTests: XCTestCase {
    private func snapshot(profile: ProfileID = .one, score: Int = 1234, finished: Bool = true) -> GameSnapshot {
        var engine = GameEngine(seed: 42)
        var session = engine.makeNewSession()
        session.day = 52
        session.cash = score + 500
        session.bank = 0
        session.debt = 0
        session.health = 50
        if finished { engine.endJourney(session: &session) }
        return GameSnapshot(profileID: profile, session: session, randomCheckpoint: engine.randomCheckpoint,
                            updatedAt: Date(timeIntervalSince1970: 1_788_600_000))
    }

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UploadURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    func testPayloadUsesOnlyThisRunActualScoreVersionAndPurchases() throws {
        let current = snapshot(profile: .two, score: -125)
        let submission = try XCTUnwrap(RankingSubmission(snapshot: current, displayName: "测试旅人", appVersion: "1.1 (2)"))
        XCTAssertEqual(submission.netWorth, current.session.netWorth)
        XCTAssertEqual(submission.netWorth, -125)
        XCTAssertEqual(submission.profileID, 2)
        XCTAssertEqual(submission.appVersion, "1.1 (2)")
        XCTAssertEqual(submission.runID, JourneyRecord(snapshot: current)?.id)
        XCTAssertEqual(submission.ending, "deported")
        XCTAssertFalse(submission.usedPurchases)
        var purchased = current.session
        purchased.log.append(GameLogEntry(day: 10, title: "充值", message: "测试", eventID: "iap-test"))
        let paid = GameSnapshot(profileID: .two, session: purchased, randomCheckpoint: 42)
        XCTAssertEqual(RankingSubmission(snapshot: paid, displayName: "测试", appVersion: "1")?.usedPurchases, true)
    }

    func testOnlyFullSuccessfulRunsQualifyIncludingRootedEnding() {
        let current = snapshot()
        var session = current.session
        session.rootedEnding = true
        XCTAssertEqual(RankingSubmission(snapshot: GameSnapshot(profileID: .one, session: session, randomCheckpoint: 42), displayName: "测试", appVersion: "1")?.ending, "rooted")
        session.health = 0
        XCTAssertNil(RankingSubmission(snapshot: GameSnapshot(profileID: .one, session: session, randomCheckpoint: 42), displayName: "测试", appVersion: "1"))
        XCTAssertNil(RankingSubmission(snapshot: snapshot(finished: false), displayName: "测试", appVersion: "1"))
    }

    @MainActor
    func testOfflineQueueSurvivesRelaunchAndDuplicateSaveWithoutChangingPayload() async throws {
        let file = try directory().appending(path: "outbox.json")
        let session = mockSession()
        defer { session.invalidateAndCancel() }
        let first = RankingUploadStore(fileURL: file, session: session, baseURL: URL(string: "https://example.com/offline")!, monitorNetwork: false)
        let current = snapshot(score: 50)
        try first.enqueue(current, appVersion: "1.1 (2)")
        await first.retryPending()
        XCTAssertEqual(first.pendingCount, 1)
        XCTAssertNotNil(first.errorMessage)
        let second = RankingUploadStore(fileURL: file, session: session, monitorNetwork: false)
        XCTAssertEqual(first.playerID, second.playerID)
        var modified = current.session
        modified.cash = 999999
        try second.enqueue(GameSnapshot(profileID: .one, session: modified, randomCheckpoint: 43), appVersion: "9.9")
        XCTAssertEqual(second.uploads.count, 1)
        XCTAssertEqual(second.uploads.first?.submission.netWorth, 50)
        XCTAssertEqual(second.uploads.first?.submission.appVersion, "1.1 (2)")
        XCTAssertEqual(second.uploads.first?.submission.completedAt, current.updatedAt)
        await second.retryPending()
        XCTAssertEqual(second.uploads.first?.status, .uploaded)
        let third = RankingUploadStore(fileURL: file, session: session, monitorNetwork: false)
        try third.enqueue(current)
        XCTAssertEqual(third.pendingCount, 0)
        XCTAssertEqual(third.uploads.count, 1)
    }

    @MainActor
    func testDuplicateReceiptAcceptedButWrongReceiptAndConflictNeverClaimSuccess() async throws {
        let session = mockSession()
        defer { session.invalidateAndCancel() }
        for (path, expected) in [("duplicate", RankingUpload.Status.uploaded), ("wrong-receipt", .pending), ("rejected", .rejected)] {
            let file = try directory().appending(path: "outbox.json")
            let store = RankingUploadStore(fileURL: file, session: session, baseURL: URL(string: "https://example.com/\(path)")!, monitorNetwork: false)
            try store.enqueue(snapshot())
            await store.retryPending()
            XCTAssertEqual(store.uploads.first?.status, expected, path)
        }
    }

    @MainActor
    func testCompletionHookDoesNotScanOtherSlotsHistoryOrAlreadyFinishedSaves() throws {
        let folder = try directory()
        let repository = ProfileRepository(directoryURL: folder.appending(path: "profiles"))
        let uploads = RankingUploadStore(fileURL: folder.appending(path: "outbox.json"), session: mockSession(), monitorNetwork: false)
        try repository.save(snapshot(profile: .one, score: 55, finished: false))
        try repository.save(snapshot(profile: .two, score: 900000))
        try repository.archiveJourney(snapshot(profile: .three, score: 990000))
        let manager = ProfileManager(repository: repository, rankingUploads: uploads)
        manager.open(.two)
        XCTAssertTrue(uploads.uploads.isEmpty)
        manager.open(.one) // Restore week 52, engine settles, then the completion hook queues this run.
        XCTAssertEqual(uploads.uploads.count, 1)
        XCTAssertEqual(uploads.uploads.first?.submission.profileID, 1)
        XCTAssertEqual(uploads.uploads.first?.submission.netWorth, 55)
        manager.activeStore?.loadLeaderboard()
        manager.saveActiveProfile()
        XCTAssertEqual(uploads.uploads.count, 1)
        manager.activeStore?.restart()
        XCTAssertEqual(uploads.uploads.count, 1)
        XCTAssertFalse(manager.activeStore!.session.isFinished)
    }

    @MainActor
    func testCorruptOutboxIsNotOverwrittenAndNicknameValidationIsDurable() throws {
        let file = try directory().appending(path: "outbox.json")
        let store = RankingUploadStore(fileURL: file, monitorNetwork: false)
        store.saveDisplayName("  测试旅人  ")
        XCTAssertEqual(store.displayName, "测试旅人")
        XCTAssertTrue(store.nameNeedsSync)
        store.saveDisplayName("\u{200B}")
        XCTAssertEqual(store.displayName, "测试旅人")
        let saved = RankingUploadStore(fileURL: file, monitorNetwork: false)
        XCTAssertEqual(saved.displayName, "测试旅人")
        let invalid = Data("unreadable queue".utf8)
        try invalid.write(to: file)
        let corrupt = RankingUploadStore(fileURL: file, monitorNetwork: false)
        XCTAssertThrowsError(try corrupt.enqueue(snapshot()))
        XCTAssertEqual(try Data(contentsOf: file), invalid)
    }
}

extension RankingUploadTests {
    /// Explicit opt-in only. The operator removes this temporary player after verification.
    @MainActor
    func testLiveCompletionUploadAndPublicRankingWhenEnabled() async throws {
        guard ProcessInfo.processInfo.environment["LEADERBOARD_LIVE_TEST"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_LEADERBOARD_LIVE_TEST=1 to verify the deployed service.")
        }
        let folder = try directory()
        let repository = ProfileRepository(directoryURL: folder.appending(path: "profiles"))
        let uploads = RankingUploadStore(fileURL: folder.appending(path: "outbox.json"), monitorNetwork: false)
        uploads.saveDisplayName("Codex上传联调临时")
        print("LEADERBOARD_LIVE_PLAYER=\(uploads.playerID)")
        await uploads.retryPending()
        XCTAssertNil(uploads.errorMessage)
        try repository.save(snapshot(profile: .one, score: 4321, finished: false))
        try repository.save(snapshot(profile: .two, score: 1234, finished: false))
        let manager = ProfileManager(repository: repository, rankingUploads: uploads)
        manager.open(.one)
        manager.open(.two)
        await uploads.retryPending()
        for _ in 0..<100 where uploads.isUploading {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertNil(uploads.errorMessage)
        XCTAssertEqual(uploads.uploads.count, 2)
        XCTAssertTrue(uploads.uploads.allSatisfy { $0.status == .uploaded })
        let ranking = WorldRankingStore()
        await ranking.refresh()
        XCTAssertNil(ranking.errorMessage)
        let ids = Set(uploads.uploads.map(\.id))
        let entries = try XCTUnwrap(ranking.result).entries.filter { ids.contains($0.id) }
        XCTAssertEqual(entries.map(\.netWorth), [4321, 1234])
        XCTAssertTrue(entries.allSatisfy { $0.displayName == "Codex上传联调临时" && $0.appVersion == RankingUploadStore.appVersion })
        // Replay the exact payload: no duplicate record, even after a lost local acknowledgement.
        let replay = RankingUploadStore(fileURL: folder.appending(path: "outbox.json"), monitorNetwork: false)
        XCTAssertEqual(replay.playerID, uploads.playerID)
        XCTAssertEqual(replay.pendingCount, 0)
    }
}
