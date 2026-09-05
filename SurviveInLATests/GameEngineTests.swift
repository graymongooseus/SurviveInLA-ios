import XCTest
@testable import SurviveInLA

final class GameEngineTests: XCTestCase {
    func testNewSessionUsesClassicStartingPressure() {
        var engine = GameEngine(seed: 42)
        let session = engine.makeNewSession()

        XCTAssertEqual(session.day, 1)
        XCTAssertEqual(session.cash, 2_000)
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
        XCTAssertTrue((1_992 ... 2_008).contains(session.cash))
        XCTAssertEqual(session.debt, 5_000)
        XCTAssertEqual(session.actionThisWeek, .investment)
        XCTAssertEqual(session.latestEvent?.group, .money)
        XCTAssertThrowsError(try engine.invest(100, in: &session)) { error in
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

    @MainActor
    func testAdventurePurchasesApplyCashAndIgnoreDuplicateTransactions() {
        let historyKey = "iap.processedTransactionIDs.v1"
        UserDefaults.standard.removeObject(forKey: historyKey)
        defer { UserDefaults.standard.removeObject(forKey: historyKey) }

        let store = GameStore(seed: 101)
        let startingLogCount = store.session.log.count

        for (index, adventure) in AdventureProduct.allCases.enumerated() {
            store.applyPurchasedAdventure(adventure, transactionID: UInt64(9_000 + index))
        }

        XCTAssertEqual(store.session.cash, 59_000)
        XCTAssertEqual(store.session.log.count, startingLogCount + 4)
        XCTAssertEqual(store.purchasedAdventure, .garageSaleWatch)

        store.applyPurchasedAdventure(.vietnamGirlfriend, transactionID: 9_000)

        XCTAssertEqual(store.session.cash, 59_000)
        XCTAssertEqual(store.session.log.count, startingLogCount + 4)
    }

    func testAdventureCatalogHasFourUniqueConsumableProductIDs() {
        let products = AdventureProduct.allCases

        XCTAssertEqual(products.count, 4)
        XCTAssertEqual(Set(products.map(\.rawValue)).count, 4)
        XCTAssertEqual(products.map(\.fallbackPrice), ["$1.99", "$2.99", "$5.99", "$9.99"])
        XCTAssertEqual(products.map(\.cashDelta), [-3_000, 6_000, 18_000, 36_000])
    }
}

extension GameEngineTests {
    func testWeek52ArrivalEndsJourneyBeforeAnotherRandomEvent() throws {
        var engine = GameEngine(seed: 200)
        var session = engine.makeNewSession()
        session.day = 51
        let health = session.health
        try engine.travel(to: .hollywood, session: &session)
        XCTAssertTrue(session.isDeported)
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.health, health)
        XCTAssertEqual(session.settlement?.ticketCost, 500)
        XCTAssertEqual(session.log.first?.eventID, "ending-ice-guangzhou")
        XCTAssertThrowsError(try engine.work(in: &session))
        XCTAssertThrowsError(try engine.travel(to: .venice, session: &session))
    }

    func testStationaryAndSkippedWeeksAlsoTriggerEnding() throws {
        var engine = GameEngine(seed: 202)
        var stationary = engine.makeNewSession()
        stationary.day = 51
        stationary.actionThisWeek = .investment
        try engine.finishStationaryWeek(in: &stationary)
        XCTAssertTrue(stationary.isDeported)

        var arrested = engine.makeNewSession()
        arrested.day = 50
        arrested.currentDistrictID = .figueroaCorridor
        arrested.consecutivePimpingWeeks = 2
        try engine.work(in: &arrested)
        XCTAssertTrue(arrested.isDeported)
        XCTAssertEqual(arrested.settlement?.ticketCost, 500)
    }

    func testAirfareUsesSavingsThenDebtAndCannotBeChargedTwice() {
        for (cash, bank, expectedCash, expectedBank, ticketDebt) in [
            (700, 300, 200, 300, 0), (100, 600, 0, 200, 0), (100, 150, 0, 0, 250), (0, 0, 0, 0, 500)
        ] {
            var engine = GameEngine(seed: 203)
            var session = engine.makeNewSession()
            session.day = 52
            session.cash = cash
            session.bank = bank
            let before = session.netWorth
            engine.endJourney(session: &session)
            engine.endJourney(session: &session)
            XCTAssertEqual(session.cash, expectedCash)
            XCTAssertEqual(session.bank, expectedBank)
            XCTAssertEqual(session.debt, 5_000 + ticketDebt)
            XCTAssertEqual(session.netWorth, before - 500)
            XCTAssertEqual(session.historicalEvents.filter { $0.eventID == "ending-ice-guangzhou" }.count, 1)
        }
    }

    func testEarlyAndHealthFailureDoNotChargeAFlight() {
        var engine = GameEngine(seed: 204)
        var session = engine.makeNewSession()
        engine.endJourney(session: &session)
        XCTAssertFalse(session.isFinished)
        session.day = 52
        session.health = 0
        let cash = session.cash
        engine.endJourney(session: &session)
        XCTAssertNil(session.settlement)
        XCTAssertEqual(session.cash, cash)
    }

    func testHealthLedgerPreservesActualLossesAfterTreatment() throws {
        var engine = GameEngine(seed: 205)
        var session = engine.makeNewSession()
        session.cash = 10_000
        let harm = GameEvent(id: "harm", kind: .health, title: "受伤", message: "测试", healthDelta: -70)
        engine.apply(harm, to: &session)
        try engine.heal(60, in: &session)
        engine.apply(harm, to: &session)
        XCTAssertEqual(session.health, 20)
        XCTAssertEqual(session.journey?.healthLost, 140)
        XCTAssertEqual(session.journey?.healthRecovered, 60)
        XCTAssertEqual(session.journey?.treatmentSpending, 1_500)
        engine.apply(harm, to: &session)
        XCTAssertEqual(session.journey?.healthLost, 160, "Health loss is clamped to actual remaining health")
    }

    func testJourneyArchiveKeepsBestForEveryPlayerAndAllEventsAfterRestart() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ProfileRepository(directoryURL: directory)
        var engine = GameEngine(seed: 206)
        for (index, profile, amount) in [(1, ProfileID.one, 5_000), (2, .one, 3_000), (3, .two, 9_000), (4, .three, 0)] {
            var session = engine.makeNewSession()
            session.day = 52
            session.cash = amount
            engine.endJourney(session: &session)
            let snapshot = GameSnapshot(profileID: profile, session: session, randomCheckpoint: 1, updatedAt: Date(timeIntervalSince1970: Double(index)))
            try repository.save(snapshot)
            try repository.archiveJourney(snapshot)
            try repository.archiveJourney(snapshot)
        }
        try repository.save(GameSnapshot(profileID: .one, session: engine.makeNewSession(), randomCheckpoint: 2))
        try repository.deleteLocal(.two)
        let records = try ProfileRepository(directoryURL: directory).loadJourneyRecords()
        XCTAssertEqual(records.count, 4)
        let leaders = JourneyRecord.rankedBest(from: records)
        XCTAssertEqual(leaders.map(\.profileID), [.two, .one, .three])
        XCTAssertEqual(leaders.map { $0.session.netWorth }, [3_500, -500, -5_500])
        XCTAssertTrue(records.allSatisfy { $0.session.log.contains { $0.eventID == "ending-ice-guangzhou" } })
    }

    func testOldSaveDecodesWithoutInventingYearlyStatistics() throws {
        var engine = GameEngine(seed: 207)
        let session = engine.makeNewSession()
        let data = try JSONEncoder().encode(session)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "journey")
        json.removeValue(forKey: "settlement")
        let restored = try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.netGain)
        XCTAssertNil(restored.journey)
        XCTAssertEqual(restored.log.count, 1)
    }

    @MainActor
    func testCompletedStoreRestoresEndingAndRejectsLatePurchase() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ProfileRepository(directoryURL: directory)
        var engine = GameEngine(seed: 208)
        var session = engine.makeNewSession()
        session.day = 52
        let snapshot = GameSnapshot(profileID: .one, session: session, randomCheckpoint: engine.randomCheckpoint)
        let store = GameStore(profileID: .one, snapshot: snapshot, repository: repository)
        XCTAssertTrue(store.session.isDeported)
        let cash = store.session.cash
        XCTAssertFalse(store.applyPurchasedAdventure(.garageSaleWatch, transactionID: 123_456))
        XCTAssertEqual(store.session.cash, cash)
        store.restart()
        XCTAssertEqual(store.session.day, 1)
        XCTAssertEqual(try repository.loadJourneyRecords().count, 1)
        store.loadLeaderboard()
        XCTAssertEqual(store.journeyRecords.count, 1)
    }

    func testRepeatedWorkCountsAsOneKindOfExperience() throws {
        var engine = GameEngine(seed: 209)
        var session = engine.makeNewSession()
        try engine.work(in: &session)
        try engine.finishStationaryWeek(in: &session)
        try engine.work(in: &session)
        XCTAssertEqual(session.historicalEvents.count, 2)
        XCTAssertEqual(session.experienceCount, 1)
    }
}
