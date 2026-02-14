//
//  GymWorkoutAttributes.swift
//  LifeFlow
//
//  Shared model for Gym Workout Live Activity.
//  Must be available to both main app and widget extension.
//

import Foundation
import ActivityKit

/// Activity attributes for the Gym Workout Live Activity.
/// Shows workout progress in Dynamic Island and Lock Screen.
public struct GymWorkoutAttributes: ActivityAttributes, Sendable {
    /// Content that updates during the Live Activity
    public struct ContentState: Codable, Hashable, Sendable {
        /// Current exercise name
        public var exerciseName: String
        
        /// SF Symbol name for the current exercise type
        public var exerciseIcon: String
        
        /// Current set number (e.g., 2)
        public var currentSet: Int
        
        /// Total sets for current exercise
        public var totalSets: Int
        
        /// Current exercise index within the workout (0-based)
        public var currentExerciseIndex: Int
        
        /// Elapsed workout time in seconds
        public var elapsedTime: Int
        
        /// Start date of the workout (for native count-up timer)
        public var workoutStartDate: Date
        
        /// Is rest timer active
        public var isResting: Bool
        
        /// Rest time remaining (if resting)
        public var restTimeRemaining: Int
        
        /// End date of the rest timer (for native countdown timer)
        public var restEndTime: Date?
        
        /// Whether the workout is currently paused
        public var isPaused: Bool
        
        /// Cardio fields
        public var isCardio: Bool
        public var cardioModeIndex: Int   // 0 for Timed, 1 for Freestyle
        public var cardioSpeed: Double
        public var cardioIncline: Double
        public var cardioEndTime: Date?   // For countdown in timed mode
        public var cardioDuration: TimeInterval // For progress bar in timed mode
        public var cardioTimeRemaining: TimeInterval? // Frozen remaining time when paused
        
        /// Optional interval metadata for guided speed workouts
        public var intervalProgress: Double?
        public var currentIntervalName: String?
        
        /// Optional distance target metadata for guided runs
        public var targetDistanceRemaining: Double?
        public var targetDistanceTotal: Double?
        public var currentDistanceMiles: Double?
        public var targetPaceMinutesPerMile: Double?
        public var ghostExpectedDistanceMiles: Double?
        public var ghostDeltaMiles: Double?
        
        /// Formatted elapsed time (MM:SS or H:MM:SS)
        public var formattedElapsedTime: String {
            let hours = elapsedTime / 3600
            let minutes = (elapsedTime % 3600) / 60
            let seconds = elapsedTime % 60
            
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%02d:%02d", minutes, seconds)
            }
        }
        
        /// Formatted rest time (M:SS)
        public var formattedRestTime: String {
            let minutes = restTimeRemaining / 60
            let seconds = restTimeRemaining % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        /// Formatted cardio time remaining (MM:SS or H:MM:SS)
        public var formattedCardioTime: String {
            let totalSeconds = Int(cardioTimeRemaining ?? 0)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60
            
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%d:%02d", minutes, seconds)
            }
        }
        
        public var formattedDistanceRemaining: String {
            guard let targetDistanceRemaining else { return "--" }
            return String(format: "%.2f mi", max(0, targetDistanceRemaining))
        }
        
        public init(
            exerciseName: String,
            exerciseIcon: String = "dumbbell.fill",
            currentSet: Int,
            totalSets: Int,
            currentExerciseIndex: Int = 0,
            elapsedTime: Int,
            workoutStartDate: Date = Date(),
            isResting: Bool = false,
            restTimeRemaining: Int = 0,
            restEndTime: Date? = nil,
            isPaused: Bool = false,
            isCardio: Bool = false,
            cardioModeIndex: Int = 0,
            cardioSpeed: Double = 0,
            cardioIncline: Double = 0,
            cardioEndTime: Date? = nil,
            cardioDuration: TimeInterval = 0,
            cardioTimeRemaining: TimeInterval? = nil,
            intervalProgress: Double? = nil,
            currentIntervalName: String? = nil,
            targetDistanceRemaining: Double? = nil,
            targetDistanceTotal: Double? = nil,
            currentDistanceMiles: Double? = nil,
            targetPaceMinutesPerMile: Double? = nil,
            ghostExpectedDistanceMiles: Double? = nil,
            ghostDeltaMiles: Double? = nil
        ) {
            self.exerciseName = exerciseName
            self.exerciseIcon = exerciseIcon
            self.currentSet = currentSet
            self.totalSets = totalSets
            self.currentExerciseIndex = currentExerciseIndex
            self.elapsedTime = elapsedTime
            self.workoutStartDate = workoutStartDate
            self.isResting = isResting
            self.restTimeRemaining = restTimeRemaining
            self.restEndTime = restEndTime
            self.isPaused = isPaused
            self.isCardio = isCardio
            self.cardioModeIndex = cardioModeIndex
            self.cardioSpeed = cardioSpeed
            self.cardioIncline = cardioIncline
            self.cardioEndTime = cardioEndTime
            self.cardioDuration = cardioDuration
            self.cardioTimeRemaining = cardioTimeRemaining
            self.intervalProgress = intervalProgress
            self.currentIntervalName = currentIntervalName
            self.targetDistanceRemaining = targetDistanceRemaining
            self.targetDistanceTotal = targetDistanceTotal
            self.currentDistanceMiles = currentDistanceMiles
            self.targetPaceMinutesPerMile = targetPaceMinutesPerMile
            self.ghostExpectedDistanceMiles = ghostExpectedDistanceMiles
            self.ghostDeltaMiles = ghostDeltaMiles
        }
    }
    
    /// Workout title (e.g., "Push Day")
    public var workoutTitle: String
    
    /// Total exercises in workout
    public var totalExercises: Int
    
    public init(workoutTitle: String, totalExercises: Int) {
        self.workoutTitle = workoutTitle
        self.totalExercises = totalExercises
    }
}
