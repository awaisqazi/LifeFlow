//
//  AppDependencyManager.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation
import SwiftData

/// Manages the shared ModelContainer for the main app.
/// This ensures we always use the correct App Group configuration.
final class AppDependencyManager {
    static let shared = AppDependencyManager()
    
    let sharedModelContainer: ModelContainer
    
    private init() {
        let appGroupIdentifier = "group.com.Fez.LifeFlow"
        let schema = Schema([
            DayLog.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            ExerciseSet.self,
            Goal.self,
            DailyEntry.self,
            WorkoutRoutine.self,
        ])
        
        // Use the shared App Group container
        let modelConfiguration = ModelConfiguration(
            url: URL.storeURL(for: appGroupIdentifier)
        )

        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
