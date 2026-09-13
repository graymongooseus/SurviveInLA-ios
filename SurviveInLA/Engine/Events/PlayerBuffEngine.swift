import Foundation

enum PlayerBuffEngine {
    static func grant(_ definition: PlayerBuffDefinition, instanceID: String,
                      sourceEventID: String, in session: inout GameSession) {
        guard !(session.playerBuffs ?? []).contains(where: { $0.id == instanceID }) else { return }
        let oldLuck = session.currentLuck
        session.playerBuffs = (session.playerBuffs ?? []) + [ActivePlayerBuff(
            id: instanceID, definition: definition, sourceEventID: sourceEventID,
            remainingTurns: definition.durationTurns, lastProcessedTurn: session.day
        )]
        session.recordStatusChange(.luck, from: oldLuck, reason: definition.title)
    }

    /// Called once for each crossed turn, before equipment and terminal settlement.
    /// A second call in the same turn cannot heal twice or shorten a buff again.
    static func advance(in session: inout GameSession) {
        let oldLuck = session.currentLuck
        var buffs = session.playerBuffs ?? []
        for index in buffs.indices {
            let steps = min(buffs[index].remainingTurns, max(0, session.day - buffs[index].lastProcessedTurn))
            guard steps > 0 else { continue }
            if session.health > 0, buffs[index].definition.healthPerTurn != 0 {
                EventEffectExecutor.apply([.health(amount: buffs[index].definition.healthPerTurn * steps)],
                                          reason: buffs[index].definition.title, healthMultiplier: 1, to: &session)
            }
            buffs[index].remainingTurns -= steps
            buffs[index].lastProcessedTurn = session.day
        }
        session.playerBuffs = buffs.filter { $0.remainingTurns > 0 }
        session.recordStatusChange(.luck, from: oldLuck, reason: "限时增益到期")
    }
}
