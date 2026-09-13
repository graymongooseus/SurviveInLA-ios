import Foundation

/// Exactly one blocking presentation is selected. Selecting never removes a queued event.
enum GamePresentation: Equatable, Sendable {
    case introduction, purchasedAdventure, worldEvent, healthEvent, lifeChoiceResult, notice
    case awaitingTravelNotice, lifeChoice, investment, celebrity, acting, result
}

extension GameStore {
    var presentation: GamePresentation? {
        if isIntroductionPresented { return .introduction }
        if purchasedAdventure != nil { return .purchasedAdventure }
        if worldEventNotice != nil { return .worldEvent }
        if notice != nil {
            if lifeChoiceResult != nil { return .lifeChoiceResult }
            if notice?.healthEvent != nil { return .healthEvent }
            return .notice
        }
        if isAwaitingTravelNotice { return .awaitingTravelNotice }
        // Resolved investment notices must remain readable even at the end of a run.
        if !session.isFinished, session.pendingInteraction == .lifeChoice { return .lifeChoice }
        if investmentNotice != nil { return .investment }
        if actingNotice != nil { return .acting }
        if !session.isFinished {
            switch session.pendingInteraction {
            case .investment: return .investment
            case .celebrity: return .celebrity
            case .acting: return .acting
            case .lifeChoice: return .lifeChoice
            case nil: break
            }
        }
        return session.isFinished ? .result : nil
    }
}
