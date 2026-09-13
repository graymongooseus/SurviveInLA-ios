import Foundation

extension GameEngine {
    @discardableResult
    mutating func work(in session: inout GameSession) throws -> GameEvent {
        try work(GameContent.job(in: session.currentDistrictID).id, in: &session)
    }

    @discardableResult
    mutating func work(_ jobID: String, in session: inout GameSession) throws -> GameEvent {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        guard let job = GameContent.job(jobID, in: session.currentDistrictID) else {
            throw GameRuleError.jobUnavailable
        }
        if job.requiresHousing, !session.currentEquipment.hasHousing {
            throw GameRuleError.housingRequired
        }
        if job.requiresVehicle, !session.currentEquipment.hasVehicle {
            throw GameRuleError.vehicleRequired
        }
        let operatingCost = job.requiresVehicle ? balance.drivingOperatingCost : 0
        guard session.cash >= operatingCost else { throw GameRuleError.insufficientCash }
        try claimWeeklyAction(.work, in: &session)

        if job.id == "figueroa-pimping" {
            return performPimpingWork(job: job, in: &session)
        }

        session.consecutivePimpingWeeks = 0
        let outcome = Int.random(in: 0 ..< 5, using: &random)
        let bonus: Int
        let extraHealthCost: Int
        let luckDelta: Int
        let outcomeText: String

        switch outcome {
        case 0:
            bonus = 80
            extraHealthCost = 1
            luckDelta = 0
            outcomeText = "临时多干了一会儿，老板把加班费一起结了。"
        case 1:
            bonus = 50
            extraHealthCost = 0
            luckDelta = 0
            outcomeText = "这周遇到爽快的客人，你多拿到一点小费。"
        case 2:
            bonus = -40
            extraHealthCost = 0
            luckDelta = -1
            outcomeText = "一个小失误被扣了钱，这周算是交了学费。"
        case 3:
            bonus = 0
            extraHealthCost = 0
            luckDelta = 2
            outcomeText = "你顺手帮了同样在异乡讨生活的人，社区里有人记住了你。"
        default:
            bonus = 0
            extraHealthCost = 0
            luckDelta = 0
            outcomeText = "这一周没出岔子，工资按约定到账。"
        }

        let equippedWage = session.currentEquipment.hasTools
            ? Int((Double(job.wage) * balance.toolsWageMultiplier).rounded())
            : job.wage
        let baseIncome = max(0, equippedWage + bonus - operatingCost)
        let income = scaled(baseIncome, by: worldModifiers(for: session).workIncome * session.playerWorkIncomeMultiplier)
        let protectedHealthCost = job.requiresVehicle
            ? max(0, job.healthCost - balance.vehicleHealthProtection)
            : job.healthCost
        let finalHealthCost = max(
            0,
            protectedHealthCost - (session.currentEquipment.hasTools ? balance.toolsHealthProtection : 0)
        )
        var event = GameEvent(
            id: "job-\(job.id)",
            kind: .opportunity,
            group: .money,
            title: job.title,
            message: "\(job.detail) \(outcomeText) 本周净收入 \(income.usdText)\(operatingCost > 0 ? "（已扣车辆运营费 \(operatingCost.usdText)）" : "")。",
            cashDelta: income,
            healthDelta: -(finalHealthCost + extraHealthCost),
            districtIDs: [session.currentDistrictID],
            baseCashDelta: baseIncome,
            luckDelta: luckDelta
        )
        apply(event, to: &session)
        if job.requiresVehicle {
            if var journey = session.journey {
                journey.vehicleSpending = (journey.vehicleSpending ?? 0) + operatingCost
                journey.drivingIncome = (journey.drivingIncome ?? 0) + income
                session.journey = journey
            }
            let riskMessage = resolveDrivingRisk(in: &session)
            if !riskMessage.isEmpty {
                event = GameEvent(
                    id: event.id,
                    kind: event.kind,
                    group: event.group,
                    title: event.title,
                    message: event.message + "\n\n" + riskMessage,
                    cashDelta: event.cashDelta,
                    healthDelta: event.healthDelta,
                    districtIDs: event.districtIDs,
                    baseCashDelta: event.baseCashDelta,
                    skippedWeeks: event.skippedWeeks,
                    encounterTone: event.encounterTone,
                    luckDelta: event.luckDelta
                )
            }
        }
        log(event, in: &session, at: session.currentDistrictID, week: session.day)
        return event
    }

    private mutating func resolveDrivingRisk(in session: inout GameSession) -> String {
        let hadLicense = session.hasActiveDriversLicense
        let chance = hadLicense ? balance.licensedDrivingLossChance : balance.unlicensedDrivingArrestChance
        guard Double.random(in: 0 ..< 1, using: &random) < chance else { return "" }

        if hadLicense {
            var equipment = session.currentEquipment
            equipment.driversLicenseRecoveryUntilWeek = session.day + balance.licenseReplacementWeeks
            session.equipment = equipment
            let message = "⚠️ 驾照丢失：补办需要 4 周。在第 \(equipment.driversLicenseRecoveryUntilWeek!) 周前没有“有驾照”增益，继续开车会更容易被警察拦下。"
            session.log.insert(GameLogEntry(day: session.day, title: "驾照丢失", message: message, eventID: "license-lost-\(session.day)"), at: 0)
            return message
        }

        let message = "🚨 无证驾驶被捕：警察查到你没有有效驾照。你被关押 2 个回合（两周），期间不能行动。"
        session.log.insert(GameLogEntry(day: session.day, title: "无证驾驶被捕", message: message, eventID: "unlicensed-driving-arrest-\(session.day)"), at: 0)
        skipStationaryWeeks(balance.drivingArrestWeeks, in: &session)
        return message
    }

    @discardableResult
    mutating func restAtHome(in session: inout GameSession) throws -> GameEvent {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        guard session.currentEquipment.hasHousing else { throw GameRuleError.homeRequiredToRest }
        try claimWeeklyAction(.work, in: &session)

        session.consecutivePimpingWeeks = 0
        let oldHealth = session.health
        session.health = min(100, session.health + balance.restAtHomeHealthRecovery)
        let recovered = session.health - oldHealth
        session.recordStatusChange(.health, from: oldHealth, reason: "在家躺平")
        session.journey?.healthRecovered += recovered

        let event = GameEvent(
            id: "rest-at-home-\(session.day)",
            kind: .opportunity,
            group: .health,
            title: "在家躺平",
            message: recovered > 0
                ? "这周你没有去打工，关掉闹钟好好休息，健康恢复了 \(recovered) 点。"
                : "这周你没有去打工，关掉闹钟好好休息。你的健康已经满了。",
            healthDelta: balance.restAtHomeHealthRecovery,
            districtIDs: [session.currentDistrictID]
        )
        session.latestEvent = event
        log(event, in: &session, at: session.currentDistrictID, week: session.day)
        return event
    }

    mutating func invest(_ amount: Int, in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        guard amount > 0 else { throw GameRuleError.invalidQuantity }

        let opportunity = GameContent.investment(in: session.currentDistrictID)
        guard amount >= opportunity.minimumInvestment else { throw GameRuleError.investmentTooSmall }
        guard session.cash >= amount else { throw GameRuleError.insufficientCash }
        try claimWeeklyAction(.investment, in: &session)

        let sampledPercentage = investmentReturnPercentage(for: opportunity.risk)
        let modifiers = worldModifiers(for: session)
        let percentage = modifiers.investmentReturnCap.map {
            min(sampledPercentage, $0)
        } ?? sampledPercentage
        let baseProfit = amount * percentage / 100
        let profit = scaled(baseProfit, by: modifiers.investmentReturn)
        let resultText = profit >= 0
            ? "项目顺利结算，你赚到 +\(profit.usdText)。"
            : "行情没有站在你这边，你亏了 \((-profit).usdText)。"
        let event = GameEvent(
            id: "investment-\(session.day)-\(opportunity.districtID.rawValue)",
            kind: profit >= 0 ? .opportunity : .setback,
            group: .money,
            title: opportunity.title,
            message: "\(opportunity.detail) \(resultText)",
            cashDelta: profit,
            districtIDs: [session.currentDistrictID],
            baseCashDelta: baseProfit
        )
        apply(event, to: &session)
        log(event, in: &session, at: session.currentDistrictID, week: session.day)
    }

    private mutating func performPimpingWork(
        job: JobOpportunity,
        in session: inout GameSession
    ) -> GameEvent {
        let streak = (session.consecutivePimpingWeeks ?? 0) + 1
        session.consecutivePimpingWeeks = streak

        if streak >= 3 {
            let eventWeek = session.day
            let skippedWeeks = 2
            let returnWeek = min(session.totalDays, eventWeek + skippedWeeks)
            let event = GameEvent(
                id: "lapd-sting-operation",
                kind: .setback,
                group: .money,
                title: "LAPD 钓鱼执法",
                message: "你连续第三天在菲格罗亚拉皮条，遇上了 LAPD 钓鱼执法。你被罚 1,000 美元并关押两周，时间直接来到第 \(returnWeek) 天。",
                cashDelta: -1_000,
                districtIDs: [.figueroaCorridor],
                skippedWeeks: skippedWeeks,
                luckDelta: -8
            )
            apply(event, to: &session)
            log(event, in: &session, at: session.currentDistrictID, week: eventWeek)
            session.consecutivePimpingWeeks = 0
            skipStationaryWeeks(skippedWeeks, in: &session)
            return event
        }

        let baseIncome = Int.random(in: 500 ... 700, using: &random)
        let sweep = GameContent.marketEvents.first { $0.id == "figueroa-vice-sweep" }!
        let triggerChance = sweep.triggerChance ?? 0.30
        let didTriggerSweep = (sweep.condition ?? .always).matches(session)
            && Double.random(in: 0 ..< 1, using: &random) < triggerChance
        let multiplier = didTriggerSweep ? (sweep.workIncomeMultiplier ?? 2) : 1
        let localIncome = Int((Double(baseIncome) * multiplier).rounded())
        let income = scaled(localIncome, by: worldModifiers(for: session).workIncome * session.playerWorkIncomeMultiplier)
        let event = GameEvent(
            id: didTriggerSweep ? sweep.id : "pimping-\(session.day)-figueroa",
            kind: .opportunity,
            group: didTriggerSweep ? .market : .money,
            title: didTriggerSweep ? sweep.title : job.title,
            message: didTriggerSweep
                ? "\(sweep.message) 本周原本能赚 \(baseIncome.usdText)，扫黄后行情翻倍；实际收入 \(income.usdText)。"
                : "\(job.detail) 本周收入 \(income.usdText)。这是连续第 \(streak) 天。",
            cashDelta: income,
            healthDelta: -job.healthCost,
            districtIDs: [.figueroaCorridor],
            triggerChance: sweep.triggerChance,
            workIncomeMultiplier: didTriggerSweep ? multiplier : nil,
            baseCashDelta: localIncome,
            luckDelta: -1
        )
        apply(event, to: &session)
        log(event, in: &session, at: session.currentDistrictID, week: session.day)
        return event
    }

    private mutating func investmentReturnPercentage(for risk: InvestmentRisk) -> Int {
        let roll = Int.random(in: 0 ..< 100, using: &random)
        switch risk {
        case .low:
            return roll < 20 ? -8 : (roll < 70 ? 3 : 8)
        case .medium:
            return roll < 35 ? -20 : (roll < 75 ? 8 : 25)
        case .high:
            return roll < 40 ? -45 : (roll < 75 ? 20 : 60)
        }
    }
}
