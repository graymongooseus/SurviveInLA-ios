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

    func testWorkingPaysCashCostsHealthAndAdvancesWeek() throws {
        var engine = GameEngine(seed: 14)
        var session = engine.makeNewSession()

        try engine.work(in: &session)

        XCTAssertEqual(session.day, 2)
        XCTAssertGreaterThan(session.cash, 2_000)
        XCTAssertLessThan(session.health, 100)
        XCTAssertEqual(session.debt, 5_100)
        XCTAssertNil(session.actionThisWeek)
        XCTAssertEqual(session.latestEvent?.group, .money)
    }

    func testInvestmentSettlesImmediatelyAndAdvancesWeek() throws {
        var engine = GameEngine(seed: 15)
        var session = engine.makeNewSession()

        try engine.invest(100, in: &session)

        XCTAssertEqual(session.day, 2)
        XCTAssertTrue((1_992 ... 2_008).contains(session.cash))
        XCTAssertEqual(session.debt, 5_100)
        XCTAssertNil(session.actionThisWeek)
        XCTAssertEqual(session.latestEvent?.group, .money)
    }

    func testLosAngelesEventCatalogIncludesRegionalExpansion() {
        XCTAssertEqual(GameContent.marketEvents.count, 23)
        XCTAssertEqual(GameContent.healthEvents.count, 17)
        XCTAssertEqual(GameContent.moneyEvents.count, 12)
        XCTAssertEqual(GameContent.events.count, 52)
        XCTAssertEqual(Set(GameContent.events.map(\.id)).count, 52)
        XCTAssertTrue(GameContent.marketEvents.allSatisfy {
            $0.group == .market && $0.affectedCommodityID != nil
        })

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
        let expectedCash = session.cash + quote.price

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
}
