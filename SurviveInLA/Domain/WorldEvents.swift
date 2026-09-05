import Foundation

struct WorldEventModifiers: Hashable, Codable, Sendable {
    let workIncome: Double
    let tradeIncome: Double
    let bankInterest: Double
    let investmentReturn: Double
    let debtInterest: Double
    let healthChange: Double
    let reputationChange: Double

    static let neutral = WorldEventModifiers(
        workIncome: 1,
        tradeIncome: 1,
        bankInterest: 1,
        investmentReturn: 1,
        debtInterest: 1,
        healthChange: 1,
        reputationChange: 1
    )
}

struct WorldEvent: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let message: String
    let triggerWeeks: [Int]
    let triggerChance: Double
    let durationWeeks: Int
    let modifiers: WorldEventModifiers

    var effectSummary: String {
        [
            effect("打工", modifiers.workIncome),
            effect("倒卖", modifiers.tradeIncome),
            effect("存款利息", modifiers.bankInterest),
            effect("投资", modifiers.investmentReturn),
            effect("债务利息", modifiers.debtInterest),
            effect("健康变动", modifiers.healthChange),
            effect("声望变动", modifiers.reputationChange)
        ].joined(separator: " · ")
    }

    private func effect(_ label: String, _ multiplier: Double) -> String {
        let percentage = Int(((multiplier - 1) * 100).rounded())
        return "\(label) \(percentage >= 0 ? "+" : "")\(percentage)%"
    }
}

struct ActiveWorldEvent: Hashable, Codable, Sendable {
    let eventID: String
    let startedWeek: Int
    let endingWeek: Int

    func isActive(in week: Int) -> Bool {
        (startedWeek ... endingWeek).contains(week)
    }
}

enum WorldEventCatalog {
    static let events: [WorldEvent] = [
        WorldEvent(
            id: "labor-enforcement-wave",
            title: "劳工执法整顿",
            message: "南加州展开劳工执法行动，正规临工工资上涨，但灰色交易和投资变得谨慎。",
            triggerWeeks: [5],
            triggerChance: 0.80,
            durationWeeks: 4,
            modifiers: WorldEventModifiers(
                workIncome: 1.20, tradeIncome: 0.95, bankInterest: 1.05,
                investmentReturn: 0.95, debtInterest: 0.95,
                healthChange: 0.90, reputationChange: 1.10
            )
        ),
        WorldEvent(
            id: "port-logistics-gridlock",
            title: "港口物流大拥堵",
            message: "港口与仓储周转失灵，货物流通变慢，搬运工作增加，但倒卖和投资回报承压。",
            triggerWeeks: [12],
            triggerChance: 0.65,
            durationWeeks: 5,
            modifiers: WorldEventModifiers(
                workIncome: 1.10, tradeIncome: 0.78, bankInterest: 0.90,
                investmentReturn: 0.80, debtInterest: 1.15,
                healthChange: 1.20, reputationChange: 0.90
            )
        ),
        WorldEvent(
            id: "southern-california-spending-boom",
            title: "南加州消费热潮",
            message: "游客与本地消费同时升温，工作、交易和投资机会增加，但借贷成本也开始抬头。",
            triggerWeeks: [20],
            triggerChance: 0.55,
            durationWeeks: 6,
            modifiers: WorldEventModifiers(
                workIncome: 1.12, tradeIncome: 1.25, bankInterest: 1.10,
                investmentReturn: 1.20, debtInterest: 1.10,
                healthChange: 0.90, reputationChange: 1.15
            )
        ),
        WorldEvent(
            id: "rapid-rate-hike",
            title: "利率快速上升",
            message: "市场利率突然走高，存款收益明显增加，但债务膨胀、消费降温，投资回报也更加保守。",
            triggerWeeks: [28],
            triggerChance: 0.50,
            durationWeeks: 8,
            modifiers: WorldEventModifiers(
                workIncome: 0.95, tradeIncome: 0.90, bankInterest: 1.60,
                investmentReturn: 0.75, debtInterest: 1.55,
                healthChange: 1.10, reputationChange: 0.90
            )
        ),
        WorldEvent(
            id: "regional-public-health-crisis",
            title: "区域公共卫生危机",
            message: "公共卫生危机让客流和工作机会锐减，身体损耗加重，社区关系也更难维持。",
            triggerWeeks: [36],
            triggerChance: 0.40,
            durationWeeks: 6,
            modifiers: WorldEventModifiers(
                workIncome: 0.72, tradeIncome: 0.82, bankInterest: 0.95,
                investmentReturn: 0.70, debtInterest: 1.08,
                healthChange: 1.50, reputationChange: 0.75
            )
        ),
        WorldEvent(
            id: "holiday-economy-surge",
            title: "节日经济旺季",
            message: "节庆活动带来大量客流，临工、倒卖和投资全面升温，但忙碌也让健康消耗加快。",
            triggerWeeks: [44],
            triggerChance: 0.70,
            durationWeeks: 5,
            modifiers: WorldEventModifiers(
                workIncome: 1.25, tradeIncome: 1.30, bankInterest: 1.08,
                investmentReturn: 1.15, debtInterest: 1.05,
                healthChange: 1.10, reputationChange: 1.25
            )
        )
    ]

    static func event(_ id: String) -> WorldEvent? {
        events.first { $0.id == id }
    }
}
