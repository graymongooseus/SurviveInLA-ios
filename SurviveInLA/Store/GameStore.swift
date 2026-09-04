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
    @ObservationIgnored private var pendingTravelNoticeTask: Task<Void, Never>?

    let profileID: ProfileID?
    var onSave: ((GameSnapshot) -> Void)?

    var session: GameSession
    var selectedDestinationID: District.ID
    var isMarketExpanded = false
    var tradeContext: TradeContext?
    var notice: UserNotice?

    var treatmentCostPerPoint: Int { engine.balance.treatmentCostPerPoint }
    var maximumCapacity: Int { engine.balance.maximumCapacity }
    var capacityUpgradeCost: Int { engine.capacityUpgradeCost(for: session) }

    init(
        seed: UInt64 = UInt64(Date.now.timeIntervalSince1970),
        profileID: ProfileID? = nil,
        snapshot: GameSnapshot? = nil
    ) {
        self.profileID = profileID
        let initialEngine: GameEngine
        let initialSession: GameSession
        if let snapshot {
            initialEngine = GameEngine(randomCheckpoint: snapshot.randomCheckpoint)
            initialSession = snapshot.session
        } else {
            var newEngine = GameEngine(seed: seed)
            initialSession = newEngine.makeNewSession()
            initialEngine = newEngine
        }
        engine = initialEngine
        session = initialSession
        selectedDestinationID = initialSession.currentDistrictID
    }

    var currentDistrict: District {
        GameContent.district(session.currentDistrictID)
    }

    var selectedDestination: District {
        GameContent.district(selectedDestinationID)
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
        do {
            switch mode {
            case .buy:
                try engine.buy(commodityID, quantity: quantity, in: &session)
            case .sell:
                try engine.sell(commodityID, quantity: quantity, in: &session)
            }
            tradeContext = nil
            saveProgress()
            return true
        } catch {
            notice = UserNotice(title: "交易没有完成", message: error.localizedDescription)
            return false
        }
    }

    func travel() {
        pendingTravelNoticeTask?.cancel()
        do {
            try engine.travel(to: selectedDestinationID, session: &session)
            selectedDestinationID = session.currentDistrictID
            isMarketExpanded = session.day == session.totalDays

            if let event = session.latestEvent {
                let eventNotice = UserNotice(title: event.title, message: event.message)
                pendingTravelNoticeTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(850))
                    guard !Task.isCancelled else { return }
                    self?.notice = eventNotice
                }
            }
            saveProgress()
        } catch {
            notice = UserNotice(title: "暂时不能出发", message: error.localizedDescription)
        }
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
        pendingTravelNoticeTask?.cancel()
        var newEngine = GameEngine(seed: UInt64(Date.now.timeIntervalSince1970))
        session = newEngine.makeNewSession()
        engine = newEngine
        selectedDestinationID = session.currentDistrictID
        isMarketExpanded = false
        tradeContext = nil
        notice = nil
        saveProgress()
    }

    func saveProgress() {
        guard let profileID else { return }
        onSave?(
            GameSnapshot(
                profileID: profileID,
                session: session,
                randomCheckpoint: engine.randomCheckpoint
            )
        )
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
}
