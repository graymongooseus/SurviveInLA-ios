import Foundation
import Observation

struct UserNotice: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let message: String
    var event: GameEvent? = nil
    var isHousingEviction = false

    var healthEvent: GameEvent? {
        guard let event, event.healthEventImageName != nil else { return nil }
        return event
    }
}

extension UserNotice {
    init(event: GameEvent) {
        self.init(
            title: event.title,
            message: "基础效果\n\(event.baseEffectSummary)\n\n\(event.message)",
            event: event
        )
    }
}

struct WorldEventNotice: Identifiable, Sendable {
    let id = UUID()
    let eventID: String
    let triggeredWeek: Int
    let endingWeek: Int
    let localNotice: UserNotice?
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
    var onCompletedRun: ((GameSnapshot) throws -> Void)?
    private var automaticallySubmitCompletion: Bool
    private var rankingCompletedAt: Date?

    var session: GameSession
    var selectedDestinationID: District.ID
    var selectedAction: WeeklyAction = .trading
    var isMarketExpanded = false
    var isIntroductionPresented = false
    var tradeContext: TradeContext?
    var notice: UserNotice?
    var queuedNotice: UserNotice?
    var worldEventNotice: WorldEventNotice?
    var purchasedAdventure: AdventureProduct?
    var journeyRecords: [JourneyRecord] = []
    var leaderboardError: String?
    var investmentInvitationError: String?

    var investmentNotice: GameEvent? { session.unreadInvestmentNotices?.first }

    var canPresentInvestmentEvent: Bool {
        !isIntroductionPresented && pendingTravelNoticeTask == nil && worldEventNotice == nil && notice == nil
            && purchasedAdventure == nil && pendingLifeChoice == nil
    }

    func respondToInvestmentInvitation(amount: Int?) {
        do {
            try engine.respondToInvestmentInvitation(amount: amount, in: &session)
            investmentInvitationError = nil
            saveProgress()
        } catch {
            investmentInvitationError = error.localizedDescription
        }
    }

    func dismissInvestmentNotice(_ id: String) {
        guard session.unreadInvestmentNotices?.first?.id == id else { return }
        session.unreadInvestmentNotices?.removeFirst()
        saveProgress()
    }

    var treatmentCostPerPoint: Int { engine.balance.treatmentCostPerPoint }
    var clinicClosureHoliday: USFederalHoliday? { engine.clinicClosureHoliday(in: session) }
    var clinicWeeklyHealthLimit: Int { engine.balance.clinicWeeklyHealthLimit }
    var clinicRemainingTreatmentPoints: Int { engine.clinicRemainingTreatmentPoints(in: session) }
    var massageHealthRecovery: Int { engine.balance.massageHealthRecovery }
    var massageCostPerPoint: Int { engine.balance.massageCostPerPoint }
    var massageCost: Int { engine.massageCost }
    var didVisitMassageThisWeek: Bool { session.massageVisitWeek == session.day }
    var maximumCapacity: Int { engine.balance.maximumCapacity }
    var capacityUpgradeCost: Int { engine.capacityUpgradeCost(for: session) }
    var bankInterestRate: Double { engine.balance.bankInterestRate }
    var debtInterestRate: Double { engine.balance.debtInterestRate }
    var driversLicenseCost: Int { engine.balance.driversLicenseCost }
    var weeklyHousingRent: Int { engine.balance.weeklyHousingRent }
    var basementMoveInFee: Int { engine.balance.basementMoveInFee }
    var weeklyCarRent: Int { engine.balance.weeklyCarRent }
    var carPurchasePrice: Int { engine.balance.carPurchasePrice }
    var carResaleValue: Int { engine.balance.carResaleValue }
    var drivingOperatingCost: Int { engine.balance.drivingOperatingCost }
    var vehicleHealthProtection: Int { engine.balance.vehicleHealthProtection }
    var toolsPurchasePrice: Int { engine.balance.toolsPurchasePrice }
    var toolsWageMultiplier: Double { engine.balance.toolsWageMultiplier }
    var toolsHealthProtection: Int { engine.balance.toolsHealthProtection }
    var propertyInvestmentPrice: Int { engine.balance.propertyInvestmentPrice }
    var propertyWeeklyIncome: Int { engine.balance.propertyWeeklyIncome }
    var propertyHealthRecovery: Int { engine.balance.propertyHealthRecovery }
    var restAtHomeHealthRecovery: Int { engine.balance.restAtHomeHealthRecovery }
    var housingTiers: [HousingTier] { HousingTier.allCases }
    var canPerformDreamAction: Bool { !session.didPerformDreamActionThisWeek }
    var driversLicensePassChancePercent: Int {
        Int((engine.driversLicensePassChance(for: session.currentLuck) * 100).rounded())
    }
    var activeWorldEvents: [WorldEvent] { engine.activeWorldEvents(in: session) }
    var combinedWorldModifiers: WorldEventModifiers { engine.worldModifiers(for: session) }
    func worldEventRemainingWeeks(_ eventID: String) -> Int {
        guard let active = session.activeWorldEvents.first(where: { $0.eventID == eventID && $0.isActive(in: session.day) }) else { return 0 }
        return active.endingWeek - session.day + 1
    }

    init(
        seed: UInt64 = UInt64(Date.now.timeIntervalSince1970),
        profileID: ProfileID? = nil,
        snapshot: GameSnapshot? = nil,
        repository: ProfileRepository = ProfileRepository()
    ) {
        self.repository = repository
        self.profileID = profileID
        automaticallySubmitCompletion = snapshot?.session.isFinished != true
        rankingCompletedAt = snapshot?.session.isFinished == true ? snapshot?.updatedAt : nil
        let initialEngine: GameEngine
        let initialSession: GameSession
        if let snapshot {
            initialEngine = GameEngine(randomCheckpoint: snapshot.randomCheckpoint)
            var restoredSession = snapshot.session
            if restoredSession.totalDays == 40 {
                restoredSession.totalDays = 52
                restoredSession.resetWeeklyActions()
            }
            if restoredSession.luck == nil { restoredSession.luck = 50 }
            if restoredSession.equipment == nil { restoredSession.equipment = LifeEquipment() }
            if restoredSession.resolvedLifeChoiceIDs == nil { restoredSession.resolvedLifeChoiceIDs = [] }
            if restoredSession.cityServiceSeed == nil { restoredSession.cityServiceSeed = snapshot.randomCheckpoint }
            restoredSession.startStatusHistory(reason: "从当前存档开始记录")
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
        if let pending = session.unreadWorldEvents?.first {
            worldEventNotice = WorldEventNotice(eventID: pending.eventID, triggeredWeek: pending.startedWeek, endingWeek: pending.endingWeek, localNotice: nil)
        }
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

    var currentJobs: [JobOpportunity] {
        GameContent.jobs(in: session.currentDistrictID)
    }

    var pendingLifeChoice: LifeChoiceEvent? {
        session.pendingLifeChoiceID.flatMap(GameContent.lifeChoice)
    }

    var lifeChoiceResult: GameEvent? {
        guard let event = notice?.event, event.id.hasPrefix("life-choice-") else { return nil }
        return event
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
        pendingTravelNoticeTask = nil
        DebugLog.record("travel.begin", "\(debugContext) destination=\(selectedDestinationID.rawValue)")
        do {
            let endingWeek = session.day
            let previousWorldEventID = session.latestWorldEventID
            let previousWorldEventWeek = session.latestWorldEventWeek
            try engine.travel(to: selectedDestinationID, session: &session)
            selectedDestinationID = session.currentDistrictID
            isMarketExpanded = session.day == session.totalDays

            let worldNotice = worldEventNoticeIfChanged(
                previousID: previousWorldEventID,
                previousWeek: previousWorldEventWeek
            )
            let localNotice = session.latestEvent.map {
                UserNotice(event: $0)
            }
            let rentNotice = housingEvictionNotice(afterEnding: endingWeek)
            if var worldNotice {
                worldNotice = WorldEventNotice(
                    eventID: worldNotice.eventID,
                    triggeredWeek: worldNotice.triggeredWeek,
                    endingWeek: worldNotice.endingWeek,
                    localNotice: rentNotice ?? localNotice
                )
                worldEventNotice = worldNotice
                if rentNotice != nil { queuedNotice = localNotice }
            } else if let rentNotice {
                notice = rentNotice
                queuedNotice = localNotice
            } else if let localNotice, !session.isFinished {
                pendingTravelNoticeTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(850))
                    guard !Task.isCancelled else { return }
                    self?.pendingTravelNoticeTask = nil
                    self?.notice = localNotice
                }
            }
            let didSave = saveProgress()
            // 终局仍先展示本次健康事件，让玩家看清健康归零的原因。
            if didSave, session.health <= 0, worldNotice == nil,
               rentNotice == nil, localNotice?.healthEvent != nil {
                notice = localNotice
            }
            DebugLog.record("travel.success", debugContext)
        } catch {
            DebugLog.record("travel.failure", "\(debugContext) error=\(error.localizedDescription)")
            notice = UserNotice(title: "暂时不能出发", message: error.localizedDescription)
        }
    }

    func work(_ jobID: String? = nil) {
        DebugLog.record("work.begin", debugContext)
        do {
            let previousWorldEventID = session.latestWorldEventID
            let previousWorldEventWeek = session.latestWorldEventWeek
            let event = try engine.work(jobID ?? currentJob.id, in: &session)
            selectedDestinationID = session.currentDistrictID
            let localNotice = UserNotice(event: event)
            if let worldNotice = worldEventNoticeIfChanged(
                previousID: previousWorldEventID,
                previousWeek: previousWorldEventWeek
            ) {
                worldEventNotice = WorldEventNotice(
                    eventID: worldNotice.eventID,
                    triggeredWeek: worldNotice.triggeredWeek,
                    endingWeek: worldNotice.endingWeek,
                    localNotice: localNotice
                )
            } else {
                notice = localNotice
            }
            saveProgress()
            DebugLog.record("work.success", debugContext)
        } catch {
            DebugLog.record("work.failure", "\(debugContext) error=\(error.localizedDescription)")
            notice = UserNotice(title: "这周不能打工", message: error.localizedDescription)
        }
    }

    func restAtHome() {
        DebugLog.record("rest.begin", debugContext)
        do {
            let event = try engine.restAtHome(in: &session)
            selectedDestinationID = session.currentDistrictID
            notice = UserNotice(event: event)
            saveProgress()
            DebugLog.record("rest.success", debugContext)
        } catch {
            DebugLog.record("rest.failure", "\(debugContext) error=\(error.localizedDescription)")
            notice = UserNotice(title: "这周不能躺平", message: error.localizedDescription)
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
            let endingWeek = session.day
            let previousWorldEventID = session.latestWorldEventID
            let previousWorldEventWeek = session.latestWorldEventWeek
            try engine.finishStationaryWeek(in: &session)
            selectedDestinationID = session.currentDistrictID
            selectedAction = .trading
            let localNotice = session.latestEvent.map(UserNotice.init(event:))
            let rentNotice = housingEvictionNotice(afterEnding: endingWeek)
            if let worldNotice = worldEventNoticeIfChanged(
                previousID: previousWorldEventID,
                previousWeek: previousWorldEventWeek
            ) {
                self.worldEventNotice = WorldEventNotice(
                    eventID: worldNotice.eventID,
                    triggeredWeek: worldNotice.triggeredWeek,
                    endingWeek: worldNotice.endingWeek,
                    localNotice: rentNotice ?? localNotice
                )
                if rentNotice != nil { queuedNotice = localNotice }
            } else if let rentNotice {
                notice = rentNotice
                queuedNotice = localNotice
            } else if let localNotice, !session.isFinished {
                notice = localNotice
            }
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

    func dismissWorldEvent() {
        guard let current = worldEventNotice else { return }
        let localNotice = current.localNotice
        session.unreadWorldEvents?.removeAll {
            $0.eventID == current.eventID && $0.startedWeek == current.triggeredWeek
        }
        if let pending = session.unreadWorldEvents?.first {
            worldEventNotice = WorldEventNotice(eventID: pending.eventID, triggeredWeek: pending.startedWeek, endingWeek: pending.endingWeek, localNotice: localNotice)
        } else {
            worldEventNotice = nil
            if let localNotice { notice = localNotice }
        }
        saveProgress()
    }

    func dismissNotice() {
        notice = queuedNotice
        queuedNotice = nil
    }

    @discardableResult
    func applyPurchasedAdventure(_ adventure: AdventureProduct, transactionID: UInt64) -> Bool {
        guard !session.isFinished else { return false }
        var processedIDs = Set(
            UserDefaults.standard.stringArray(forKey: purchaseHistoryKey) ?? []
        )
        let transactionKey = String(transactionID)
        guard !processedIDs.contains(transactionKey) else { return true }

        let oldCash = session.cash
        session.cash += adventure.cashDelta
        session.recordStatusChange(.cash, from: oldCash, reason: adventure.eventTitle)
        let event = GameEvent(
            id: "iap-\(adventure.rawValue)-\(transactionID)",
            kind: adventure.cashDelta >= 0 ? .opportunity : .setback,
            group: .money,
            title: adventure.eventTitle,
            message: adventure.narrative,
            cashDelta: adventure.cashDelta
        )
        session.latestEvent = event
        session.log.append(
            GameLogEntry(
                day: min(session.day, session.totalDays),
                title: event.title,
                message: event.message,
                eventID: "iap-\(adventure.rawValue)"
            )
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

    func clinicTreatmentRecovery(_ points: Int) -> Int {
        engine.clinicTreatmentRecovery(points, in: session)
    }

    func visitMassageParlor() -> Bool {
        performService(title: "按摩失败") {
            try engine.visitMassageParlor(in: &session)
        }
    }

    func expandCapacity() -> Bool {
        performService(title: "升级失败") {
            try engine.expandCapacity(in: &session)
        }
    }

    func obtainDriversLicense() -> Bool {
        do {
            let passed = try engine.obtainDriversLicense(in: &session)
            notice = UserNotice(
                title: passed ? "路考通过" : "路考没有通过",
                message: passed
                    ? "你完成了一周学习并通过路考，驾照已经到手。"
                    : "这次没有通过。报名费不会重复收取，请到下一周再来路考。"
            )
            saveProgress()
            return true
        } catch {
            notice = UserNotice(title: "驾照办理失败", message: error.localizedDescription)
            return false
        }
    }

    func startHousingRental(
        _ tier: HousingTier = .basement,
        paymentMethod: HousingPaymentMethod? = nil
    ) -> Bool {
        performService(title: "租房失败") {
            try engine.startHousingRental(tier, paymentMethod: paymentMethod, in: &session)
        }
    }

    func stopHousingRental() -> Bool {
        performService(title: "退租失败") { try engine.stopHousingRental(in: &session) }
    }

    func startCarRental() -> Bool {
        performService(title: "租车失败") { try engine.startCarRental(in: &session) }
    }

    func stopCarRental() -> Bool {
        performService(title: "还车失败") { try engine.stopCarRental(in: &session) }
    }

    func buyCar() -> Bool {
        performService(title: "买车失败") { try engine.buyCar(in: &session) }
    }

    func sellCar() -> Bool {
        performService(title: "卖车失败") { try engine.sellCar(in: &session) }
    }

    func buyTools() -> Bool {
        performService(title: "购买工具失败") { try engine.buyTools(in: &session) }
    }

    func investInProperty() -> Bool {
        performService(title: "物业投资失败") { try engine.investInProperty(in: &session) }
    }

    func resolveLifeChoice(_ optionID: String) {
        do {
            let event = try engine.resolveLifeChoice(optionID, in: &session)
            notice = UserNotice(event: event)
            saveProgress()
        } catch {
            notice = UserNotice(title: "选择没有生效", message: error.localizedDescription)
        }
    }

    func restart() {
        guard saveProgress() else { return }
        automaticallySubmitCompletion = true
        rankingCompletedAt = nil
        pendingTravelNoticeTask?.cancel()
        pendingTravelNoticeTask = nil
        var newEngine = GameEngine(seed: UInt64(Date.now.timeIntervalSince1970))
        session = newEngine.makeNewSession()
        engine = newEngine
        selectedDestinationID = session.currentDistrictID
        selectedAction = .trading
        isMarketExpanded = false
        isIntroductionPresented = true
        tradeContext = nil
        notice = nil
        queuedNotice = nil
        worldEventNotice = nil
        purchasedAdventure = nil
        investmentInvitationError = nil
        saveProgress()
    }

    @discardableResult
    func saveProgress() -> Bool {
        if session.isFinished {
            if rankingCompletedAt == nil { rankingCompletedAt = .now }
            pendingTravelNoticeTask?.cancel()
            pendingTravelNoticeTask = nil
            if notice?.healthEvent == nil, notice?.isHousingEviction != true { notice = nil }
            tradeContext = nil
        }
        guard let profileID else { return true }
        let snapshot = GameSnapshot(
            profileID: profileID,
            session: session,
            randomCheckpoint: engine.randomCheckpoint,
            updatedAt: session.isFinished ? (rankingCompletedAt ?? .now) : .now
        )
        do {
            try repository.archiveJourney(snapshot)
            if session.isFinished, automaticallySubmitCompletion {
                try onCompletedRun?(snapshot)
            }
        } catch {
            notice = UserNotice(
                title: "成绩尚未保存",
                message: "请稍后重试。保存成功前不会重开本局。\n\(error.localizedDescription)"
            )
            return false
        }
        onSave?(snapshot)
        return true
    }

    var currentRankingSnapshot: GameSnapshot? {
        guard let profileID else { return nil }
        return GameSnapshot(profileID: profileID, session: session, randomCheckpoint: engine.randomCheckpoint,
                            updatedAt: rankingCompletedAt ?? .now)
    }

    func loadLeaderboard() {
        leaderboardError = nil
        do {
            for id in ProfileID.allCases {
                if let snapshot = try repository.load(id) {
                    try repository.archiveJourney(snapshot)
                }
            }
            if let profileID {
                try repository.archiveJourney(
                    GameSnapshot(
                        profileID: profileID,
                        session: session,
                        randomCheckpoint: engine.randomCheckpoint
                    )
                )
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
        notice = UserNotice(event: event)
    }

    private func housingEvictionNotice(afterEnding week: Int) -> UserNotice? {
        guard session.latestHousingEvictionWeek == min(week + 1, session.totalDays),
              let amount = session.latestHousingEvictionAmount else { return nil }
        return UserNotice(
            title: "房租没有续上",
            message: "结束第 \(week) 周时，房东要求支付下一回合房租 \(amount.usdText)。现金与银行存款合计不足，所以下回合将失去“有房住”增益，并开始流落街头。",
            isHousingEviction: true
        )
    }

    private func worldEventNoticeIfChanged(
        previousID: String?,
        previousWeek: Int?
    ) -> WorldEventNotice? {
        guard session.latestWorldEventID != previousID || session.latestWorldEventWeek != previousWeek else { return nil }
        guard let active = session.unreadWorldEvents?.first ?? session.activeWorldEvent,
              WorldEventCatalog.event(active.eventID) != nil else { return nil }
        return WorldEventNotice(eventID: active.eventID, triggeredWeek: active.startedWeek, endingWeek: active.endingWeek, localNotice: nil)
    }

    private var debugContext: String {
        let profile = profileID.map { String($0.rawValue) } ?? "preview"
        let completedActions = session.completedWeeklyActions
            .map(\.rawValue)
            .sorted()
            .joined(separator: "+")
        let action = completedActions.isEmpty ? "none" : completedActions
        return "profile=\(profile) week=\(session.day) district=\(session.currentDistrictID.rawValue) cash=\(session.cash) debt=\(session.debt) action=\(action)"
    }
}
