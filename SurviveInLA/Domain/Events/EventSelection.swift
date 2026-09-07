import Foundation

enum EventFavorability: String, Codable, Sendable {
    case favorable, mixed, unfavorable

    var direction: Double {
        switch self {
        case .favorable: 1
        case .mixed: 0
        case .unfavorable: -1
        }
    }
}

/// Authored rating, not an estimate of the current player's financial benefit.
/// A neutral-luck player sees the base weights. Stronger favorable events gain
/// more weight with high luck; strong setbacks gain more weight with low luck.
struct EventSelectionWeight: Hashable, Codable, Sendable {
    let baseWeight: Double
    let favorability: EventFavorability
    let strength: Int

    func weight(luck: Int, luckScale: Double) -> Double {
        let position = Double(min(100, max(0, luck)) - 50) / 50
        return baseWeight * pow(luckScale, favorability.direction * Double(strength) * position)
    }
}

struct WorldEventSchedule: Hashable, Codable, Sendable {
    let firstWeek: Int
    let intervalWeeks: Int
    let occurrenceChance: Double
    let luckScale: Double

    func isDue(in week: Int) -> Bool {
        week >= firstWeek && intervalWeeks > 0 && (week - firstWeek).isMultiple(of: intervalWeeks)
    }
}

enum EventSelection {
    /// Stable input order is intentional. Empty pools consume no randomness.
    static func choose<Element, RNG: RandomNumberGenerator>(
        from candidates: [Element],
        weight: (Element) -> Double,
        using random: inout RNG
    ) -> Element? {
        let weighted = candidates.map { ($0, weight($0)) }.filter { $0.1.isFinite && $0.1 > 0 }
        let total = weighted.reduce(0) { $0 + $1.1 }
        guard total.isFinite, total > 0 else { return nil }
        var roll = Double.random(in: 0 ..< total, using: &random)
        for (candidate, value) in weighted {
            if roll < value { return candidate }
            roll -= value
        }
        return weighted.last?.0
    }
}
