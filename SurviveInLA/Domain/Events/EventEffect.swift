import Foundation

/// Immediate state changes. Trigger checks and persistent modifiers belong to
/// their own systems; evaluating an event's eligibility must never apply these.
enum EventEffect: Hashable, Codable, Sendable {
    case cash(amount: Int)
    case health(amount: Int)
    case luck(amount: Int)
    case marketPrice(commodityID: Commodity.ID, multiplier: Double)
    case grantCommodity(commodityID: Commodity.ID, quantity: Int)

    var summary: String? {
        switch self {
        case let .cash(delta):
            guard delta != 0 else { return nil }
            let amount = delta.magnitude.formatted(.currency(code: "USD").precision(.fractionLength(0)).locale(Locale(identifier: "en_US")))
            return "现金 \(delta > 0 ? "+" : "−")\(amount)"
        case let .health(delta):
            return delta == 0 ? nil : "健康 \(delta > 0 ? "+" : "−")\(delta.magnitude)"
        case let .luck(delta):
            return delta == 0 ? nil : "运气 \(delta > 0 ? "+" : "−")\(delta.magnitude)"
        case let .marketPrice(commodityID, multiplier):
            let amount = multiplier.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "en_US")))
            return "\(GameContent.commodity(commodityID).name)价格 ×\(amount)（受价格上下限限制）"
        case let .grantCommodity(commodityID, quantity):
            guard quantity > 0 else { return nil }
            return "免费获得最多 \(quantity) 份\(GameContent.commodity(commodityID).name)（受剩余仓储容量限制）"
        }
    }
}

extension GameEvent {
    /// Compatibility boundary for the existing catalog, dynamic action results,
    /// and saved event cards. New effect types can extend the executor without
    /// adding another optional field to GameEvent.
    var immediateEffects: [EventEffect] {
        if let effects { return effects }
        var effects: [EventEffect] = [.cash(amount: cashDelta), .health(amount: healthDelta)]
        if let luckDelta { effects.append(.luck(amount: luckDelta)) }
        if let commodityID = affectedCommodityID {
            if let multiplier = marketPriceMultiplier {
                effects.append(.marketPrice(commodityID: commodityID, multiplier: multiplier))
            }
            if let quantity = grantedQuantity {
                effects.append(.grantCommodity(commodityID: commodityID, quantity: quantity))
            }
        }
        return effects
    }
}
