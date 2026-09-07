import Foundation

enum GameEventKind: String, Codable, Sendable {
    case opportunity
    case setback
    case health
    case reputation
}

enum GameEventGroup: String, CaseIterable, Codable, Sendable {
    case market
    case health
    case money
}

enum EncounterTone: String, Codable, Sendable {
    case favorable
    case unfavorable
    case mixed
}

struct GameEvent: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let kind: GameEventKind
    let group: GameEventGroup?
    let title: String
    let message: String
    let cashDelta: Int
    let healthDelta: Int
    let reputationDelta: Int
    let affectedCommodityID: Commodity.ID?
    let marketPriceMultiplier: Double?
    let grantedQuantity: Int?
    let districtIDs: [District.ID]?
    let triggerChance: Double?
    let workIncomeMultiplier: Double?
    // 动态打工、投资事件保留世界倍率修正前的现金效果。
    let baseCashDelta: Int?
    let skippedWeeks: Int?
    let encounterTone: EncounterTone?
    let luckDelta: Int?
    let condition: EventCondition?
    let selectionWeight: EventSelectionWeight?
    let effects: [EventEffect]?

    init(
        id: String,
        kind: GameEventKind,
        group: GameEventGroup? = nil,
        title: String,
        message: String,
        cashDelta: Int = 0,
        healthDelta: Int = 0,
        reputationDelta: Int = 0,
        affectedCommodityID: Commodity.ID? = nil,
        marketPriceMultiplier: Double? = nil,
        grantedQuantity: Int? = nil,
        districtIDs: [District.ID]? = nil,
        triggerChance: Double? = nil,
        workIncomeMultiplier: Double? = nil,
        baseCashDelta: Int? = nil,
        skippedWeeks: Int? = nil,
        encounterTone: EncounterTone? = nil,
        luckDelta: Int? = nil,
        condition: EventCondition? = nil,
        selectionWeight: EventSelectionWeight? = nil,
        effects: [EventEffect]? = nil
    ) {
        self.id = id
        self.kind = kind
        self.group = group
        self.title = title
        self.message = message
        self.cashDelta = cashDelta
        self.healthDelta = healthDelta
        self.reputationDelta = reputationDelta
        self.affectedCommodityID = affectedCommodityID
        self.marketPriceMultiplier = marketPriceMultiplier
        self.grantedQuantity = grantedQuantity
        self.districtIDs = districtIDs
        self.triggerChance = triggerChance
        self.workIncomeMultiplier = workIncomeMultiplier
        self.baseCashDelta = baseCashDelta
        self.skippedWeeks = skippedWeeks
        self.encounterTone = encounterTone
        self.luckDelta = luckDelta
        self.condition = condition
        self.selectionWeight = selectionWeight
        self.effects = effects
    }

    var baseEffectSummary: String {
        if let effects {
            let summaries = effects.compactMap(\.summary)
            return summaries.isEmpty ? "无数值变化" : summaries.joined(separator: "\n")
        }
        var effects: [String] = []
        let baseCash = baseCashDelta ?? cashDelta
        if baseCash != 0 {
            let amount = baseCash.magnitude.formatted(
                .currency(code: "USD")
                    .precision(.fractionLength(0))
                    .locale(Locale(identifier: "en_US"))
            )
            effects.append("现金 \(baseCash > 0 ? "+" : "−")\(amount)")
        }
        if healthDelta != 0 {
            effects.append("健康 \(healthDelta > 0 ? "+" : "−")\(healthDelta.magnitude)")
        }
        // 1.0 的声望字段只为旧存档和旧事件解码保留，不再参与 1.1 结算。
        if let luckDelta, luckDelta != 0 {
            effects.append("运气 \(luckDelta > 0 ? "+" : "−")\(luckDelta.magnitude)")
        }
        if let commodityID = affectedCommodityID {
            let name = GameContent.commodity(commodityID).name
            if let multiplier = marketPriceMultiplier {
                effects.append("\(name)价格 ×\(multiplier.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "en_US"))))（受价格上下限限制）")
            }
            if let quantity = grantedQuantity, quantity > 0 {
                effects.append("免费获得最多 \(quantity) 份\(name)（受剩余仓储容量限制）")
            }
        }
        if let multiplier = workIncomeMultiplier {
            effects.append("当周打工收入 ×\(multiplier.formatted(.number.precision(.fractionLength(0 ... 2)).locale(Locale(identifier: "en_US"))))")
        }
        if let skippedWeeks, skippedWeeks > 0 {
            effects.append("跳过 \(skippedWeeks) 周（债务与存款继续计息）")
        }
        return effects.isEmpty ? "无数值变化" : effects.joined(separator: "\n")
    }

    func canOccur(in districtID: District.ID) -> Bool {
        districtIDs?.contains(districtID) ?? true
    }
}

struct LifeChoiceOption: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let result: String
    let cashDelta: Int
    let healthDelta: Int
    let luckDelta: Int
}

struct LifeChoiceEvent: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let story: String
    let imageName: String?
    let stage: Int
    let options: [LifeChoiceOption]
    var condition: EventCondition? = nil
}
