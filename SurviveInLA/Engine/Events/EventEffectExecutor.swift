import Foundation

/// Applies immediate effects in their declared order. Owns the existing bounds,
/// rounding, inventory cost accounting, and actual-change history. It neither
/// selects events nor consumes randomness or controls presentation.
enum EventEffectExecutor {
    static func apply(
        _ effects: [EventEffect],
        reason: String,
        healthMultiplier: Double,
        to session: inout GameSession
    ) {
        for effect in effects {
            switch effect {
            case let .cash(delta):
                let previous = session.cash
                session.cash = max(0, session.cash + delta)
                session.recordStatusChange(.cash, from: previous, reason: reason)

            case let .health(delta):
                let previous = session.health
                let adjusted = Int((Double(delta) * healthMultiplier).rounded())
                session.health = min(100, max(0, session.health + adjusted))
                session.recordStatusChange(.health, from: previous, reason: reason)
                session.journey?.healthLost += max(0, previous - session.health)
                session.journey?.healthRecovered += max(0, session.health - previous)

            case let .luck(delta):
                let previous = session.currentLuck
                session.currentLuck += delta
                session.recordStatusChange(.luck, from: previous, reason: reason)

            case let .marketPrice(commodityID, multiplier):
                guard let index = session.market.firstIndex(where: { $0.commodityID == commodityID }) else {
                    continue
                }
                let quote = session.market[index]
                let commodity = GameContent.commodity(commodityID)
                let adjusted = Int((Double(quote.price) * multiplier).rounded())
                let price = min(commodity.maximumPrice, max(commodity.minimumPrice, adjusted))
                session.market[index] = MarketQuote(
                    commodityID: commodityID, price: price, previousPrice: quote.previousPrice
                )
                session.market.sort { $0.price > $1.price }

            case let .grantCommodity(commodityID, requested):
                let granted = min(requested, session.availableCapacity)
                guard granted > 0 else { continue }
                let previous = session.inventory[commodityID]
                let oldQuantity = previous?.quantity ?? 0
                let quantity = oldQuantity + granted
                let cost = (previous?.averageCost ?? 0) * oldQuantity
                session.inventory[commodityID] = InventoryPosition(
                    commodityID: commodityID, quantity: quantity, averageCost: cost / quantity
                )
            }
        }
    }
}
