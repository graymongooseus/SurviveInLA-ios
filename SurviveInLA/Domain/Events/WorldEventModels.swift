import Foundation

struct WorldEventModifiers: Hashable, Codable, Sendable {
    let workIncome: Double
    let tradeIncome: Double
    let bankInterest: Double
    let investmentReturn: Double
    let debtInterest: Double
    let healthChange: Double
    let marketPrice: Double
    let investmentReturnCap: Int?

    init(
        workIncome: Double,
        tradeIncome: Double,
        bankInterest: Double,
        investmentReturn: Double,
        debtInterest: Double,
        healthChange: Double,
        marketPrice: Double = 1,
        investmentReturnCap: Int? = nil
    ) {
        self.workIncome = workIncome
        self.tradeIncome = tradeIncome
        self.bankInterest = bankInterest
        self.investmentReturn = investmentReturn
        self.debtInterest = debtInterest
        self.healthChange = healthChange
        self.marketPrice = marketPrice
        self.investmentReturnCap = investmentReturnCap
    }

    static let neutral = WorldEventModifiers(
        workIncome: 1,
        tradeIncome: 1,
        bankInterest: 1,
        investmentReturn: 1,
        debtInterest: 1,
        healthChange: 1
    )
}

struct WorldEvent: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let message: String
    let imageName: String
    let selection: EventSelectionWeight
    let condition: EventCondition?
    let durationWeeks: Int
    var modifiers: WorldEventModifiers

    var effectSummary: String {
        var effects = [
            effect("打工", modifiers.workIncome),
            effect("倒卖", modifiers.tradeIncome),
            effect("存款利息", modifiers.bankInterest),
            effect("投资", modifiers.investmentReturn),
            effect("债务利息", modifiers.debtInterest),
            effect("健康变动", modifiers.healthChange)
        ]
        if modifiers.marketPrice != 1 {
            effects.append(effect("消费品报价", modifiers.marketPrice))
        }
        if let cap = modifiers.investmentReturnCap {
            effects.append("投资回报上限 \(cap)%")
        }
        return effects.joined(separator: " · ")
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
    // Freeze active effects across later content balance changes.
    var modifiers: WorldEventModifiers? = nil

    func isActive(in week: Int) -> Bool {
        (startedWeek ... endingWeek).contains(week)
    }
}

extension WorldEventModifiers {
    static func combined(_ values: [WorldEventModifiers]) -> WorldEventModifiers {
        values.reduce(.neutral) { total, next in
            WorldEventModifiers(
                workIncome: total.workIncome * next.workIncome,
                tradeIncome: total.tradeIncome * next.tradeIncome,
                bankInterest: total.bankInterest * next.bankInterest,
                investmentReturn: total.investmentReturn * next.investmentReturn,
                debtInterest: total.debtInterest * next.debtInterest,
                healthChange: total.healthChange * next.healthChange,
                marketPrice: total.marketPrice * next.marketPrice,
                investmentReturnCap: [total.investmentReturnCap, next.investmentReturnCap].compactMap { $0 }.min()
            )
        }
    }
}
