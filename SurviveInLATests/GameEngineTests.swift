import XCTest
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

    private func activateWorldEvent(_ id: String, in session: inout GameSession) {
        session.activeWorldEvent = ActiveWorldEvent(
            eventID: id,
            startedWeek: session.day,
            endingWeek: session.totalDays
        )
    }
}
