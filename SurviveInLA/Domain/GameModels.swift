import Foundation
import CoreLocation

struct GameBalance: Sendable {
    var totalDays = 52
    var startingCash = 2_000
    var startingDebt = 5_000
    var startingHealth = 100
    var startingReputation = 100
    var startingCapacity = 100
    var debtInterestRate = 0.02
    var bankInterestRate = 0.002
    var treatmentCostPerPoint = 25
    var capacityUpgradeAmount = 10
    var maximumCapacity = 140
    var baseCapacityUpgradeCost = 2_500
}

enum WeeklyAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case trading = "倒卖"
    case work = "打工"
    case investment = "投资"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .trading: "arrow.left.arrow.right"
        case .work: "hammer.fill"
        case .investment: "chart.line.uptrend.xyaxis"
        }
    }
}

struct JobOpportunity: Identifiable, Hashable, Sendable {
    var id: District.ID { districtID }
    let districtID: District.ID
    let title: String
    let detail: String
    let wage: Int
    let healthCost: Int
}

enum InvestmentRisk: String, Hashable, Sendable {
    case low = "低风险"
    case medium = "中风险"
    case high = "高风险"

    var returnRange: String {
        switch self {
        case .low: "−8% ～ +8%"
        case .medium: "−20% ～ +25%"
        case .high: "−45% ～ +60%"
        }
    }
}

struct InvestmentOpportunity: Identifiable, Hashable, Sendable {
    var id: District.ID { districtID }
    let districtID: District.ID
    let title: String
    let detail: String
    let risk: InvestmentRisk
    let minimumInvestment: Int
}

struct Commodity: Identifiable, Hashable, Sendable {
    enum ID: String, CaseIterable, Codable, Sendable {
        case sneakers
        case camera
        case vinyl
        case concertTickets
        case vintageJacket
        case importedSnacks
        case gameConsole
        case beautySet
        case usedTesla
        case smuggledVape
    }

    let id: ID
    let name: String
    let symbol: String
    let basePrice: Int
    let minimumPrice: Int
    let maximumPrice: Int
}

struct District: Identifiable, Hashable, Sendable {
    enum ID: String, CaseIterable, Codable, Sendable {
        case koreatown
        case pasadenaRoseBowl
        case figueroaCorridor
        case hollywood
        case silverLake
        case inglewood
        case culverCity
        case westwood
        case venice
        case santaMonica
        case dingPangZiPlaza
        case sanGabriel
        case rowlandHeights
        case irvine
        case littleSaigon

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)

            switch rawValue {
            case "fashionDistrict":
                self = .pasadenaRoseBowl
            case "downtown", "artsDistrict", "boyleHeights", "unionStation":
                self = .figueroaCorridor
            case "centuryCity":
                self = .westwood
            default:
                guard let id = Self(rawValue: rawValue) else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Unknown district ID: \(rawValue)"
                    )
                }
                self = id
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }

    let id: ID
    let name: String
    let englishName: String
    let coordinate: CLLocationCoordinate2D
    let transitHint: String
    let marketRole: String
    let marketBiases: [Commodity.ID: Double]

    var fullName: String {
        "\(name) · \(englishName)"
    }

    func priceBias(for commodityID: Commodity.ID) -> Double {
        marketBiases[commodityID] ?? 1
    }

    static func == (lhs: District, rhs: District) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct MarketQuote: Identifiable, Hashable, Codable, Sendable {
    var id: Commodity.ID { commodityID }
    let commodityID: Commodity.ID
    let price: Int
    let previousPrice: Int?

    var change: Double? {
        guard let previousPrice, previousPrice > 0 else { return nil }
        return Double(price - previousPrice) / Double(previousPrice)
    }
}

struct InventoryPosition: Identifiable, Hashable, Codable, Sendable {
    var id: Commodity.ID { commodityID }
    let commodityID: Commodity.ID
    var quantity: Int
    var averageCost: Int
}

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
        districtIDs: [District.ID]? = nil
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
    }

    func canOccur(in districtID: District.ID) -> Bool {
        districtIDs?.contains(districtID) ?? true
    }
}

struct GameLogEntry: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let day: Int
    let title: String
    let message: String

    init(id: UUID = UUID(), day: Int, title: String, message: String) {
        self.id = id
        self.day = day
        self.title = title
        self.message = message
    }
}

struct GameSession: Codable, Sendable {
    var day: Int
    var totalDays: Int
    var cash: Int
    var debt: Int
    var bank: Int
    var health: Int
    var reputation: Int
    var capacity: Int
    var currentDistrictID: District.ID
    var market: [MarketQuote]
    var inventory: [Commodity.ID: InventoryPosition]
    var latestEvent: GameEvent?
    var log: [GameLogEntry]
    var actionThisWeek: WeeklyAction?

    var usedCapacity: Int {
        inventory.values.reduce(0) { $0 + $1.quantity }
    }

    var availableCapacity: Int {
        max(0, capacity - usedCapacity)
    }

    var netWorth: Int {
        cash + bank - debt
    }

    var isFinished: Bool {
        day > totalDays || health <= 0
    }
}

enum TradeMode: String, CaseIterable, Identifiable, Sendable {
    case buy = "买入"
    case sell = "卖出"

    var id: Self { self }
}

struct TradeContext: Identifiable, Sendable {
    let commodityID: Commodity.ID
    var mode: TradeMode

    var id: Commodity.ID { commodityID }
}

enum GameRuleError: LocalizedError, Equatable {
    case invalidQuantity
    case quoteUnavailable
    case insufficientCash
    case insufficientInventory
    case insufficientCapacity
    case insufficientBankBalance
    case healthAlreadyFull
    case capacityAtMaximum
    case alreadyThere
    case weeklyActionAlreadyChosen
    case investmentTooSmall
    case gameFinished

    var errorDescription: String? {
        switch self {
        case .invalidQuantity: "数量必须大于零。"
        case .quoteUnavailable: "这个商品本周没有报价。"
        case .insufficientCash: "现金不足。"
        case .insufficientInventory: "库存不足。"
        case .insufficientCapacity: "背包容量不足。"
        case .insufficientBankBalance: "银行存款不足。"
        case .healthAlreadyFull: "当前健康已经满了。"
        case .capacityAtMaximum: "当前仓储容量已经达到上限。"
        case .alreadyThere: "你已经在这里了。"
        case .weeklyActionAlreadyChosen: "本周已经选择了另一种赚钱方式。"
        case .investmentTooSmall: "投资金额没有达到最低门槛。"
        case .gameFinished: "本轮游戏已经结束。"
        }
    }
}
