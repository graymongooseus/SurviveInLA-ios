import XCTest
@testable import SurviveInLA

final class EventLibraryTests: XCTestCase {
    private func world(
        _ id: String,
        favorability: EventFavorability = .mixed,
        strength: Int = 1,
        duration: Int = 8,
        condition: EventCondition? = nil,
        modifiers: WorldEventModifiers = .neutral
    ) -> WorldEvent {
        WorldEvent(
            id: id, title: id, message: id, imageName: "WorldLaborEnforcement",
            selection: EventSelectionWeight(baseWeight: 1, favorability: favorability, strength: strength),
            condition: condition, durationWeeks: duration, modifiers: modifiers
        )
    }

    private var schedule: WorldEventSchedule {
        WorldEventSchedule(firstWeek: 5, intervalWeeks: 4, occurrenceChance: 1, luckScale: 3)
    }

    func testAuthoredStrengthChangesLuckWeightsMonotonically() {
        let strongGood = EventSelectionWeight(baseWeight: 1, favorability: .favorable, strength: 3)
        let weakGood = EventSelectionWeight(baseWeight: 1, favorability: .favorable, strength: 1)
        let strongBad = EventSelectionWeight(baseWeight: 1, favorability: .unfavorable, strength: 3)
        XCTAssertEqual(strongGood.weight(luck: 50, luckScale: 3), 1)
        XCTAssertEqual(strongGood.weight(luck: 100, luckScale: 3), 27, accuracy: 0.00001)
        XCTAssertGreaterThan(strongGood.weight(luck: 100, luckScale: 3), weakGood.weight(luck: 100, luckScale: 3))
        XCTAssertGreaterThan(strongBad.weight(luck: 0, luckScale: 3), strongGood.weight(luck: 0, luckScale: 3))
        XCTAssertEqual(strongBad.weight(luck: -100, luckScale: 3), strongBad.weight(luck: 0, luckScale: 3))
    }

    func testLuckActuallyChangesWhichWorldEventIsDrawn() {
        let events = [world("good", favorability: .favorable, strength: 3), world("bad", favorability: .unfavorable, strength: 3)]
        var highGood = 0
        var lowGood = 0
        for seed in 1 ... 200 {
            for luck in [0, 100] {
                var engine = GameEngine(seed: UInt64(seed))
                var session = engine.makeNewSession()
                session.day = 5
                session.currentLuck = luck
                var random = SeededRandomNumberGenerator(seed: UInt64(seed))
                WorldEventScheduler.update(in: &session, catalog: events, schedule: schedule, using: &random)
                if session.latestWorldEventID == "good" {
                    if luck == 100 { highGood += 1 } else { lowGood += 1 }
                }
            }
        }
        XCTAssertGreaterThan(highGood, 190)
        XCTAssertLessThan(lowGood, 10)
    }

    func testWorldDrawsRepeatByIntervalOverlapAndExpireIndividually() {
        var engine = GameEngine(seed: 12)
        var session = engine.makeNewSession()
        var random = SeededRandomNumberGenerator(seed: 8)
        let events = [world("first"), world("second")]
        session.day = 4
        let before = random.checkpoint
        WorldEventScheduler.update(in: &session, catalog: events, schedule: schedule, using: &random)
        XCTAssertEqual(random.checkpoint, before)
        XCTAssertTrue(session.activeWorldEvents.isEmpty)
        session.day = 5
        WorldEventScheduler.update(in: &session, catalog: events, schedule: schedule, using: &random)
        let firstID = session.activeWorldEvent?.eventID
        let after = random.checkpoint
        WorldEventScheduler.update(in: &session, catalog: events, schedule: schedule, using: &random)
        XCTAssertEqual(random.checkpoint, after)
        XCTAssertEqual(session.activeWorldEvents.count, 1)
        session.day = 9
        WorldEventScheduler.update(in: &session, catalog: events, schedule: schedule, using: &random)
        XCTAssertEqual(session.activeWorldEvents.count, 2)
        XCTAssertEqual(Set(session.activeWorldEvents.map(\.eventID)).count, 2)
        session.day = 12
        WorldEventScheduler.update(in: &session, catalog: events, schedule: schedule, using: &random)
        XCTAssertEqual(session.activeWorldEvents.count, 2)
        session.day = 13
        // No candidates prevents a replacement, so the expiry boundary is visible.
        WorldEventScheduler.update(in: &session, catalog: [], schedule: schedule, using: &random)
        XCTAssertEqual(session.activeWorldEvents.count, 1)
        XCTAssertNotEqual(session.activeWorldEvent?.eventID, firstID)
    }

    func testFailedEligibilityDoesNotConsumeRandomnessOrAllowSameWeekReroll() {
        var engine = GameEngine(seed: 1)
        var session = engine.makeNewSession()
        session.day = 5
        let events = [world("rich", condition: .metric(name: .cash, comparison: .atLeast, value: 100000))]
        var random = SeededRandomNumberGenerator(seed: 3)
        let before = random.checkpoint
        WorldEventScheduler.update(in: &session, catalog: events, schedule: schedule, using: &random)
        session.cash = 200000
        WorldEventScheduler.update(in: &session, catalog: events, schedule: schedule, using: &random)
        XCTAssertEqual(random.checkpoint, before)
        XCTAssertTrue(session.activeWorldEvents.isEmpty)
        session.day = 9
        WorldEventScheduler.update(in: &session, catalog: events, schedule: schedule, using: &random)
        XCTAssertEqual(session.activeWorldEvent?.eventID, "rich")
    }

    func testCombinedModifiersPreserveStagesAndMostRestrictiveReturnCap() {
        let first = WorldEventModifiers(workIncome: 1.2, tradeIncome: 1, bankInterest: 1, investmentReturn: 1, debtInterest: 1, healthChange: 1.5, investmentReturnCap: -20)
        let second = WorldEventModifiers(workIncome: 0.85, tradeIncome: 1, bankInterest: 1, investmentReturn: 1, debtInterest: 1, healthChange: 1.2, investmentReturnCap: -35)
        let combined = WorldEventModifiers.combined([first, second])
        XCTAssertEqual(Int((300 * combined.workIncome).rounded()), 306)
        XCTAssertEqual(combined.healthChange, 1.8, accuracy: 0.00001)
        XCTAssertEqual(combined.investmentReturnCap, -35)
        XCTAssertEqual(WorldEventModifiers.combined([]), .neutral)
    }

    func testEngineUsesAllActiveFrozenModifiersAndDropsExpiredOnes() {
        var engine = GameEngine(seed: 2)
        var session = engine.makeNewSession()
        let first = WorldEventCatalog.events[0]
        let second = WorldEventCatalog.events[1]
        session.activeWorldEvents = [
            ActiveWorldEvent(eventID: first.id, startedWeek: 1, endingWeek: 4, modifiers: first.modifiers),
            ActiveWorldEvent(eventID: second.id, startedWeek: 1, endingWeek: 8, modifiers: second.modifiers)
        ]
        XCTAssertEqual(engine.worldModifiers(for: session), .combined([first.modifiers, second.modifiers]))
        session.day = 5
        XCTAssertEqual(engine.worldModifiers(for: session), second.modifiers)
    }

    func testConditionsComposeAndRememberTheSelectedOption() throws {
        var engine = GameEngine(seed: 3)
        var session = engine.makeNewSession()
        let choice = GameContent.lifeChoices[0]
        session.pendingLifeChoiceID = choice.id
        _ = try engine.resolveLifeChoice(choice.options[1].id, in: &session)
        let condition = EventCondition.all(conditions: [
            .metric(name: .luck, comparison: .atLeast, value: 50),
            .not(condition: .equipment(item: .vehicle)),
            .any(conditions: [.district(id: .sanGabriel), .district(id: .dingPangZiPlaza)]),
            .choiceSelected(eventID: choice.id, optionID: choice.options[1].id)
        ])
        XCTAssertTrue(condition.matches(session))
        XCTAssertFalse(EventCondition.choiceSelected(eventID: choice.id, optionID: choice.options[0].id).matches(session))
        let restored = try JSONDecoder().decode(EventCondition.self, from: JSONEncoder().encode(condition))
        XCTAssertEqual(restored, condition)
    }

    func testTypedEffectsApplyInOrderAndDescribeTheActualConfiguration() {
        var engine = GameEngine(seed: 4)
        var session = engine.makeNewSession()
        let event = GameEvent(id: "effects", kind: .opportunity, title: "测试", message: "", effects: [
            .cash(amount: -2000), .cash(amount: 30), .health(amount: -10), .luck(amount: 4), .grantCommodity(commodityID: .camera, quantity: 1000)
        ])
        engine.apply(event, to: &session)
        XCTAssertEqual(session.cash, 30)
        XCTAssertEqual(session.health, 90)
        XCTAssertEqual(session.currentLuck, 54)
        XCTAssertEqual(session.usedCapacity, 100)
        XCTAssertTrue(event.baseEffectSummary.contains("现金 +$30"))
    }

    func testVersionTwoSaveWithoutNewFieldsRetainsItsActiveWorldEvent() throws {
        var engine = GameEngine(seed: 5)
        var session = engine.makeNewSession()
        session.activeWorldEvent = ActiveWorldEvent(eventID: WorldEventCatalog.events[0].id, startedWeek: 1, endingWeek: 4)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any])
        for key in ["additionalWorldEvents", "lastWorldEventDrawWeek", "unreadWorldEvents", "selectedLifeChoiceOptions"] { object.removeValue(forKey: key) }
        let restored = try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(restored.activeWorldEvents.count, 1)
        XCTAssertEqual(restored.activeWorldEvent, session.activeWorldEvent)
    }

    func testRepositoryMigratesVersionTwoAndFreezesActiveModifiers() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ProfileRepository(directoryURL: directory)
        var engine = GameEngine(seed: 5)
        var session = engine.makeNewSession()
        let event = WorldEventCatalog.events[0]
        session.day = 5
        session.activeWorldEvent = ActiveWorldEvent(eventID: event.id, startedWeek: 5, endingWeek: 8)
        session.latestWorldEventID = event.id
        session.latestWorldEventWeek = 5
        try repository.save(GameSnapshot(version: 2, profileID: .one, session: session, randomCheckpoint: engine.randomCheckpoint, contentVersion: nil))
        let restored = try XCTUnwrap(repository.load(.one))
        XCTAssertEqual(restored.version, GameSnapshot.currentVersion)
        XCTAssertEqual(restored.session.activeWorldEvents.count, 1)
        XCTAssertEqual(restored.session.activeWorldEvent?.modifiers, event.modifiers)
        XCTAssertEqual(restored.session.lastWorldEventDrawWeek, 5)
        XCTAssertEqual(restored.randomCheckpoint, engine.randomCheckpoint)
        XCTAssertEqual(restored.session.cash, session.cash)
    }

    func testRepositoryPreservesTheGeneratingContentVersionOnRead() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ProfileRepository(directoryURL: directory)
        var engine = GameEngine(seed: 7)
        try repository.save(GameSnapshot(profileID: .one, session: engine.makeNewSession(), randomCheckpoint: engine.randomCheckpoint, contentVersion: "previous-content"))
        XCTAssertEqual(try repository.load(.one)?.contentVersion, "previous-content")
    }

    func testContentLoaderRejectsDanglingConditionsAndInvalidWeights() throws {
        let source = try XCTUnwrap(EventContentCatalog.bundledContentURL)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.copyItem(at: source, to: directory)
        let file = directory.appendingPathComponent("events/world/economy.json")
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [[String: Any]])
        var events = original
        events[0]["condition"] = ["worldEventActive": ["id": "missing-world-event"]]
        try JSONSerialization.data(withJSONObject: events).write(to: file)
        XCTAssertThrowsError(try EventContentCatalog.load(from: directory)) { error in
            XCTAssertTrue(String(describing: error).contains("unknown world reference"))
        }
        events = original
        events[0]["selection"] = ["baseWeight": -1, "favorability": "favorable", "strength": 2]
        try JSONSerialization.data(withJSONObject: events).write(to: file)
        XCTAssertThrowsError(try EventContentCatalog.load(from: directory)) { error in
            XCTAssertTrue(String(describing: error).contains("invalid selection weight"))
        }
    }

    func testContentLoaderResolvesComposedConditionsAndTypedEffectsFromJSON() throws {
        let source = try XCTUnwrap(EventContentCatalog.bundledContentURL)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.copyItem(at: source, to: directory)
        let file = directory.appendingPathComponent("events/locations/money.json")
        var events = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [[String: Any]])
        events[0]["condition"] = ["all": ["conditions": [["metric": ["name": "luck", "comparison": "atLeast", "value": 60]]]]]
        events[0]["effects"] = [["cash": ["amount": 321]], ["luck": ["amount": 2]]]
        for key in ["cashDelta", "healthDelta", "reputationDelta", "luckDelta"] { events[0][key] = 0 }
        events[0]["encounterTone"] = "favorable"
        try JSONSerialization.data(withJSONObject: events).write(to: file)
        let catalog = try EventContentCatalog.load(from: directory)
        let event = try XCTUnwrap(catalog.locationsByID[try XCTUnwrap(events[0]["id"] as? String)])
        var engine = GameEngine(seed: 8)
        var session = engine.makeNewSession()
        XCTAssertFalse(try XCTUnwrap(event.condition).matches(session))
        session.currentLuck = 60
        XCTAssertTrue(try XCTUnwrap(event.condition).matches(session))
        let cash = session.cash
        engine.apply(event, to: &session)
        XCTAssertEqual(session.cash, cash + 321)
        XCTAssertEqual(session.currentLuck, 62)
        XCTAssertFalse(event.title.isEmpty)
    }

    @MainActor
    func testUnreadWorldQueueRestoresAndDismissalDoesNotReapplyEffects() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var engine = GameEngine(seed: 6)
        var session = engine.makeNewSession()
        let events = WorldEventCatalog.events.prefix(2)
        session.activeWorldEvents = events.map { ActiveWorldEvent(eventID: $0.id, startedWeek: 1, endingWeek: 8, modifiers: $0.modifiers) }
        session.unreadWorldEvents = session.activeWorldEvents
        let snapshot = GameSnapshot(profileID: .one, session: session, randomCheckpoint: engine.randomCheckpoint)
        let restored = try JSONDecoder().decode(GameSnapshot.self, from: JSONEncoder().encode(snapshot))
        let store = GameStore(snapshot: restored, repository: ProfileRepository(directoryURL: directory))
        XCTAssertEqual(store.worldEventNotice?.eventID, events.first?.id)
        XCTAssertEqual(store.activeWorldEvents.count, 2)
        let cash = store.session.cash
        store.dismissWorldEvent()
        XCTAssertEqual(store.worldEventNotice?.eventID, events.last?.id)
        store.dismissWorldEvent()
        store.dismissWorldEvent()
        XCTAssertNil(store.worldEventNotice)
        XCTAssertTrue(store.session.unreadWorldEvents?.isEmpty == true)
        XCTAssertEqual(store.session.cash, cash)
    }
}
