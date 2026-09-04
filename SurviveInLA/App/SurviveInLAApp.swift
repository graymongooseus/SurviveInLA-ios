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
                    if phase != .active {
                        profileManager.saveActiveProfile()
                    }
                }
        }
    }
}
