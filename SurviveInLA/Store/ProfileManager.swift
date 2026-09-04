import Foundation
import Observation

@MainActor
@Observable
final class ProfileManager {
    private let repository: ProfileRepository

    var slots: [ProfileSlot] = []
    var activeStore: GameStore?
    var notice: UserNotice?

    init(repository: ProfileRepository = ProfileRepository()) {
        self.repository = repository
        reload()
    }

    func open(_ profileID: ProfileID) {
        do {
            let snapshot = try repository.load(profileID)
            let store = GameStore(profileID: profileID, snapshot: snapshot)
            store.onSave = { [weak self] snapshot in
                self?.persist(snapshot)
            }
            activeStore = store

            if snapshot == nil {
                store.saveProgress()
            }
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

    func reload() {
        slots = ProfileID.allCases.map { profileID in
            ProfileSlot(id: profileID, snapshot: try? repository.load(profileID))
        }
    }

    private func persist(_ snapshot: GameSnapshot) {
        do {
            try repository.save(snapshot)
            slots = slots.map { slot in
                slot.id == snapshot.profileID
                    ? ProfileSlot(id: slot.id, snapshot: snapshot)
                    : slot
            }
        } catch {
            notice = UserNotice(title: "自动存档失败", message: error.localizedDescription)
        }
    }
}
