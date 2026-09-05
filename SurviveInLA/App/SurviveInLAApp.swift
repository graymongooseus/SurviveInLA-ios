import Foundation
import SwiftUI

@main
struct SurviveInLAApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var profileManager = ProfileManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if let store = profileManager.activeStore {
                    GameHomeView(
                        store: store,
                        exitToProfiles: profileManager.closeActiveProfile
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
