import XCTest
@testable import SurviveInLA

final class GameEngineTests: XCTestCase {
    func testNewSessionUsesClassicStartingPressure() {
        var engine = GameEngine(seed: 42)
        let session = engine.makeNewSession()

        XCTAssertEqual(session.day, 1)
        XCTAssertEqual(session.cash, 2_000)
        XCTAssertEqual(session.debt, 5_000)
        XCTAssertEqual(session.market.count, 5)
        XCTAssertEqual(session.currentDistrictID, .koreatown)
        XCTAssertEqual(GameContent.districts.count, 10)
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

    func testTravelAdvancesDayAndAccruesDebtInterest() throws {
        var engine = GameEngine(seed: 99)
        var session = engine.makeNewSession()

        try engine.travel(to: .fashionDistrict, session: &session)

        XCTAssertEqual(session.day, 2)
        XCTAssertEqual(session.currentDistrictID, .fashionDistrict)
        XCTAssertEqual(session.debt, 5_500)
        XCTAssertEqual(session.market.count, 5)
        XCTAssertNotNil(session.latestEvent)
        XCTAssertTrue(session.latestEvent?.canOccur(in: .fashionDistrict) == true)
        if session.latestEvent?.group == .market,
           let commodityID = session.latestEvent?.affectedCommodityID {
            XCTAssertTrue(session.market.contains(where: { $0.commodityID == commodityID }))
        }
    }

    func testLosAngelesEventCatalogMatchesClassicCategoryCounts() {
        XCTAssertEqual(GameContent.marketEvents.count, 18)
        XCTAssertEqual(GameContent.healthEvents.count, 12)
        XCTAssertEqual(GameContent.moneyEvents.count, 7)
        XCTAssertEqual(GameContent.events.count, 37)
        XCTAssertEqual(Set(GameContent.events.map(\.id)).count, 37)
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
        XCTAssertEqual(Set(GameContent.districts.map(\.id)).count, 10)
        XCTAssertTrue(GameContent.districts.allSatisfy { !$0.marketRole.isEmpty })
        XCTAssertLessThan(
            GameContent.district(.koreatown).priceBias(for: .importedSnacks),
            GameContent.district(.santaMonica).priceBias(for: .importedSnacks)
        )
        XCTAssertGreaterThan(
            GameContent.district(.hollywood).priceBias(for: .concertTickets),
            GameContent.district(.fashionDistrict).priceBias(for: .concertTickets)
        )
    }

    func testLegacyDistrictIDsMigrateWhenDecoded() throws {
        let decoder = JSONDecoder()

        XCTAssertEqual(
            try decoder.decode(District.ID.self, from: Data("\"downtown\"".utf8)),
            .fashionDistrict
        )
        XCTAssertEqual(
            try decoder.decode(District.ID.self, from: Data("\"unionStation\"".utf8)),
            .boyleHeights
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

    func testBankingAndDebtPaymentsMoveMoneyWithoutAdvancingDay() throws {
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
        try engine.travel(to: .fashionDistrict, session: &session)
        let snapshot = GameSnapshot(
            profileID: .two,
            session: session,
            randomCheckpoint: engine.randomCheckpoint
        )

        try repository.save(snapshot)
        let restored = try XCTUnwrap(repository.load(.two))

        XCTAssertEqual(restored.profileID, .two)
        XCTAssertEqual(restored.session.day, 2)
        XCTAssertEqual(restored.session.currentDistrictID, .fashionDistrict)
        XCTAssertEqual(restored.randomCheckpoint, engine.randomCheckpoint)
        XCTAssertNil(try repository.load(.one))
    }
}
