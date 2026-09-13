import XCTest
@testable import SurviveInLA

final class CelebrityActingTests: XCTestCase {
    private var event: CelebrityActingEventDefinition { EventContentCatalog.bundled.celebrityActingEvents[0] }

    private func session(turn: Int = 5, luck: Int = 55, district: District.ID = .hollywood) -> GameSession {
        var engine = GameEngine(seed: 42)
        var state = engine.makeNewSession()
        state.day = turn
        state.baseLuck = luck
        state.health = 80
        state.cash = 1_000
        state.currentDistrictID = district
        return state
    }

    @discardableResult
    private func choose(_ role: String, in state: inout GameSession) throws -> String {
        CelebrityActingEngine.onArrival(in: &state, catalog: [event])
        let id = try XCTUnwrap(state.pendingActingEncounter?.id)
        try CelebrityActingEngine.choose(role, encounterID: id, in: &state)
        return id
    }

    func testContentContainsDirectorAndThreeDistinctChoices() {
        XCTAssertEqual(EventContentCatalog.bundled.celebritiesByID[event.sourceNPCID]?.title, "吴宇森")
        XCTAssertEqual(event.interactionKind, .acting)
        XCTAssertEqual(event.options.map(\.id), ["messenger", "action", "extra"])
        XCTAssertEqual(event.options.map(\.fee), [300, 600, 0])
        XCTAssertEqual(event.options.map(\.healthDelta), [-5, -12, 10])
        XCTAssertEqual(event.delayTurns, 10)
        XCTAssertEqual(event.bonusMultiplier, 10)
        XCTAssertFalse(event.invitation.message.contains("10"))
        XCTAssertFalse(event.invitation.message.contains("十倍"))
    }

    func testHollywoodLuckBoundaryIsInclusiveAndUsesEffectiveLuck() {
        for luck in [54, 55, 56] {
            var state = session(luck: luck)
            CelebrityActingEngine.onArrival(in: &state, catalog: [event])
            XCTAssertEqual(state.pendingActingEncounter != nil, luck >= 55)
        }
        var elsewhere = session(luck: 100, district: .santaMonica)
        CelebrityActingEngine.onArrival(in: &elsewhere, catalog: [event])
        XCTAssertNil(elsewhere.pendingActingEncounter)
        var boosted = session(luck: 50)
        let buff = PlayerBuffDefinition(id: "boost", title: "好运", message: "", durationTurns: 3,
                                        luckDelta: 5, healthPerTurn: 0, workIncomeMultiplier: 1)
        PlayerBuffEngine.grant(buff, instanceID: "boost", sourceEventID: "test", in: &boosted)
        CelebrityActingEngine.onArrival(in: &boosted, catalog: [event])
        XCTAssertNotNil(boosted.pendingActingEncounter)
    }

    func testActualArrivalTriggersWhileStationaryWeekAndRestoreDoNot() throws {
        var engine = GameEngine(seed: 42)
        var arrival = session(turn: 1, district: .dingPangZiPlaza)
        try engine.travel(to: .hollywood, session: &arrival)
        XCTAssertNotNil(arrival.pendingActingEncounter)
        var stationary = session(turn: 1)
        stationary.recordWeeklyAction(.work)
        try engine.finishStationaryWeek(in: &stationary)
        XCTAssertNil(stationary.pendingActingEncounter)
        let snapshot = GameSnapshot(profileID: .one, session: session(), randomCheckpoint: 42)
        XCTAssertNil(GameSnapshotMigration.restoreSession(snapshot).pendingActingEncounter)
    }

    func testBothPaidRolesReceiveFeeNowAndFreezeSeparateTenfoldBonus() throws {
        for (role, fee, health) in [("messenger", 300, 75), ("action", 600, 68)] {
            var state = session()
            let instance = try choose(role, in: &state)
            XCTAssertEqual(state.cash, 1_000 + fee)
            XCTAssertEqual(state.health, health)
            XCTAssertEqual(state.currentLuck, 55)
            let bonus = try XCTUnwrap(state.pendingActingBonuses?.first)
            XCTAssertEqual(bonus.id, instance + "-bonus")
            XCTAssertEqual(bonus.originalFee, fee)
            XCTAssertEqual(bonus.amount, fee * 10)
            XCTAssertEqual(bonus.dueTurn, 15)
            XCTAssertEqual(state.unreadActingNotices?.count, 1)
            XCTAssertNil(state.pendingActingEncounter)
            XCTAssertFalse(state.hasCompletedAnyWeeklyAction)
        }
    }

    func testExtraGetsOneMealAndLuckWithNoFeeOrFutureBonus() throws {
        var state = session()
        try choose("extra", in: &state)
        XCTAssertEqual(state.cash, 1_000)
        XCTAssertEqual(state.health, 90)
        XCTAssertEqual(state.currentLuck, 58)
        XCTAssertTrue(state.pendingActingBonuses?.isEmpty ?? true)
        state.day += 10
        CelebrityActingEngine.settleDue(in: &state)
        XCTAssertEqual(state.cash, 1_000)
        XCTAssertEqual(state.unreadActingNotices?.count, 1)
        var capped = session(luck: 99)
        capped.health = 98
        try choose("extra", in: &capped)
        XCTAssertEqual(capped.health, 100)
        XCTAssertEqual(capped.currentLuck, 100)
        XCTAssertEqual(capped.unreadActingNotices?.first?.healthDelta, 2)
        XCTAssertEqual(capped.unreadActingNotices?.first?.luckDelta, 1)
    }

    func testBonusArrivesAfterTenWeeksAndCannotBeCreditedTwice() throws {
        var state = session()
        try choose("messenger", in: &state)
        state.currentDistrictID = .irvine
        state.day = 14
        CelebrityActingEngine.settleDue(in: &state)
        XCTAssertEqual(state.cash, 1_300)
        state.day = 15
        CelebrityActingEngine.settleDue(in: &state)
        XCTAssertEqual(state.cash, 4_300)
        XCTAssertEqual(state.unreadActingNotices?.last?.cashDelta, 3_000)
        XCTAssertTrue(state.pendingActingBonuses?.isEmpty == true)
        CelebrityActingEngine.settleDue(in: &state)
        state.day += 1
        CelebrityActingEngine.settleDue(in: &state)
        XCTAssertEqual(state.cash, 4_300)
        XCTAssertEqual(state.unreadActingNotices?.count, 2)
    }

    func testEveryTurnRouteDeliversDueBonus() throws {
        for route in 0 ..< 3 {
            var state = session()
            try choose("action", in: &state)
            state.day = 14
            state.recordWeeklyAction(.work)
            var engine = GameEngine(seed: 91)
            switch route {
            case 0: try engine.travel(to: .sanGabriel, session: &state)
            case 1: try engine.finishStationaryWeek(in: &state)
            default: engine.skipStationaryWeeks(1, in: &state)
            }
            XCTAssertTrue(state.pendingActingBonuses?.isEmpty == true)
            XCTAssertEqual(state.unreadActingNotices?.last?.cashDelta, 6_000)
            XCTAssertEqual(state.history(for: .cash).filter { $0.reason == event.premiere.title }.map(\.delta), [6_000])
        }
    }

    func testDeadlineAllowsWeek42AndBonusPrecedesFinalSettlement() throws {
        var late = session(turn: 43)
        CelebrityActingEngine.onArrival(in: &late, catalog: [event])
        XCTAssertNil(late.pendingActingEncounter)
        var state = session(turn: 42)
        try choose("messenger", in: &state)
        XCTAssertEqual(state.pendingActingBonuses?.first?.dueTurn, 52)
        state.day = 51
        state.cash = 0
        state.bank = 0
        state.debt = 0
        state.recordWeeklyAction(.work)
        var engine = GameEngine(seed: 91)
        try engine.finishStationaryWeek(in: &state)
        XCTAssertTrue(state.isFinished)
        XCTAssertEqual(state.cash, 2_500) // $3,000 bonus, then $500 fare.
        XCTAssertEqual(state.unreadActingNotices?.last?.cashDelta, 3_000)
        XCTAssertNotNil(state.settlement)
    }

    func testInvitationAndChoiceAreDeduplicatedAcrossVisits() throws {
        var state = session()
        CelebrityActingEngine.onArrival(in: &state, catalog: [event])
        let id = try XCTUnwrap(state.pendingActingEncounter?.id)
        CelebrityActingEngine.onArrival(in: &state, catalog: [event])
        XCTAssertTrue(state.queuedActingEncounters?.isEmpty == true)
        try CelebrityActingEngine.choose("extra", encounterID: id, in: &state)
        XCTAssertThrowsError(try CelebrityActingEngine.choose("action", encounterID: id, in: &state))
        XCTAssertEqual(state.cash, 1_000)
        XCTAssertEqual(state.health, 90)
        state.day += 1
        CelebrityActingEngine.onArrival(in: &state, catalog: [event])
        XCTAssertNil(state.pendingActingEncounter)
        XCTAssertTrue(state.resolvedActingEventIDs?.contains(event.id) == true)
    }

    func testInvalidRoleDoesNotConsumeInvitationOrMoney() throws {
        var state = session()
        CelebrityActingEngine.onArrival(in: &state, catalog: [event])
        let id = try XCTUnwrap(state.pendingActingEncounter?.id)
        XCTAssertThrowsError(try CelebrityActingEngine.choose("typo", encounterID: id, in: &state))
        XCTAssertEqual(state.pendingActingEncounter?.id, id)
        XCTAssertEqual(state.cash, 1_000)
        XCTAssertEqual(state.health, 80)
        XCTAssertNil(state.pendingActingBonuses)
    }

    func testPendingAndCompletedContractsRoundTripWithoutDuplicatePayment() throws {
        var state = session()
        CelebrityActingEngine.onArrival(in: &state, catalog: [event])
        state = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(state))
        let id = try XCTUnwrap(state.pendingActingEncounter?.id)
        try CelebrityActingEngine.choose("action", encounterID: id, in: &state)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = ProfileRepository(directoryURL: directory)
        try repo.save(GameSnapshot(profileID: .one, session: state, randomCheckpoint: 42))
        state = try XCTUnwrap(repo.load(.one)).session
        XCTAssertEqual(state.pendingActingBonuses?.first?.amount, 6_000)
        XCTAssertEqual(state.unreadActingNotices?.count, 1)
        state.day = 15
        CelebrityActingEngine.settleDue(in: &state)
        try repo.save(GameSnapshot(profileID: .one, session: state, randomCheckpoint: 42))
        state = try XCTUnwrap(repo.load(.one)).session
        CelebrityActingEngine.settleDue(in: &state)
        XCTAssertEqual(state.cash, 7_600)
        XCTAssertEqual(state.unreadActingNotices?.count, 2)
    }

    func testVersion5WithoutActingFieldsStillRestores() throws {
        let snapshot = GameSnapshot(version: 5, profileID: .one, session: session(), randomCheckpoint: 42)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        var old = try XCTUnwrap(object["session"] as? [String: Any])
        for key in ["pendingActingEncounter", "queuedActingEncounters", "lastActingArrivalTurn", "resolvedActingEventIDs", "pendingActingBonuses", "unreadActingNotices"] { old.removeValue(forKey: key) }
        object["session"] = old
        let decoded = try JSONDecoder().decode(GameSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        let restored = try GameSnapshotMigration.migrate(decoded)
        XCTAssertEqual(restored.version, GameSnapshot.currentVersion)
        XCTAssertEqual(restored.session.cash, 1_000)
        XCTAssertNil(restored.session.pendingActingEncounter)
        XCTAssertNil(restored.session.pendingActingBonuses)
    }

    @MainActor
    func testNoticesWaitTheirTurnAndStayReadableAfterDeath() throws {
        let store = GameStore(seed: 42)
        store.isIntroductionPresented = false
        store.session = session()
        CelebrityActingEngine.onArrival(in: &store.session, catalog: [event])
        store.notice = UserNotice(title: "先看地点遭遇", message: "")
        XCTAssertEqual(store.presentation, .notice)
        store.dismissNotice()
        XCTAssertEqual(store.presentation, .acting)
        var engine = GameEngine(seed: 42)
        XCTAssertThrowsError(try engine.travel(to: .irvine, session: &store.session))
        XCTAssertThrowsError(try engine.expandCapacity(in: &store.session))
        store.session.health = 5
        let id = try XCTUnwrap(store.session.pendingActingEncounter?.id)
        store.chooseActingRole("action", encounterID: id)
        XCTAssertTrue(store.session.isFinished)
        XCTAssertEqual(store.presentation, .acting)
        let notice = try XCTUnwrap(store.actingNotice)
        XCTAssertEqual(notice.healthDelta, -5)
        let cash = store.session.cash
        store.dismissActingNotice(notice.id)
        store.dismissActingNotice(notice.id)
        XCTAssertEqual(store.presentation, .result)
        XCTAssertEqual(store.session.cash, cash)
    }

    func testCatalogRejectsInvalidActingReferencesAmountsAndDuplicateChoices() throws {
        let source = try XCTUnwrap(EventContentCatalog.bundledContentURL)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.copyItem(at: source, to: directory)
        let file = directory.appendingPathComponent("events/celebrities/wu-yu-sen.json")
        let original = try Data(contentsOf: file)
        for mutation in 0 ..< 4 {
            var definitions = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [[String: Any]])
            switch mutation {
            case 0: definitions[0]["sourceNPCID"] = "unknown-person"
            case 1: definitions[0]["delayTurns"] = 0
            case 2: definitions[0]["bonusMultiplier"] = 101
            default:
                var options = try XCTUnwrap(definitions[0]["options"] as? [[String: Any]])
                options[1]["id"] = options[0]["id"]
                definitions[0]["options"] = options
            }
            try JSONSerialization.data(withJSONObject: definitions).write(to: file)
            XCTAssertThrowsError(try EventContentCatalog.load(from: directory))
        }
    }
}
