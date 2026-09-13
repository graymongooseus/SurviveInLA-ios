import Foundation

extension GameEngine {
    func driversLicensePassChance(for luck: Int) -> Double {
        min(0.90, max(0.40, 0.40 + Double(min(100, max(0, luck))) * 0.005))
    }

    mutating func obtainDriversLicense(in session: inout GameSession) throws -> Bool {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        var equipment = session.currentEquipment
        guard equipment.hasHousingMilestone else { throw GameRuleError.previousMilestoneRequired }
        guard !session.hasActiveDriversLicense else { return true }
        let registrationFee = equipment.licenseAttemptCount == 0 ? balance.driversLicenseCost : 0
        guard session.cash >= registrationFee else { throw GameRuleError.insufficientCash }
        try claimDreamAction(in: &session)
        let oldCash = session.cash
        session.cash -= registrationFee
        session.recordStatusChange(.cash, from: oldCash, reason: "驾照报名费")
        equipment.driversLicenseAttempts = equipment.licenseAttemptCount + 1
        let passed = Double.random(in: 0 ..< 1, using: &random)
            < driversLicensePassChance(for: session.currentLuck)
        equipment.hasDriversLicense = passed
        session.equipment = equipment
        if registrationFee > 0 {
            recordDreamInvestment(registrationFee, in: &session)
            if var journey = session.journey {
                journey.vehicleSpending = (journey.vehicleSpending ?? 0) + registrationFee
                session.journey = journey
            }
        }
        session.log.insert(
            GameLogEntry(
                day: session.day,
                title: passed ? "路考通过" : "路考没有通过",
                message: passed
                    ? "这一周的学习没有白费。你通过了路考，拿到了驾照。"
                    : "这一周完成了学习和第一次路考，但考试没有通过。报名费不再重复收取，下周可以再来路考。",
                eventID: passed ? "license-test-passed" : "license-test-failed"
            ),
            at: 0
        )
        return passed
    }

    func startHousingRental(
        _ tier: HousingTier = .basement,
        paymentMethod: HousingPaymentMethod? = nil,
        in session: inout GameSession
    ) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        var equipment = session.currentEquipment
        guard !equipment.hasProperty else { return }
        guard equipment.activeHousingTier != tier else { return }
        let resolvedMethod: HousingPaymentMethod
        if tier == .basement {
            resolvedMethod = .weeklyWithSavingsProof
        } else if let paymentMethod {
            resolvedMethod = paymentMethod
        } else {
            resolvedMethod = session.bank >= tier.savingsProofAmount
                ? .weeklyWithSavingsProof
                : .prepaidInstallments
        }
        if resolvedMethod == .weeklyWithSavingsProof, tier.savingsProofAmount > 0 {
            guard session.bank >= tier.savingsProofAmount else {
                throw GameRuleError.insufficientSavingsProof
            }
        }
        let paymentWeeks = resolvedMethod == .prepaidInstallments ? tier.prepaidWeeks : 1
        let initialPayment = tier == .basement
            ? balance.basementMoveInFee
            : tier.weeklyRent * paymentWeeks
        if resolvedMethod == .prepaidInstallments {
            guard session.cash >= initialPayment else { throw GameRuleError.insufficientCash }
        } else {
            guard session.cash + session.bank >= initialPayment else { throw GameRuleError.insufficientCash }
        }
        try claimDreamAction(in: &session)
        chargeHousingPayment(
            initialPayment,
            cashOnly: resolvedMethod == .prepaidInstallments,
            reason: "入住" + tier.name,
            in: &session
        )
        equipment.rentsHousing = true
        equipment.housingTier = tier
        equipment.housingPaymentMethod = resolvedMethod
        equipment.housingPaidThroughWeek = session.day + paymentWeeks - 1
        equipment.housingNextPaymentWeek = session.day + paymentWeeks
        equipment.completedHousingMilestone = true
        session.equipment = equipment
        recordDreamInvestment(initialPayment, in: &session)
        if var journey = session.journey {
            journey.housingSpending = (journey.housingSpending ?? 0) + initialPayment
            session.journey = journey
        }
    }

    func stopHousingRental(in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        var equipment = session.currentEquipment
        guard equipment.rentsHousing else { return }
        try claimDreamAction(in: &session)
        equipment.rentsHousing = false
        equipment.housingNextPaymentWeek = nil
        session.equipment = equipment
    }

    func startCarRental(in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        var equipment = session.currentEquipment
        guard session.hasActiveDriversLicense else { throw GameRuleError.driversLicenseRequired }
        guard !equipment.ownsCar else { throw GameRuleError.incompatibleVehicle }
        guard !equipment.rentsCar else { return }
        guard session.cash >= balance.weeklyCarRent else { throw GameRuleError.insufficientCash }
        try claimDreamAction(in: &session)
        let oldCash = session.cash
        session.cash -= balance.weeklyCarRent
        session.recordStatusChange(.cash, from: oldCash, reason: "开始租车")
        equipment.rentsCar = true
        equipment.carRentPaidThroughWeek = session.day
        equipment.completedVehicleMilestone = true
        session.equipment = equipment
        recordDreamInvestment(balance.weeklyCarRent, in: &session)
        if var journey = session.journey {
            journey.vehicleSpending = (journey.vehicleSpending ?? 0) + balance.weeklyCarRent
            session.journey = journey
        }
    }

    func stopCarRental(in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        var equipment = session.currentEquipment
        guard equipment.rentsCar else { return }
        try claimDreamAction(in: &session)
        equipment.rentsCar = false
        session.equipment = equipment
    }

    func buyCar(in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        var equipment = session.currentEquipment
        guard session.hasActiveDriversLicense else { throw GameRuleError.driversLicenseRequired }
        guard !equipment.rentsCar else { throw GameRuleError.incompatibleVehicle }
        guard !equipment.ownsCar else { return }
        guard session.cash >= balance.carPurchasePrice else { throw GameRuleError.insufficientCash }
        try claimDreamAction(in: &session)
        let oldCash = session.cash
        session.cash -= balance.carPurchasePrice
        session.recordStatusChange(.cash, from: oldCash, reason: "购买车辆")
        equipment.ownsCar = true
        equipment.completedVehicleMilestone = true
        session.equipment = equipment
        recordDreamInvestment(balance.carPurchasePrice, in: &session)
        if var journey = session.journey {
            journey.vehicleSpending = (journey.vehicleSpending ?? 0) + balance.carPurchasePrice
            session.journey = journey
        }
    }

    func sellCar(in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        var equipment = session.currentEquipment
        guard equipment.ownsCar else { return }
        try claimDreamAction(in: &session)
        equipment.ownsCar = false
        session.equipment = equipment
        let oldCash = session.cash
        session.cash += balance.carResaleValue
        session.recordStatusChange(.cash, from: oldCash, reason: "出售车辆")
        if var journey = session.journey {
            journey.vehicleSpending = (journey.vehicleSpending ?? 0) - balance.carResaleValue
            session.journey = journey
        }
    }

    func buyTools(in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        var equipment = session.currentEquipment
        guard equipment.hasVehicleMilestone else { throw GameRuleError.previousMilestoneRequired }
        guard !equipment.hasTools else { return }
        guard session.cash >= balance.toolsPurchasePrice else { throw GameRuleError.insufficientCash }
        try claimDreamAction(in: &session)
        let oldCash = session.cash
        session.cash -= balance.toolsPurchasePrice
        session.recordStatusChange(.cash, from: oldCash, reason: "购买设备与工具")
        equipment.ownsTools = true
        session.equipment = equipment
        recordDreamInvestment(balance.toolsPurchasePrice, in: &session)
    }

    func investInProperty(in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        var equipment = session.currentEquipment
        guard equipment.hasTools else { throw GameRuleError.previousMilestoneRequired }
        guard !equipment.hasProperty else { return }
        guard session.cash >= balance.propertyInvestmentPrice else { throw GameRuleError.insufficientCash }
        try claimDreamAction(in: &session)
        let oldCash = session.cash
        session.cash -= balance.propertyInvestmentPrice
        session.recordStatusChange(.cash, from: oldCash, reason: "投资物业")
        equipment.ownsProperty = true
        equipment.rentsHousing = false
        equipment.housingNextPaymentWeek = nil
        session.equipment = equipment
        recordDreamInvestment(balance.propertyInvestmentPrice, in: &session)
        session.log.insert(
            GameLogEntry(
                day: session.day,
                title: "希望 · 已经生根洛杉矶",
                message: "你完成了整条美国生存路线。只要活到第 52 周，就不会再触发 ICE 遣返结局。",
                eventID: "hope-rooted-los-angeles"
            ),
            at: 0
        )
    }

    func settleEquipmentForNewWeek(in session: inout GameSession) {
        guard session.health > 0 else { return }
        var equipment = session.currentEquipment

        if equipment.hasProperty {
            let oldCash = session.cash
            let oldHealth = session.health
            session.cash += balance.propertyWeeklyIncome
            session.health = min(100, session.health + balance.propertyHealthRecovery)
            session.recordStatusChange(.cash, from: oldCash, reason: "物业每周收入")
            session.recordStatusChange(.health, from: oldHealth, reason: "物业休养恢复")
            session.journey?.healthRecovered += session.health - oldHealth
        }

        if let housingTier = equipment.activeHousingTier {
            let paymentMethod = equipment.activeHousingPaymentMethod
            let paymentWeeks = paymentMethod == .prepaidInstallments ? housingTier.prepaidWeeks : 1
            let nextPaymentWeek = equipment.housingNextPaymentWeek
                ?? ((equipment.housingPaidThroughWeek ?? (session.day - 1)) + 1)
            let paymentDue = session.day >= nextPaymentWeek
            let payment = housingTier.weeklyRent * paymentWeeks

            if paymentDue, session.cash + session.bank < payment {
                equipment.rentsHousing = false
                equipment.housingNextPaymentWeek = nil
                session.latestHousingEvictionWeek = session.day
                session.latestHousingEvictionAmount = payment
                session.log.insert(
                    GameLogEntry(
                        day: session.day,
                        title: "被房东赶出房子",
                        message: "本周应付房租 \(payment.usdText)，但现金与银行存款不足。你失去了“有住处”增益，开始流落街头。",
                        eventID: "housing-evicted"
                    ),
                    at: 0
                )
            } else {
                if paymentDue {
                    chargeHousingPayment(
                        payment,
                        cashOnly: false,
                        reason: housingTier.name + "房租",
                        in: &session
                    )
                    equipment.housingPaidThroughWeek = session.day + paymentWeeks - 1
                    equipment.housingNextPaymentWeek = session.day + paymentWeeks
                    if var journey = session.journey {
                        journey.housingSpending = (journey.housingSpending ?? 0) + payment
                        session.journey = journey
                    }
                }

                let oldHealth = session.health
                session.health = min(100, session.health + housingTier.weeklyHealthRecovery)
                session.recordStatusChange(.health, from: oldHealth, reason: housingTier.name + "休养恢复")
                session.journey?.healthRecovered += session.health - oldHealth
            }
        }

        if equipment.rentsCar, equipment.carRentPaidThroughWeek != session.day {
            if session.cash >= balance.weeklyCarRent {
                let oldCash = session.cash
                session.cash -= balance.weeklyCarRent
                session.recordStatusChange(.cash, from: oldCash, reason: "每周租车费用")
                equipment.carRentPaidThroughWeek = session.day
                if var journey = session.journey {
                    journey.vehicleSpending = (journey.vehicleSpending ?? 0) + balance.weeklyCarRent
                    session.journey = journey
                }
            } else {
                equipment.rentsCar = false
                session.log.insert(
                    GameLogEntry(day: session.day, title: "车租续费失败", message: "现金不足，租车权益从本周起停止。"),
                    at: 0
                )
            }
        }
        session.equipment = equipment
    }

    private func chargeHousingPayment(
        _ amount: Int,
        cashOnly: Bool,
        reason: String,
        in session: inout GameSession
    ) {
        let oldCash = session.cash
        let cashPayment = cashOnly ? amount : min(session.cash, amount)
        session.cash -= cashPayment
        if cashPayment > 0 {
            session.recordStatusChange(.cash, from: oldCash, reason: reason)
        }
        if !cashOnly {
            session.bank -= amount - cashPayment
        }
    }

    private func recordDreamInvestment(_ amount: Int, in session: inout GameSession) {
        guard var journey = session.journey else { return }
        journey.dreamInvestmentSpending = (journey.dreamInvestmentSpending ?? 0) + amount
        session.journey = journey
    }
}
