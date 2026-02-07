//
//  WorkoutWidgetState.swift
//  LifeFlow
//
//  Shared state model for workout widget.
//  Must have target membership for BOTH LifeFlow AND GymWidgetsExtension.
//

import Foundation
import WidgetKit

/// Shared workout state between main app and widget extension.
/// Uses App Group UserDefaults for communication.
struct WorkoutWidgetState: Codable {
    var isActive: Bool
    var workoutTitle: String
    var exerciseName: String
    var currentSet: Int
    var totalSets: Int
    var workoutStartDate: Date   // For Text(date, style: .timer) count-up
    var restEndTime: Date?       // For Text(date, style: .timer) countdown
    var restDuration: TimeInterval? // Total rest duration in seconds for progress bar
    var restTimeRemaining: TimeInterval? // Stored remaining time when paused
    var pauseRequested: Bool     // Flag set by Live Activity intent to request pause
    var isPaused: Bool           // Whether the workout is currently paused
    var pausedDisplayTime: String? // Static time string to show when paused (e.g. "12:45")
    
    // Exercise flow for large widget
    var previousExerciseName: String?
    var previousSetsCompleted: Int
    var previousTotalSets: Int
    var previousIsComplete: Bool
    
    var nextExerciseName: String?
    var nextSetsCompleted: Int
    var nextTotalSets: Int
    
    var totalExercises: Int
    /// 0-based index of the current exercise
    var currentExerciseIndex: Int
    
    // Cardio-specific state
    var isCardio: Bool
    var cardioElapsedTime: TimeInterval
    var cardioDuration: TimeInterval  // Target duration for timed cardio
    var cardioSpeed: Double
    var cardioIncline: Double
    
    var cardioEndTime: Date?     // For countdown timers in timed cardio
    var cardioModeIndex: Int     // 0 for Timed, 1 for Freestyle
    var cardioTimeRemaining: TimeInterval? // Stored remaining time when paused (for timed cardio)
    
    /// Default idle state
    static var idle: WorkoutWidgetState {
        WorkoutWidgetState(
            isActive: false,
            workoutTitle: "",
            exerciseName: "",
            currentSet: 0,
            totalSets: 0,
            workoutStartDate: Date(),
            restEndTime: nil,
            restDuration: nil,
            restTimeRemaining: nil,
            pauseRequested: false,
            isPaused: false,
            pausedDisplayTime: nil,
            previousExerciseName: nil,
            previousSetsCompleted: 0,
            previousTotalSets: 0,
            previousIsComplete: false,
            nextExerciseName: nil,
            nextSetsCompleted: 0,
            nextTotalSets: 0,
            totalExercises: 0,
            currentExerciseIndex: 0,
            isCardio: false,
            cardioElapsedTime: 0,
            cardioDuration: 0,
            cardioSpeed: 0,
            cardioIncline: 0,
            cardioEndTime: nil,
            cardioModeIndex: 0,
            cardioTimeRemaining: nil
        )
    }
    
    /// Whether currently in rest period
    var isResting: Bool {
        // Active rest timer
        if let restEnd = restEndTime, restEnd > Date() {
            return true
        }
        // Paused with remaining rest time
        if isPaused, let remaining = restTimeRemaining, remaining > 0 {
            return true
        }
        return false
    }
}

// MARK: - App Group Storage

extension WorkoutWidgetState {
    static let appGroupID = "group.com.Fez.LifeFlow"
    static let storageKey = "workoutWidgetState"
    
    /// Save state to App Group UserDefaults and trigger widget reload
    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        
        if let encoded = try? JSONEncoder().encode(self) {
            defaults.set(encoded, forKey: Self.storageKey)
            WidgetCenter.shared.reloadTimelines(ofKind: "GymWidgets")
        }
    }
    
    /// Load state from App Group UserDefaults
    static func load() -> WorkoutWidgetState {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: storageKey),
              let state = try? JSONDecoder().decode(WorkoutWidgetState.self, from: data) else {
            return .idle
        }
        return state
    }
    
    /// Clear state (called when workout ends)
    static func clear() {
        WorkoutWidgetState.idle.save()
    }
}
