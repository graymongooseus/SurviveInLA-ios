import Foundation
import SwiftUI

@main
struct SurviveInLAApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var profileManager = ProfileManager()

    #if DEBUG
    // 独立无存档的原生卡片预览，供美术验收与模拟器截图使用。
    @State private var healthPreviewStore: GameStore? = {
        guard let id = ProcessInfo.processInfo.environment["HEALTH_EVENT_PREVIEW"],
              let event = LocationEventCatalog.healthEvents.first(where: { $0.id == id }) else { return nil }
        let store = GameStore(seed: 42)
        store.isIntroductionPresented = false
        store.notice = UserNotice(event: event)
        return store
    }()
    #endif

    private var displayedStore: GameStore? {
        #if DEBUG
        if let healthPreviewStore { return healthPreviewStore }
        #endif
        return profileManager.activeStore
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let store = displayedStore {
                    GameHomeView(
                        store: store,
                        profileManager: profileManager
                    )
                    .transition(.opacity)
                } else {
                    ProfileSelectionView(manager: profileManager)
                        .transition(.opacity)
                }
            }
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        DebugLog.appBecameActive()
                        profileManager.syncWithICloud()
                    case .background:
                        profileManager.saveActiveProfile()
                        DebugLog.appEnteredBackground()
                    case .inactive:
                        profileManager.saveActiveProfile()
                        DebugLog.record("app.inactive")
                    @unknown default:
                        DebugLog.record("app.unknown_scene_phase")
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: NSUbiquitousKeyValueStore.didChangeExternallyNotification
                    )
                ) { _ in
                    profileManager.syncWithICloud()
                }
        }
    }
}
