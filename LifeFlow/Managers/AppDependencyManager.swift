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
    
    /// Shared GymModeManager instance that persists across view lifecycle
    let gymModeManager: GymModeManager = GymModeManager()

    /// Shared MarathonCoachManager instance for race training plans
    let marathonCoachManager: MarathonCoachManager = MarathonCoachManager()
    
    /// Shared HealthKitManager instance for workout data syncing
    let healthKitManager: HealthKitManager = HealthKitManager()
    
    /// Shared WatchConnectivity bridge for optional watch mirroring.
    let watchConnectivityManager: WatchConnectivityManager = WatchConnectivityManager()
    
    private init() {
        let appGroupIdentifier = HydrationSettings.appGroupID
        let schema = Schema([
            DayLog.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            ExerciseSet.self,
            Goal.self,
            DailyEntry.self,
            WorkoutRoutine.self,
            TrainingPlan.self,
            TrainingSession.self,
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
        
        watchConnectivityManager.onHeartRateUpdate = { [healthKitManager] heartRate in
            Task { @MainActor in
                healthKitManager.applyMirroredHeartRate(heartRate)
            }
        }
    }
}
