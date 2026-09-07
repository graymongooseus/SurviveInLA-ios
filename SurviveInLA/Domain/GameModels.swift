import Foundation
import CoreLocation

struct GameBalance: Sendable {
    var totalDays = 52
    var startingCash = 1_000
    var startingDebt = 5_000
    var startingHealth = 100
    var startingLuck = 50
    var startingCapacity = 100
    var debtInterestRate = 0.02
    var bankInterestRate = 0.002
    var treatmentCostPerPoint = 25
    var clinicClosureChance = 0.70
    var clinicWeeklyHealthLimit = 30
    var massageHealthRecovery = 10
    var massageCostPerPoint = 60
    var capacityUpgradeAmount = 10
    var maximumCapacity = 140
    var baseCapacityUpgradeCost = 2_500
    var driversLicenseCost = 500
    var weeklyHousingRent = 110
    var basementMoveInFee = 110
    var weeklyCarRent = 180
    var carPurchasePrice = 3_500
    var carResaleValue = 2_000
    var drivingOperatingCost = 35
    var housingHealthRecovery = 2
    var vehicleHealthProtection = 2
    var toolsPurchasePrice = 1_200
    var toolsWageMultiplier = 1.15
    var toolsHealthProtection = 1
    var propertyInvestmentPrice = 15_000
    var propertyWeeklyIncome = 250
    var propertyHealthRecovery = 5
    var restAtHomeHealthRecovery = 4
    var unlicensedDrivingArrestChance = 0.24
    var licensedDrivingLossChance = 0.08
    var drivingArrestWeeks = 2
    var licenseReplacementWeeks = 4
}

enum WeeklyAction: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
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
    let id: String
    let districtID: District.ID
    let title: String
    let detail: String
    let wage: Int
    let healthCost: Int
    let requiresHousing: Bool
    let requiresVehicle: Bool

    init(
        id: String,
        districtID: District.ID,
        title: String,
        detail: String,
        wage: Int,
        healthCost: Int,
        requiresHousing: Bool = true,
        requiresVehicle: Bool = false
    ) {
        self.id = id
        self.districtID = districtID
        self.title = title
        self.detail = detail
        self.wage = wage
        self.healthCost = healthCost
        self.requiresHousing = requiresHousing
        self.requiresVehicle = requiresVehicle
    }
}

enum HousingPaymentMethod: String, Codable, Sendable {
    case weeklyWithSavingsProof
    case prepaidInstallments

    var name: String {
        switch self {
        case .weeklyWithSavingsProof: "存款证明 · 每周付"
        case .prepaidInstallments: "无存款证明 · 周期预付"
        }
    }
}

enum HousingTier: String, CaseIterable, Identifiable, Codable, Sendable {
    case basement
    case cityApartment
    case hillsideHouse

    var id: Self { self }

    var name: String {
        switch self {
        case .basement: "半地下室"
        case .cityApartment: "合租小公寓"
        case .hillsideHouse: "山边大豪斯中的一间"
        }
    }

    var symbol: String {
        switch self {
        case .basement: "stairs"
        case .cityApartment: "building.fill"
        case .hillsideHouse: "house.lodge.fill"
        }
    }

    var weeklyRent: Int {
        switch self {
        case .basement: 110
        case .cityApartment: 180
        case .hillsideHouse: 250
        }
    }

    var monthlyRent: Int { weeklyRent * 4 }

    var savingsProofMonths: Int {
        switch self {
        case .basement: 0
        case .cityApartment: 2
        case .hillsideHouse: 4
        }
    }

    var savingsProofAmount: Int { monthlyRent * savingsProofMonths }

    var prepaidWeeks: Int {
        switch self {
        case .basement: 1
        case .cityApartment: 3
        case .hillsideHouse: 6
        }
    }

    var weeklyHealthRecovery: Int {
        switch self {
        case .basement: 2
        case .cityApartment: 4
        case .hillsideHouse: 6
        }
    }
}

struct LifeEquipment: Hashable, Codable, Sendable {
    var hasDriversLicense = false
    var rentsHousing = false
    var rentsCar = false
    var ownsCar = false
    var housingPaidThroughWeek: Int?
    var carRentPaidThroughWeek: Int?
    var completedHousingMilestone: Bool?
    var completedVehicleMilestone: Bool?
    var ownsTools: Bool?
    var ownsProperty: Bool?
    var housingTier: HousingTier?
    var driversLicenseAttempts: Int?
    var driversLicenseRecoveryUntilWeek: Int?
    var housingPaymentMethod: HousingPaymentMethod?
    var housingNextPaymentWeek: Int?

    var hasVehicle: Bool { rentsCar || ownsCar }
    var hasHousingMilestone: Bool { completedHousingMilestone == true || rentsHousing || ownsProperty == true }
    var hasVehicleMilestone: Bool { completedVehicleMilestone == true || hasVehicle }
    var hasTools: Bool { ownsTools == true }
    var hasProperty: Bool { ownsProperty == true }
    var activeHousingTier: HousingTier? {
        guard rentsHousing else { return nil }
        return housingTier ?? .basement
    }
    var hasHousing: Bool { rentsHousing || hasProperty }
    var activeHousingPaymentMethod: HousingPaymentMethod {
        housingPaymentMethod ?? .weeklyWithSavingsProof
    }
    var licenseAttemptCount: Int { driversLicenseAttempts ?? 0 }
    func hasActiveDriversLicense(in week: Int) -> Bool {
        hasDriversLicense && (driversLicenseRecoveryUntilWeek.map { week >= $0 } ?? true)
    }
    var completedMilestoneCount: Int {
        [hasHousingMilestone, hasDriversLicense, hasVehicleMilestone, hasTools, hasProperty]
            .filter { $0 }.count
    }
    var hasHope: Bool {
        hasHousingMilestone && hasDriversLicense && hasVehicleMilestone && hasTools && hasProperty
    }
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
        case inglewood
        case culverCity
        case westwood
        case venice
        case santaMonica
        case dingPangZiPlaza
        case sanGabriel
        case rowlandHeights
        case cityOfIndustry
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
            case "silverLake":
                self = .cityOfIndustry
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
    let characterSummary: String
    let gameplayHooks: [String]
    let jobHooks: [String]

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

struct GameLogEntry: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let day: Int
    let title: String
    let message: String
    let eventID: String?

    init(id: UUID = UUID(), day: Int, title: String, message: String, eventID: String? = nil) {
        self.id = id
        self.day = day
        self.title = title
        self.message = message
        self.eventID = eventID
    }
}

enum StatusMetric: String, CaseIterable, Identifiable, Codable, Sendable {
    case cash
    case debt
    case health
    case luck

    var id: Self { self }
}

struct StatusHistoryEntry: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let day: Int
    let metric: StatusMetric
    let reason: String
    let delta: Int
    let valueAfter: Int

    init(
        id: UUID = UUID(),
        day: Int,
        metric: StatusMetric,
        reason: String,
        delta: Int,
        valueAfter: Int
    ) {
        self.id = id
        self.day = day
        self.metric = metric
        self.reason = reason
        self.delta = delta
        self.valueAfter = valueAfter
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
    var luck: Int?
    var capacity: Int
    var currentDistrictID: District.ID
    var market: [MarketQuote]
    var inventory: [Commodity.ID: InventoryPosition]
    var latestEvent: GameEvent?
    var log: [GameLogEntry]
    // Retained for old saves and as the most recently completed action.
    var actionThisWeek: WeeklyAction?
    // Optional so saves from the one-action-per-week rules remain readable.
    var completedActionsThisWeek: Set<WeeklyAction>? = nil
    var consecutivePimpingWeeks: Int?
    // Retains the old save key for the newest event. Earlier concurrent events
    // occupy a separate array; activeWorldEvents is the only runtime write API.
    var activeWorldEvent: ActiveWorldEvent?
    var additionalWorldEvents: [ActiveWorldEvent]? = nil
    var lastWorldEventDrawWeek: Int? = nil
    var unreadWorldEvents: [ActiveWorldEvent]? = nil
    var selectedLifeChoiceOptions: [String: String]? = nil
    var pendingInvestmentInvitation: InvestmentEventDefinition? = nil
    var resolvedInvestmentEventIDs: Set<String>? = nil
    var lastInvestmentEventCheckTurn: Int? = nil
    var pendingInvestments: [ScheduledInvestment]? = nil
    var unreadInvestmentNotices: [GameEvent]? = nil
    var latestWorldEventID: String?
    var latestWorldEventWeek: Int?
    // Optional fields keep pre-ending saves readable without inventing past statistics.
    var journey: JourneyStatistics?
    var settlement: JourneySettlement?
    var equipment: LifeEquipment?
    var pendingLifeChoiceID: String?
    var resolvedLifeChoiceIDs: Set<String>?
    var rootedEnding: Bool?
    var dreamActionWeek: Int?
    var latestHousingEvictionWeek: Int?
    var latestHousingEvictionAmount: Int?
    // Optional so saves created before status tracking remain decodable.
    var statusHistory: [StatusHistoryEntry]? = nil
    // Optional for old saves. A separate seed keeps service schedules stable without
    // consuming the market/event RNG when the services screen is opened.
    var cityServiceSeed: UInt64? = nil
    var clinicTreatmentWeek: Int? = nil
    var clinicTreatmentPoints: Int? = nil
    var massageVisitWeek: Int? = nil

    var activeWorldEvents: [ActiveWorldEvent] {
        get { (additionalWorldEvents ?? []) + (activeWorldEvent.map { [$0] } ?? []) }
        set {
            activeWorldEvent = newValue.last
            additionalWorldEvents = Array(newValue.dropLast())
        }
    }

    var usedCapacity: Int {
        inventory.values.reduce(0) { $0 + $1.quantity }
    }

    var availableCapacity: Int {
        max(0, capacity - usedCapacity)
    }

    var netWorth: Int {
        cash + bank - debt
    }

    var currentLuck: Int {
        get { min(100, max(0, luck ?? 50)) }
        set { luck = min(100, max(0, newValue)) }
    }

    var currentEquipment: LifeEquipment {
        equipment ?? LifeEquipment()
    }

    var hasHope: Bool { currentEquipment.hasHope }
    var hasActiveDriversLicense: Bool { currentEquipment.hasActiveDriversLicense(in: day) }
    var didPerformDreamActionThisWeek: Bool { dreamActionWeek == day }

    var completedWeeklyActions: Set<WeeklyAction> {
        var actions = completedActionsThisWeek ?? []
        if let actionThisWeek { actions.insert(actionThisWeek) }
        return actions
    }

    var hasCompletedAnyWeeklyAction: Bool { !completedWeeklyActions.isEmpty }

    func didCompleteWeeklyAction(_ action: WeeklyAction) -> Bool {
        completedWeeklyActions.contains(action)
    }

    mutating func recordWeeklyAction(_ action: WeeklyAction) {
        var actions = completedWeeklyActions
        actions.insert(action)
        completedActionsThisWeek = actions
        actionThisWeek = action
    }

    mutating func resetWeeklyActions() {
        completedActionsThisWeek = []
        actionThisWeek = nil
    }

    var isFinished: Bool {
        day > totalDays || health <= 0
    }

    func statusValue(for metric: StatusMetric) -> Int {
        switch metric {
        case .cash: cash
        case .debt: debt
        case .health: health
        case .luck: currentLuck
        }
    }

    func history(for metric: StatusMetric) -> [StatusHistoryEntry] {
        (statusHistory ?? []).filter { $0.metric == metric }
    }

    mutating func startStatusHistory(reason: String) {
        guard statusHistory == nil else { return }
        let week = min(day, totalDays)
        statusHistory = StatusMetric.allCases.map { metric in
            StatusHistoryEntry(
                day: week,
                metric: metric,
                reason: reason,
                delta: 0,
                valueAfter: statusValue(for: metric)
            )
        }
    }

    mutating func recordStatusChange(
        _ metric: StatusMetric,
        from oldValue: Int,
        reason: String
    ) {
        startStatusHistory(reason: day <= 1 ? "初始状态" : "从当前存档开始记录")
        let newValue = statusValue(for: metric)
        guard newValue != oldValue else { return }
        statusHistory?.insert(
            StatusHistoryEntry(
                day: min(day, totalDays),
                metric: metric,
                reason: reason,
                delta: newValue - oldValue,
                valueAfter: newValue
            ),
            at: 0
        )
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
    case clinicClosed(String)
    case clinicWeeklyLimitReached
    case massageAlreadyVisited
    case capacityAtMaximum
    case alreadyThere
    case weeklyActionAlreadyChosen
    case weeklyActionNotCompleted
    case investmentTooSmall
    case jobUnavailable
    case driversLicenseRequired
    case vehicleRequired
    case housingRequired
    case homeRequiredToRest
    case insufficientSavingsProof
    case incompatibleVehicle
    case lifeChoicePending
    case previousMilestoneRequired
    case dreamActionAlreadyTaken
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
        case .clinicClosed(let holiday): "今天是\(holiday)节日关门一周"
        case .clinicWeeklyLimitReached: "本周诊所治疗额度已用完，请下周再来。"
        case .massageAlreadyVisited: "本周已经去过波霸按摩院，请下周再来。"
        case .capacityAtMaximum: "当前仓储容量已经达到上限。"
        case .alreadyThere: "你已经在这里了。"
        case .weeklyActionAlreadyChosen: "本周已经完成过这项行动，不能重复执行。"
        case .weeklyActionNotCompleted: "请先完成至少一项本周行动，或者选择在家躺平。"
        case .investmentTooSmall: "投资金额没有达到最低门槛。"
        case .jobUnavailable: "这个工种不属于你当前所在的地点。"
        case .driversLicenseRequired: "需要先取得驾照。"
        case .vehicleRequired: "这份工作需要自有车或租车。"
        case .housingRequired: "这份工作要求有稳定住处。请先租房或拥有物业。"
        case .homeRequiredToRest: "需要先有住处，才能选择在家躺平休息。"
        case .insufficientSavingsProof: "银行存款不足，无法提供房东要求的存款证明。"
        case .incompatibleVehicle: "租车和自有车不能同时使用。"
        case .lifeChoicePending: "请先处理眼前的人生选择。"
        case .previousMilestoneRequired: "请先完成路线中的上一项投入。"
        case .dreamActionAlreadyTaken: "本周已经完成一项美国生存路线操作，请下周再来。"
        case .gameFinished: "本轮游戏已经结束。"
        }
    }
}
