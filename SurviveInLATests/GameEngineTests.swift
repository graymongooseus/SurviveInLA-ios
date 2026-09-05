import XCTest
import UIKit
@testable import SurviveInLA

final class GameEngineTests: XCTestCase {
    func testNewSessionUsesReleaseStartingBalance() {
        var engine = GameEngine(seed: 42)
        let session = engine.makeNewSession()

        XCTAssertEqual(session.day, 1)
        XCTAssertEqual(session.cash, 1_000)
        XCTAssertEqual(session.debt, 5_000)
        XCTAssertEqual(session.totalDays, 52)
        XCTAssertEqual(session.market.count, 5)
        XCTAssertEqual(session.currentDistrictID, .dingPangZiPlaza)
        XCTAssertEqual(GameContent.districts.count, 15)
        XCTAssertEqual(GameContent.commodities.count, 10)
    }

    func testBuyingUpdatesCashCapacityAndAverageCost() throws {
        var engine = GameEngine(seed: 42)
        var session = engine.makeNewSession()
        let quote = try XCTUnwrap(session.market.first)
        session.cash = 100_000
        let startingCash = session.cash

        try engine.buy(quote.commodityID, quantity: 2, in: &session)

        XCTAssertEqual(session.cash, startingCash - quote.price * 2)
        XCTAssertEqual(session.usedCapacity, 2)
        XCTAssertEqual(session.inventory[quote.commodityID]?.averageCost, quote.price)
    }

    func testSellingReturnsCashAndRemovesEmptyPosition() throws {
        var engine = GameEngine(seed: 7)
        var session = engine.makeNewSession()
        let quote = try XCTUnwrap(session.market.first)
        session.cash = 100_000

        try engine.buy(quote.commodityID, quantity: 1, in: &session)
        let cashAfterBuy = session.cash
        try engine.sell(quote.commodityID, quantity: 1, in: &session)

        XCTAssertEqual(session.cash, cashAfterBuy + quote.price)
        XCTAssertNil(session.inventory[quote.commodityID])
    }

    func testSellingSmuggledVapeReducesReputation() throws {
        var engine = GameEngine(seed: 8)
        var session = engine.makeNewSession()
        session.market.append(
            MarketQuote(commodityID: .smuggledVape, price: 60, previousPrice: 55)
        )
        session.inventory[.smuggledVape] = InventoryPosition(
            commodityID: .smuggledVape,
            quantity: 1,
            averageCost: 40
        )

        try engine.sell(.smuggledVape, quantity: 1, in: &session)

        XCTAssertEqual(session.reputation, 95)
        XCTAssertEqual(session.log.first?.title, "声望受损")
    }

    func testTravelAdvancesWeekAndAccruesDebtInterest() throws {
        var engine = GameEngine(seed: 99)
        var session = engine.makeNewSession()

        try engine.travel(to: .pasadenaRoseBowl, session: &session)

        XCTAssertEqual(session.day, 2)
        XCTAssertEqual(session.currentDistrictID, .pasadenaRoseBowl)
        XCTAssertEqual(session.debt, 5_100)
        XCTAssertEqual(session.market.count, 5)
        XCTAssertNotNil(session.latestEvent)
        XCTAssertTrue(session.latestEvent?.canOccur(in: .pasadenaRoseBowl) == true)
        if session.latestEvent?.group == .market,
           let commodityID = session.latestEvent?.affectedCommodityID {
            XCTAssertTrue(session.market.contains(where: { $0.commodityID == commodityID }))
        }
    }

    func testTradingLocksOutOtherIncomeForTheWeek() throws {
        var engine = GameEngine(seed: 13)
        var session = engine.makeNewSession()
        session.cash = 100_000
        let quote = try XCTUnwrap(session.market.first)

        try engine.buy(quote.commodityID, quantity: 1, in: &session)

        XCTAssertEqual(session.actionThisWeek, .trading)
        XCTAssertThrowsError(try engine.work(in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .weeklyActionAlreadyChosen)
        }
        XCTAssertThrowsError(try engine.invest(100, in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .weeklyActionAlreadyChosen)
        }
    }

    func testWorkingCanOnlyRunOnceBeforeFinishingTheWeek() throws {
        var engine = GameEngine(seed: 14)
        var session = engine.makeNewSession()

        try engine.work(in: &session)

        XCTAssertEqual(session.day, 1)
        XCTAssertGreaterThan(session.cash, 1_000)
        XCTAssertLessThan(session.health, 100)
        XCTAssertEqual(session.debt, 5_000)
        XCTAssertEqual(session.actionThisWeek, .work)
        XCTAssertEqual(session.latestEvent?.group, .money)
        XCTAssertThrowsError(try engine.work(in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .weeklyActionAlreadyChosen)
        }
        session.cash = 100_000
        let quote = try XCTUnwrap(session.market.first)
        XCTAssertThrowsError(try engine.buy(quote.commodityID, quantity: 1, in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .weeklyActionAlreadyChosen)
        }
        XCTAssertThrowsError(try engine.invest(100, in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .weeklyActionAlreadyChosen)
        }

        try engine.finishStationaryWeek(in: &session)

        XCTAssertEqual(session.day, 2)
        XCTAssertEqual(session.debt, 5_100)
        XCTAssertNil(session.actionThisWeek)
    }

    func testFigueroaPimpingPaysHighIncomeAndViceSweepCanDoubleIt() throws {
        var sawRegularIncome = false
        var sawDoubledIncome = false

        for seed in 0 ..< 200 {
            var engine = GameEngine(seed: UInt64(seed))
            var session = engine.makeNewSession()
            session.currentDistrictID = .figueroaCorridor
            let startingCash = session.cash

            let event = try engine.work(in: &session)
            let income = session.cash - startingCash

            if event.id == "figueroa-vice-sweep" {
                sawDoubledIncome = true
                XCTAssertTrue((1_000 ... 1_400).contains(income))
                XCTAssertEqual(event.workIncomeMultiplier, 2)
            } else {
                sawRegularIncome = true
                XCTAssertTrue((500 ... 700).contains(income))
            }
            XCTAssertEqual(session.consecutivePimpingWeeks, 1)
        }

        XCTAssertTrue(sawRegularIncome)
        XCTAssertTrue(sawDoubledIncome)
    }

    func testThirdConsecutivePimpingWeekTriggersLAPDStingAndTwoWeekSentence() throws {
        var engine = GameEngine(seed: 14)
        var session = engine.makeNewSession()
        session.currentDistrictID = .figueroaCorridor

        try engine.work(in: &session)
        try engine.finishStationaryWeek(in: &session)
        try engine.work(in: &session)
        try engine.finishStationaryWeek(in: &session)

        session.cash = 2_000
        let event = try engine.work(in: &session)

        XCTAssertEqual(event.id, "lapd-sting-operation")
        XCTAssertEqual(event.baseEffectSummary, "现金 −$1,000\n跳过 2 周（债务与存款继续计息）")
        XCTAssertEqual(session.cash, 1_000)
        XCTAssertEqual(session.day, 5)
        XCTAssertEqual(session.debt, 5_412)
        XCTAssertEqual(session.consecutivePimpingWeeks, 0)
        XCTAssertNil(session.actionThisWeek)
    }

    func testLeavingFigueroaBreaksConsecutivePimpingStreak() throws {
        var engine = GameEngine(seed: 14)
        var session = engine.makeNewSession()
        session.currentDistrictID = .figueroaCorridor

        try engine.work(in: &session)
        try engine.finishStationaryWeek(in: &session)
        try engine.travel(to: .hollywood, session: &session)

        XCTAssertEqual(session.consecutivePimpingWeeks, 0)
    }

    func testInvestmentCanOnlyRunOnceBeforeFinishingTheWeek() throws {
        var engine = GameEngine(seed: 15)
        var session = engine.makeNewSession()

        try engine.invest(100, in: &session)

        XCTAssertEqual(session.day, 1)
        XCTAssertTrue((992 ... 1_008).contains(session.cash))
        XCTAssertEqual(session.debt, 5_000)
        XCTAssertEqual(session.actionThisWeek, .investment)
        XCTAssertEqual(session.latestEvent?.group, .money)
        XCTAssertThrowsError(try engine.invest(100, in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .weeklyActionAlreadyChosen)
        }
        session.cash = 100_000
        let quote = try XCTUnwrap(session.market.first)
        XCTAssertThrowsError(try engine.buy(quote.commodityID, quantity: 1, in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .weeklyActionAlreadyChosen)
        }
        XCTAssertThrowsError(try engine.work(in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .weeklyActionAlreadyChosen)
        }

        try engine.finishStationaryWeek(in: &session)

        XCTAssertEqual(session.day, 2)
        XCTAssertEqual(session.debt, 5_100)
        XCTAssertNil(session.actionThisWeek)
    }

    func testLosAngelesEventCatalogIncludesRegionalExpansion() {
        XCTAssertEqual(GameContent.marketEvents.count, 25)
        XCTAssertEqual(GameContent.healthEvents.count, 18)
        XCTAssertEqual(GameContent.moneyEvents.count, 13)
        XCTAssertEqual(GameContent.events.count, 56)
        XCTAssertEqual(Set(GameContent.events.map(\.id)).count, 56)
        XCTAssertTrue(GameContent.marketEvents.allSatisfy {
            $0.group == .market
                && ($0.affectedCommodityID != nil || $0.workIncomeMultiplier != nil)
        })
        let viceSweep = GameContent.marketEvents.first { $0.id == "figueroa-vice-sweep" }
        XCTAssertEqual(viceSweep?.triggerChance, 0.30)
        XCTAssertEqual(viceSweep?.workIncomeMultiplier, 2)

        for districtID in District.ID.allCases {
            let groups = Set(
                GameContent.events
                    .filter { $0.canOccur(in: districtID) }
                    .compactMap(\.group)
            )
            XCTAssertEqual(groups, Set(GameEventGroup.allCases), "\(districtID) 缺少事件分类")
        }
    }

    func testEveryLocationEventNoticeIncludesBaseEffectsBeforeStory() {
        XCTAssertEqual(LocationEventCatalog.events.count, 56)
        XCTAssertEqual(LocationEventCatalog.events, GameContent.events)
        for event in LocationEventCatalog.events {
            XCTAssertNotEqual(event.baseEffectSummary, "无数值变化", event.id)
            let notice = UserNotice(event: event)
            XCTAssertTrue(notice.message.hasPrefix("基础效果\n"), event.id)
            XCTAssertTrue(notice.message.hasSuffix("\n\n" + event.message), event.id)
        }
    }

    @MainActor
    func testAllHealthCardsHaveBundledArtworkAndPreserveEventData() throws {
        for event in GameContent.healthEvents {
            let name = try XCTUnwrap(event.healthEventImageName, event.id)
            let image = try XCTUnwrap(UIImage(named: name), "Missing bundled artwork: \(name)")
            XCTAssertEqual(image.size.width / image.size.height, 1.5, accuracy: 0.01, event.id)
            XCTAssertEqual(UserNotice(event: event).healthEvent, event)
            // 旧存档只保存事件内容；新插图仍能按稳定 ID 恢复关联。
            let restored = try JSONDecoder().decode(GameEvent.self, from: JSONEncoder().encode(event))
            XCTAssertEqual(restored.healthEventImageName, name)
        }
        for event in GameContent.marketEvents + GameContent.moneyEvents {
            XCTAssertNil(UserNotice(event: event).healthEvent, event.id)
        }
        XCTAssertNil(UserNotice(title: "错误", message: "请重试").healthEvent)
    }

    @MainActor
    func testHealthCardFollowsWorldEventWithoutApplyingEffectsAgain() throws {
        let event = try XCTUnwrap(GameContent.healthEvents.first)
        let store = GameStore(seed: 42)
        store.worldEventNotice = WorldEventNotice(
            eventID: "regional-public-health-crisis", triggeredWeek: 36, endingWeek: 41,
            localNotice: UserNotice(event: event)
        )
        let cash = store.session.cash
        let health = store.session.health
        store.dismissWorldEvent()
        XCTAssertNil(store.worldEventNotice)
        XCTAssertEqual(store.notice?.healthEvent, event)
        XCTAssertEqual(store.session.cash, cash)
        XCTAssertEqual(store.session.health, health)
        store.notice = nil
        store.dismissWorldEvent()
        XCTAssertNil(store.notice)
    }

    @MainActor
    func testFatalTravelKeepsHealthCardUntilDismissed() throws {
        var foundFatalEvent = false
        for seed in 0 ..< 100 where !foundFatalEvent {
            let store = GameStore(seed: UInt64(seed))
            store.session.health = 1
            store.select(.hollywood)
            store.travel()
            guard store.session.health == 0, store.session.latestEvent?.group == .health else { continue }
            foundFatalEvent = true
            XCTAssertEqual(store.notice?.healthEvent, store.session.latestEvent)
            XCTAssertTrue(store.saveProgress())
            XCTAssertNotNil(store.notice?.healthEvent)
            store.notice = nil
            XCTAssertTrue(store.session.isFinished)
        }
        XCTAssertTrue(foundFatalEvent)
    }

    @MainActor
    func testFinalWeekDoesNotRepeatPreviousHealthCard() {
        let store = GameStore(seed: 42)
        store.session.day = 51
        store.session.latestEvent = GameContent.healthEvents.first
        store.select(.hollywood)
        store.travel()
        XCTAssertTrue(store.session.isFinished)
        XCTAssertNil(store.notice)
    }

    func testLocationEventEffectsIncludeLossesGainsPricesGiftsAndWorkMultiplier() throws {
        let examples = [
            ("sleep-debt", "现金 −$7\n健康 −4"),
            ("ding-pang-zi-referral-shift", "现金 +$110\n声望 +1"),
            ("industry-damaged-shipment", "现金 −$190\n声望 −1"),
            ("studio-camera-rush", "二手相机价格 ×1.90（受价格上下限限制）"),
            ("camera-estate-sale", "二手相机价格 ×0.55（受价格上下限限制）"),
            ("community-leftovers", "声望 +1\n免费获得最多 6 份国产辣条（受剩余仓储容量限制）"),
            ("figueroa-vice-sweep", "当周打工收入 ×2")
        ]
        for (id, expected) in examples {
            let event = try XCTUnwrap(LocationEventCatalog.events.first { $0.id == id })
            XCTAssertEqual(event.baseEffectSummary, expected, id)
        }
    }

    @MainActor
    func testTravelNoticesIncludeEffectsInStandaloneAndWorldEventPopups() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        var sawStandalone = false
        var sawWorldEvent = false
        for seed in 0 ..< 100 where !sawStandalone || !sawWorldEvent {
            let store = GameStore(seed: UInt64(seed), repository: ProfileRepository(directoryURL: directory))
            store.session.day = 4
            store.select(.hollywood)
            store.travel()
            let event = try XCTUnwrap(store.session.latestEvent)
            let expected = UserNotice(event: event).message
            if let worldNotice = store.worldEventNotice {
                XCTAssertEqual(worldNotice.localNotice?.message, expected)
                sawWorldEvent = true
            } else if !sawStandalone {
                try await Task.sleep(for: .milliseconds(1_100))
                XCTAssertEqual(store.notice?.message, expected)
                sawStandalone = true
            }
        }
        XCTAssertTrue(sawStandalone)
        XCTAssertTrue(sawWorldEvent)
    }

    @MainActor
    func testWorkAndInvestmentPopupsIncludeBaseEffects() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = GameStore(seed: 14, repository: ProfileRepository(directoryURL: directory))
        store.work()
        let work = try XCTUnwrap(store.session.latestEvent)
        XCTAssertEqual(store.notice?.message, UserNotice(event: work).message)
        XCTAssertTrue(store.notice?.message.contains("健康 −") == true)
        store.finishStationaryWeek()
        store.invest(100)
        let investment = try XCTUnwrap(store.session.latestEvent)
        XCTAssertEqual(store.notice?.message, UserNotice(event: investment).message)
    }

    func testWorldEventCatalogHasValidSchedulesAndGlobalModifiers() {
        XCTAssertEqual(WorldEventCatalog.events.count, 7)
        XCTAssertEqual(Set(WorldEventCatalog.events.map(\.id)).count, 7)
        XCTAssertEqual(Set(WorldEventCatalog.events.map(\.imageName)).count, 7)

        for event in WorldEventCatalog.events {
            XCTAssertFalse(event.imageName.isEmpty)
            XCTAssertFalse(event.triggerWeeks.isEmpty)
            XCTAssertTrue(event.triggerWeeks.allSatisfy { (1 ... 52).contains($0) })
            XCTAssertTrue((0 ... 1).contains(event.triggerChance))
            XCTAssertGreaterThan(event.durationWeeks, 0)
            XCTAssertGreaterThan(event.modifiers.workIncome, 0)
            XCTAssertGreaterThan(event.modifiers.tradeIncome, 0)
            XCTAssertGreaterThan(event.modifiers.bankInterest, 0)
            XCTAssertGreaterThan(event.modifiers.investmentReturn, 0)
            XCTAssertGreaterThan(event.modifiers.debtInterest, 0)
            XCTAssertGreaterThan(event.modifiers.healthChange, 0)
            XCTAssertGreaterThan(event.modifiers.reputationChange, 0)
            XCTAssertGreaterThan(event.modifiers.marketPrice, 0)
        }
    }

    func testHormuzCrisisRaisesEveryGeneratedMarketPrice() throws {
        var baseEngine = GameEngine(seed: 106)
        var crisisEngine = GameEngine(seed: 106)
        var baseSession = baseEngine.makeNewSession()
        var crisisSession = crisisEngine.makeNewSession()
        activateWorldEvent("strait-of-hormuz-crisis", in: &crisisSession)

        try baseEngine.travel(to: .sanGabriel, session: &baseSession)
        try crisisEngine.travel(to: .sanGabriel, session: &crisisSession)

        let basePrices = Dictionary(uniqueKeysWithValues: baseSession.market.map { ($0.commodityID, $0.price) })
        for quote in crisisSession.market {
            XCTAssertGreaterThanOrEqual(quote.price, basePrices[quote.commodityID]!)
        }
        XCTAssertTrue(crisisSession.market.contains { $0.price > basePrices[$0.commodityID]! })
    }

    func testHormuzCrisisForcesInvestmentLoss() throws {
        var engine = GameEngine(seed: 107)
        var session = engine.makeNewSession()
        activateWorldEvent("strait-of-hormuz-crisis", in: &session)

        try engine.invest(100, in: &session)

        XCTAssertEqual(session.cash, 965)
        XCTAssertEqual(session.latestEvent?.cashDelta, -35)
    }

    func testWorldEventModifiesTradingRevenue() throws {
        var engine = GameEngine(seed: 101)
        var session = engine.makeNewSession()
        session.market = [MarketQuote(commodityID: .camera, price: 100, previousPrice: 90)]
        session.inventory[.camera] = InventoryPosition(
            commodityID: .camera,
            quantity: 1,
            averageCost: 50
        )
        activateWorldEvent("southern-california-spending-boom", in: &session)
        let startingCash = session.cash

        try engine.sell(.camera, quantity: 1, in: &session)

        XCTAssertEqual(session.cash, startingCash + 125)
    }

    func testWorldEventModifiesWorkIncomeWithoutChangingLocalOutcome() throws {
        var baseEngine = GameEngine(seed: 102)
        var worldEngine = GameEngine(seed: 102)
        var baseSession = baseEngine.makeNewSession()
        var worldSession = worldEngine.makeNewSession()
        activateWorldEvent("labor-enforcement-wave", in: &worldSession)

        try baseEngine.work(in: &baseSession)
        try worldEngine.work(in: &worldSession)

        let baseIncome = baseSession.cash - 1_000
        let worldIncome = worldSession.cash - 1_000
        XCTAssertEqual(worldIncome, Int((Double(baseIncome) * 1.20).rounded()))
        XCTAssertEqual(worldSession.latestEvent?.baseCashDelta, baseIncome)
        XCTAssertEqual(worldSession.latestEvent?.baseEffectSummary, baseSession.latestEvent?.baseEffectSummary)
    }

    func testWorldEventModifiesInvestmentProfitAndLoss() throws {
        var baseEngine = GameEngine(seed: 103)
        var worldEngine = GameEngine(seed: 103)
        var baseSession = baseEngine.makeNewSession()
        var worldSession = worldEngine.makeNewSession()
        activateWorldEvent("rapid-rate-hike", in: &worldSession)

        try baseEngine.invest(100, in: &baseSession)
        try worldEngine.invest(100, in: &worldSession)

        let baseProfit = baseSession.cash - 1_000
        let worldProfit = worldSession.cash - 1_000
        XCTAssertEqual(worldProfit, Int((Double(baseProfit) * 0.75).rounded()))
        XCTAssertEqual(worldSession.latestEvent?.baseCashDelta, baseProfit)
        XCTAssertEqual(worldSession.latestEvent?.baseEffectSummary, baseSession.latestEvent?.baseEffectSummary)
    }

    func testWorldEventModifiesBankAndDebtInterest() throws {
        var engine = GameEngine(seed: 104)
        var session = engine.makeNewSession()
        session.bank = 10_000
        session.debt = 5_000
        activateWorldEvent("rapid-rate-hike", in: &session)

        try engine.work(in: &session)
        try engine.finishStationaryWeek(in: &session)

        XCTAssertEqual(session.bank, 10_032)
        XCTAssertEqual(session.debt, 5_155)
    }

    func testWorldEventModifiesHealthAndReputationChanges() {
        var engine = GameEngine(seed: 105)
        var session = engine.makeNewSession()
        activateWorldEvent("regional-public-health-crisis", in: &session)
        let event = GameEvent(
            id: "world-modifier-test",
            kind: .setback,
            group: .health,
            title: "测试事件",
            message: "测试世界事件修正。",
            healthDelta: -10,
            reputationDelta: -10
        )

        engine.apply(event, to: &session)

        XCTAssertEqual(session.health, 85)
        XCTAssertEqual(session.reputation, 92)
    }

    func testWorldEventTriggersWhenEnteringItsScheduledWeek() throws {
        var foundTriggeredEvent = false
        var foundMissedEvent = false

        for seed in 0 ..< 200 where !foundTriggeredEvent || !foundMissedEvent {
            var engine = GameEngine(seed: UInt64(seed))
            var session = engine.makeNewSession()
            for _ in 1 ..< 5 {
                try engine.work(in: &session)
                try engine.finishStationaryWeek(in: &session)
            }

            if session.latestWorldEventID == "labor-enforcement-wave" {
                foundTriggeredEvent = true
                XCTAssertEqual(session.latestWorldEventWeek, 5)
                XCTAssertEqual(session.activeWorldEvent?.endingWeek, 8)
            } else {
                foundMissedEvent = true
                XCTAssertNil(session.activeWorldEvent)
            }
        }

        XCTAssertTrue(foundTriggeredEvent)
        XCTAssertTrue(foundMissedEvent)
    }

    func testNewestDistrictsHaveDedicatedEventsInEveryCategory() {
        let newestDistricts: [District.ID] = [
            .dingPangZiPlaza,
            .sanGabriel,
            .rowlandHeights,
            .cityOfIndustry,
            .irvine,
            .littleSaigon
        ]

        for districtID in newestDistricts {
            let dedicatedEvents = GameContent.events.filter {
                $0.districtIDs == [districtID]
            }

            XCTAssertEqual(dedicatedEvents.count, 3, "\(districtID) 专属事件数量不正确")
            XCTAssertEqual(
                Set(dedicatedEvents.compactMap(\.group)),
                Set(GameEventGroup.allCases),
                "\(districtID) 缺少专属事件分类"
            )
        }
    }

    func testLegacySavedEventDecodesWithoutNewClassificationFields() throws {
        let data = Data(
            #"{"id":"legacy","kind":"setback","title":"旧事件","message":"旧存档","cashDelta":-10,"healthDelta":0,"reputationDelta":0}"#.utf8
        )

        let event = try JSONDecoder().decode(GameEvent.self, from: data)

        XCTAssertNil(event.group)
        XCTAssertNil(event.affectedCommodityID)
        XCTAssertNil(event.baseCashDelta)
        XCTAssertNil(event.skippedWeeks)
        XCTAssertEqual(event.baseEffectSummary, "现金 −$10")
        XCTAssertTrue(event.canOccur(in: .koreatown))
    }

    func testMarketEventChangesPriceAndGiftRespectsCapacity() throws {
        var engine = GameEngine(seed: 10)
        var session = engine.makeNewSession()
        session.market = [MarketQuote(commodityID: .camera, price: 500, previousPrice: 480)]

        let cameraRush = try XCTUnwrap(
            GameContent.marketEvents.first(where: { $0.id == "studio-camera-rush" })
        )
        engine.apply(cameraRush, to: &session)
        XCTAssertEqual(session.market.first?.price, 950)

        session.capacity = 2
        session.inventory.removeAll()
        let leftovers = try XCTUnwrap(
            GameContent.marketEvents.first(where: { $0.id == "community-leftovers" })
        )
        engine.apply(leftovers, to: &session)
        XCTAssertEqual(session.inventory[.importedSnacks]?.quantity, 2)
        XCTAssertEqual(session.inventory[.importedSnacks]?.averageCost, 0)
    }

    func testDistrictsHaveDistinctCommodityProfiles() {
        XCTAssertEqual(Set(GameContent.districts.map(\.id)).count, 15)
        XCTAssertTrue(GameContent.districts.allSatisfy { !$0.marketRole.isEmpty })
        XCTAssertTrue(GameContent.districts.allSatisfy { !$0.characterSummary.isEmpty })
        XCTAssertTrue(GameContent.districts.allSatisfy { !$0.gameplayHooks.isEmpty })
        XCTAssertTrue(GameContent.districts.allSatisfy { !$0.jobHooks.isEmpty })
        XCTAssertLessThan(
            GameContent.district(.koreatown).priceBias(for: .importedSnacks),
            GameContent.district(.santaMonica).priceBias(for: .importedSnacks)
        )
        XCTAssertGreaterThan(
            GameContent.district(.hollywood).priceBias(for: .concertTickets),
            GameContent.district(.pasadenaRoseBowl).priceBias(for: .concertTickets)
        )
    }

    func testEveryDistrictHasOneJobAndInvestment() {
        XCTAssertEqual(GameContent.jobs.count, GameContent.districts.count)
        XCTAssertEqual(GameContent.investments.count, GameContent.districts.count)
        XCTAssertEqual(Set(GameContent.jobs.map(\.districtID)), Set(District.ID.allCases))
        XCTAssertEqual(Set(GameContent.investments.map(\.districtID)), Set(District.ID.allCases))
    }

    func testLegacyDistrictIDsMigrateWhenDecoded() throws {
        let decoder = JSONDecoder()

        XCTAssertEqual(
            try decoder.decode(District.ID.self, from: Data("\"fashionDistrict\"".utf8)),
            .pasadenaRoseBowl
        )
        XCTAssertEqual(
            try decoder.decode(District.ID.self, from: Data("\"downtown\"".utf8)),
            .figueroaCorridor
        )
        XCTAssertEqual(
            try decoder.decode(District.ID.self, from: Data("\"unionStation\"".utf8)),
            .figueroaCorridor
        )
        XCTAssertEqual(
            try decoder.decode(District.ID.self, from: Data("\"boyleHeights\"".utf8)),
            .figueroaCorridor
        )
        XCTAssertEqual(
            try decoder.decode(District.ID.self, from: Data("\"centuryCity\"".utf8)),
            .westwood
        )
        XCTAssertEqual(
            try decoder.decode(District.ID.self, from: Data("\"silverLake\"".utf8)),
            .cityOfIndustry
        )
    }

    func testCannotBuyBeyondCapacity() throws {
        var balance = GameBalance()
        balance.startingCapacity = 1
        balance.startingCash = 100_000
        var engine = GameEngine(balance: balance, seed: 12)
        var session = engine.makeNewSession()
        let quote = try XCTUnwrap(session.market.first)

        XCTAssertThrowsError(try engine.buy(quote.commodityID, quantity: 2, in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .insufficientCapacity)
        }
    }

    func testBankingAndDebtPaymentsMoveMoneyWithoutAdvancingWeek() throws {
        var engine = GameEngine(seed: 18)
        var session = engine.makeNewSession()
        session.cash = 2_000

        try engine.deposit(500, in: &session)
        XCTAssertEqual(session.cash, 1_500)
        XCTAssertEqual(session.bank, 500)

        try engine.withdraw(200, in: &session)
        XCTAssertEqual(session.cash, 1_700)
        XCTAssertEqual(session.bank, 300)

        try engine.repayDebt(700, in: &session)
        XCTAssertEqual(session.cash, 1_000)
        XCTAssertEqual(session.debt, 4_300)
        XCTAssertEqual(session.day, 1)
    }

    func testTreatmentAndStorageUpgradeChargeCash() throws {
        var engine = GameEngine(seed: 24)
        var session = engine.makeNewSession()
        session.health = 90
        session.cash = 10_000

        try engine.heal(5, in: &session)
        XCTAssertEqual(session.health, 95)
        XCTAssertEqual(session.cash, 9_875)

        try engine.expandCapacity(in: &session)
        XCTAssertEqual(session.capacity, 110)
        XCTAssertEqual(session.cash, 7_375)
    }

    func testEndingJourneyLiquidatesRemainingInventory() throws {
        var engine = GameEngine(seed: 31)
        var session = engine.makeNewSession()
        let quote = try XCTUnwrap(session.market.first)
        session.cash = 100_000
        try engine.buy(quote.commodityID, quantity: 1, in: &session)
        let expectedCash = session.cash + quote.price - JourneySettlement.airfare
        session.day = session.totalDays

        engine.endJourney(session: &session)

        XCTAssertTrue(session.isFinished)
        XCTAssertTrue(session.inventory.isEmpty)
        XCTAssertEqual(session.cash, expectedCash)
    }

    @MainActor
    func testFinishingWorkReturnsStoreToTradingSoPlayerCanMove() {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = GameStore(seed: 14, repository: ProfileRepository(directoryURL: directory))
        store.selectedAction = .work
        store.work()

        XCTAssertEqual(store.session.actionThisWeek, .work)
        store.finishStationaryWeek()

        XCTAssertEqual(store.session.day, 2)
        XCTAssertNil(store.session.actionThisWeek)
        XCTAssertEqual(store.selectedAction, .trading)
        XCTAssertEqual(store.selectedDestinationID, store.session.currentDistrictID)
    }

    @MainActor
    func testCompletedGameStoreArchivesAndLoadsJourneyHistory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = ProfileRepository(directoryURL: directory)
        var engine = GameEngine(seed: 32)
        var session = engine.makeNewSession()
        session.day = session.totalDays
        let snapshot = GameSnapshot(
            profileID: .one,
            session: session,
            randomCheckpoint: engine.randomCheckpoint
        )
        let store = GameStore(profileID: .one, snapshot: snapshot, repository: repository)

        XCTAssertTrue(store.session.isFinished)
        XCTAssertTrue(store.saveProgress())
        store.loadLeaderboard()

        XCTAssertEqual(store.journeyRecords.count, 1)
        XCTAssertEqual(store.journeyRecords.first?.profileID, .one)
    }

    func testProfileSnapshotRoundTripsSessionAndRandomState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = ProfileRepository(directoryURL: directory)
        var engine = GameEngine(seed: 77)
        var session = engine.makeNewSession()
        try engine.travel(to: .pasadenaRoseBowl, session: &session)
        let snapshot = GameSnapshot(
            profileID: .two,
            session: session,
            randomCheckpoint: engine.randomCheckpoint
        )

        try repository.save(snapshot)
        let restored = try XCTUnwrap(repository.load(.two))

        XCTAssertEqual(restored.profileID, .two)
        XCTAssertEqual(restored.session.day, 2)
        XCTAssertEqual(restored.session.currentDistrictID, .pasadenaRoseBowl)
        XCTAssertEqual(restored.randomCheckpoint, engine.randomCheckpoint)
        XCTAssertNil(try repository.load(.one))
    }

    func testDeletingLocalProfileReturnsSlotToEmpty() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = ProfileRepository(directoryURL: directory)
        var engine = GameEngine(seed: 79)
        let session = engine.makeNewSession()

        try repository.save(
            GameSnapshot(
                profileID: .one,
                session: session,
                randomCheckpoint: engine.randomCheckpoint
            )
        )
        XCTAssertNotNil(try repository.load(.one))

        try repository.deleteLocal(.one)

        XCTAssertNil(try repository.load(.one))
    }

    func testCompletedWorkLockSurvivesSaveAndReload() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = ProfileRepository(directoryURL: directory)
        var engine = GameEngine(seed: 88)
        var session = engine.makeNewSession()
        try engine.work(in: &session)

        try repository.save(
            GameSnapshot(
                profileID: .one,
                session: session,
                randomCheckpoint: engine.randomCheckpoint
            )
        )
        let restored = try XCTUnwrap(repository.load(.one))

        XCTAssertEqual(restored.session.day, 1)
        XCTAssertEqual(restored.session.actionThisWeek, .work)
        XCTAssertThrowsError(try engine.work(in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .weeklyActionAlreadyChosen)
        }
    }

    func testInAppPurchaseCatalogContainsOnlyFixedCurrencyPacks() {
        XCTAssertEqual(
            AdventureProduct.allCases.map(\.rawValue),
            [
                "com.graymongooseus.SurviveInLA.currency.starter",
                "com.graymongooseus.SurviveInLA.currency.survivor",
                "com.graymongooseus.SurviveInLA.currency.builder",
                "com.graymongooseus.SurviveInLA.currency.dream",
            ]
        )
        XCTAssertEqual(AdventureProduct.allCases.map(\.cashDelta), [3_000, 6_000, 18_000, 36_000])
        XCTAssertTrue(AdventureProduct.allCases.allSatisfy { $0.cashDelta > 0 })
    }

    @MainActor
    func testPurchasedCurrencyIsDeliveredExactlyOncePerTransaction() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = GameStore(seed: 91, repository: ProfileRepository(directoryURL: directory))
        let transactionID = UInt64(Date.now.timeIntervalSince1970 * 1_000_000)
        let startingCash = store.session.cash

        XCTAssertTrue(store.applyPurchasedAdventure(.starterCash, transactionID: transactionID))
        XCTAssertEqual(store.session.cash, startingCash + 3_000)
        XCTAssertTrue(store.applyPurchasedAdventure(.starterCash, transactionID: transactionID))
        XCTAssertEqual(store.session.cash, startingCash + 3_000)
    }

    private func activateWorldEvent(_ id: String, in session: inout GameSession) {
        session.activeWorldEvent = ActiveWorldEvent(
            eventID: id,
            startedWeek: session.day,
            endingWeek: session.totalDays
        )
    }
}
