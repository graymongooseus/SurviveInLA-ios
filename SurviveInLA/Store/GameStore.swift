import Foundation
import Observation

struct UserNotice: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
@Observable
final class GameStore {
    private var engine: GameEngine
    private let repository: ProfileRepository
    @ObservationIgnored private var pendingTravelNoticeTask: Task<Void, Never>?
    @ObservationIgnored private let purchaseHistoryKey = "iap.processedTransactionIDs.v1"

    let profileID: ProfileID?
    var onSave: ((GameSnapshot) -> Void)?

    var session: GameSession
    var selectedDestinationID: District.ID
    var selectedAction: WeeklyAction = .trading
    var isMarketExpanded = false
    var isIntroductionPresented = false
    var tradeContext: TradeContext?
    var notice: UserNotice?
    var purchasedAdventure: AdventureProduct?
    var journeyRecords: [JourneyRecord] = []
    var leaderboardError: String?

    var treatmentCostPerPoint: Int { engine.balance.treatmentCostPerPoint }
    var maximumCapacity: Int { engine.balance.maximumCapacity }
    var capacityUpgradeCost: Int { engine.capacityUpgradeCost(for: session) }
    var activeWorldEvent: WorldEvent? { engine.activeWorldEvent(in: session) }
    var activeWorldEventRemainingWeeks: Int {
        guard activeWorldEvent != nil, let active = session.activeWorldEvent else { return 0 }
        return max(0, active.endingWeek - session.day + 1)
    }

    init(
        seed: UInt64 = UInt64(Date.now.timeIntervalSince1970),
        profileID: ProfileID? = nil,
        snapshot: GameSnapshot? = nil,
        repository: ProfileRepository = ProfileRepository()
    ) {
        self.repository = repository
        self.profileID = profileID
        let initialEngine: GameEngine
        let initialSession: GameSession
        if let snapshot {
            initialEngine = GameEngine(randomCheckpoint: snapshot.randomCheckpoint)
            var restoredSession = snapshot.session
            if restoredSession.totalDays == 40 {
                restoredSession.totalDays = 52
                restoredSession.actionThisWeek = nil
            }
            initialSession = restoredSession
        } else {
            var newEngine = GameEngine(seed: seed)
            initialSession = newEngine.makeNewSession()
            initialEngine = newEngine
        }
        engine = initialEngine
        session = initialSession
        selectedDestinationID = initialSession.currentDistrictID
        if session.day == session.totalDays, !session.isFinished {
            engine.endJourney(session: &session)
        }
        isIntroductionPresented = snapshot == nil
        DebugLog.record("profile.open", debugContext)
    }

    var currentDistrict: District {
        GameContent.district(session.currentDistrictID)
    }

    var selectedDestination: District {
        GameContent.district(selectedDestinationID)
    }

    var currentJob: JobOpportunity {
        GameContent.job(in: session.currentDistrictID)
    }

    var currentInvestment: InvestmentOpportunity {
        GameContent.investment(in: session.currentDistrictID)
    }

    func select(_ districtID: District.ID) {
        selectedDestinationID = districtID
    }

    func openTrade(for commodityID: Commodity.ID, mode: TradeMode = .buy) {
        let owned = session.inventory[commodityID]?.quantity ?? 0
        tradeContext = TradeContext(
            commodityID: commodityID,
            mode: owned > 0 ? mode : .buy
        )
    }

    func performTrade(commodityID: Commodity.ID, mode: TradeMode, quantity: Int) -> Bool {
        DebugLog.record(
            "trade.begin",
            "\(debugContext) commodity=\(commodityID.rawValue) mode=\(mode.rawValue) quantity=\(quantity)"
        )
        do {
            switch mode {
            case .buy:
                try engine.buy(commodityID, quantity: quantity, in: &session)
            case .sell:
                try engine.sell(commodityID, quantity: quantity, in: &session)
            }
            DebugLog.record("trade.engine_applied", debugContext)
            saveProgress()
            DebugLog.record("trade.success", debugContext)
            return true
        } catch {
            DebugLog.record("trade.failure", "\(debugContext) error=\(error.localizedDescription)")
            notice = UserNotice(title: "交易没有完成", message: error.localizedDescription)
            return false
        }
    }

    func travel() {
        pendingTravelNoticeTask?.cancel()
        DebugLog.record("travel.begin", "\(debugContext) destination=\(selectedDestinationID.rawValue)")
        do {
            try engine.travel(to: selectedDestinationID, session: &session)
            selectedDestinationID = session.currentDistrictID
            isMarketExpanded = session.day == session.totalDays

            if !session.isFinished, let event = session.latestEvent {
                let eventNotice = UserNotice(title: event.title, message: event.message)
                pendingTravelNoticeTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(850))
                    guard !Task.isCancelled else { return }
                    self?.notice = eventNotice
                }
            }
            saveProgress()
            DebugLog.record("travel.success", debugContext)
        } catch {
            DebugLog.record("travel.failure", "\(debugContext) error=\(error.localizedDescription)")
            notice = UserNotice(title: "暂时不能出发", message: error.localizedDescription)
        }
    }

    func work() {
        DebugLog.record("work.begin", debugContext)
        do {
            let event = try engine.work(in: &session)
            selectedDestinationID = session.currentDistrictID
            notice = UserNotice(title: event.title, message: event.message)
            saveProgress()
            DebugLog.record("work.success", debugContext)
        } catch {
            DebugLog.record("work.failure", "\(debugContext) error=\(error.localizedDescription)")
            notice = UserNotice(title: "这周不能打工", message: error.localizedDescription)
        }
    }

    func invest(_ amount: Int) {
        DebugLog.record("investment.begin", "\(debugContext) amount=\(amount)")
        do {
            try engine.invest(amount, in: &session)
            selectedDestinationID = session.currentDistrictID
            showLatestEvent()
            saveProgress()
            DebugLog.record("investment.success", debugContext)
        } catch {
            DebugLog.record("investment.failure", "\(debugContext) error=\(error.localizedDescription)")
            notice = UserNotice(title: "投资没有完成", message: error.localizedDescription)
        }
    }

    func finishStationaryWeek() {
        do {
            try engine.finishStationaryWeek(in: &session)
            selectedDestinationID = session.currentDistrictID
            saveProgress()
            DebugLog.record("stationary_week.finished", debugContext)
        } catch {
            DebugLog.record("stationary_week.failure", "\(debugContext) error=\(error.localizedDescription)")
            notice = UserNotice(title: "还不能进入下一周", message: error.localizedDescription)
        }
    }

    func dismissIntroduction() {
        isIntroductionPresented = false
    }

    @discardableResult
    func applyPurchasedAdventure(_ adventure: AdventureProduct, transactionID: UInt64) -> Bool {
        guard !session.isFinished else { return false }
        var processedIDs = Set(
            UserDefaults.standard.stringArray(forKey: purchaseHistoryKey) ?? []
        )
        let transactionKey = String(transactionID)
        guard !processedIDs.contains(transactionKey) else { return true }

        session.cash += adventure.cashDelta
        let event = GameEvent(
            id: "iap-\(adventure.rawValue)-\(transactionID)",
            kind: adventure.cashDelta >= 0 ? .opportunity : .setback,
            group: .money,
            title: adventure.eventTitle,
            message: "\(adventure.narrative) 本次现金变化：\(adventure.resultLabel)。",
            cashDelta: adventure.cashDelta
        )
        session.latestEvent = event
        session.log.append(
            GameLogEntry(day: min(session.day, session.totalDays), title: event.title, message: event.message, eventID: "iap-\(adventure.rawValue)")
        )
        saveProgress()

        processedIDs.insert(transactionKey)
        UserDefaults.standard.set(Array(processedIDs).sorted(), forKey: purchaseHistoryKey)
        purchasedAdventure = adventure
        DebugLog.record(
            "iap.reward_delivered",
            "\(debugContext) product=\(adventure.rawValue) transaction=\(transactionID) delta=\(adventure.cashDelta)"
        )
        return true
    }

    func dismissPurchasedAdventure() {
        purchasedAdventure = nil
    }

    func finishGame() {
        engine.endJourney(session: &session)
        saveProgress()
    }

    func deposit(_ amount: Int) -> Bool {
        performService(title: "存款失败") {
            try engine.deposit(amount, in: &session)
        }
    }

    func withdraw(_ amount: Int) -> Bool {
        performService(title: "取款失败") {
            try engine.withdraw(amount, in: &session)
        }
    }

    func repayDebt(_ amount: Int) -> Bool {
        performService(title: "还款失败") {
            try engine.repayDebt(amount, in: &session)
        }
    }

    func heal(_ points: Int) -> Bool {
        performService(title: "治疗失败") {
            try engine.heal(points, in: &session)
        }
    }

    func expandCapacity() -> Bool {
        performService(title: "升级失败") {
            try engine.expandCapacity(in: &session)
        }
    }

    func restart() {
        guard saveProgress() else { return }
        pendingTravelNoticeTask?.cancel()
        var newEngine = GameEngine(seed: UInt64(Date.now.timeIntervalSince1970))
        session = newEngine.makeNewSession()
        engine = newEngine
        selectedDestinationID = session.currentDistrictID
        selectedAction = .trading
        isMarketExpanded = false
        isIntroductionPresented = true
        tradeContext = nil
        notice = nil
        purchasedAdventure = nil
        saveProgress()
    }

    @discardableResult
    func saveProgress() -> Bool {
        if session.isFinished {
            pendingTravelNoticeTask?.cancel()
            notice = nil
            tradeContext = nil
        }
        guard let profileID else { return true }
        let snapshot = GameSnapshot(
                profileID: profileID,
                session: session,
                randomCheckpoint: engine.randomCheckpoint
            )
        do {
            try repository.archiveJourney(snapshot)
        } catch {
            notice = UserNotice(title: "成绩尚未保存", message: "请稍后重试。保存成功前不会重开本局。\n\(error.localizedDescription)")
            return false
        }
        onSave?(snapshot)
        return true
    }

    func loadLeaderboard() {
        leaderboardError = nil
        do {
            // Also include completed slots that have not been opened since this update.
            for id in ProfileID.allCases {
                if let snapshot = try repository.load(id) { try repository.archiveJourney(snapshot) }
            }
            if let profileID {
                try repository.archiveJourney(GameSnapshot(
                    profileID: profileID, session: session, randomCheckpoint: engine.randomCheckpoint
                ))
            }
            journeyRecords = try repository.loadJourneyRecords()
        } catch {
            leaderboardError = error.localizedDescription
        }
    }

    private func performService(title: String, action: () throws -> Void) -> Bool {
        do {
            try action()
            saveProgress()
            return true
        } catch {
            notice = UserNotice(title: title, message: error.localizedDescription)
            return false
        }
    }

    private func showLatestEvent() {
        guard let event = session.latestEvent else { return }
        notice = UserNotice(title: event.title, message: event.message)
    }

    private var debugContext: String {
        let profile = profileID.map { String($0.rawValue) } ?? "preview"
        let action = session.actionThisWeek?.rawValue ?? "none"
        return "profile=\(profile) week=\(session.day) district=\(session.currentDistrictID.rawValue) cash=\(session.cash) debt=\(session.debt) action=\(action)"
    }
}
