import XCTest
@testable import SurviveInLA

final class ArchitectureReplayTests: XCTestCase {
    func testSeededTravelAndStationarySequence() throws {
        // Content 2026.09.09.2 adds wildfire to the pool: seed 42 now selects tourism.
        // Market quotes and RNG checkpoints remain unchanged.
        let expected: [UInt64: String] = [
            42: "7|99988|1012|5652|87|51|extreme-heat|usedTesla:17501,concertTickets:147,sneakers:89,beautySet:57,importedSnacks:16|southern-california-spending-boom|11100747932625521989",
            91: "7|99915|1012|5652|97|53|vending-compliance|usedTesla:20201,concertTickets:183,beautySet:73,vinyl:48,importedSnacks:15|southern-california-spending-boom|11100747932625522038",
            2026: "7|99703|1010|5663|82|50|sleep-debt|usedTesla:17942,camera:789,vintageJacket:329,sneakers:81,smuggledVape:80|port-logistics-gridlock|11100747932625523973",
        ]
        for seed: UInt64 in [42, 91, 2026] {
            var engine = GameEngine(seed: seed)
            var session = engine.makeNewSession()
            session.cash = 100_000
            session.bank = 1_000
            session.health = 100
            for step in 0 ..< 6 {
                if step.isMultiple(of: 2) {
                    try engine.travel(to: session.currentDistrictID == .hollywood ? .sanGabriel : .hollywood, session: &session)
                } else {
                    session.recordWeeklyAction(.work)
                    try engine.finishStationaryWeek(in: &session)
                }
            }
            let summary = [String(session.day), String(session.cash), String(session.bank), String(session.debt),
                           String(session.health), String(session.currentLuck), session.latestEvent?.id ?? "none",
                           session.market.map { "\($0.commodityID.rawValue):\($0.price)" }.joined(separator: ","),
                           session.activeWorldEvents.map(\.eventID).joined(separator: ","), String(engine.randomCheckpoint)]
                .joined(separator: "|")
            XCTAssertEqual(summary, expected[seed], "Preserve the content-version baseline for market, event, money and RNG sequence.")
        }
    }
}
