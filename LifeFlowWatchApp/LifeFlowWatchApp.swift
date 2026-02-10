import SwiftUI
import SwiftData

@main
struct LifeFlowWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var coordinator = WatchAppCoordinator()

    init() {
        // Initialize Watch Connectivity early
        _ = WatchExtensionDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                rootView
            }
            .onChange(of: scenePhase) { _, newPhase in
                coordinator.handleScenePhase(newPhase)
                WatchExtensionDelegate.shared.handleScenePhase(newPhase)
            }
            .onAppear {
                coordinator.workoutManager.applyPendingIntentActions()
                coordinator.syncRouteFromRunState()
            }
        }
        .modelContainer(WatchDataStore.shared.modelContainer)
    }

    @ViewBuilder
    private var rootView: some View {
        switch coordinator.route {
        case .dashboard:
            WatchDashboardView(coordinator: coordinator)
        case .activeRun:
            WatchRunHUDView(coordinator: coordinator)
        case .summary:
            WatchPostRunSummaryView(coordinator: coordinator)
        case .settings:
            WatchSettingsView(coordinator: coordinator)
        }
    }
}
