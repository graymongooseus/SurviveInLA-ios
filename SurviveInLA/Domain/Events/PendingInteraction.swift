import Foundation

enum PendingInteraction: Equatable, Sendable {
    case lifeChoice
    case investment
    case celebrity
    case acting
}

extension GameSession {
    /// Decision priority shared by the engine and presentation. Notices are already settled.
    var pendingInteraction: PendingInteraction? {
        if pendingLifeChoiceID != nil { return .lifeChoice }
        if pendingInvestmentInvitation != nil { return .investment }
        if pendingCelebrityEncounter != nil { return .celebrity }
        if pendingActingEncounter != nil { return .acting }
        return nil
    }
}
