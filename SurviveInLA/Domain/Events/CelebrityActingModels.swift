import Foundation

struct CelebrityActingOption: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let result: String
    let fee: Int
    let healthDelta: Int
    let luckDelta: Int

    var immediateEffects: [EventEffect] {
        [.cash(amount: fee), .health(amount: healthDelta), .luck(amount: luckDelta)]
    }
    var effectSummary: String { immediateEffects.compactMap(\.summary).joined(separator: " · ") }
}

struct CelebrityActingEventDefinition: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let sourceNPCID: String
    let districtID: District.ID
    let condition: EventCondition
    let oncePerJourney: Bool
    let requiresTimeForBonus: Bool
    let delayTurns: Int
    let bonusMultiplier: Int
    let invitation: EventStory
    let premiere: EventStory
    let options: [CelebrityActingOption]
    var interactionKind: CelebrityInteractionKind { .acting }
}

struct PendingActingEncounter: Identifiable, Codable, Sendable {
    let id: String
    let event: CelebrityActingEventDefinition
}

/// Freeze the agreed fee and premiere story so balancing updates cannot change an existing contract.
struct ScheduledActingBonus: Identifiable, Codable, Sendable {
    let id: String
    let eventID: String
    let sourceNPCID: String
    let roleTitle: String
    let originalFee: Int
    let amount: Int
    let dueTurn: Int
    let story: EventStory
}

enum CelebrityActingError: LocalizedError {
    case staleEncounter, invalidOption
    var errorDescription: String? {
        switch self {
        case .staleEncounter: "这次片场邀约已经处理过了。"
        case .invalidOption: "请选择一个片场身份。"
        }
    }
}
