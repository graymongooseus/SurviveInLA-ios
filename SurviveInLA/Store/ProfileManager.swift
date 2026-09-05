import Foundation
import Observation

enum ICloudSyncState: Equatable {
    case disabled
    case ready
    case syncing
    case synced(Date)
    case waitingForAccount
    case failed(String)
}

@MainActor
@Observable
final class ProfileManager {
    private static let iCloudSyncPreferenceKey = "profiles.iCloudSyncEnabled"
    private let repository: ProfileRepository

    var slots: [ProfileSlot] = []
    var activeStore: GameStore?
    var notice: UserNotice?
    var isICloudSyncEnabled: Bool
    var iCloudSyncState: ICloudSyncState

    init(repository: ProfileRepository = ProfileRepository()) {
        self.repository = repository
        let syncEnabled = UserDefaults.standard.bool(forKey: Self.iCloudSyncPreferenceKey)
        isICloudSyncEnabled = syncEnabled
        iCloudSyncState = syncEnabled ? .ready : .disabled
        reload()
        syncWithICloud()
    }

    func open(_ profileID: ProfileID) {
        do {
            let snapshot = try repository.load(profileID)
            let store = GameStore(profileID: profileID, snapshot: snapshot, repository: repository)
            store.onSave = { [weak self] snapshot in
                self?.persist(snapshot)
            }
            activeStore = store

            store.saveProgress()
        } catch {
            notice = UserNotice(
                title: "无法打开存档",
                message: "PROFILE \(profileID.rawValue) 仍然保留，没有被覆盖。\n\(error.localizedDescription)"
            )
        }
    }

    func closeActiveProfile() {
        activeStore?.saveProgress()
        activeStore = nil
        reload()
    }

    func saveActiveProfile() {
        activeStore?.saveProgress()
    }

    func setICloudSyncEnabled(_ isEnabled: Bool) {
        isICloudSyncEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.iCloudSyncPreferenceKey)
        iCloudSyncState = isEnabled ? .ready : .disabled

        if isEnabled {
            syncWithICloud()
        }
    }

    func syncWithICloud() {
        guard isICloudSyncEnabled else { return }
        guard repository.isICloudAccountAvailable else {
            iCloudSyncState = .waitingForAccount
            return
        }

        iCloudSyncState = .syncing
        do {
            for profileID in ProfileID.allCases {
                _ = try repository.reconcileWithICloud(profileID)
            }
            reload()
            iCloudSyncState = .synced(.now)
        } catch {
            iCloudSyncState = .failed(error.localizedDescription)
            notice = UserNotice(title: "iCloud 同步失败", message: error.localizedDescription)
        }
    }

    func delete(_ profileID: ProfileID) {
        do {
            try repository.deleteEverywhere(profileID)
            reload()
            if isICloudSyncEnabled {
                iCloudSyncState = .synced(.now)
            }
            DebugLog.record("profile.delete", "profile=\(profileID.rawValue)")
        } catch {
            notice = UserNotice(title: "无法删除存档", message: error.localizedDescription)
        }
    }

    func reload() {
        slots = ProfileID.allCases.map { profileID in
            ProfileSlot(id: profileID, snapshot: try? repository.load(profileID))
        }
    }

    private func persist(_ snapshot: GameSnapshot) {
        do {
            try repository.save(snapshot)
            DebugLog.record(
                "profile.save.success",
                "profile=\(snapshot.profileID.rawValue) week=\(snapshot.session.day) action=\(snapshot.session.actionThisWeek?.rawValue ?? "none")"
            )
            slots = slots.map { slot in
                slot.id == snapshot.profileID
                    ? ProfileSlot(id: slot.id, snapshot: snapshot)
                    : slot
            }
        } catch {
            DebugLog.record(
                "profile.save.failure",
                "profile=\(snapshot.profileID.rawValue) error=\(error.localizedDescription)"
            )
            notice = UserNotice(title: "自动存档失败", message: error.localizedDescription)
            return
        }

        guard isICloudSyncEnabled, repository.isICloudAccountAvailable else { return }
        do {
            try repository.saveToICloud(snapshot)
            iCloudSyncState = .synced(.now)
        } catch {
            iCloudSyncState = .failed(error.localizedDescription)
            notice = UserNotice(
                title: "本机已保存",
                message: "iCloud 同步暂时失败，稍后会自动重试。\n\(error.localizedDescription)"
            )
        }
    }
}
