import Foundation

struct EventStory: Hashable, Codable, Sendable {
    let title: String
    let message: String
}

/// Odds and settlement timing are engine data, never invitation copy.
struct InvestmentEventDefinition: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let sourceNPCID: String
    let districtID: District.ID
    let condition: EventCondition?
    let encounterChance: Double
    let minimumInvestment: Int
    let delayTurns: Int
    let profitChance: Double
    let profitPercent: Int
    let lossPercent: Int
    let invitation: EventStory
    let accepted: EventStory
    let declined: EventStory
    let profit: EventStory
    let loss: EventStory
}

struct ScheduledInvestment: Identifiable, Hashable, Codable, Sendable {
    // One invitation per definition per journey; also identifies this payment.
    let id: String
    let sourceNPCID: String
    let principal: Int
    let investedTurn: Int
    let dueTurn: Int
    let profitAmount: Int
    let resultStory: EventStory

    var payout: Int { principal + profitAmount }
}

enum InvestmentEventError: LocalizedError {
    case noInvitation, pendingChoice, invalidAmount, tooLate

    var errorDescription: String? {
        switch self {
        case .noInvitation: "这次邀请已经处理过了。"
        case .pendingChoice: "请先回应当前的投资邀请。"
        case .invalidAmount: "请输入可用现金范围内的正整数金额。"
        case .tooLate: "这次邀请已经结束。"
        }
    }
}
