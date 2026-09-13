import Foundation

/// Personal modifiers remain separate from base stats and from world events.
struct PlayerBuffDefinition: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let message: String
    let durationTurns: Int
    let luckDelta: Int
    let healthPerTurn: Int
    let workIncomeMultiplier: Double

    var effectSummary: String {
        var parts: [String] = []
        if luckDelta != 0 { parts.append("运气 \(luckDelta > 0 ? "+" : "")\(luckDelta)") }
        if healthPerTurn != 0 { parts.append("每回合健康 \(healthPerTurn > 0 ? "+" : "")\(healthPerTurn)") }
        if workIncomeMultiplier != 1 {
            let percent = Int(((workIncomeMultiplier - 1) * 100).rounded())
            parts.append("打工收入 \(percent > 0 ? "+" : "")\(percent)%")
        }
        return parts.joined(separator: " · ")
    }
}

struct ActivePlayerBuff: Identifiable, Codable, Sendable {
    let id: String
    let definition: PlayerBuffDefinition
    let sourceEventID: String
    var remainingTurns: Int
    var lastProcessedTurn: Int
}

extension GameSession {
    var currentPlayerBuffs: [ActivePlayerBuff] {
        (playerBuffs ?? []).filter { $0.remainingTurns > 0 }
    }

    var playerLuckBonus: Int { currentPlayerBuffs.reduce(0) { $0 + $1.definition.luckDelta } }
    var playerWorkIncomeMultiplier: Double {
        currentPlayerBuffs.reduce(1) { $0 * $1.definition.workIncomeMultiplier }
    }
}
