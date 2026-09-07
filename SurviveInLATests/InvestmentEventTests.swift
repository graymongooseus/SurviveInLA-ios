import XCTest
@testable import SurviveInLA

final class InvestmentEventTests: XCTestCase {
    private var definition: InvestmentEventDefinition { EventContentCatalog.bundled.investmentEvents[0] }

    private func configured(chance: Double = 1, profitChance: Double = 1) throws -> InvestmentEventDefinition {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(definition)) as? [String: Any])
        object["encounterChance"] = chance
        object["profitChance"] = profitChance
        return try JSONDecoder().decode(InvestmentEventDefinition.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func session(turn: Int = 5) -> GameSession {
        var engine = GameEngine(seed: 123)
        var session = engine.makeNewSession()
        session.day = turn
        session.currentDistrictID = .rowlandHeights
        session.cash = 20_000
        return session
    }

    func testInvitationOnlyAppearsInRowlandWithEnoughRemainingTurns() throws {
        let event = try configured()
        for district in District.ID.allCases {
            var session = session()
            session.currentDistrictID = district
            var random = SeededRandomNumberGenerator(seed: 1)
            let before = random.checkpoint
            InvestmentEventEngine.offer(in: &session, catalog: [event], using: &random)
            XCTAssertEqual(session.pendingInvestmentInvitation != nil, district == .rowlandHeights)
            if district != .rowlandHeights { XCTAssertEqual(random.checkpoint, before) }
        }
        for turn in [42, 43] {
            var session = session(turn: turn)
            var random = SeededRandomNumberGenerator(seed: 1)
            InvestmentEventEngine.offer(in: &session, catalog: [event], using: &random)
            XCTAssertEqual(session.pendingInvestmentInvitation != nil, turn == 42)
        }
    }

    func testDecliningSpendsNothingAndDoesNotRepeatOrDrawOutcome() throws {
        var session = session()
        session.pendingInvestmentInvitation = try configured()
        var random = SeededRandomNumberGenerator(seed: 9)
        let before = random.checkpoint
        try InvestmentEventEngine.respond(amount: nil, in: &session, using: &random)
        XCTAssertEqual(session.cash, 20_000)
        XCTAssertEqual(random.checkpoint, before)
        XCTAssertNil(session.pendingInvestments)
        XCTAssertNil(session.pendingInvestmentInvitation)
        session.day += 1
        InvestmentEventEngine.offer(in: &session, catalog: [try configured()], using: &random)
        XCTAssertNil(session.pendingInvestmentInvitation)
    }

    func testInvalidAmountsLeaveInvitationCashAndRandomStateUntouched() throws {
        var session = session()
        session.pendingInvestmentInvitation = try configured()
        var random = SeededRandomNumberGenerator(seed: 12)
        let before = random.checkpoint
        for amount in [-1, 0, 20_001, Int.max] {
            XCTAssertThrowsError(try InvestmentEventEngine.respond(amount: amount, in: &session, using: &random))
            XCTAssertEqual(session.cash, 20_000)
            XCTAssertNotNil(session.pendingInvestmentInvitation)
            XCTAssertEqual(random.checkpoint, before)
            XCTAssertNil(session.pendingInvestments)
        }
    }

    func testCustomAmountSettlesExactlyTenTurnsLaterOffSiteAndOnlyOnce() throws {
        var session = session()
        session.pendingInvestmentInvitation = try configured()
        var random = SeededRandomNumberGenerator(seed: 12)
        try InvestmentEventEngine.respond(amount: 777, in: &session, using: &random)
        XCTAssertEqual(session.cash, 20_000 - 777)
        XCTAssertThrowsError(try InvestmentEventEngine.respond(amount: 777, in: &session, using: &random))
        let investment = try XCTUnwrap(session.pendingInvestments?.first)
        XCTAssertEqual(investment.dueTurn, 15)
        session.currentDistrictID = .hollywood
        session.day = 14
        InvestmentEventEngine.settleDue(in: &session)
        XCTAssertEqual(session.cash, 20_000 - 777)
        session.day = 15
        InvestmentEventEngine.settleDue(in: &session)
        XCTAssertEqual(session.cash, 20_000 + investment.profitAmount)
        let count = session.unreadInvestmentNotices?.count
        InvestmentEventEngine.settleDue(in: &session)
        XCTAssertEqual(session.cash, 20_000 + investment.profitAmount)
        XCTAssertEqual(session.unreadInvestmentNotices?.count, count)
        XCTAssertTrue(session.pendingInvestments?.isEmpty == true)
    }

    func testLossReturnsRemainingPrincipalWithoutChargingTwice() throws {
        var session = session()
        session.pendingInvestmentInvitation = try configured(profitChance: 0)
        var random = SeededRandomNumberGenerator(seed: 13)
        try InvestmentEventEngine.respond(amount: 1000, in: &session, using: &random)
        session.day += 10
        InvestmentEventEngine.settleDue(in: &session)
        XCTAssertEqual(session.cash, 19_600)
        XCTAssertEqual(session.unreadInvestmentNotices?.last?.kind, .setback)
        XCTAssertTrue(session.unreadInvestmentNotices?.last?.message.contains("亏损") == true)
    }

    func testSmallInvestmentsStillHaveARealGainOrBoundedLoss() throws {
        for chance in [0.0, 1.0] {
            var session = session()
            session.pendingInvestmentInvitation = try configured(profitChance: chance)
            var random = SeededRandomNumberGenerator(seed: 2)
            try InvestmentEventEngine.respond(amount: 1, in: &session, using: &random)
            let investment = try XCTUnwrap(session.pendingInvestments?.first)
            XCTAssertEqual(investment.profitAmount, chance == 1 ? 1 : -1)
            XCTAssertGreaterThanOrEqual(investment.payout, 0)
        }
    }

    func testAuthoredOddsProduceManyGainsAndSomeLossesWithoutSpoilingInvitation() throws {
        var gains = 0
        for seed in 1 ... 500 {
            var session = session()
            session.pendingInvestmentInvitation = definition
            var random = SeededRandomNumberGenerator(seed: UInt64(seed))
            try InvestmentEventEngine.respond(amount: 100, in: &session, using: &random)
            if try XCTUnwrap(session.pendingInvestments?.first).profitAmount > 0 { gains += 1 }
            let visible = definition.invitation.message + (session.unreadInvestmentNotices?.first?.message ?? "")
            for spoiler in ["概率", "85%", "50%", "40%", "10回合", "10 回合", "大概率", "稳赚"] {
                XCTAssertFalse(visible.contains(spoiler))
            }
        }
        XCTAssertGreaterThan(gains, 375)
        XCTAssertLessThan(gains, 475)
    }

    func testSaveRestoreFreezesOutcomeAndRestoresUnreadResult() throws {
        var session = session()
        session.pendingInvestmentInvitation = definition
        var random = SeededRandomNumberGenerator(seed: 93)
        try InvestmentEventEngine.respond(amount: 1234, in: &session, using: &random)
        let original = try XCTUnwrap(session.pendingInvestments?.first)
        let snapshot = GameSnapshot(profileID: .one, session: session, randomCheckpoint: random.checkpoint)
        var restored = try JSONDecoder().decode(GameSnapshot.self, from: JSONEncoder().encode(snapshot)).session
        XCTAssertEqual(restored.pendingInvestments?.first, original)
        restored.day = original.dueTurn
        InvestmentEventEngine.settleDue(in: &restored)
        let reread = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(restored))
        XCTAssertEqual(reread.unreadInvestmentNotices?.last?.id, "\(original.id)-settled")
        XCTAssertEqual(reread.cash, 20_000 + original.profitAmount)
    }

    func testVersionThreeSaveWithoutInvestmentFieldsStillDecodes() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(session())) as? [String: Any])
        for key in ["pendingInvestmentInvitation", "resolvedInvestmentEventIDs", "lastInvestmentEventCheckTurn", "pendingInvestments", "unreadInvestmentNotices"] { object.removeValue(forKey: key) }
        let restored = try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(restored.pendingInvestmentInvitation)
        XCTAssertNil(restored.pendingInvestments)
        XCTAssertEqual(restored.cash, 20_000)
    }

    func testTravelAndStationaryAdvanceBothDeliverMatureInvestments() throws {
        for travel in [false, true] {
            var session = session(turn: 5)
            session.pendingInvestmentInvitation = try configured()
            var engine = GameEngine(seed: 22)
            try engine.respondToInvestmentInvitation(amount: 100, in: &session)
            session.day = 14
            session.recordWeeklyAction(.trading)
            if travel { try engine.travel(to: .hollywood, session: &session) }
            else { try engine.finishStationaryWeek(in: &session) }
            XCTAssertEqual(session.day, 15)
            XCTAssertTrue(session.pendingInvestments?.isEmpty == true)
            XCTAssertTrue(session.unreadInvestmentNotices?.contains { $0.id.hasSuffix("-settled") } == true)
        }
    }

    func testFinalTurnPaysBeforeJourneySettlement() throws {
        var session = session(turn: 42)
        session.pendingInvestmentInvitation = try configured()
        var engine = GameEngine(seed: 22)
        try engine.respondToInvestmentInvitation(amount: 100, in: &session)
        session.day = 51
        try engine.travel(to: .hollywood, session: &session)
        XCTAssertTrue(session.isFinished)
        XCTAssertTrue(session.pendingInvestments?.isEmpty == true)
        XCTAssertTrue(session.unreadInvestmentNotices?.contains { $0.id.hasSuffix("-settled") } == true)
    }

    @MainActor
    func testWorldAndInvestmentNoticesQueueWithoutReapplyingMoney() throws {
        var session = session()
        session.pendingInvestmentInvitation = try configured()
        let store = GameStore(snapshot: GameSnapshot(profileID: .one, session: session, randomCheckpoint: 22))
        store.respondToInvestmentInvitation(amount: 100)
        let cash = store.session.cash
        let id = try XCTUnwrap(store.investmentNotice?.id)
        store.worldEventNotice = WorldEventNotice(eventID: WorldEventCatalog.events[0].id, triggeredWeek: 5, endingWeek: 8, localNotice: nil)
        XCTAssertFalse(store.canPresentInvestmentEvent)
        store.dismissWorldEvent()
        XCTAssertTrue(store.canPresentInvestmentEvent)
        store.dismissInvestmentNotice(id)
        store.dismissInvestmentNotice(id)
        XCTAssertNil(store.investmentNotice)
        XCTAssertEqual(store.session.cash, cash)
    }
}
