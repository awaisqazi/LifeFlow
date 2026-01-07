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

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .fullScreenCover(isPresented: $showGymMode) {
                    GymModeView()
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
