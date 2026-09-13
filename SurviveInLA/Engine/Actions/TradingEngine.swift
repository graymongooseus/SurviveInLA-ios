import Foundation

extension GameEngine {
    func buy(_ commodityID: Commodity.ID, quantity: Int, in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
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
        try requireNoPendingInteraction(session)
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
            session.baseLuck -= 5
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

    mutating func makeMarket(
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
}
