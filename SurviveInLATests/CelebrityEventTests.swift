import XCTest
@testable import SurviveInLA

final class CelebrityEventTests: XCTestCase {
    private var event: CelebrityPhotoEventDefinition { EventContentCatalog.bundled.celebrityPhotoEvents[0] }

    private func session(turn: Int = 5, luck: Int = 70) -> GameSession {
        var engine = GameEngine(seed: 37)
        var session = engine.makeNewSession()
        session.day = turn
        session.currentDistrictID = .santaMonica
        session.currentLuck = luck
        session.health = 80
        session.cash = 1000
        return session
    }

    @discardableResult
    private func photograph(_ background: String, in session: inout GameSession) throws -> String {
        CelebrityEventEngine.onArrival(in: &session, catalog: [event])
        let id = try XCTUnwrap(session.pendingCelebrityEncounter?.id)
        try CelebrityEventEngine.respondToInvitation(encounterID: id, approach: true, in: &session)
        try CelebrityEventEngine.chooseBackground(background, encounterID: id, in: &session)
        return id
    }

    func testRegistryIncludesAllThreePeopleAndBothInteractionKinds() {
        let catalog = EventContentCatalog.bundled
        XCTAssertEqual(catalog.celebritiesByID["chen-guanxi"]?.title, "陈冠希")
        XCTAssertEqual(catalog.celebritiesByID["xu-jinglei"]?.title, "徐静蕾")
        XCTAssertEqual(catalog.celebritiesByID["jia-yueting"]?.title, "贾跃亭")
        XCTAssertEqual(catalog.investmentEvents[0].id, "jia-ff-night-market")
        XCTAssertEqual(catalog.investmentEvents[0].interactionKind, .investment)
        XCTAssertEqual(event.interactionKind, .photo)
        XCTAssertEqual(event.options.map(\.salePrice), [300, 500, 800])
    }

    func testOnlySantaMonicaAndStrictlyGreaterThanSixtyAreEligible() {
        for district in District.ID.allCases {
            for luck in [0, 59, 60, 61, 100] {
                var session = session(luck: luck)
                session.currentDistrictID = district
                CelebrityEventEngine.onArrival(in: &session, catalog: [event])
                XCTAssertEqual(session.pendingCelebrityEncounter != nil, district == .santaMonica && luck > 60)
            }
        }
    }

    func testDecliningCannotRepeatOnTheSameArrivalButNextVisitCanTrigger() throws {
        var session = session()
        CelebrityEventEngine.onArrival(in: &session, catalog: [event])
        let first = try XCTUnwrap(session.pendingCelebrityEncounter?.id)
        try CelebrityEventEngine.respondToInvitation(encounterID: first, approach: false, in: &session)
        CelebrityEventEngine.onArrival(in: &session, catalog: [event])
        XCTAssertNil(session.pendingCelebrityEncounter)
        XCTAssertNil(session.celebrityPhotos)
        XCTAssertEqual(session.cash, 1000)
        session.day += 2
        CelebrityEventEngine.onArrival(in: &session, catalog: [event])
        XCTAssertNotEqual(session.pendingCelebrityEncounter?.id, first)
    }

    func testTravelTriggersWithoutAnExtraChanceAndStayingDoesNotTrigger() throws {
        for seed in 1 ... 30 {
            var engine = GameEngine(seed: UInt64(seed))
            var session = engine.makeNewSession()
            session.currentLuck = 61
            try engine.travel(to: .santaMonica, session: &session)
            XCTAssertNotNil(session.pendingCelebrityEncounter, "seed \(seed)")
        }
        var engine = GameEngine(seed: 37)
        var session = session(turn: 2, luck: 100)
        session.completedActionsThisWeek = [.work]
        try engine.finishStationaryWeek(in: &session)
        XCTAssertNil(session.pendingCelebrityEncounter)
    }

    func testEveryBackgroundCreatesOnePhotoAndCorrectBuffWithoutAutomaticSale() throws {
        for option in event.options {
            var session = session()
            let id = try photograph(option.id, in: &session)
            XCTAssertEqual(session.pendingCelebrityEncounter?.stage, .result)
            XCTAssertEqual(session.celebrityPhotos?.count, 1)
            XCTAssertEqual(session.celebrityPhotos?.first?.salePrice, option.salePrice)
            XCTAssertEqual(session.playerBuffs?.first?.definition, option.buff)
            XCTAssertEqual(session.cash, 1000)
            XCTAssertThrowsError(try CelebrityEventEngine.chooseBackground(option.id, encounterID: id, in: &session))
            XCTAssertEqual(session.celebrityPhotos?.count, 1)
            XCTAssertEqual(session.playerBuffs?.count, 1)
        }
    }

    func testInvalidOrStaleChoiceDoesNotGrantAnything() throws {
        var session = session()
        CelebrityEventEngine.onArrival(in: &session, catalog: [event])
        let id = try XCTUnwrap(session.pendingCelebrityEncounter?.id)
        XCTAssertThrowsError(try CelebrityEventEngine.chooseBackground("beach", encounterID: id, in: &session))
        try CelebrityEventEngine.respondToInvitation(encounterID: id, approach: true, in: &session)
        XCTAssertThrowsError(try CelebrityEventEngine.chooseBackground("unknown", encounterID: id, in: &session))
        XCTAssertThrowsError(try CelebrityEventEngine.chooseBackground("beach", encounterID: "old-visit", in: &session))
        XCTAssertNil(session.playerBuffs)
        XCTAssertNil(session.celebrityPhotos)
    }

    func testSaleIsFixedAndIdempotentAndDoesNotRemoveTheBuff() throws {
        for option in event.options {
            var session = session()
            let id = try photograph(option.id, in: &session)
            let photoID = try XCTUnwrap(session.celebrityPhotos?.first?.id)
            try CelebrityEventEngine.finishEncounter(encounterID: id, sell: true, in: &session)
            XCTAssertEqual(session.cash, 1000 + option.salePrice)
            XCTAssertEqual(session.celebrityPhotos?.first?.soldTurn, 5)
            XCTAssertEqual(session.currentPlayerBuffs.count, 1)
            XCTAssertThrowsError(try CelebrityEventEngine.finishEncounter(encounterID: id, sell: true, in: &session))
            XCTAssertThrowsError(try CelebrityEventEngine.sellPhoto(photoID, in: &session))
            XCTAssertEqual(session.cash, 1000 + option.salePrice)
        }
    }

    func testKeptPhotoCanBeSoldAfterLeavingAndLoadingTheGame() throws {
        var session = session()
        let id = try photograph("route-66", in: &session)
        try CelebrityEventEngine.finishEncounter(encounterID: id, sell: false, in: &session)
        session = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(session))
        session.currentDistrictID = .hollywood
        let photoID = try XCTUnwrap(session.celebrityPhotos?.first?.id)
        try CelebrityEventEngine.sellPhoto(photoID, in: &session)
        session = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(session))
        XCTAssertThrowsError(try CelebrityEventEngine.sellPhoto(photoID, in: &session))
        XCTAssertEqual(session.cash, 1800)
    }

    func testSaveRestoresEveryPendingStageAndDoesNotGrantTwice() throws {
        var session = session()
        CelebrityEventEngine.onArrival(in: &session, catalog: [event])
        let id = try XCTUnwrap(session.pendingCelebrityEncounter?.id)
        func restored(_ value: GameSession) throws -> GameSession {
            try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(value))
        }
        session = try restored(session)
        XCTAssertEqual(session.pendingCelebrityEncounter?.stage, .invitation)
        try CelebrityEventEngine.respondToInvitation(encounterID: id, approach: true, in: &session)
        session = try restored(session)
        XCTAssertEqual(session.pendingCelebrityEncounter?.stage, .background)
        try CelebrityEventEngine.chooseBackground("beach", encounterID: id, in: &session)
        session = try restored(session)
        XCTAssertEqual(session.pendingCelebrityEncounter?.selectedOptionID, "beach")
        XCTAssertThrowsError(try CelebrityEventEngine.chooseBackground("ferris-wheel", encounterID: id, in: &session))
        XCTAssertEqual(session.currentPlayerBuffs.count, 1)
    }

    func testLuckBuffExpiresWithoutCorruptingClampedBaseLuck() throws {
        var session = session(luck: 95)
        _ = try photograph("ferris-wheel", in: &session)
        XCTAssertEqual(session.currentLuck, 100)
        EventEffectExecutor.apply([.luck(amount: -5)], reason: "another event", healthMultiplier: 1, to: &session)
        XCTAssertEqual(session.baseLuck, 90)
        for turn in 6 ... 8 { session.day = turn; PlayerBuffEngine.advance(in: &session) }
        XCTAssertEqual(session.currentLuck, 90)
        XCTAssertTrue(session.currentPlayerBuffs.isEmpty)
    }

    func testSameBuffStacksAndEachInstanceExpiresIndependently() throws {
        var session = session(luck: 61)
        let definition = event.options[0].buff
        PlayerBuffEngine.grant(definition, instanceID: "one", sourceEventID: event.id, in: &session)
        PlayerBuffEngine.grant(definition, instanceID: "one", sourceEventID: event.id, in: &session)
        XCTAssertEqual(session.currentPlayerBuffs.count, 1)
        session.day = 6; PlayerBuffEngine.advance(in: &session)
        PlayerBuffEngine.grant(definition, instanceID: "two", sourceEventID: event.id, in: &session)
        XCTAssertEqual(session.currentLuck, 81)
        session.day = 8; PlayerBuffEngine.advance(in: &session)
        XCTAssertEqual(session.currentLuck, 71)
        session.day = 9; PlayerBuffEngine.advance(in: &session)
        XCTAssertEqual(session.currentLuck, 61)
    }

    func testBeachHealsOnExactlyThreeTransitionsAndRepeatedTickIsHarmless() throws {
        var session = session()
        _ = try photograph("beach", in: &session)
        PlayerBuffEngine.advance(in: &session)
        XCTAssertEqual(session.health, 80)
        for turn in 6 ... 8 {
            session.day = turn
            PlayerBuffEngine.advance(in: &session)
            let health = session.health
            PlayerBuffEngine.advance(in: &session)
            XCTAssertEqual(session.health, health)
        }
        XCTAssertEqual(session.health, 92)
        session.day = 9; PlayerBuffEngine.advance(in: &session)
        XCTAssertEqual(session.health, 92)
    }

    func testRoadSignBuffMultipliesActualWorkIncome() throws {
        var baselineEngine = GameEngine(seed: 21)
        var boostedEngine = GameEngine(seed: 21)
        var baseline = baselineEngine.makeNewSession()
        var boosted = boostedEngine.makeNewSession()
        PlayerBuffEngine.grant(event.options[2].buff, instanceID: "boost", sourceEventID: event.id, in: &boosted)
        let ordinary = try baselineEngine.work(in: &baseline)
        let better = try boostedEngine.work(in: &boosted)
        XCTAssertEqual(better.cashDelta, Int((Double(ordinary.cashDelta) * 1.15).rounded()))
        XCTAssertEqual(boostedEngine.randomCheckpoint, baselineEngine.randomCheckpoint)
    }

    func testFinalArrivalWaitsForThePhotoDecisionBeforeJourneySettlement() throws {
        var engine = GameEngine(seed: 37)
        var session = session(turn: 51)
        session.currentDistrictID = .hollywood
        session.debt = 0
        try engine.travel(to: .santaMonica, session: &session)
        XCTAssertEqual(session.day, 52)
        XCTAssertFalse(session.isFinished)
        let id = try XCTUnwrap(session.pendingCelebrityEncounter?.id)
        engine.endJourney(session: &session)
        XCTAssertFalse(session.isFinished)
        try engine.respondToCelebrityInvitation(id, approach: true, in: &session)
        try engine.chooseCelebrityBackground("route-66", encounterID: id, in: &session)
        try engine.finishCelebrityEncounter(id, sell: true, in: &session)
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.celebrityPhotos?.first?.soldTurn, 52)
        XCTAssertEqual(session.cash, 1300)
    }

    func testMultipleEligibleCelebrityEventsQueueWithoutDroppingAny() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any])
        object["id"] = "second-photo-story"
        let second = try JSONDecoder().decode(CelebrityPhotoEventDefinition.self, from: JSONSerialization.data(withJSONObject: object))
        var session = session()
        CelebrityEventEngine.onArrival(in: &session, catalog: [event, second])
        XCTAssertEqual(session.queuedCelebrityEncounters?.count, 1)
        let firstID = try XCTUnwrap(session.pendingCelebrityEncounter?.id)
        try CelebrityEventEngine.respondToInvitation(encounterID: firstID, approach: false, in: &session)
        XCTAssertEqual(session.pendingCelebrityEncounter?.event.id, second.id)
        session = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(session))
        let secondID = try XCTUnwrap(session.pendingCelebrityEncounter?.id)
        try CelebrityEventEngine.respondToInvitation(encounterID: secondID, approach: false, in: &session)
        XCTAssertNil(session.pendingCelebrityEncounter)
        XCTAssertTrue(session.queuedCelebrityEncounters?.isEmpty == true)
    }

    func testOldSaveWithoutCelebrityFieldsRemainsReadable() throws {
        var old = session()
        old.pendingInvestmentInvitation = EventContentCatalog.bundled.investmentEvents[0]
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        for key in ["pendingCelebrityEncounter", "queuedCelebrityEncounters", "lastCelebrityArrivalTurn", "celebrityPhotos", "playerBuffs"] { object.removeValue(forKey: key) }
        let restored = try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(restored.pendingCelebrityEncounter)
        XCTAssertEqual(restored.currentLuck, 70)
        XCTAssertEqual(restored.pendingInvestmentInvitation?.id, "jia-ff-night-market")
    }

    @MainActor
    func testCelebrityPopupWaitsForOtherNoticesAndPendingActionsBlockTravel() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = GameStore(seed: 37, repository: ProfileRepository(directoryURL: directory))
        store.isIntroductionPresented = false
        store.session = session()
        CelebrityEventEngine.onArrival(in: &store.session, catalog: [event])
        store.notice = UserNotice(title: "other", message: "pending")
        XCTAssertFalse(store.canPresentCelebrityEvent)
        store.notice = nil
        store.session.pendingInvestmentInvitation = EventContentCatalog.bundled.investmentEvents[0]
        XCTAssertFalse(store.canPresentCelebrityEvent)
        store.session.pendingInvestmentInvitation = nil
        XCTAssertTrue(store.canPresentCelebrityEvent)
        var engine = GameEngine(seed: 37)
        XCTAssertThrowsError(try engine.travel(to: .hollywood, session: &store.session))
    }
}
