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
public struct GymWorkoutAttributes: ActivityAttributes {
    /// Content that updates during the Live Activity
    public struct ContentState: Codable, Hashable {
        /// Current exercise name
        public var exerciseName: String
        
        /// SF Symbol name for the current exercise type
        public var exerciseIcon: String
        
        /// Current set number (e.g., 2)
        public var currentSet: Int
        
        /// Total sets for current exercise
        public var totalSets: Int
        
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
        
        /// Cardio fields
        public var isCardio: Bool
        public var cardioModeIndex: Int   // 0 for Timed, 1 for Freestyle
        public var cardioSpeed: Double
        public var cardioIncline: Double
        public var cardioEndTime: Date?   // For countdown in timed mode
        public var cardioDuration: TimeInterval // For progress bar in timed mode
        
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
        
        public init(
            exerciseName: String,
            exerciseIcon: String = "dumbbell.fill",
            currentSet: Int,
            totalSets: Int,
            elapsedTime: Int,
            workoutStartDate: Date = Date(),
            isResting: Bool = false,
            restTimeRemaining: Int = 0,
            restEndTime: Date? = nil,
            isCardio: Bool = false,
            cardioModeIndex: Int = 0,
            cardioSpeed: Double = 0,
            cardioIncline: Double = 0,
            cardioEndTime: Date? = nil,
            cardioDuration: TimeInterval = 0
        ) {
            self.exerciseName = exerciseName
            self.exerciseIcon = exerciseIcon
            self.currentSet = currentSet
            self.totalSets = totalSets
            self.elapsedTime = elapsedTime
            self.workoutStartDate = workoutStartDate
            self.isResting = isResting
            self.restTimeRemaining = restTimeRemaining
            self.restEndTime = restEndTime
            self.isCardio = isCardio
            self.cardioModeIndex = cardioModeIndex
            self.cardioSpeed = cardioSpeed
            self.cardioIncline = cardioIncline
            self.cardioEndTime = cardioEndTime
            self.cardioDuration = cardioDuration
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
