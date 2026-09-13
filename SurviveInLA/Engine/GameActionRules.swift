import Foundation

extension GameEngine {
    func validateActiveSession(_ session: GameSession, amount: Int) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        guard amount > 0 else { throw GameRuleError.invalidQuantity }
    }

    func claimWeeklyAction(
        _ action: WeeklyAction,
        allowsRepeat: Bool = false,
        in session: inout GameSession
    ) throws {
        if session.didCompleteWeeklyAction(action), !allowsRepeat {
            throw GameRuleError.weeklyActionAlreadyChosen
        }
        session.recordWeeklyAction(action)
    }

    func claimDreamAction(in session: inout GameSession) throws {
        guard !session.didPerformDreamActionThisWeek else {
            throw GameRuleError.dreamActionAlreadyTaken
        }
        session.dreamActionWeek = session.day
    }

    func scaled(_ value: Int, by multiplier: Double) -> Int {
        Int((Double(value) * multiplier).rounded())
    }

    func requireNoPendingInteraction(_ session: GameSession) throws {
        switch session.pendingInteraction {
        case .lifeChoice: throw GameRuleError.lifeChoicePending
        case .investment: throw InvestmentEventError.pendingChoice
        case .celebrity, .acting: throw CelebrityEventError.pendingChoice
        case nil: break
        }
    }
}
