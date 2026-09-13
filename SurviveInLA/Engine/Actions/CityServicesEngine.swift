import Foundation

extension GameEngine {
    func clinicClosureHoliday(in session: GameSession) -> USFederalHoliday? {
        let weekSeed = (session.cityServiceSeed ?? 0) &+
            UInt64(max(0, session.day)) &* 0x9E37_79B9_7F4A_7C15
        var serviceRandom = SeededRandomNumberGenerator(seed: weekSeed)
        guard Double.random(in: 0 ..< 1, using: &serviceRandom) < balance.clinicClosureChance else {
            return nil
        }
        let holidays = USFederalHoliday.allCases
        return holidays[Int.random(in: holidays.indices, using: &serviceRandom)]
    }

    func clinicRemainingTreatmentPoints(in session: GameSession) -> Int {
        let used = session.clinicTreatmentWeek == session.day ? (session.clinicTreatmentPoints ?? 0) : 0
        return max(0, balance.clinicWeeklyHealthLimit - used)
    }

    func clinicTreatmentRecovery(_ points: Int, in session: GameSession) -> Int {
        guard points > 0 else { return 0 }
        let requestedPoints = min(points, balance.clinicWeeklyHealthLimit)
        let adjustedPoints = max(1, scaled(requestedPoints, by: worldModifiers(for: session).healthChange))
        return max(0, min(adjustedPoints, 100 - session.health, clinicRemainingTreatmentPoints(in: session)))
    }

    func heal(_ points: Int, in session: inout GameSession) throws {
        try validateActiveSession(session, amount: points)
        if let holiday = clinicClosureHoliday(in: session) {
            throw GameRuleError.clinicClosed(holiday.rawValue)
        }
        guard session.health < 100 else { throw GameRuleError.healthAlreadyFull }
        guard clinicRemainingTreatmentPoints(in: session) > 0 else {
            throw GameRuleError.clinicWeeklyLimitReached
        }
        let restoredPoints = clinicTreatmentRecovery(points, in: session)
        let cost = restoredPoints * balance.treatmentCostPerPoint
        guard session.cash >= cost else { throw GameRuleError.insufficientCash }
        let oldCash = session.cash
        let oldHealth = session.health
        session.cash -= cost
        session.health += restoredPoints
        let previousPoints = session.clinicTreatmentWeek == session.day ? (session.clinicTreatmentPoints ?? 0) : 0
        session.clinicTreatmentWeek = session.day
        session.clinicTreatmentPoints = previousPoints + restoredPoints
        session.recordStatusChange(.cash, from: oldCash, reason: "诊所治疗")
        session.recordStatusChange(.health, from: oldHealth, reason: "诊所治疗")
        session.journey?.healthRecovered += restoredPoints
        session.journey?.treatmentSpending += cost
    }

    var massageCost: Int { balance.massageHealthRecovery * balance.massageCostPerPoint }

    func visitMassageParlor(in session: inout GameSession) throws {
        try validateActiveSession(session, amount: balance.massageHealthRecovery)
        guard session.massageVisitWeek != session.day else { throw GameRuleError.massageAlreadyVisited }
        guard session.health < 100 else { throw GameRuleError.healthAlreadyFull }
        guard session.cash >= massageCost else { throw GameRuleError.insufficientCash }
        let oldCash = session.cash
        let oldHealth = session.health
        let restoredPoints = min(balance.massageHealthRecovery, 100 - session.health)
        session.cash -= massageCost
        session.health += restoredPoints
        session.massageVisitWeek = session.day
        session.recordStatusChange(.cash, from: oldCash, reason: "波霸按摩院")
        session.recordStatusChange(.health, from: oldHealth, reason: "波霸按摩院")
        session.journey?.healthRecovered += restoredPoints
        session.journey?.treatmentSpending += massageCost
    }

    func expandCapacity(in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        guard session.capacity < balance.maximumCapacity else { throw GameRuleError.capacityAtMaximum }
        let cost = capacityUpgradeCost(for: session)
        guard session.cash >= cost else { throw GameRuleError.insufficientCash }
        let oldCash = session.cash
        session.cash -= cost
        session.recordStatusChange(.cash, from: oldCash, reason: "升级仓储容量")
        session.capacity = min(balance.maximumCapacity, session.capacity + balance.capacityUpgradeAmount)
    }

    func capacityUpgradeCost(for session: GameSession) -> Int {
        let completedUpgrades = max(0, (session.capacity - 100) / balance.capacityUpgradeAmount)
        return balance.baseCapacityUpgradeCost + completedUpgrades * 1_000
    }
}
