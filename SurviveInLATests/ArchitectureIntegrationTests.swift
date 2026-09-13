import XCTest
@testable import SurviveInLA

final class ArchitectureIntegrationTests: XCTestCase {
    private func buff(health: Int = 4) -> PlayerBuffDefinition {
        PlayerBuffDefinition(id: "turn-test", title: "逐回合测试", message: "", durationTurns: 3,
                             luckDelta: 0, healthPerTurn: health, workIncomeMultiplier: 1)
    }

    func testAllTurnEntrancesSettleInvestmentsBuffsAndInterestExactlyOnce() throws {
        for route in 0 ..< 3 {
            var engine = GameEngine(seed: 42)
            var session = engine.makeNewSession()
            session.day = 4
            session.health = 80
            session.bank = 1_000
            session.recordWeeklyAction(.work)
            PlayerBuffEngine.grant(buff(), instanceID: "buff", sourceEventID: "test", in: &session)
            session.pendingInvestments = [ScheduledInvestment(
                id: "due", sourceNPCID: "jia-yueting", principal: 100, investedTurn: 1,
                dueTurn: 5, profitAmount: 50, resultStory: EventStory(title: "到期测试", message: "到账")
            )]
            switch route {
            case 0: try engine.travel(to: .hollywood, session: &session)
            case 1: try engine.finishStationaryWeek(in: &session)
            default: engine.skipStationaryWeeks(1, in: &session)
            }
            XCTAssertEqual(session.day, 5)
            XCTAssertEqual(session.bank, 1_002)
            XCTAssertEqual(session.debt, 5_100)
            XCTAssertEqual(session.currentPlayerBuffs.first?.remainingTurns, 2)
            XCTAssertEqual(session.history(for: .health).filter { $0.reason == "逐回合测试" }.map(\.delta), [4])
            XCTAssertEqual(session.history(for: .cash).filter { $0.reason == "到期测试" }.map(\.delta), [150])
            XCTAssertTrue(session.pendingInvestments?.isEmpty == true)
            XCTAssertEqual(session.unreadInvestmentNotices?.count, 1)
            XCTAssertEqual(session.lastWorldEventDrawWeek, 5)
        }
    }

    func testFatalBuffStopsMultiTurnAdvanceBeforeNewEvents() {
        var engine = GameEngine(seed: 42)
        var session = engine.makeNewSession()
        session.day = 7
        session.health = 1
        session.latestEvent = GameEvent(id: "previous", kind: .opportunity, title: "上一回合", message: "已经处理")
        PlayerBuffEngine.grant(buff(health: -4), instanceID: "fatal", sourceEventID: "test", in: &session)
        let checkpoint = engine.randomCheckpoint
        engine.skipStationaryWeeks(5, in: &session)
        XCTAssertEqual(session.day, 8)
        XCTAssertEqual(session.health, 0)
        XCTAssertNil(session.latestEvent)
        XCTAssertNil(session.pendingLifeChoiceID)
        XCTAssertNil(session.pendingCelebrityEncounter)
        XCTAssertEqual(engine.randomCheckpoint, checkpoint)
        XCTAssertEqual(session.history(for: .debt).filter { $0.reason == "每周欠款利息" }.count, 1)
    }

    func testMultiTurnAdvancePausesAtChoiceAndResetsPreviousActions() throws {
        var engine = GameEngine(seed: 42)
        var session = engine.makeNewSession()
        session.day = 7
        session.recordWeeklyAction(.work)
        engine.skipStationaryWeeks(3, in: &session)
        XCTAssertEqual(session.day, 8)
        XCTAssertEqual(session.pendingInteraction, .lifeChoice)
        XCTAssertFalse(session.hasCompletedAnyWeeklyAction)
        let choice = try XCTUnwrap(session.pendingLifeChoiceID.flatMap(GameContent.lifeChoice))
        _ = try engine.resolveLifeChoice(choice.options[0].id, in: &session)
        XCTAssertNoThrow(try engine.work(in: &session))
    }

    func testCapacityUpgradeCannotBypassAnyPendingDecision() throws {
        for kind in [PendingInteraction.lifeChoice, .investment, .celebrity, .acting] {
            var engine = GameEngine(seed: 42)
            var session = engine.makeNewSession()
            session.cash = 100_000
            switch kind {
            case .lifeChoice: session.pendingLifeChoiceID = GameContent.lifeChoices[0].id
            case .investment: session.pendingInvestmentInvitation = EventContentCatalog.bundled.investmentEvents[0]
            case .acting:
                session.currentDistrictID = .hollywood
                session.baseLuck = 55
                CelebrityActingEngine.onArrival(in: &session, catalog: EventContentCatalog.bundled.celebrityActingEvents)
            case .celebrity:
                session.currentDistrictID = .santaMonica
                session.baseLuck = 70
                CelebrityEventEngine.onArrival(in: &session, catalog: EventContentCatalog.bundled.celebrityPhotoEvents)
            }
            let cash = session.cash
            let capacity = session.capacity
            let checkpoint = engine.randomCheckpoint
            XCTAssertThrowsError(try engine.expandCapacity(in: &session))
            XCTAssertEqual(session.cash, cash)
            XCTAssertEqual(session.capacity, capacity)
            XCTAssertEqual(engine.randomCheckpoint, checkpoint)
        }
    }

    func testFinalSettlementWaitsForAllPendingChoicesAndRunsOnce() throws {
        var engine = GameEngine(seed: 42)
        var session = engine.makeNewSession()
        session.day = 52
        session.currentDistrictID = .santaMonica
        session.baseLuck = 70
        CelebrityEventEngine.onArrival(in: &session, catalog: EventContentCatalog.bundled.celebrityPhotoEvents)
        let choice = GameContent.lifeChoices[0]
        session.pendingLifeChoiceID = choice.id
        session.pendingInvestmentInvitation = EventContentCatalog.bundled.investmentEvents[0]
        engine.endJourney(session: &session)
        XCTAssertEqual(session.day, 52)
        _ = try engine.resolveLifeChoice(choice.options[0].id, in: &session)
        XCTAssertEqual(session.day, 52)
        try engine.respondToInvestmentInvitation(amount: nil, in: &session)
        XCTAssertEqual(session.day, 52)
        let encounter = try XCTUnwrap(session.pendingCelebrityEncounter)
        try engine.respondToCelebrityInvitation(encounter.id, approach: false, in: &session)
        XCTAssertEqual(session.day, 53)
        XCTAssertNotNil(session.settlement)
        let cash = session.cash
        let debt = session.debt
        engine.endJourney(session: &session)
        XCTAssertEqual(session.cash, cash)
        XCTAssertEqual(session.debt, debt)
    }

    @MainActor
    func testPresentationDrainsWorldNoticesBeforeChoicesAndKeepsCelebrityPending() throws {
        let store = GameStore(seed: 42)
        store.isIntroductionPresented = false
        store.session.day = 8
        store.session.currentDistrictID = .santaMonica
        store.session.baseLuck = 70
        CelebrityEventEngine.onArrival(in: &store.session, catalog: EventContentCatalog.bundled.celebrityPhotoEvents)
        let encounterID = store.session.pendingCelebrityEncounter?.id
        let choice = GameContent.lifeChoices[0]
        store.session.pendingLifeChoiceID = choice.id
        store.session.pendingInvestmentInvitation = EventContentCatalog.bundled.investmentEvents[0]
        let worlds = WorldEventCatalog.events.prefix(2).map {
            ActiveWorldEvent(eventID: $0.id, startedWeek: 8, endingWeek: 10)
        }
        store.session.unreadWorldEvents = worlds
        store.worldEventNotice = WorldEventNotice(eventID: worlds[0].eventID, triggeredWeek: 8, endingWeek: 10,
                                                  localNotice: UserNotice(title: "抵达", message: "地点通知"))
        XCTAssertEqual(store.presentation, .worldEvent)
        store.dismissWorldEvent()
        XCTAssertEqual(store.presentation, .worldEvent)
        store.dismissWorldEvent()
        XCTAssertEqual(store.presentation, .notice)
        store.dismissNotice()
        XCTAssertEqual(store.presentation, .lifeChoice)
        store.resolveLifeChoice(choice.options[0].id)
        XCTAssertEqual(store.presentation, .lifeChoiceResult)
        store.dismissNotice()
        XCTAssertEqual(store.presentation, .investment)
        store.respondToInvestmentInvitation(amount: nil)
        XCTAssertEqual(store.presentation, .investment)
        store.dismissInvestmentNotice(try XCTUnwrap(store.investmentNotice?.id))
        XCTAssertEqual(store.presentation, .celebrity)
        XCTAssertEqual(store.session.pendingCelebrityEncounter?.id, encounterID)
        store.respondToCelebrityInvitation(try XCTUnwrap(encounterID), approach: false)
        XCTAssertNil(store.presentation)
    }

    @MainActor
    func testTerminalInvestmentNoticeRemainsAheadOfResultAndIgnoresStaleChoices() throws {
        let store = GameStore(seed: 42)
        store.isIntroductionPresented = false
        store.session.day = 53
        store.session.pendingLifeChoiceID = GameContent.lifeChoices[0].id
        store.session.unreadInvestmentNotices = [GameEvent(id: "due", kind: .opportunity, title: "到账", message: "已结算")]
        XCTAssertEqual(store.presentation, .investment)
        store.dismissInvestmentNotice("due")
        XCTAssertEqual(store.presentation, .result)
    }

    @MainActor
    func testRepositoryAndDirectRestoreUseIdenticalLegacyDefaults() throws {
        var engine = GameEngine(seed: 42)
        var session = engine.makeNewSession()
        session.totalDays = 40
        session.luck = nil
        session.equipment = nil
        session.cityServiceSeed = nil
        session.statusHistory = nil
        let event = WorldEventCatalog.events[0]
        session.activeWorldEvent = ActiveWorldEvent(eventID: event.id, startedWeek: 1, endingWeek: 9)
        session.latestWorldEventWeek = 1
        let old = GameSnapshot(version: 2, profileID: .one, session: session, randomCheckpoint: 123)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ProfileRepository(directoryURL: directory)
        try repository.save(old)
        let loaded = try XCTUnwrap(repository.load(.one))
        let store = GameStore(snapshot: old, repository: repository)
        XCTAssertEqual(loaded.session.totalDays, store.session.totalDays)
        XCTAssertEqual(store.session.totalDays, 52)
        XCTAssertEqual(loaded.session.currentLuck, store.session.currentLuck)
        XCTAssertEqual(store.session.currentLuck, 50)
        XCTAssertEqual(loaded.session.activeWorldEvents, store.session.activeWorldEvents)
        XCTAssertEqual(store.session.activeWorldEvent?.modifiers, event.modifiers)
        XCTAssertEqual(loaded.session.cityServiceSeed, 123)
        XCTAssertEqual(store.session.cityServiceSeed, 123)
        XCTAssertEqual(loaded.session.lastWorldEventDrawWeek, store.session.lastWorldEventDrawWeek)
        XCTAssertFalse(store.session.statusHistory?.isEmpty ?? true)
        let again = try GameSnapshotMigration.migrate(loaded)
        XCTAssertEqual(again.session.statusHistory, loaded.session.statusHistory)
    }
}
