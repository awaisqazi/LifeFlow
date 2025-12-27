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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DayLog.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            ExerciseSet.self,
            Goal.self,
            DailyEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
