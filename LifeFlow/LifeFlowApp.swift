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

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
