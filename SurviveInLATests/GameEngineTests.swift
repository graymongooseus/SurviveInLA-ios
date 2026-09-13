import XCTest
#if canImport(UIKit)
import UIKit
#endif
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

    func testNewSessionStartsStatusHistoryAndTradeRecordsCashChange() throws {
        var engine = GameEngine(seed: 42)
        var session = engine.makeNewSession()

        for metric in StatusMetric.allCases {
            let entry = try XCTUnwrap(session.history(for: metric).first)
            XCTAssertEqual(entry.reason, "抵达洛杉矶")
            XCTAssertEqual(entry.delta, 0)
            XCTAssertEqual(entry.valueAfter, session.statusValue(for: metric))
        }

        let quote = try XCTUnwrap(session.market.first)
        let oldCash = session.cash
        try engine.buy(quote.commodityID, quantity: 1, in: &session)

        let cashEntry = try XCTUnwrap(session.history(for: .cash).first)
        XCTAssertEqual(cashEntry.delta, -quote.price)
        XCTAssertEqual(cashEntry.valueAfter, oldCash - quote.price)
        XCTAssertTrue(cashEntry.reason.contains(GameContent.commodity(quote.commodityID).name))
    }

    func testStatusHistoryTracksDebtHealthLuckAndEventReasons() throws {
        var engine = GameEngine(seed: 43)
        var session = engine.makeNewSession()

        try engine.travel(to: .pasadenaRoseBowl, session: &session)
        let debtEntry = try XCTUnwrap(session.history(for: .debt).first)
        XCTAssertEqual(debtEntry.reason, "每周欠款利息")
        XCTAssertEqual(debtEntry.delta, 100)
        XCTAssertEqual(debtEntry.valueAfter, 5_100)

        let event = GameEvent(
            id: "history-test",
            kind: .setback,
            group: .health,
            title: "历史追踪测试",
            message: "测试状态变化。",
            cashDelta: -25,
            healthDelta: -7,
            luckDelta: 3
        )
        engine.apply(event, to: &session)

        XCTAssertEqual(session.history(for: .cash).first?.reason, event.title)
        XCTAssertEqual(session.history(for: .cash).first?.delta, -25)
        XCTAssertEqual(session.history(for: .health).first?.reason, event.title)
        XCTAssertEqual(session.history(for: .health).first?.delta, -7)
        XCTAssertEqual(session.history(for: .luck).first?.reason, event.title)
        XCTAssertEqual(session.history(for: .luck).first?.delta, 3)
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

    func testSellingSmuggledVapeReducesLuck() throws {
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

        XCTAssertEqual(session.currentLuck, 45)
        XCTAssertEqual(session.log.first?.title, "运气下降")
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

    func testTradingWorkAndInvestmentCanAllRunInTheSameWeek() throws {
        var engine = GameEngine(seed: 13)
        var session = engine.makeNewSession()
        provideHousing(in: &session)
        session.cash = 100_000
        let quote = try XCTUnwrap(session.market.first)

        try engine.buy(quote.commodityID, quantity: 1, in: &session)
        try engine.work(in: &session)
        try engine.invest(100, in: &session)

        XCTAssertEqual(session.completedWeeklyActions, [.trading, .work, .investment])
        XCTAssertEqual(session.actionThisWeek, .investment)
        XCTAssertNoThrow(try engine.sell(quote.commodityID, quantity: 1, in: &session))

        try engine.travel(to: .pasadenaRoseBowl, session: &session)

        XCTAssertEqual(session.day, 2)
        XCTAssertEqual(session.currentDistrictID, .pasadenaRoseBowl)
        XCTAssertTrue(session.completedWeeklyActions.isEmpty)
        XCTAssertNil(session.actionThisWeek)
    }

    func testWorkingCanOnlyRunOnceBeforeFinishingTheWeek() throws {
        var engine = GameEngine(seed: 14)
        var session = engine.makeNewSession()
        provideHousing(in: &session)

        try engine.work(in: &session)

        XCTAssertEqual(session.day, 1)
        XCTAssertGreaterThan(session.cash, 1_000)
        XCTAssertLessThan(session.health, 100)
        XCTAssertEqual(session.debt, 5_000)
        XCTAssertEqual(session.actionThisWeek, .work)
        XCTAssertTrue(session.didCompleteWeeklyAction(.work))
        XCTAssertEqual(session.latestEvent?.group, .money)
        XCTAssertThrowsError(try engine.work(in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .weeklyActionAlreadyChosen)
        }
        session.cash = 100_000
        let quote = try XCTUnwrap(session.market.first)
        XCTAssertNoThrow(try engine.buy(quote.commodityID, quantity: 1, in: &session))
        XCTAssertNoThrow(try engine.invest(100, in: &session))
        XCTAssertEqual(session.completedWeeklyActions, [.trading, .work, .investment])

        try engine.finishStationaryWeek(in: &session)

        XCTAssertEqual(session.day, 2)
        XCTAssertEqual(session.debt, 5_100)
        XCTAssertNil(session.actionThisWeek)
        XCTAssertTrue(session.completedWeeklyActions.isEmpty)
    }

    func testRestAtHomeReplacesWorkAndRestoresFourHealth() throws {
        var engine = GameEngine(seed: 141)
        var session = engine.makeNewSession()
        provideHousing(in: &session)
        session.health = 80

        let event = try engine.restAtHome(in: &session)

        XCTAssertEqual(session.health, 84)
        XCTAssertEqual(event.title, "在家躺平")
        XCTAssertTrue(session.didCompleteWeeklyAction(.work))
        XCTAssertThrowsError(try engine.work(in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .weeklyActionAlreadyChosen)
        }
        XCTAssertNoThrow(try engine.invest(100, in: &session))
    }

    func testRestAtHomeRequiresHousing() throws {
        var engine = GameEngine(seed: 142)
        var session = engine.makeNewSession()

        XCTAssertThrowsError(try engine.restAtHome(in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .homeRequiredToRest)
        }
        XCTAssertFalse(session.didCompleteWeeklyAction(.work))
    }

    func testFigueroaPimpingPaysHighIncomeAndViceSweepCanDoubleIt() throws {
        var sawRegularIncome = false
        var sawDoubledIncome = false

        for seed in 0 ..< 200 {
            var engine = GameEngine(seed: UInt64(seed))
            var session = engine.makeNewSession()
            provideHousing(in: &session)
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
            XCTAssertEqual(session.currentLuck, 49)
        }

        XCTAssertTrue(sawRegularIncome)
        XCTAssertTrue(sawDoubledIncome)
    }

    func testThirdConsecutivePimpingDayTriggersLAPDStingAndTwoWeekSentence() throws {
        var engine = GameEngine(seed: 14)
        var session = engine.makeNewSession()
        provideHousing(in: &session)
        session.currentDistrictID = .figueroaCorridor

        try engine.work(in: &session)
        try engine.finishStationaryWeek(in: &session)
        try engine.work(in: &session)
        try engine.finishStationaryWeek(in: &session)

        session.cash = 2_000
        let event = try engine.work(in: &session)

        XCTAssertEqual(event.id, "lapd-sting-operation")
        XCTAssertEqual(event.baseEffectSummary, "现金 −$1,000\n运气 −8\n跳过 2 周（债务与存款继续计息）")
        XCTAssertEqual(session.cash, 1_000)
        XCTAssertEqual(session.currentLuck, 40)
        XCTAssertEqual(session.day, 5)
        XCTAssertEqual(session.debt, 5_412)
        XCTAssertEqual(session.consecutivePimpingWeeks, 0)
        XCTAssertNil(session.actionThisWeek)
    }

    func testLeavingFigueroaBreaksConsecutivePimpingStreak() throws {
        var engine = GameEngine(seed: 14)
        var session = engine.makeNewSession()
        provideHousing(in: &session)
        session.currentDistrictID = .figueroaCorridor

        try engine.work(in: &session)
        try engine.finishStationaryWeek(in: &session)
        try engine.travel(to: .hollywood, session: &session)

        XCTAssertEqual(session.consecutivePimpingWeeks, 0)
    }

    func testInvestmentCanOnlyRunOnceBeforeFinishingTheWeek() throws {
        var engine = GameEngine(seed: 15)
        var session = engine.makeNewSession()
        provideHousing(in: &session)

        try engine.invest(100, in: &session)

        XCTAssertEqual(session.day, 1)
        XCTAssertTrue((992 ... 1_008).contains(session.cash))
        XCTAssertEqual(session.debt, 5_000)
        XCTAssertEqual(session.actionThisWeek, .investment)
        XCTAssertTrue(session.didCompleteWeeklyAction(.investment))
        XCTAssertEqual(session.latestEvent?.group, .money)
        XCTAssertThrowsError(try engine.invest(100, in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .weeklyActionAlreadyChosen)
        }
        session.cash = 100_000
        let quote = try XCTUnwrap(session.market.first)
        XCTAssertNoThrow(try engine.buy(quote.commodityID, quantity: 1, in: &session))
        XCTAssertNoThrow(try engine.work(in: &session))
        XCTAssertEqual(session.completedWeeklyActions, [.trading, .work, .investment])

        try engine.finishStationaryWeek(in: &session)

        XCTAssertEqual(session.day, 2)
        XCTAssertEqual(session.debt, 5_100)
        XCTAssertNil(session.actionThisWeek)
        XCTAssertTrue(session.completedWeeklyActions.isEmpty)
    }

    func testLosAngelesEventCatalogIncludesRegionalExpansion() {
        XCTAssertEqual(GameContent.marketEvents.count, 25)
        XCTAssertEqual(GameContent.healthEvents.count, 17)
        XCTAssertEqual(GameContent.moneyEvents.count, 14)
        XCTAssertEqual(GameContent.events.count, 56)
        XCTAssertEqual(Set(GameContent.events.map(\.id)).count, 56)
        XCTAssertTrue(GameContent.events.allSatisfy { $0.reputationDelta == 0 })
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
        #if canImport(UIKit)
        let gridlock = try XCTUnwrap(GameContent.moneyEvents.first { $0.id == "freeway-gridlock" })
        XCTAssertEqual(gridlock.group, .money)
        XCTAssertEqual(gridlock.cashDelta, -250)
        XCTAssertEqual(gridlock.healthDelta, 0)
        XCTAssertEqual(gridlock.baseEffectSummary, "现金 −$250")
        for event in GameContent.healthEvents + [gridlock] {
            let name = try XCTUnwrap(event.healthEventImageName, event.id)
            let image = try XCTUnwrap(UIImage(named: name), "Missing bundled artwork: \(name)")
            XCTAssertEqual(image.size.width / image.size.height, 1.5, accuracy: 0.01, event.id)
            XCTAssertEqual(UserNotice(event: event).healthEvent, event)
            // 旧存档只保存事件内容；新插图仍能按稳定 ID 恢复关联。
            let restored = try JSONDecoder().decode(GameEvent.self, from: JSONEncoder().encode(event))
            XCTAssertEqual(restored.healthEventImageName, name)
        }
        for event in GameContent.marketEvents + GameContent.moneyEvents where event.id != gridlock.id {
            XCTAssertNil(UserNotice(event: event).healthEvent, event.id)
        }
        XCTAssertNil(UserNotice(title: "错误", message: "请重试").healthEvent)
        #else
        throw XCTSkip("Bundled artwork is verified by the iOS test target.")
        #endif
    }

    @MainActor
    func testHealthCardFollowsWorldEventWithoutApplyingEffectsAgain() throws {
        let event = try XCTUnwrap(GameContent.healthEvents.first)
        let store = GameStore(seed: 42)
        store.worldEventNotice = WorldEventNotice(
            eventID: "regional-public-health-crisis", triggeredWeek: 49, endingWeek: 52,
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
            ("ding-pang-zi-referral-shift", "现金 +$110\n运气 +1"),
            ("industry-damaged-shipment", "现金 −$190\n运气 −1"),
            ("studio-camera-rush", "二手相机价格 ×1.90（受价格上下限限制）"),
            ("camera-estate-sale", "二手相机价格 ×0.55（受价格上下限限制）"),
            ("community-leftovers", "运气 +1\n免费获得最多 6 份国产辣条（受剩余仓储容量限制）"),
            ("figueroa-vice-sweep", "当周打工收入 ×2")
        ]
        for (id, expected) in examples {
            let event = try XCTUnwrap(LocationEventCatalog.events.first { $0.id == id })
            XCTAssertEqual(event.baseEffectSummary, expected, id)
        }
    }

    func testFormerReputationEffectsNowChangeLuckByEventTone() throws {
        let expectedLuck: [String: Int] = [
            "community-leftovers": 1,
            "vending-compliance": 2,
            "ding-pang-zi-referral-shift": 1,
            "san-gabriel-repaid-tab": 1,
            "industry-damaged-shipment": -1,
            "irvine-expo-overtime": 1,
            "little-saigon-wedding-tips": 1
        ]

        for (id, luckDelta) in expectedLuck {
            let event = try XCTUnwrap(LocationEventCatalog.events.first { $0.id == id })
            XCTAssertEqual(event.luckDelta, luckDelta, id)
            XCTAssertEqual(event.reputationDelta, 0, id)

            var engine = GameEngine(seed: 42)
            var session = engine.makeNewSession()
            let startingLuck = session.currentLuck
            engine.apply(event, to: &session)
            XCTAssertEqual(session.currentLuck, startingLuck + luckDelta, id)
        }
    }

    func testWorkGoodAndBadOutcomesAdjustLuck() throws {
        var sawGoodOutcome = false
        var sawBadOutcome = false

        for seed in 0 ..< 500 where !sawGoodOutcome || !sawBadOutcome {
            var engine = GameEngine(seed: UInt64(seed))
            var session = engine.makeNewSession()
            provideHousing(in: &session)
            let startingLuck = session.currentLuck
            let event = try engine.work(in: &session)

            if event.luckDelta == 2 {
                sawGoodOutcome = true
                XCTAssertEqual(session.currentLuck, startingLuck + 2)
            } else if event.luckDelta == -1 {
                sawBadOutcome = true
                XCTAssertEqual(session.currentLuck, startingLuck - 1)
            }
        }

        XCTAssertTrue(sawGoodOutcome)
        XCTAssertTrue(sawBadOutcome)
    }

    @MainActor
    func testTravelNoticesIncludeEffectsInStandaloneAndWorldEventPopups() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        for startingWeek in [1, 4] {
            let store = GameStore(seed: 42, repository: ProfileRepository(directoryURL: directory))
            store.session.day = startingWeek
            store.select(.hollywood)
            store.travel()
            let event = try XCTUnwrap(store.session.latestEvent)
            let expected = UserNotice(event: event).message
            if startingWeek == 4 {
                let worldNotice = try XCTUnwrap(store.worldEventNotice)
                XCTAssertEqual(worldNotice.localNotice?.message, expected)
            } else {
                XCTAssertNil(store.worldEventNotice)
                try await Task.sleep(for: .milliseconds(1_100))
                XCTAssertEqual(store.notice?.message, expected)
            }
        }
    }

    @MainActor
    func testWorkAndInvestmentPopupsIncludeBaseEffects() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = GameStore(seed: 14, repository: ProfileRepository(directoryURL: directory))
        provideHousing(in: &store.session)
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
        XCTAssertEqual(WorldEventCatalog.events.count, 8)
        XCTAssertEqual(Set(WorldEventCatalog.events.map(\.id)).count, 8)
        XCTAssertEqual(Set(WorldEventCatalog.events.map(\.imageName)).count, 8)
        XCTAssertTrue(WorldEventCatalog.schedule.isDue(in: 5))
        XCTAssertTrue(WorldEventCatalog.schedule.isDue(in: 9))
        XCTAssertFalse(WorldEventCatalog.schedule.isDue(in: 6))

        for event in WorldEventCatalog.events {
            XCTAssertFalse(event.imageName.isEmpty)
            XCTAssertGreaterThan(event.selection.baseWeight, 0)
            XCTAssertTrue((1 ... 3).contains(event.selection.strength))
            XCTAssertGreaterThan(event.durationWeeks, 0)
            XCTAssertGreaterThan(event.modifiers.workIncome, 0)
            XCTAssertGreaterThan(event.modifiers.tradeIncome, 0)
            XCTAssertGreaterThan(event.modifiers.bankInterest, 0)
            XCTAssertGreaterThan(event.modifiers.investmentReturn, 0)
            XCTAssertGreaterThan(event.modifiers.debtInterest, 0)
            XCTAssertGreaterThan(event.modifiers.healthChange, 0)
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

        XCTAssertEqual(session.cash, startingCash + 150)
    }

    func testWildfireAndTourismStackForSalesThenExpireIndependently() throws {
        var engine = GameEngine(seed: 108)
        var session = engine.makeNewSession()
        session.market = [MarketQuote(commodityID: .camera, price: 100, previousPrice: 100)]
        session.inventory[.camera] = InventoryPosition(commodityID: .camera, quantity: 2, averageCost: 100)
        session.activeWorldEvents = [
            ActiveWorldEvent(eventID: "los-angeles-wildfire", startedWeek: 1, endingWeek: 4),
            ActiveWorldEvent(eventID: "southern-california-spending-boom", startedWeek: 1, endingWeek: 6)
        ]
        let startingCash = session.cash
        try engine.sell(.camera, quantity: 1, in: &session)
        XCTAssertEqual(session.cash, startingCash + 75)
        XCTAssertEqual(session.market.first?.price, 100, "Selling-income modifiers must not rewrite market quotes.")

        session.day = 5
        session.resetWeeklyActions()
        try engine.sell(.camera, quantity: 1, in: &session)
        XCTAssertEqual(session.cash, startingCash + 75 + 150, "Only the expired wildfire multiplier is removed.")
    }

    func testWildfireReducesFinalInventoryLiquidation() throws {
        var engine = GameEngine(seed: 109)
        var session = engine.makeNewSession()
        session.day = session.totalDays
        session.market = [MarketQuote(commodityID: .camera, price: 100, previousPrice: 100)]
        session.inventory[.camera] = InventoryPosition(commodityID: .camera, quantity: 3, averageCost: 100)
        session.activeWorldEvents = [
            ActiveWorldEvent(eventID: "los-angeles-wildfire", startedWeek: 49, endingWeek: 52)
        ]
        engine.endJourney(session: &session)
        XCTAssertEqual(session.settlement?.liquidationIncome, 150)
        XCTAssertTrue(session.inventory.isEmpty)
    }

    func testWorldEventModifiesWorkIncomeWithoutChangingLocalOutcome() throws {
        var baseEngine = GameEngine(seed: 102)
        var worldEngine = GameEngine(seed: 102)
        var baseSession = baseEngine.makeNewSession()
        var worldSession = worldEngine.makeNewSession()
        provideHousing(in: &baseSession)
        provideHousing(in: &worldSession)
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
        provideHousing(in: &session)
        session.bank = 10_000
        session.debt = 5_000
        activateWorldEvent("rapid-rate-hike", in: &session)

        try engine.work(in: &session)
        try engine.finishStationaryWeek(in: &session)

        XCTAssertEqual(session.bank, 10_032)
        XCTAssertEqual(session.debt, 5_155)
    }

    func testWorldEventModifiesHealthButDoesNotRewriteLuck() {
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
        XCTAssertEqual(session.currentLuck, 50)
    }

    func testWorldEventTriggersWhenEnteringScheduledInterval() throws {
        var selectedIDs = Set<String>()
        for seed in 0 ..< 24 {
            var engine = GameEngine(seed: UInt64(seed))
            var session = engine.makeNewSession()
            provideHousing(in: &session)
            for _ in 1 ..< 5 {
                try engine.work(in: &session)
                try engine.finishStationaryWeek(in: &session)
            }
            let active = try XCTUnwrap(session.activeWorldEvent)
            let definition = try XCTUnwrap(WorldEventCatalog.event(active.eventID))
            selectedIDs.insert(active.eventID)
            XCTAssertEqual(session.latestWorldEventWeek, 5)
            XCTAssertEqual(active.endingWeek, 5 + definition.durationWeeks - 1)
            XCTAssertEqual(session.lastWorldEventDrawWeek, 5)
        }
        XCTAssertGreaterThan(selectedIDs.count, 1)
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

    func testEveryDistrictHasThreeJobsAndOneInvestment() {
        XCTAssertEqual(GameContent.jobs.count, GameContent.districts.count * 3)
        XCTAssertEqual(GameContent.investments.count, GameContent.districts.count)
        XCTAssertEqual(Set(GameContent.jobs.map(\.districtID)), Set(District.ID.allCases))
        XCTAssertEqual(Set(GameContent.investments.map(\.districtID)), Set(District.ID.allCases))
        XCTAssertEqual(Set(GameContent.jobs.map(\.id)).count, GameContent.jobs.count)
        for districtID in District.ID.allCases {
            let jobs = GameContent.jobs(in: districtID)
            XCTAssertEqual(jobs.count, 3)
            XCTAssertGreaterThanOrEqual(jobs.filter { !$0.requiresVehicle }.count, 2)
        }
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
        var balance = GameBalance()
        balance.clinicClosureChance = 0
        var engine = GameEngine(balance: balance, seed: 24)
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

    func testClinicClosureIsStableAcrossReadsSaveAndOtherActions() throws {
        var engine = GameEngine(seed: 24)
        var session = engine.makeNewSession()
        session.cash = 10_000
        let holiday = engine.clinicClosureHoliday(in: session)
        let checkpoint = engine.randomCheckpoint
        for _ in 0 ..< 20 {
            XCTAssertEqual(engine.clinicClosureHoliday(in: session), holiday)
        }
        try engine.deposit(100, in: &session)
        provideHousing(in: &session)
        _ = try engine.work(in: &session)
        let restored = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(engine.clinicClosureHoliday(in: restored), holiday)
        let resumedEngine = GameEngine(randomCheckpoint: checkpoint)
        XCTAssertEqual(resumedEngine.clinicClosureHoliday(in: restored), holiday)
    }

    func testClinicClosesAboutSeventyPercentOfWeeksAndUsesHolidayLibrary() {
        var engine = GameEngine(seed: 42)
        var session = engine.makeNewSession()
        var closedCount = 0
        var holidays = Set<String>()
        let checkpoint = engine.randomCheckpoint
        for week in 1 ... 10_000 {
            session.day = week
            if let holiday = engine.clinicClosureHoliday(in: session) {
                closedCount += 1
                holidays.insert(holiday.rawValue)
            }
        }
        XCTAssertEqual(Double(closedCount) / 10_000, 0.70, accuracy: 0.02)
        XCTAssertEqual(holidays, Set(USFederalHoliday.allCases.map(\.rawValue)))
        XCTAssertEqual(holidays.count, 11)
        XCTAssertEqual(engine.randomCheckpoint, checkpoint)
    }

    func testClinicClosureRejectsTreatmentWithoutChangingSession() throws {
        var balance = GameBalance()
        balance.clinicClosureChance = 1
        var engine = GameEngine(balance: balance, seed: 24)
        var session = engine.makeNewSession()
        session.health = 40
        let before = session
        let holiday = try XCTUnwrap(engine.clinicClosureHoliday(in: session))
        XCTAssertThrowsError(try engine.heal(30, in: &session)) {
            XCTAssertEqual($0 as? GameRuleError, .clinicClosed(holiday.rawValue))
            XCTAssertEqual($0.localizedDescription, "今天是\(holiday.rawValue)节日关门一周")
        }
        XCTAssertEqual(session.cash, before.cash)
        XCTAssertEqual(session.health, before.health)
        XCTAssertNil(session.clinicTreatmentWeek)
        XCTAssertEqual(session.journey?.healthRecovered, before.journey?.healthRecovered)
        XCTAssertEqual(session.journey?.treatmentSpending, before.journey?.treatmentSpending)
    }

    func testClinicWeeklyCapSurvivesRepeatedTreatmentAndReload() throws {
        var balance = GameBalance()
        balance.clinicClosureChance = 0
        var engine = GameEngine(balance: balance, seed: 24)
        var session = engine.makeNewSession()
        session.health = 10
        session.cash = 10_000
        try engine.heal(20, in: &session)
        session = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(session))
        try engine.heal(30, in: &session)
        XCTAssertEqual(session.health, 40)
        XCTAssertEqual(session.cash, 9_250)
        XCTAssertEqual(session.clinicTreatmentPoints, 30)
        XCTAssertEqual(session.journey?.healthRecovered, 30)
        XCTAssertEqual(session.journey?.treatmentSpending, 750)
        XCTAssertThrowsError(try engine.heal(1, in: &session)) {
            XCTAssertEqual($0 as? GameRuleError, .clinicWeeklyLimitReached)
        }
        XCTAssertEqual(session.cash, 9_250)
        session.day += 1
        try engine.heal(30, in: &session)
        XCTAssertEqual(session.health, 70)
        XCTAssertEqual(session.clinicTreatmentPoints, 30)
        XCTAssertEqual(session.clinicTreatmentWeek, 2)
    }

    func testClinicWorldModifierCannotExceedWeeklyCapAndQuoteMatchesCharge() throws {
        var balance = GameBalance()
        balance.clinicClosureChance = 0
        var engine = GameEngine(balance: balance, seed: 24)
        var session = engine.makeNewSession()
        session.health = 10
        session.cash = 10_000
        activateWorldEvent("regional-public-health-crisis", in: &session)
        let recovery = engine.clinicTreatmentRecovery(25, in: session)
        XCTAssertEqual(recovery, 30)
        try engine.heal(25, in: &session)
        XCTAssertEqual(session.health, 10 + recovery)
        XCTAssertEqual(session.cash, 10_000 - recovery * balance.treatmentCostPerPoint)
        XCTAssertEqual(engine.clinicRemainingTreatmentPoints(in: session), 0)
    }

    func testClinicAndMassageRespectHealthCeilingAndCashFailuresDoNotUseAllowance() throws {
        var balance = GameBalance()
        balance.clinicClosureChance = 0
        var engine = GameEngine(balance: balance, seed: 24)
        var session = engine.makeNewSession()
        session.health = 98
        session.cash = 0
        XCTAssertThrowsError(try engine.heal(30, in: &session))
        XCTAssertThrowsError(try engine.visitMassageParlor(in: &session))
        XCTAssertNil(session.clinicTreatmentWeek)
        XCTAssertNil(session.massageVisitWeek)
        XCTAssertEqual(session.health, 98)
        session.cash = 10_000
        try engine.heal(30, in: &session)
        XCTAssertEqual(session.health, 100)
        XCTAssertEqual(session.cash, 9_950)
        XCTAssertEqual(session.clinicTreatmentPoints, 2)
        XCTAssertThrowsError(try engine.visitMassageParlor(in: &session)) {
            XCTAssertEqual($0 as? GameRuleError, .healthAlreadyFull)
        }
        XCTAssertNil(session.massageVisitWeek)
        session.health = 98
        try engine.visitMassageParlor(in: &session)
        XCTAssertEqual(session.health, 100)
        XCTAssertEqual(session.cash, 9_350)
    }

    func testMassageWorksDuringClosureRestoresTenAndLocksUntilNextWeek() throws {
        var balance = GameBalance()
        balance.clinicClosureChance = 1
        var engine = GameEngine(balance: balance, seed: 24)
        var session = engine.makeNewSession()
        session.health = 40
        session.cash = 10_000
        activateWorldEvent("regional-public-health-crisis", in: &session)
        try engine.visitMassageParlor(in: &session)
        XCTAssertEqual(session.health, 50)
        XCTAssertEqual(session.cash, 9_400)
        XCTAssertEqual(session.history(for: .health).first?.reason, "波霸按摩院")
        XCTAssertEqual(session.journey?.healthRecovered, 10)
        XCTAssertEqual(session.journey?.treatmentSpending, 600)
        XCTAssertFalse(session.hasCompletedAnyWeeklyAction)
        session = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(session))
        XCTAssertThrowsError(try engine.visitMassageParlor(in: &session)) {
            XCTAssertEqual($0 as? GameRuleError, .massageAlreadyVisited)
        }
        XCTAssertEqual(session.cash, 9_400)
        session.day += 1
        try engine.visitMassageParlor(in: &session)
        XCTAssertEqual(session.health, 60)
        XCTAssertEqual(session.cash, 8_800)
    }

    func testMassageUnitPriceExceedsClinicAndEveryHousingTier() {
        let balance = GameBalance()
        XCTAssertGreaterThan(balance.massageCostPerPoint, balance.treatmentCostPerPoint)
        for tier in HousingTier.allCases {
            XCTAssertGreaterThan(Double(balance.massageCostPerPoint),
                                 Double(tier.weeklyRent) / Double(tier.weeklyHealthRecovery))
        }
    }

    @MainActor
    func testLegacyCityServicesMigrateAndStorePersistsUsage() throws {
        var engine = GameEngine(seed: 24)
        let original = engine.makeNewSession()
        var legacyJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        for key in ["cityServiceSeed", "clinicTreatmentWeek", "clinicTreatmentPoints", "massageVisitWeek"] {
            legacyJSON.removeValue(forKey: key)
        }
        let legacy = try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: legacyJSON))
        XCTAssertNil(legacy.cityServiceSeed)
        let store = GameStore(snapshot: GameSnapshot(profileID: .one, session: legacy,
                                                    randomCheckpoint: engine.randomCheckpoint))
        XCTAssertEqual(store.session.cityServiceSeed, engine.randomCheckpoint)
        store.session.health = 50
        store.session.cash = 1_000
        XCTAssertTrue(store.visitMassageParlor())
        XCTAssertTrue(store.didVisitMassageThisWeek)
        XCTAssertFalse(store.visitMassageParlor())
        XCTAssertEqual(store.session.health, 60)
        XCTAssertEqual(store.session.cash, 400)
        XCTAssertEqual(store.notice?.message, GameRuleError.massageAlreadyVisited.localizedDescription)
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
        provideHousing(in: &store.session)
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
        provideHousing(in: &session)
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
        XCTAssertTrue(restored.session.didCompleteWeeklyAction(.work))
        XCTAssertThrowsError(try engine.work(in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .weeklyActionAlreadyChosen)
        }
    }

    func testVersion11StartsWithNeutralLuckAndNoEquipment() {
        var engine = GameEngine(seed: 90)
        let session = engine.makeNewSession()

        XCTAssertEqual(session.currentLuck, 50)
        XCTAssertFalse(session.currentEquipment.hasDriversLicense)
        XCTAssertFalse(session.currentEquipment.hasVehicle)
        XCTAssertFalse(session.currentEquipment.rentsHousing)
        XCTAssertEqual(session.currentEquipment.completedMilestoneCount, 0)
        XCTAssertFalse(session.hasHope)
        XCTAssertEqual(GameContent.lifeChoices.count, 12)
    }

    func testDrivingJobRequiresVehicleAndUsesNetIncome() throws {
        var engine = GameEngine(seed: 92)
        var session = engine.makeNewSession()
        provideHousing(in: &session)
        let drivingJob = try XCTUnwrap(
            GameContent.jobs(in: .dingPangZiPlaza).first(where: \.requiresVehicle)
        )

        XCTAssertThrowsError(try engine.work(drivingJob.id, in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .vehicleRequired)
        }
        try engine.startHousingRental(in: &session)
        session.day += 1
        try completeDriversLicense(in: &session, using: &engine)
        session.day += 1
        try engine.startCarRental(in: &session)
        let startingCash = session.cash

        let event = try engine.work(drivingJob.id, in: &session)

        XCTAssertEqual(session.actionThisWeek, .work)
        XCTAssertTrue(
            [80, 50, -40, 0].map { drivingJob.wage + $0 - engine.balance.drivingOperatingCost }
                .contains(event.baseCashDelta ?? -1)
        )
        XCTAssertEqual(session.cash, startingCash + event.cashDelta)
        XCTAssertEqual(session.journey?.drivingIncome, event.cashDelta)
    }

    func testHousingAndCarRentRenewOnceWhenEnteringNextWeek() throws {
        var engine = GameEngine(seed: 93)
        var session = engine.makeNewSession()
        session.cash = 5_000
        session.health = 80
        try engine.startHousingRental(in: &session)
        session.day += 1
        try completeDriversLicense(in: &session, using: &engine)
        session.day += 1
        try engine.startCarRental(in: &session)
        try engine.work(in: &session)
        let healthAfterWork = session.health

        try engine.finishStationaryWeek(in: &session)

        XCTAssertEqual(session.currentEquipment.housingPaidThroughWeek, session.day)
        XCTAssertEqual(session.currentEquipment.carRentPaidThroughWeek, session.day)
        XCTAssertEqual(session.health, min(100, healthAfterWork + engine.balance.housingHealthRecovery))
        XCTAssertEqual(session.journey?.housingSpending, engine.balance.weeklyHousingRent * 2)
        XCTAssertEqual(
            session.journey?.vehicleSpending,
            engine.balance.driversLicenseCost + engine.balance.weeklyCarRent * 2
        )
    }

    func testLifeChoiceBlocksActionsAndCanOnlyResolveOnce() throws {
        var engine = GameEngine(seed: 94)
        var session = engine.makeNewSession()
        provideHousing(in: &session)
        for _ in 1 ..< 8 {
            try engine.work(in: &session)
            try engine.finishStationaryWeek(in: &session)
        }
        let choice = try XCTUnwrap(session.pendingLifeChoiceID.flatMap(GameContent.lifeChoice))
        let option = try XCTUnwrap(choice.options.first)
        let startingLuck = session.currentLuck

        XCTAssertThrowsError(try engine.work(in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .lifeChoicePending)
        }
        _ = try engine.resolveLifeChoice(option.id, in: &session)

        XCTAssertNil(session.pendingLifeChoiceID)
        XCTAssertEqual(session.currentLuck, min(100, max(0, startingLuck + option.luckDelta)))
        XCTAssertTrue(session.resolvedLifeChoiceIDs?.contains(choice.id) == true)
        XCTAssertThrowsError(try engine.resolveLifeChoice(option.id, in: &session))
    }

    func testHighLuckProducesMoreFavorableEncountersThanLowLuck() throws {
        var lowLuckFavorable = 0
        var highLuckFavorable = 0
        for seed in 0 ..< 400 {
            var lowEngine = GameEngine(seed: UInt64(seed))
            var lowSession = lowEngine.makeNewSession()
            lowSession.currentLuck = 0
            try lowEngine.travel(to: .pasadenaRoseBowl, session: &lowSession)
            if lowSession.latestEvent?.kind == .opportunity,
               (lowSession.latestEvent?.healthDelta ?? 0) >= 0 {
                lowLuckFavorable += 1
            }

            var highEngine = GameEngine(seed: UInt64(seed))
            var highSession = highEngine.makeNewSession()
            highSession.currentLuck = 100
            try highEngine.travel(to: .pasadenaRoseBowl, session: &highSession)
            if highSession.latestEvent?.kind == .opportunity,
               (highSession.latestEvent?.healthDelta ?? 0) >= 0 {
                highLuckFavorable += 1
            }
        }

        XCTAssertGreaterThan(highLuckFavorable, lowLuckFavorable + 80)
    }

    func testVersionOneSnapshotMigratesToNeutralLuckAndEmptyEquipment() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ProfileRepository(directoryURL: directory)
        var engine = GameEngine(seed: 95)
        var session = engine.makeNewSession()
        session.luck = nil
        session.equipment = nil
        session.resolvedLifeChoiceIDs = nil
        try repository.save(
            GameSnapshot(
                version: 1, profileID: .one, session: session,
                randomCheckpoint: engine.randomCheckpoint
            )
        )

        let restored = try XCTUnwrap(repository.load(.one))

        XCTAssertEqual(restored.version, GameSnapshot.currentVersion)
        XCTAssertEqual(restored.session.currentLuck, 50)
        XCTAssertEqual(restored.session.currentEquipment, LifeEquipment())
        XCTAssertEqual(restored.session.resolvedLifeChoiceIDs, [])
    }

    func testUnaffordableRentStopsWithoutCreatingDebt() throws {
        var engine = GameEngine(seed: 96)
        var session = engine.makeNewSession()
        session.cash = engine.balance.weeklyHousingRent
        try engine.startHousingRental(in: &session)
        try engine.work(in: &session)
        session.cash = 0

        try engine.finishStationaryWeek(in: &session)

        XCTAssertFalse(session.currentEquipment.rentsHousing)
        XCTAssertEqual(session.debt, 5_100)
        XCTAssertTrue(session.log.contains(where: { $0.title == "被房东赶出房子" }))
    }

    func testAmericanDreamProgressOnlyAdvancesThroughInvestments() throws {
        var engine = GameEngine(seed: 97)
        var session = engine.makeNewSession()

        try engine.invest(100, in: &session)
        try engine.finishStationaryWeek(in: &session)

        XCTAssertEqual(session.day, 2)
        XCTAssertEqual(session.currentEquipment.completedMilestoneCount, 0)

        try engine.startHousingRental(in: &session)

        XCTAssertEqual(session.currentEquipment.completedMilestoneCount, 1)
    }

    func testAmericanDreamMilestonesMustBeCompletedInOrderAndPersist() throws {
        var engine = GameEngine(seed: 98)
        var session = engine.makeNewSession()
        session.cash = 100_000

        XCTAssertThrowsError(try engine.obtainDriversLicense(in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .previousMilestoneRequired)
        }

        try engine.startHousingRental(in: &session)
        XCTAssertEqual(session.currentEquipment.completedMilestoneCount, 1)
        session.day += 1
        try completeDriversLicense(in: &session, using: &engine)
        XCTAssertEqual(session.currentEquipment.completedMilestoneCount, 2)
        session.day += 1
        try engine.startCarRental(in: &session)
        XCTAssertEqual(session.currentEquipment.completedMilestoneCount, 3)
        session.day += 1
        try engine.stopCarRental(in: &session)
        XCTAssertEqual(session.currentEquipment.completedMilestoneCount, 3)
        session.day += 1
        try engine.buyTools(in: &session)
        XCTAssertEqual(session.currentEquipment.completedMilestoneCount, 4)
        session.day += 1
        try engine.investInProperty(in: &session)

        XCTAssertEqual(session.currentEquipment.completedMilestoneCount, 5)
        XCTAssertTrue(session.hasHope)
        XCTAssertFalse(session.currentEquipment.rentsHousing)
        XCTAssertEqual(
            session.journey?.dreamInvestmentSpending,
            engine.balance.weeklyHousingRent
                + engine.balance.driversLicenseCost
                + engine.balance.weeklyCarRent
                + engine.balance.toolsPurchasePrice
                + engine.balance.propertyInvestmentPrice
        )
    }

    func testToolsIncreaseRegularJobWageAndReduceHealthCost() throws {
        var baselineEngine = GameEngine(seed: 99)
        var baseline = baselineEngine.makeNewSession()
        provideHousing(in: &baseline)
        let job = try XCTUnwrap(GameContent.jobs(in: baseline.currentDistrictID).first(where: { !$0.requiresVehicle }))
        let baselineEvent = try baselineEngine.work(job.id, in: &baseline)

        var equippedEngine = GameEngine(seed: 99)
        var equipped = equippedEngine.makeNewSession()
        equipped.equipment = LifeEquipment(ownsTools: true)
        provideHousing(in: &equipped)
        let equippedEvent = try equippedEngine.work(job.id, in: &equipped)

        let expectedWageIncrease = Int((Double(job.wage) * equippedEngine.balance.toolsWageMultiplier).rounded()) - job.wage
        XCTAssertEqual(equippedEvent.baseCashDelta, (baselineEvent.baseCashDelta ?? 0) + expectedWageIncrease)
        XCTAssertEqual(equippedEvent.healthDelta, baselineEvent.healthDelta + equippedEngine.balance.toolsHealthProtection)
    }

    func testPropertyAddsWeeklyIncomeAndHealthRecovery() throws {
        var baselineEngine = GameEngine(seed: 100)
        var baseline = baselineEngine.makeNewSession()
        baseline.cash = 10_000
        baseline.health = 60
        try baselineEngine.invest(100, in: &baseline)
        try baselineEngine.finishStationaryWeek(in: &baseline)

        var propertyEngine = GameEngine(seed: 100)
        var property = propertyEngine.makeNewSession()
        property.cash = 10_000
        property.health = 60
        property.equipment = LifeEquipment(ownsProperty: true)
        try propertyEngine.invest(100, in: &property)
        try propertyEngine.finishStationaryWeek(in: &property)

        XCTAssertEqual(property.cash, baseline.cash + propertyEngine.balance.propertyWeeklyIncome)
        XCTAssertEqual(property.health, baseline.health + propertyEngine.balance.propertyHealthRecovery)
    }

    func testHopePreventsICEEndingAtWeek52() {
        var engine = GameEngine(seed: 101)
        var session = engine.makeNewSession()
        session.day = session.totalDays
        session.equipment = LifeEquipment(
            hasDriversLicense: true,
            completedHousingMilestone: true,
            completedVehicleMilestone: true,
            ownsTools: true,
            ownsProperty: true
        )

        engine.endJourney(session: &session)

        XCTAssertTrue(session.isFinished)
        XCTAssertTrue(session.isRootedInLosAngeles)
        XCTAssertFalse(session.isDeported)
        XCTAssertEqual(session.settlement?.ticketCost, 0)
        XCTAssertTrue(session.log.contains(where: { $0.eventID == "ending-rooted-los-angeles" }))
    }

    func testHousingTiersConvertMonthlyRentToWeeklyBenefits() {
        XCTAssertEqual(HousingTier.allCases.map(\.monthlyRent), [440, 720, 1_000])
        XCTAssertEqual(HousingTier.allCases.map(\.weeklyRent), [110, 180, 250])
        XCTAssertEqual(HousingTier.allCases.map(\.weeklyHealthRecovery), [2, 4, 6])
        XCTAssertEqual(HousingTier.allCases.map(\.savingsProofMonths), [0, 2, 4])
        XCTAssertEqual(HousingTier.allCases.map(\.prepaidWeeks), [1, 3, 6])
    }

    func testApartmentWithoutSavingsProofUsesThreeWeekPrepayment() throws {
        var engine = GameEngine(seed: 104)
        var session = engine.makeNewSession()
        session.cash = 2_000

        try engine.startHousingRental(
            .cityApartment,
            paymentMethod: .prepaidInstallments,
            in: &session
        )

        XCTAssertEqual(session.cash, 1_460)
        XCTAssertEqual(session.currentEquipment.housingNextPaymentWeek, 4)
        XCTAssertEqual(session.currentEquipment.housingPaidThroughWeek, 3)
        XCTAssertEqual(session.journey?.housingSpending, 540)
    }

    func testHillsideSavingsProofRequiresFourMonthsInBank() throws {
        var engine = GameEngine(seed: 105)
        var session = engine.makeNewSession()
        session.cash = 2_000
        session.bank = HousingTier.hillsideHouse.savingsProofAmount - 1

        XCTAssertThrowsError(
            try engine.startHousingRental(
                .hillsideHouse,
                paymentMethod: .weeklyWithSavingsProof,
                in: &session
            )
        ) { error in
            XCTAssertEqual(error as? GameRuleError, .insufficientSavingsProof)
        }

        session.bank += 1
        try engine.startHousingRental(
            .hillsideHouse,
            paymentMethod: .weeklyWithSavingsProof,
            in: &session
        )
        XCTAssertEqual(session.currentEquipment.housingNextPaymentWeek, 2)
        XCTAssertEqual(session.cash, 1_750)
    }

    func testHousingPaymentFailureEvictsPlayerAndRemovesWorkAccess() throws {
        var engine = GameEngine(seed: 106)
        var session = engine.makeNewSession()
        session.cash = 600
        try engine.startHousingRental(
            .cityApartment,
            paymentMethod: .prepaidInstallments,
            in: &session
        )
        session.day = 3
        session.cash = 0
        session.bank = 0
        session.actionThisWeek = .work

        try engine.finishStationaryWeek(in: &session)

        XCTAssertFalse(session.currentEquipment.hasHousing)
        XCTAssertTrue(session.log.contains(where: { $0.eventID == "housing-evicted" }))
        XCTAssertEqual(session.latestHousingEvictionWeek, 4)
        XCTAssertEqual(session.latestHousingEvictionAmount, 540)
        session.currentDistrictID = .koreatown
        XCTAssertThrowsError(try engine.work("koreatown-market", in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .housingRequired)
        }
    }

    @MainActor
    func testEndingWeekWithUnaffordableRentShowsWarningBeforeRandomEvent() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = GameStore(seed: 110, repository: ProfileRepository(directoryURL: directory))
        store.session.cash = 600
        XCTAssertTrue(store.startHousingRental(.cityApartment, paymentMethod: .prepaidInstallments))
        store.session.day = 3
        store.session.cash = 0
        store.session.bank = 0
        store.session.actionThisWeek = .work

        store.finishStationaryWeek()

        XCTAssertEqual(store.session.day, 4)
        XCTAssertEqual(store.notice?.title, "房租没有续上")
        XCTAssertTrue(store.notice?.message.contains("下回合将失去“有房住”增益") == true)
        XCTAssertTrue(store.notice?.isHousingEviction == true)
        XCTAssertNotNil(store.queuedNotice?.event)

        store.dismissNotice()
        XCTAssertNotNil(store.notice?.event)
        XCTAssertNil(store.queuedNotice)
    }

    func testLowEndDistrictsOfferWorkWithoutHousing() throws {
        let expectedJobs: Set<String> = [
            "figueroa-cleanup",
            "inglewood-loader",
            "inglewood-cleaner",
            "ding-kitchen",
            "ding-loader",
            "rowland-night-market",
            "industry-sorter",
        ]
        XCTAssertEqual(Set(GameContent.jobs.filter { !$0.requiresHousing }.map(\.id)), expectedJobs)

        var engine = GameEngine(seed: 107)
        var session = engine.makeNewSession()
        XCTAssertFalse(session.currentEquipment.hasHousing)
        XCTAssertNoThrow(try engine.work("ding-kitchen", in: &session))
    }

    func testStableWorkStillRequiresHousing() throws {
        var engine = GameEngine(seed: 108)
        var session = engine.makeNewSession()
        session.currentDistrictID = .koreatown

        XCTAssertThrowsError(try engine.work("koreatown-market", in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .housingRequired)
        }
    }

    func testBasementMoveInFeeUsesBalanceVariable() throws {
        var balance = GameBalance()
        balance.basementMoveInFee = 75
        var engine = GameEngine(balance: balance, seed: 109)
        var session = engine.makeNewSession()
        let startingCash = session.cash

        try engine.startHousingRental(.basement, in: &session)

        XCTAssertEqual(session.cash, startingCash - 75)
        XCTAssertEqual(session.journey?.housingSpending, 75)
    }

    func testOnlyOneAmericanDreamOperationCanRunEachWeek() throws {
        var engine = GameEngine(seed: 102)
        var session = engine.makeNewSession()
        session.cash = 10_000

        try engine.startHousingRental(.cityApartment, in: &session)

        XCTAssertTrue(session.didPerformDreamActionThisWeek)
        XCTAssertThrowsError(try engine.obtainDriversLicense(in: &session)) { error in
            XCTAssertEqual(error as? GameRuleError, .dreamActionAlreadyTaken)
        }

        session.day += 1
        XCTAssertFalse(session.didPerformDreamActionThisWeek)
    }

    func testLicensePassChanceFollowsLuck() {
        let engine = GameEngine(seed: 103)

        XCTAssertEqual(engine.driversLicensePassChance(for: 0), 0.40)
        XCTAssertEqual(engine.driversLicensePassChance(for: 50), 0.65)
        XCTAssertEqual(engine.driversLicensePassChance(for: 100), 0.90)
    }

    func testFailedLicenseAttemptChargesRegistrationOnceAndRetriesNextWeek() throws {
        var foundFailure = false

        for seed in 0 ..< 100 where !foundFailure {
            var engine = GameEngine(seed: UInt64(seed))
            var session = engine.makeNewSession()
            session.cash = 10_000
            session.currentLuck = 0
            session.equipment = LifeEquipment(completedHousingMilestone: true)
            let startingCash = session.cash

            let passed = try engine.obtainDriversLicense(in: &session)
            guard !passed else { continue }
            foundFailure = true

            XCTAssertEqual(session.cash, startingCash - engine.balance.driversLicenseCost)
            XCTAssertEqual(session.currentEquipment.licenseAttemptCount, 1)
            XCTAssertThrowsError(try engine.obtainDriversLicense(in: &session)) { error in
                XCTAssertEqual(error as? GameRuleError, .dreamActionAlreadyTaken)
            }

            session.day += 1
            let cashBeforeRetry = session.cash
            _ = try engine.obtainDriversLicense(in: &session)
            XCTAssertEqual(session.cash, cashBeforeRetry)
            XCTAssertEqual(session.currentEquipment.licenseAttemptCount, 2)
        }

        XCTAssertTrue(foundFailure)
    }

    func testInAppPurchaseCatalogRestoresFourFixedAdventureProducts() {
        XCTAssertEqual(
            AdventureProduct.allCases.map(\.rawValue),
            [
                "com.graymongooseus.SurviveInLA.adventure.vietnam",
                "com.graymongooseus.SurviveInLA.adventure.lottery",
                "com.graymongooseus.SurviveInLA.adventure.options",
                "com.graymongooseus.SurviveInLA.adventure.watch",
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

        XCTAssertTrue(store.applyPurchasedAdventure(.vietnamGirlfriend, transactionID: transactionID))
        XCTAssertEqual(store.session.cash, startingCash + 3_000)
        XCTAssertTrue(store.applyPurchasedAdventure(.vietnamGirlfriend, transactionID: transactionID))
        XCTAssertEqual(store.session.cash, startingCash + 3_000)
    }

    @MainActor
    func testPurchasedCurrencyAndTransactionMarkerPersistTogether() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = ProfileRepository(directoryURL: directory)
        let store = GameStore(seed: 92, profileID: .one, repository: repository)
        store.onSave = { snapshot in try repository.save(snapshot) }
        let transactionID = UInt64(Date.now.timeIntervalSince1970 * 1_000_000) &+ 1
        let startingCash = store.session.cash

        XCTAssertTrue(store.applyPurchasedAdventure(.anonymousBroker, transactionID: transactionID))
        XCTAssertEqual(store.session.cash, startingCash + 18_000)

        let snapshot = try XCTUnwrap(repository.load(.one))
        XCTAssertTrue(snapshot.session.processedPurchaseTransactionIDs?.contains(String(transactionID)) == true)

        let restored = GameStore(profileID: .one, snapshot: snapshot, repository: repository)
        restored.onSave = { newSnapshot in try repository.save(newSnapshot) }
        XCTAssertTrue(restored.applyPurchasedAdventure(.anonymousBroker, transactionID: transactionID))
        XCTAssertEqual(restored.session.cash, startingCash + 18_000)
    }

    @MainActor
    func testPurchasedCurrencyRollsBackWhenSnapshotSaveFails() {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = GameStore(
            seed: 93,
            profileID: .one,
            repository: ProfileRepository(directoryURL: directory)
        )
        store.onSave = { _ in throw CocoaError(.fileWriteNoPermission) }
        let transactionID = UInt64(Date.now.timeIntervalSince1970 * 1_000_000) &+ 2
        let startingCash = store.session.cash

        XCTAssertFalse(store.applyPurchasedAdventure(.sanGabrielGarageSale, transactionID: transactionID))
        XCTAssertEqual(store.session.cash, startingCash)
        XCTAssertFalse(
            store.session.processedPurchaseTransactionIDs?.contains(String(transactionID)) == true
        )
    }

    private func activateWorldEvent(_ id: String, in session: inout GameSession) {
        session.activeWorldEvent = ActiveWorldEvent(
            eventID: id,
            startedWeek: session.day,
            endingWeek: session.totalDays
        )
    }

    private func provideHousing(in session: inout GameSession) {
        var equipment = session.currentEquipment
        equipment.rentsHousing = true
        equipment.housingTier = .basement
        equipment.housingPaidThroughWeek = 999
        equipment.housingNextPaymentWeek = 1_000
        session.equipment = equipment
    }

    private func completeDriversLicense(
        in session: inout GameSession,
        using engine: inout GameEngine
    ) throws {
        while !session.currentEquipment.hasDriversLicense {
            _ = try engine.obtainDriversLicense(in: &session)
            if !session.currentEquipment.hasDriversLicense {
                session.day += 1
            }
        }
    }
}
