import Foundation

/// Rule facade. Mechanism-specific implementations live in Engine extensions.
/// The RNG belongs to this engine; views and stores never draw gameplay randomness.
struct GameEngine: Sendable {
    let balance: GameBalance

    var random: SeededRandomNumberGenerator

    var randomCheckpoint: UInt64 { random.checkpoint }

    init(balance: GameBalance = GameBalance(), seed: UInt64 = 2_026_090_3) {
        self.balance = balance
        random = SeededRandomNumberGenerator(seed: seed)
    }

    init(balance: GameBalance = GameBalance(), randomCheckpoint: UInt64) {
        self.balance = balance
        random = SeededRandomNumberGenerator(checkpoint: randomCheckpoint)
    }

    mutating func makeNewSession() -> GameSession {
        let districtID = District.ID.dingPangZiPlaza
        var session = GameSession(
            day: 1,
            totalDays: balance.totalDays,
            cash: balance.startingCash,
            debt: balance.startingDebt,
            bank: 0,
            health: balance.startingHealth,
            reputation: 100,
            luck: balance.startingLuck,
            capacity: balance.startingCapacity,
            currentDistrictID: districtID,
            market: makeMarket(in: districtID, previous: []),
            inventory: [:],
            latestEvent: nil,
            log: [
                GameLogEntry(
                    day: 1,
                    title: "抵达丁胖子广场",
                    message: "跨过边境、一路辗转来到洛杉矶。你有一本外国护照、1,000 美元现金和 5,000 美元债务。五十二周，先活下来，再想办法翻身。"
                )
            ],
            actionThisWeek: nil,
            consecutivePimpingWeeks: 0,
            activeWorldEvent: nil,
            latestWorldEventID: nil,
            latestWorldEventWeek: nil,
            journey: JourneyStatistics(
                startingNetWorth: balance.startingCash - balance.startingDebt,
                startingHealth: balance.startingHealth,
                visitedDistricts: [districtID]
            ),
            equipment: LifeEquipment(),
            pendingLifeChoiceID: nil,
            resolvedLifeChoiceIDs: []
        )
        session.startStatusHistory(reason: "抵达洛杉矶")
        session.cityServiceSeed = random.checkpoint
        return session
    }
}
