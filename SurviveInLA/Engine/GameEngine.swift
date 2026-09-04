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
        return GameSession(
            day: 1,
            totalDays: balance.totalDays,
            cash: balance.startingCash,
            debt: balance.startingDebt,
            bank: 0,
            health: balance.startingHealth,
            reputation: balance.startingReputation,
            capacity: balance.startingCapacity,
            currentDistrictID: districtID,
            market: makeMarket(in: districtID, previous: []),
            inventory: [:],
            latestEvent: nil,
            log: [
                GameLogEntry(
                    day: 1,
                    title: "抵达丁胖子广场",
                    message: "跨过边境、一路辗转来到洛杉矶。你有一本外国护照、2,000 美元现金和 5,000 美元债务。五十二周，先活下来，再想办法翻身。"
                )
            ],
            actionThisWeek: nil
        )
    }

    func buy(_ commodityID: Commodity.ID, quantity: Int, in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        guard quantity > 0 else { throw GameRuleError.invalidQuantity }
        guard let quote = session.market.first(where: { $0.commodityID == commodityID }) else {
            throw GameRuleError.quoteUnavailable
        }
        guard session.availableCapacity >= quantity else { throw GameRuleError.insufficientCapacity }

        let total = quote.price * quantity
        guard session.cash >= total else { throw GameRuleError.insufficientCash }
        try claimWeeklyAction(.trading, in: &session)

        let oldPosition = session.inventory[commodityID]
        let oldQuantity = oldPosition?.quantity ?? 0
        let oldCost = (oldPosition?.averageCost ?? 0) * oldQuantity
        let newQuantity = oldQuantity + quantity
        let averageCost = (oldCost + total) / newQuantity

        session.cash -= total
        session.inventory[commodityID] = InventoryPosition(
            commodityID: commodityID,
            quantity: newQuantity,
            averageCost: averageCost
        )
    }

    func sell(_ commodityID: Commodity.ID, quantity: Int, in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        guard quantity > 0 else { throw GameRuleError.invalidQuantity }
        guard let quote = session.market.first(where: { $0.commodityID == commodityID }) else {
            throw GameRuleError.quoteUnavailable
        }
        guard var position = session.inventory[commodityID], position.quantity >= quantity else {
            throw GameRuleError.insufficientInventory
        }
        try claimWeeklyAction(.trading, in: &session)

        session.cash += quote.price * quantity
        position.quantity -= quantity
        if position.quantity == 0 {
            session.inventory.removeValue(forKey: commodityID)
        } else {
            session.inventory[commodityID] = position
        }

        if commodityID == .smuggledVape {
            session.reputation = max(0, session.reputation - 5)
            session.log.insert(
                GameLogEntry(
                    day: session.day,
                    title: "声望受损",
                    message: "无证电子烟虽然卖掉了，但这笔生意让社区对你的评价下降。"
                ),
                at: 0
            )
        }
    }

    func deposit(_ amount: Int, in session: inout GameSession) throws {
        try validateActiveSession(session, amount: amount)
        guard session.cash >= amount else { throw GameRuleError.insufficientCash }
        session.cash -= amount
        session.bank += amount
    }

    func withdraw(_ amount: Int, in session: inout GameSession) throws {
        try validateActiveSession(session, amount: amount)
        guard session.bank >= amount else { throw GameRuleError.insufficientBankBalance }
        session.bank -= amount
        session.cash += amount
    }

    func repayDebt(_ amount: Int, in session: inout GameSession) throws {
        try validateActiveSession(session, amount: amount)
        let payment = min(amount, session.debt)
        guard session.cash >= payment else { throw GameRuleError.insufficientCash }
        session.cash -= payment
        session.debt -= payment
    }

    func heal(_ points: Int, in session: inout GameSession) throws {
        try validateActiveSession(session, amount: points)
        guard session.health < 100 else { throw GameRuleError.healthAlreadyFull }
        let restoredPoints = min(points, 100 - session.health)
        let cost = restoredPoints * balance.treatmentCostPerPoint
        guard session.cash >= cost else { throw GameRuleError.insufficientCash }
        session.cash -= cost
        session.health += restoredPoints
    }

    func expandCapacity(in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        guard session.capacity < balance.maximumCapacity else { throw GameRuleError.capacityAtMaximum }
        let cost = capacityUpgradeCost(for: session)
        guard session.cash >= cost else { throw GameRuleError.insufficientCash }
        session.cash -= cost
        session.capacity = min(balance.maximumCapacity, session.capacity + balance.capacityUpgradeAmount)
    }

    func capacityUpgradeCost(for session: GameSession) -> Int {
        let completedUpgrades = max(0, (session.capacity - 100) / balance.capacityUpgradeAmount)
        return balance.baseCapacityUpgradeCost + completedUpgrades * 1_000
    }

    mutating func travel(to destinationID: District.ID, session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        if session.day == session.totalDays {
            endJourney(session: &session)
            return
        }
        guard destinationID != session.currentDistrictID else { throw GameRuleError.alreadyThere }
        try claimWeeklyAction(.trading, in: &session)

        let oldMarket = session.market
        session.day += 1
        session.currentDistrictID = destinationID
        session.debt += Int((Double(session.debt) * balance.debtInterestRate).rounded(.down))
        session.bank += Int((Double(session.bank) * balance.bankInterestRate).rounded(.down))

        let event = drawEvent(in: destinationID)
        session.market = makeMarket(
            in: destinationID,
            previous: oldMarket,
            quoteCount: session.day == session.totalDays ? GameContent.commodities.count : 5,
            preferredCommodityID: event.group == .market ? event.affectedCommodityID : nil
        )
        apply(event, to: &session)
        session.log.insert(
            GameLogEntry(
                day: session.day,
                title: "\(GameContent.district(destinationID).name) · \(event.title)",
                message: event.message
            ),
            at: 0
        )
        session.actionThisWeek = nil
    }

    mutating func work(in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try claimWeeklyAction(.work, in: &session)

        let job = GameContent.job(in: session.currentDistrictID)
        let outcome = Int.random(in: 0 ..< 5, using: &random)
        let bonus: Int
        let extraHealthCost: Int
        let reputationDelta: Int
        let outcomeText: String

        switch outcome {
        case 0:
            bonus = 80
            extraHealthCost = 1
            reputationDelta = 1
            outcomeText = "临时多干了一会儿，老板把加班费一起结了。"
        case 1:
            bonus = 50
            extraHealthCost = 0
            reputationDelta = 0
            outcomeText = "这周遇到爽快的客人，你多拿到一点小费。"
        case 2:
            bonus = -40
            extraHealthCost = 0
            reputationDelta = -1
            outcomeText = "一个小失误被扣了钱，这周算是交了学费。"
        case 3:
            bonus = 0
            extraHealthCost = 0
            reputationDelta = 2
            outcomeText = "你顺手帮了同样在异乡讨生活的人，社区里有人记住了你。"
        default:
            bonus = 0
            extraHealthCost = 0
            reputationDelta = 0
            outcomeText = "这一周没出岔子，工资按约定到账。"
        }

        let income = max(0, job.wage + bonus)
        let event = GameEvent(
            id: "work-\(session.day)-\(job.districtID.rawValue)",
            kind: .opportunity,
            group: .money,
            title: job.title,
            message: "\(job.detail) \(outcomeText) 本周收入 \(income.usdText)。",
            cashDelta: income,
            healthDelta: -(job.healthCost + extraHealthCost),
            reputationDelta: reputationDelta,
            districtIDs: [session.currentDistrictID]
        )
        apply(event, to: &session)
        log(event, in: &session, at: session.currentDistrictID, week: session.day)
        advanceStationaryWeek(session: &session)
    }

    mutating func invest(_ amount: Int, in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        guard amount > 0 else { throw GameRuleError.invalidQuantity }

        let opportunity = GameContent.investment(in: session.currentDistrictID)
        guard amount >= opportunity.minimumInvestment else { throw GameRuleError.investmentTooSmall }
        guard session.cash >= amount else { throw GameRuleError.insufficientCash }
        try claimWeeklyAction(.investment, in: &session)

        let percentage = investmentReturnPercentage(for: opportunity.risk)
        let profit = amount * percentage / 100
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
            districtIDs: [session.currentDistrictID]
        )
        apply(event, to: &session)
        log(event, in: &session, at: session.currentDistrictID, week: session.day)
        advanceStationaryWeek(session: &session)
    }

    mutating func endJourney(session: inout GameSession) {
        guard !session.isFinished else { return }

        var liquidationTotal = 0
        for position in session.inventory.values {
            let price = session.market.first(where: { $0.commodityID == position.commodityID })?.price
                ?? GameContent.commodity(position.commodityID).basePrice
            liquidationTotal += price * position.quantity
        }
        session.cash += liquidationTotal
        session.inventory.removeAll()
        session.day = session.totalDays + 1
        session.actionThisWeek = nil
        session.latestEvent = nil
        session.log.insert(
            GameLogEntry(
                day: session.totalDays,
                title: "旅程结束",
                message: liquidationTotal > 0
                    ? "系统按最后一周的行情卖出了剩余货物，共收入 \(liquidationTotal.usdText)。"
                    : "随身货物已经清空，开始计算最终成绩。"
            ),
            at: 0
        )
    }

    private func validateActiveSession(_ session: GameSession, amount: Int) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        guard amount > 0 else { throw GameRuleError.invalidQuantity }
    }

    private func claimWeeklyAction(_ action: WeeklyAction, in session: inout GameSession) throws {
        if let chosenAction = session.actionThisWeek, chosenAction != action {
            throw GameRuleError.weeklyActionAlreadyChosen
        }
        session.actionThisWeek = action
    }

    private mutating func advanceStationaryWeek(session: inout GameSession) {
        guard session.health > 0 else { return }
        if session.day == session.totalDays {
            endJourney(session: &session)
            return
        }

        let oldMarket = session.market
        session.day += 1
        session.debt += Int((Double(session.debt) * balance.debtInterestRate).rounded(.down))
        session.bank += Int((Double(session.bank) * balance.bankInterestRate).rounded(.down))
        session.market = makeMarket(
            in: session.currentDistrictID,
            previous: oldMarket,
            quoteCount: session.day == session.totalDays ? GameContent.commodities.count : 5
        )
        session.actionThisWeek = nil
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
                message: event.message
            ),
            at: 0
        )
    }

    private mutating func makeMarket(
        in districtID: District.ID,
        previous: [MarketQuote],
        quoteCount: Int = 5,
        preferredCommodityID: Commodity.ID? = nil
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
            let rawPrice = Double(commodity.basePrice) * district.priceBias(for: commodity.id) * swing
            let boundedPrice = min(commodity.maximumPrice, max(commodity.minimumPrice, Int(rawPrice.rounded())))
            let previousPrice = previous.first(where: { $0.commodityID == commodity.id })?.price
                ?? commodity.basePrice
            return MarketQuote(commodityID: commodity.id, price: boundedPrice, previousPrice: previousPrice)
        }
        .sorted { $0.price > $1.price }
    }

    private mutating func drawEvent(in districtID: District.ID) -> GameEvent {
        let eligibleEvents = GameContent.events.filter { $0.canOccur(in: districtID) }
        return eligibleEvents.randomElement(using: &random)!
    }

    func apply(_ event: GameEvent, to session: inout GameSession) {
        session.cash = max(0, session.cash + event.cashDelta)
        session.health = min(100, max(0, session.health + event.healthDelta))
        session.reputation = min(100, max(0, session.reputation + event.reputationDelta))

        if let commodityID = event.affectedCommodityID,
           let multiplier = event.marketPriceMultiplier,
           let quoteIndex = session.market.firstIndex(where: { $0.commodityID == commodityID }) {
            let quote = session.market[quoteIndex]
            let commodity = GameContent.commodity(commodityID)
            let adjustedPrice = Int((Double(quote.price) * multiplier).rounded())
            let boundedPrice = min(commodity.maximumPrice, max(commodity.minimumPrice, adjustedPrice))
            session.market[quoteIndex] = MarketQuote(
                commodityID: commodityID,
                price: boundedPrice,
                previousPrice: quote.previousPrice
            )
            session.market.sort { $0.price > $1.price }
        }

        if let commodityID = event.affectedCommodityID,
           let requestedQuantity = event.grantedQuantity {
            let grantedQuantity = min(requestedQuantity, session.availableCapacity)
            if grantedQuantity > 0 {
                let oldPosition = session.inventory[commodityID]
                let oldQuantity = oldPosition?.quantity ?? 0
                let newQuantity = oldQuantity + grantedQuantity
                let oldCost = (oldPosition?.averageCost ?? 0) * oldQuantity
                session.inventory[commodityID] = InventoryPosition(
                    commodityID: commodityID,
                    quantity: newQuantity,
                    averageCost: oldCost / newQuantity
                )
            }
        }

        session.latestEvent = event
    }
}
