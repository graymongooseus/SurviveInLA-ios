import Foundation

enum AdventureProduct: String, CaseIterable, Identifiable, Sendable {
    case starterCash = "com.graymongooseus.SurviveInLA.currency.starter"
    case survivorCash = "com.graymongooseus.SurviveInLA.currency.survivor"
    case builderCash = "com.graymongooseus.SurviveInLA.currency.builder"
    case dreamCash = "com.graymongooseus.SurviveInLA.currency.dream"

    var id: String { rawValue }

    var sequenceLabel: String {
        let index = Self.allCases.firstIndex(of: self) ?? 0
        return String(format: "%02d", index + 1)
    }

    var title: String {
        switch self {
        case .starterCash: "起步现金包"
        case .survivorCash: "生存现金包"
        case .builderCash: "发展现金包"
        case .dreamCash: "美国梦现金包"
        }
    }

    var storeSummary: String {
        "固定获得 \(cashDelta.usdText) 游戏现金，不含随机结果"
    }

    var eventTitle: String {
        "\(title)已到账"
    }

    var narrative: String {
        "充值成功，\(cashDelta.usdText) 游戏现金已经加入当前存档。"
    }

    var cashDelta: Int {
        switch self {
        case .starterCash: 3_000
        case .survivorCash: 6_000
        case .builderCash: 18_000
        case .dreamCash: 36_000
        }
    }

    var fallbackPrice: String {
        switch self {
        case .starterCash: "$1.99"
        case .survivorCash: "$2.99"
        case .builderCash: "$5.99"
        case .dreamCash: "$9.99"
        }
    }

    var symbolName: String {
        switch self {
        case .starterCash: "banknote"
        case .survivorCash: "banknote.fill"
        case .builderCash: "dollarsign.circle.fill"
        case .dreamCash: "building.columns.fill"
        }
    }

    var resultLabel: String {
        "+\(cashDelta.usdText)"
    }

    var accessibilitySummary: String {
        "\(title)，固定充值\(cashDelta.usdText)游戏现金"
    }
}
