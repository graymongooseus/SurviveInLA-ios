import Foundation

enum CelebrityInteractionKind: String, Codable, Sendable {
    case investment, photo, acting
}

struct CelebrityDefinition: Identifiable, Codable, Sendable {
    let id: String
    let title: String
}

struct CelebrityPhotoOption: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let result: String
    let photoTitle: String
    let salePrice: Int
    let buff: PlayerBuffDefinition
}

struct CelebrityPhotoEventDefinition: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let sourceNPCID: String
    let districtID: District.ID
    let condition: EventCondition
    let invitation: EventStory
    let selection: EventStory
    let declined: EventStory
    let options: [CelebrityPhotoOption]
    var interactionKind: CelebrityInteractionKind { .photo }
}

extension InvestmentEventDefinition {
    var interactionKind: CelebrityInteractionKind { .investment }
}

enum CelebrityEncounterStage: String, Codable, Sendable {
    case invitation, background, result
}

struct PendingCelebrityEncounter: Identifiable, Codable, Sendable {
    let id: String
    let event: CelebrityPhotoEventDefinition
    var stage: CelebrityEncounterStage = .invitation
    var selectedOptionID: String?
    var photoID: String?

    var selectedOption: CelebrityPhotoOption? {
        event.options.first { $0.id == selectedOptionID }
    }
}

struct CelebrityPhoto: Identifiable, Codable, Sendable {
    let id: String
    let sourceNPCID: String
    let eventID: String
    let backgroundID: String
    let title: String
    let acquiredTurn: Int
    let salePrice: Int
    var soldTurn: Int?
}

enum CelebrityEventError: LocalizedError {
    case pendingChoice, staleEncounter, invalidOption, unavailablePhoto
    var errorDescription: String? {
        switch self {
        case .pendingChoice: "请先完成这次名人交互。"
        case .staleEncounter: "这一步已经处理过了。"
        case .invalidOption: "请选择一个合影背景。"
        case .unavailablePhoto: "这张合照已经出售或不在相册中。"
        }
    }
}
