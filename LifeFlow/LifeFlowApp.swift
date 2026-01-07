//
//  LifeFlowApp.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData

@main
struct LifeFlowApp: App {
    var sharedModelContainer: ModelContainer {
        AppDependencyManager.shared.sharedModelContainer
    }
    
    /// Controls whether GymModeView is presented (for deep linking)
    @State private var showGymMode: Bool = false
    
    /// Scene phase for handling app lifecycle events
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .fullScreenCover(isPresented: $showGymMode) {
                    GymModeView()
                }
                .environment(\.gymModeManager, AppDependencyManager.shared.gymModeManager)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // Check for pending actions from Live Activity intents
                        AppDependencyManager.shared.gymModeManager.checkForWidgetActions()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    /// Handle deep links from widgets
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "lifeflow" else { return }
        
        switch url.host {
        case "gym":
            showGymMode = true
        default:
            break
        }
    }
}
