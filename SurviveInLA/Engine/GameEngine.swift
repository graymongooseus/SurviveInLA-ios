import Foundation

struct GameEngine: Sendable {
    let balance: GameBalance
    private var random: SeededRandomNumberGenerator

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

    func buy(_ commodityID: Commodity.ID, quantity: Int, in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingLifeChoice(session)
        guard quantity > 0 else { throw GameRuleError.invalidQuantity }
        guard let quote = session.market.first(where: { $0.commodityID == commodityID }) else {
            throw GameRuleError.quoteUnavailable
        }
        guard session.availableCapacity >= quantity else { throw GameRuleError.insufficientCapacity }

        let total = quote.price * quantity
        guard session.cash >= total else { throw GameRuleError.insufficientCash }
        try claimWeeklyAction(.trading, allowsRepeat: true, in: &session)

        let oldPosition = session.inventory[commodityID]
        let oldQuantity = oldPosition?.quantity ?? 0
        let oldCost = (oldPosition?.averageCost ?? 0) * oldQuantity
        let newQuantity = oldQuantity + quantity
        let averageCost = (oldCost + total) / newQuantity

        let oldCash = session.cash
        session.cash -= total
        session.recordStatusChange(
            .cash,
            from: oldCash,
            reason: "买入" + GameContent.commodity(commodityID).name + " ×" + String(quantity)
        )
        session.inventory[commodityID] = InventoryPosition(
            commodityID: commodityID,
            quantity: newQuantity,
            averageCost: averageCost
        )
    }

    func sell(_ commodityID: Commodity.ID, quantity: Int, in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingLifeChoice(session)
        guard quantity > 0 else { throw GameRuleError.invalidQuantity }
        guard let quote = session.market.first(where: { $0.commodityID == commodityID }) else {
            throw GameRuleError.quoteUnavailable
        }
        guard var position = session.inventory[commodityID], position.quantity >= quantity else {
            throw GameRuleError.insufficientInventory
        }
        try claimWeeklyAction(.trading, allowsRepeat: true, in: &session)

        let baseRevenue = quote.price * quantity
        let revenue = scaled(baseRevenue, by: worldModifiers(for: session).tradeIncome)
        let oldCash = session.cash
        session.cash += revenue
        session.recordStatusChange(
            .cash,
            from: oldCash,
            reason: "卖出" + GameContent.commodity(commodityID).name + " ×" + String(quantity)
        )
        position.quantity -= quantity
        if position.quantity == 0 {
            session.inventory.removeValue(forKey: commodityID)
        } else {
            session.inventory[commodityID] = position
        }

        if commodityID == .smuggledVape {
            let oldLuck = session.currentLuck
            session.currentLuck -= 5
            session.recordStatusChange(.luck, from: oldLuck, reason: "卖出走私电子烟")
            session.log.insert(
                GameLogEntry(
                    day: session.day,
                    title: "运气下降",
                    message: "走私电子烟虽然卖掉了，但你明知风险仍把它转给别人。运气 −5。"
                ),
                at: 0
            )
        }
    }

    func deposit(_ amount: Int, in session: inout GameSession) throws {
        try validateActiveSession(session, amount: amount)
        guard session.cash >= amount else { throw GameRuleError.insufficientCash }
        let oldCash = session.cash
        session.cash -= amount
        session.recordStatusChange(.cash, from: oldCash, reason: "转入银行存款")
        session.bank += amount
    }

    func withdraw(_ amount: Int, in session: inout GameSession) throws {
        try validateActiveSession(session, amount: amount)
        guard session.bank >= amount else { throw GameRuleError.insufficientBankBalance }
        session.bank -= amount
        let oldCash = session.cash
        session.cash += amount
        session.recordStatusChange(.cash, from: oldCash, reason: "从银行取款")
    }

    func repayDebt(_ amount: Int, in session: inout GameSession) throws {
        try validateActiveSession(session, amount: amount)
        let payment = min(amount, session.debt)
        guard session.cash >= payment else { throw GameRuleError.insufficientCash }
        let oldCash = session.cash
        let oldDebt = session.debt
        session.cash -= payment
        session.debt -= payment
        session.recordStatusChange(.cash, from: oldCash, reason: "偿还欠款")
        session.recordStatusChange(.debt, from: oldDebt, reason: "偿还欠款")
    }

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

    func driversLicensePassChance(for luck: Int) -> Double {
        min(0.90, max(0.40, 0.40 + Double(min(100, max(0, luck))) * 0.005))
    }

    mutating func obtainDriversLicense(in session: inout GameSession) throws -> Bool {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingLifeChoice(session)
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
        try requireNoPendingLifeChoice(session)
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
        try requireNoPendingLifeChoice(session)
        var equipment = session.currentEquipment
        guard equipment.rentsHousing else { return }
        try claimDreamAction(in: &session)
        equipment.rentsHousing = false
        equipment.housingNextPaymentWeek = nil
        session.equipment = equipment
    }

    func startCarRental(in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingLifeChoice(session)
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
        try requireNoPendingLifeChoice(session)
        var equipment = session.currentEquipment
        guard equipment.rentsCar else { return }
        try claimDreamAction(in: &session)
        equipment.rentsCar = false
        session.equipment = equipment
    }

    func buyCar(in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingLifeChoice(session)
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
        try requireNoPendingLifeChoice(session)
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
        try requireNoPendingLifeChoice(session)
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
        try requireNoPendingLifeChoice(session)
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

    func resolveLifeChoice(_ optionID: String, in session: inout GameSession) throws -> GameEvent {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        guard let eventID = session.pendingLifeChoiceID,
              let choice = GameContent.lifeChoice(eventID),
              let option = choice.options.first(where: { $0.id == optionID }) else {
            throw GameRuleError.lifeChoicePending
        }
        var resolved = session.resolvedLifeChoiceIDs ?? []
        guard !resolved.contains(choice.id) else { throw GameRuleError.lifeChoicePending }
        let event = GameEvent(
            id: "life-choice-\(choice.id)",
            kind: option.luckDelta >= 0 ? .opportunity : .setback,
            group: option.cashDelta == 0 ? .health : .money,
            title: choice.title,
            message: "\(option.title)：\(option.result)",
            cashDelta: option.cashDelta,
            healthDelta: option.healthDelta,
            encounterTone: option.luckDelta > 0 ? .favorable : (option.luckDelta < 0 ? .unfavorable : .mixed),
            luckDelta: option.luckDelta
        )
        apply(event, to: &session)
        resolved.insert(choice.id)
        session.resolvedLifeChoiceIDs = resolved
        var selected = session.selectedLifeChoiceOptions ?? [:]
        selected[choice.id] = option.id
        session.selectedLifeChoiceOptions = selected
        session.pendingLifeChoiceID = nil
        if var journey = session.journey {
            journey.keyChoices = (journey.keyChoices ?? []) + ["\(choice.title)：\(option.title)"]
            session.journey = journey
        }
        log(event, in: &session, at: session.currentDistrictID, week: session.day)
        return event
    }

    mutating func travel(to destinationID: District.ID, session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingLifeChoice(session)
        if session.day == session.totalDays {
            endJourney(session: &session)
            return
        }
        guard destinationID != session.currentDistrictID else { throw GameRuleError.alreadyThere }
        try claimWeeklyAction(.trading, allowsRepeat: true, in: &session)

        let oldMarket = session.market
        let modifiers = worldModifiers(for: session)
        session.day += 1
        session.currentDistrictID = destinationID
        session.journey?.visitedDistricts.insert(destinationID)
        accrueInterest(with: modifiers, in: &session)
        InvestmentEventEngine.settleDue(in: &session)
        settleEquipmentForNewWeek(in: &session)
        if session.day == session.totalDays {
            endJourney(session: &session)
            return
        }
        updateWorldEvent(for: session.day, in: &session)

        let event = drawEvent(in: destinationID, session: session)
        session.market = makeMarket(
            in: destinationID,
            previous: oldMarket,
            quoteCount: session.day == session.totalDays ? GameContent.commodities.count : 5,
            preferredCommodityID: event.group == .market ? event.affectedCommodityID : nil,
            priceMultiplier: worldModifiers(for: session).marketPrice
        )
        apply(event, to: &session)
        session.log.insert(
            GameLogEntry(
                day: session.day,
                title: "\(GameContent.district(destinationID).name) · \(event.title)",
                message: event.message,
                eventID: event.historyID
            ),
            at: 0
        )
        session.resetWeeklyActions()
        session.consecutivePimpingWeeks = 0
        scheduleWeekEvents(in: &session)
    }

    @discardableResult
    mutating func work(in session: inout GameSession) throws -> GameEvent {
        try work(GameContent.job(in: session.currentDistrictID).id, in: &session)
    }

    @discardableResult
    mutating func work(_ jobID: String, in session: inout GameSession) throws -> GameEvent {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingLifeChoice(session)
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
        let income = scaled(baseIncome, by: worldModifiers(for: session).workIncome)
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
        try requireNoPendingLifeChoice(session)
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
        try requireNoPendingLifeChoice(session)
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

    mutating func finishStationaryWeek(in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingLifeChoice(session)
        guard session.hasCompletedAnyWeeklyAction else {
            throw GameRuleError.weeklyActionNotCompleted
        }
        advanceStationaryWeek(session: &session)
    }

    mutating func endJourney(session: inout GameSession) {
        guard !session.isFinished, session.day >= session.totalDays else { return }

        let achievedHope = session.hasHope
        var liquidationTotal = 0
        for position in session.inventory.values {
            let price = session.market.first(where: { $0.commodityID == position.commodityID })?.price
                ?? GameContent.commodity(position.commodityID).basePrice
            liquidationTotal += price * position.quantity
        }
        liquidationTotal = scaled(liquidationTotal, by: worldModifiers(for: session).tradeIncome)
        let cashBeforeLiquidation = session.cash
        session.cash += liquidationTotal
        session.recordStatusChange(.cash, from: cashBeforeLiquidation, reason: "旅程结束 · 库存清算")
        session.inventory.removeAll()
        var vehicleResidual = 0
        if session.currentEquipment.ownsCar {
            vehicleResidual = balance.carResaleValue
            let cashBeforeVehicleSale = session.cash
            session.cash += vehicleResidual
            session.recordStatusChange(.cash, from: cashBeforeVehicleSale, reason: "旅程结束 · 车辆残值")
            var equipment = session.currentEquipment
            equipment.ownsCar = false
            session.equipment = equipment
        }
        if achievedHope {
            session.rootedEnding = true
            session.settlement = JourneySettlement(
                liquidationIncome: liquidationTotal,
                ticketCost: 0,
                ticketDebt: 0
            )
            session.day = session.totalDays + 1
            session.resetWeeklyActions()
            session.latestEvent = nil
            session.log.insert(
                GameLogEntry(
                    day: session.totalDays,
                    title: "希望成真 · 扎根洛杉矶",
                    message: "第 \(session.totalDays) 周结束，你完成了美国生存路线。剩余货物清算收入 \(liquidationTotal.usdText)\(vehicleResidual > 0 ? "，车辆残值 \(vehicleResidual.usdText)" : "")。这一次，ICE 遣返剧情没有发生；你留在洛杉矶，开始下一段生活。",
                    eventID: "ending-rooted-los-angeles"
                ),
                at: 0
            )
            return
        }
        // Settle the entire fare: cash first, then savings, then an explicit unpaid balance.
        let cashPayment = min(max(0, session.cash), JourneySettlement.airfare)
        let cashBeforeAirfare = session.cash
        session.cash -= cashPayment
        session.recordStatusChange(.cash, from: cashBeforeAirfare, reason: "回广州单程机票")
        let bankPayment = min(max(0, session.bank), JourneySettlement.airfare - cashPayment)
        session.bank -= bankPayment
        let ticketDebt = JourneySettlement.airfare - cashPayment - bankPayment
        let debtBeforeAirfare = session.debt
        session.debt += ticketDebt
        session.recordStatusChange(.debt, from: debtBeforeAirfare, reason: "无力支付的机票款")
        session.settlement = JourneySettlement(
            liquidationIncome: liquidationTotal,
            ticketCost: JourneySettlement.airfare,
            ticketDebt: ticketDebt
        )
        session.day = session.totalDays + 1
        session.resetWeeklyActions()
        session.latestEvent = nil
        session.log.insert(
            GameLogEntry(
                day: session.totalDays,
                title: "ICE 上门 · 单程广州",
                message: "第 \(session.totalDays) 周，ICE 突然上门，把你带走。剩余货物清算收入 \(liquidationTotal.usdText)\(vehicleResidual > 0 ? "，车辆残值 \(vehicleResidual.usdText)" : "")，回广州的单程机票扣除 500 美元。" + (ticketDebt > 0 ? "其中 \(ticketDebt.usdText) 无力支付，计入待偿债务。" : "") + "在这个故事里，你从此再也无法进入美国。",
                eventID: "ending-ice-guangzhou"
            ),
            at: 0
        )
    }

    private func validateActiveSession(_ session: GameSession, amount: Int) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingLifeChoice(session)
        guard amount > 0 else { throw GameRuleError.invalidQuantity }
    }

    private func claimWeeklyAction(
        _ action: WeeklyAction,
        allowsRepeat: Bool = false,
        in session: inout GameSession
    ) throws {
        if session.didCompleteWeeklyAction(action), !allowsRepeat {
            throw GameRuleError.weeklyActionAlreadyChosen
        }
        session.recordWeeklyAction(action)
    }

    private func claimDreamAction(in session: inout GameSession) throws {
        guard !session.didPerformDreamActionThisWeek else {
            throw GameRuleError.dreamActionAlreadyTaken
        }
        session.dreamActionWeek = session.day
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
        let income = scaled(localIncome, by: worldModifiers(for: session).workIncome)
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

    private mutating func skipStationaryWeeks(_ count: Int, in session: inout GameSession) {
        for _ in 0 ..< count {
            if session.day == session.totalDays {
                endJourney(session: &session)
                return
            }

            let oldMarket = session.market
            let modifiers = worldModifiers(for: session)
            session.day += 1
            accrueInterest(with: modifiers, in: &session)
            InvestmentEventEngine.settleDue(in: &session)
            settleEquipmentForNewWeek(in: &session)
            if session.day == session.totalDays {
                endJourney(session: &session)
                return
            }
            updateWorldEvent(for: session.day, in: &session)
            session.market = makeMarket(
                in: session.currentDistrictID,
                previous: oldMarket,
                quoteCount: session.day == session.totalDays ? GameContent.commodities.count : 5,
                priceMultiplier: worldModifiers(for: session).marketPrice
            )
            scheduleWeekEvents(in: &session)
            if session.pendingLifeChoiceID != nil || session.pendingInvestmentInvitation != nil { return }
        }
        session.resetWeeklyActions()
    }

    private mutating func advanceStationaryWeek(session: inout GameSession) {
        guard session.health > 0 else { return }
        if session.day == session.totalDays {
            endJourney(session: &session)
            return
        }

        let oldMarket = session.market
        let modifiers = worldModifiers(for: session)
        session.day += 1
        accrueInterest(with: modifiers, in: &session)
        InvestmentEventEngine.settleDue(in: &session)
        settleEquipmentForNewWeek(in: &session)
        if session.day == session.totalDays {
            endJourney(session: &session)
            return
        }
        updateWorldEvent(for: session.day, in: &session)
        session.market = makeMarket(
            in: session.currentDistrictID,
            previous: oldMarket,
            quoteCount: session.day == session.totalDays ? GameContent.commodities.count : 5,
            priceMultiplier: worldModifiers(for: session).marketPrice
        )
        session.resetWeeklyActions()
        let event = drawEvent(in: session.currentDistrictID, session: session)
        apply(event, to: &session)
        log(event, in: &session, at: session.currentDistrictID, week: session.day)
        scheduleWeekEvents(in: &session)
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

    private func log(_ event: GameEvent, in session: inout GameSession, at districtID: District.ID, week: Int) {
        session.log.insert(
            GameLogEntry(
                day: week,
                title: "\(GameContent.district(districtID).name) · \(event.title)",
                message: event.message,
                eventID: event.historyID
            ),
            at: 0
        )
    }

    private mutating func makeMarket(
        in districtID: District.ID,
        previous: [MarketQuote],
        quoteCount: Int = 5,
        preferredCommodityID: Commodity.ID? = nil,
        priceMultiplier: Double = 1
    ) -> [MarketQuote] {
        let district = GameContent.district(districtID)
        var available = GameContent.commodities.shuffled(using: &random)
        let boundedQuoteCount = min(quoteCount, available.count)

        if let preferredCommodityID,
           let preferredIndex = available.firstIndex(where: { $0.id == preferredCommodityID }) {
            let preferredCommodity = available.remove(at: preferredIndex)
            available.removeLast(max(0, available.count - max(0, boundedQuoteCount - 1)))
            available.append(preferredCommodity)
        } else {
            available.removeLast(max(0, available.count - boundedQuoteCount))
        }

        return available.map { commodity in
            let swing = Double.random(in: 0.78 ... 1.24, using: &random)
            let rawPrice = Double(commodity.basePrice)
                * district.priceBias(for: commodity.id)
                * swing
                * priceMultiplier
            let boundedPrice = min(commodity.maximumPrice, max(commodity.minimumPrice, Int(rawPrice.rounded())))
            let previousPrice = previous.first(where: { $0.commodityID == commodity.id })?.price
                ?? commodity.basePrice
            return MarketQuote(commodityID: commodity.id, price: boundedPrice, previousPrice: previousPrice)
        }
        .sorted { $0.price > $1.price }
    }

    func activeWorldEvents(in session: GameSession) -> [WorldEvent] {
        session.activeWorldEvents.compactMap { active in
            guard active.isActive(in: session.day), var event = WorldEventCatalog.event(active.eventID) else { return nil }
            event.modifiers = active.modifiers ?? event.modifiers
            return event
        }
    }

    func activeWorldEvent(in session: GameSession) -> WorldEvent? {
        activeWorldEvents(in: session).last
    }

    func worldModifiers(for session: GameSession) -> WorldEventModifiers {
        WorldEventModifiers.combined(activeWorldEvents(in: session).map(\.modifiers))
    }

    private func scaled(_ value: Int, by multiplier: Double) -> Int {
        Int((Double(value) * multiplier).rounded())
    }

    private func accrueInterest(
        with modifiers: WorldEventModifiers,
        in session: inout GameSession
    ) {
        let debtInterest = Double(session.debt)
            * balance.debtInterestRate
            * modifiers.debtInterest
        let bankInterest = Double(session.bank)
            * balance.bankInterestRate
            * modifiers.bankInterest
        let oldDebt = session.debt
        session.debt += Int(debtInterest.rounded(.down))
        session.recordStatusChange(.debt, from: oldDebt, reason: "每周欠款利息")
        session.bank += Int(bankInterest.rounded(.down))
    }

    private func requireNoPendingLifeChoice(_ session: GameSession) throws {
        guard session.pendingInvestmentInvitation == nil else { throw InvestmentEventError.pendingChoice }
        guard session.pendingLifeChoiceID == nil else { throw GameRuleError.lifeChoicePending }
    }

    private func settleEquipmentForNewWeek(in session: inout GameSession) {
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

    mutating func respondToInvestmentInvitation(amount: Int?, in session: inout GameSession) throws {
        try InvestmentEventEngine.respond(amount: amount, in: &session, using: &random)
    }

    private mutating func scheduleWeekEvents(in session: inout GameSession) {
        scheduleLifeChoiceIfNeeded(in: &session)
        InvestmentEventEngine.offer(in: &session, catalog: EventContentCatalog.bundled.investmentEvents, using: &random)
    }

    private mutating func scheduleLifeChoiceIfNeeded(in session: inout GameSession) {
        guard session.pendingLifeChoiceID == nil, session.day < session.totalDays else { return }
        guard let stage = EventContentCatalog.bundled.manifest.lifeChoiceStages.first(where: {
            ($0.firstWeek ... $0.lastWeek).contains(session.day)
        })?.id else { return }
        let resolved = session.resolvedLifeChoiceIDs ?? []
        guard !GameContent.lifeChoices.contains(where: { $0.stage == stage && resolved.contains($0.id) }) else {
            return
        }
        let candidates = GameContent.lifeChoices.filter {
            $0.stage == stage && !resolved.contains($0.id) && ($0.condition ?? .always).matches(session)
        }
        session.pendingLifeChoiceID = candidates.randomElement(using: &random)?.id
    }

    private func encounterTone(for event: GameEvent) -> EncounterTone {
        if let tone = event.encounterTone { return tone }
        if event.kind == .opportunity, event.healthDelta >= 0 { return .favorable }
        if event.kind == .setback || event.healthDelta < 0 { return .unfavorable }
        return .mixed
    }

    private mutating func updateWorldEvent(for week: Int, in session: inout GameSession) {
        WorldEventScheduler.update(
            in: &session, catalog: WorldEventCatalog.events,
            schedule: WorldEventCatalog.schedule, using: &random
        )
    }

    private mutating func drawEvent(in districtID: District.ID, session: GameSession) -> GameEvent {
        let eligibleEvents = GameContent.events.filter {
            $0.triggerChance == nil && $0.canOccur(in: districtID)
                && ($0.condition ?? .always).matches(session, districtID: districtID)
        }
        guard !eligibleEvents.isEmpty else {
            return GameEvent(id: "quiet-week", kind: .opportunity, title: "平静的一周", message: "这一周没有额外的遭遇。")
        }
        let boundedLuck = session.currentLuck
        let goodWeight = 0.2 + 0.004 * Double(boundedLuck)
        let badWeight = 0.6 - 0.004 * Double(boundedLuck)
        let roll = Double.random(in: 0 ..< 1, using: &random)
        let wantedTone: EncounterTone = roll < goodWeight
            ? .favorable
            : (roll < goodWeight + badWeight ? .unfavorable : .mixed)
        let matching = eligibleEvents.filter { encounterTone(for: $0) == wantedTone }
        let candidates = matching.isEmpty ? eligibleEvents : matching
        if candidates.contains(where: { $0.selectionWeight != nil }) {
            return EventSelection.choose(
                from: candidates,
                weight: { $0.selectionWeight?.weight(luck: boundedLuck, luckScale: 3) ?? 1 },
                using: &random
            ) ?? GameEvent(id: "quiet-week", kind: .opportunity, title: "平静的一周", message: "这一周没有额外的遭遇。")
        }
        // Keep the legacy draw and RNG sequence for pools without authored weights.
        return candidates.randomElement(using: &random)!
    }

    func apply(_ event: GameEvent, to session: inout GameSession) {
        EventEffectExecutor.apply(
            event.immediateEffects,
            reason: event.title,
            healthMultiplier: worldModifiers(for: session).healthChange,
            to: &session
        )
        session.latestEvent = event
    }
}
