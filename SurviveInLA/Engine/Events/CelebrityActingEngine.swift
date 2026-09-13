import Foundation

enum CelebrityActingEngine {
    /// An actual arrival, not remaining in Hollywood or loading a save, creates the invitation.
    static func onArrival(in session: inout GameSession, catalog: [CelebrityActingEventDefinition]) {
        guard !session.isFinished, session.pendingActingEncounter == nil,
              session.lastActingArrivalTurn != session.day else { return }
        session.lastActingArrivalTurn = session.day
        let resolved = session.resolvedActingEventIDs ?? []
        let encounters = catalog.filter {
            $0.districtID == session.currentDistrictID && $0.condition.matches(session)
                && (!$0.oncePerJourney || !resolved.contains($0.id))
                && (!$0.requiresTimeForBonus || session.day + $0.delayTurns <= session.totalDays)
        }.map { PendingActingEncounter(id: "\($0.id)-visit-\(session.day)", event: $0) }
        session.pendingActingEncounter = encounters.first
        session.queuedActingEncounters = Array(encounters.dropFirst())
        for encounter in encounters {
            session.log.insert(GameLogEntry(day: session.day, title: encounter.event.invitation.title,
                                            message: encounter.event.invitation.message, eventID: encounter.id), at: 0)
        }
    }

    static func choose(_ optionID: String, encounterID: String, in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        guard let encounter = session.pendingActingEncounter, encounter.id == encounterID else {
            throw CelebrityActingError.staleEncounter
        }
        guard let option = encounter.event.options.first(where: { $0.id == optionID }) else {
            throw CelebrityActingError.invalidOption
        }
        // Validate everything before changing cash or consuming the pending encounter.
        let oldCash = session.cash
        let oldHealth = session.health
        let oldLuck = session.currentLuck
        EventEffectExecutor.apply(option.immediateEffects, reason: option.title, healthMultiplier: 1, to: &session)
        session.resolvedActingEventIDs = (session.resolvedActingEventIDs ?? []).union([encounter.event.id])
        if option.fee > 0 {
            session.pendingActingBonuses = (session.pendingActingBonuses ?? []) + [ScheduledActingBonus(
                id: encounter.id + "-bonus", eventID: encounter.event.id, sourceNPCID: encounter.event.sourceNPCID,
                roleTitle: option.title, originalFee: option.fee,
                amount: option.fee * encounter.event.bonusMultiplier, dueTurn: session.day + encounter.event.delayTurns,
                story: encounter.event.premiere
            )]
        }
        let result = GameEvent(
            id: encounter.id + "-result", kind: .opportunity, group: .money,
            title: option.title, message: option.result,
            cashDelta: session.cash - oldCash, healthDelta: session.health - oldHealth,
            luckDelta: session.currentLuck - oldLuck
        )
        enqueue(result, in: &session)
        if var journey = session.journey {
            journey.keyChoices = (journey.keyChoices ?? []) + ["\(encounter.event.invitation.title)：\(option.title)"]
            session.journey = journey
        }
        var queue = session.queuedActingEncounters ?? []
        session.pendingActingEncounter = session.isFinished || queue.isEmpty ? nil : queue.removeFirst()
        session.queuedActingEncounters = session.isFinished ? [] : queue
    }

    /// Run before terminal-turn settlement. Remove due contracts before crediting cash, exactly once.
    static func settleDue(in session: inout GameSession) {
        guard !session.isFinished else { return }
        let due = (session.pendingActingBonuses ?? []).filter { $0.dueTurn <= session.day }
        guard !due.isEmpty else { return }
        session.pendingActingBonuses?.removeAll { $0.dueTurn <= session.day }
        for bonus in due {
            EventEffectExecutor.apply([.cash(amount: bonus.amount)], reason: bonus.story.title,
                                      healthMultiplier: 1, to: &session)
            enqueue(GameEvent(
                id: bonus.id, kind: .opportunity, group: .money, title: bonus.story.title,
                message: "\(bonus.story.message)\n\n你饰演的“\(bonus.roleTitle)”当初片酬为 \(bonus.originalFee.usdText)，这次另收到分红 \(bonus.amount.usdText)。",
                cashDelta: bonus.amount
            ), in: &session)
        }
    }

    private static func enqueue(_ event: GameEvent, in session: inout GameSession) {
        session.unreadActingNotices = (session.unreadActingNotices ?? []) + [event]
        session.log.insert(GameLogEntry(day: session.day, title: event.title, message: event.message, eventID: event.id), at: 0)
    }
}
