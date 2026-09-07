import Foundation

enum InvestmentEventEngine {
    static let maximumPrincipal = 1_000_000_000

    static func offer<RNG: RandomNumberGenerator>(
        in session: inout GameSession,
        catalog: [InvestmentEventDefinition],
        using random: inout RNG
    ) {
        guard !session.isFinished, session.pendingInvestmentInvitation == nil,
              session.lastInvestmentEventCheckTurn != session.day else { return }
        session.lastInvestmentEventCheckTurn = session.day
        let resolved = session.resolvedInvestmentEventIDs ?? []
        for event in catalog {
            guard event.districtID == session.currentDistrictID,
                  !resolved.contains(event.id),
                  session.day + event.delayTurns <= session.totalDays,
                  (event.condition ?? .always).matches(session),
                  event.encounterChance > 0 else { continue }
            if event.encounterChance < 1,
               Double.random(in: 0 ..< 1, using: &random) >= event.encounterChance { continue }
            session.pendingInvestmentInvitation = event
            session.log.insert(GameLogEntry(day: session.day, title: event.invitation.title,
                                            message: event.invitation.message, eventID: event.id), at: 0)
            return
        }
    }

    /// Validate before drawing randomness or deducting money.
    static func respond<RNG: RandomNumberGenerator>(
        amount: Int?, in session: inout GameSession, using random: inout RNG
    ) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        guard let event = session.pendingInvestmentInvitation,
              session.resolvedInvestmentEventIDs?.contains(event.id) != true else {
            throw InvestmentEventError.noInvitation
        }
        if let amount {
            guard amount >= event.minimumInvestment, amount <= maximumPrincipal,
                  amount <= session.cash else { throw InvestmentEventError.invalidAmount }
            guard session.day + event.delayTurns <= session.totalDays else { throw InvestmentEventError.tooLate }
            let won = Double.random(in: 0 ..< 1, using: &random) < event.profitChance
            let magnitude = max(1, amount * (won ? event.profitPercent : event.lossPercent) / 100)
            let profit = won ? magnitude : -min(amount, magnitude)
            let investment = ScheduledInvestment(
                id: event.id, sourceNPCID: event.sourceNPCID, principal: amount,
                investedTurn: session.day, dueTurn: session.day + event.delayTurns,
                profitAmount: profit, resultStory: won ? event.profit : event.loss
            )
            let previous = session.cash
            session.cash -= amount
            session.recordStatusChange(.cash, from: previous, reason: event.invitation.title)
            session.pendingInvestments = (session.pendingInvestments ?? []) + [investment]
            enqueue(story: event.accepted, id: "\(event.id)-accepted", cashDelta: -amount,
                    detail: "投入金额：\(amount.usdText)。", in: &session)
        } else {
            enqueue(story: event.declined, id: "\(event.id)-declined", cashDelta: 0, detail: "", in: &session)
        }
        session.resolvedInvestmentEventIDs = (session.resolvedInvestmentEventIDs ?? []).union([event.id])
        session.pendingInvestmentInvitation = nil
    }

    /// Every crossed turn, before terminal-turn settlement. No new RNG draw.
    static func settleDue(in session: inout GameSession) {
        let due = (session.pendingInvestments ?? []).filter { $0.dueTurn <= session.day }
        guard !due.isEmpty else { return }
        session.pendingInvestments?.removeAll { $0.dueTurn <= session.day }
        for investment in due {
            let previous = session.cash
            session.cash += investment.payout
            session.recordStatusChange(.cash, from: previous, reason: investment.resultStory.title)
            let result = investment.profitAmount >= 0
                ? "净赚 \(investment.profitAmount.usdText)"
                : "亏损 \((-investment.profitAmount).usdText)"
            enqueue(story: investment.resultStory, id: "\(investment.id)-settled",
                    cashDelta: investment.payout,
                    detail: "当初投入 \(investment.principal.usdText)，本次收回 \(investment.payout.usdText)，\(result)。",
                    kind: investment.profitAmount >= 0 ? .opportunity : .setback, in: &session)
        }
    }

    private static func enqueue(
        story: EventStory, id: String, cashDelta: Int, detail: String,
        kind: GameEventKind = .opportunity, in session: inout GameSession
    ) {
        let message = detail.isEmpty ? story.message : "\(story.message)\n\n\(detail)"
        let notice = GameEvent(id: id, kind: kind, group: .money, title: story.title,
                               message: message, cashDelta: cashDelta)
        session.unreadInvestmentNotices = (session.unreadInvestmentNotices ?? []) + [notice]
        session.log.insert(GameLogEntry(day: session.day, title: story.title, message: message, eventID: id), at: 0)
    }
}
