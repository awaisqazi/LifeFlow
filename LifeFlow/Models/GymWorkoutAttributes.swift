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
        
        /// Current set number (e.g., 2)
        public var currentSet: Int
        
        /// Total sets for current exercise
        public var totalSets: Int
        
        /// Elapsed workout time in seconds
        public var elapsedTime: Int
        
        /// Is rest timer active
        public var isResting: Bool
        
        /// Rest time remaining (if resting)
        public var restTimeRemaining: Int
        
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
            currentSet: Int,
            totalSets: Int,
            elapsedTime: Int,
            isResting: Bool = false,
            restTimeRemaining: Int = 0
        ) {
            self.exerciseName = exerciseName
            self.currentSet = currentSet
            self.totalSets = totalSets
            self.elapsedTime = elapsedTime
            self.isResting = isResting
            self.restTimeRemaining = restTimeRemaining
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
