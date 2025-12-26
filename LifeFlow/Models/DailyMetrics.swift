//
//  DailyMetrics.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import Foundation
import SwiftData

/// Tracks daily wellness metrics for the LifeFlow momentum tracker.
/// This model persists water intake and workout sessions.
@Model
final class DailyMetrics {
    /// The date this record represents (unique per day)
    var date: Date
    
    /// Water consumed in ounces
    var waterIntake: Double
    
    /// Workout sessions logged for this day
    @Relationship(deleteRule: .cascade) var workouts: [WorkoutSession]
    
    /// Total active calories burned from all workouts
    var totalActiveCalories: Double {
        workouts.reduce(0) { $0 + $1.calories }
    }
    
    /// Total workout duration for the day in seconds
    var totalWorkoutDuration: TimeInterval {
        workouts.reduce(0) { $0 + $1.duration }
    }
    
    /// Whether any workouts have been logged today
    var hasWorkedOut: Bool {
        !workouts.isEmpty
    }
    
    /// Creates a new daily metrics record
    /// - Parameters:
    ///   - date: The date for this record
    ///   - waterIntake: Starting water intake (default 0)
    ///   - workouts: Initial workout sessions (default empty)
    init(
        date: Date = .now,
        waterIntake: Double = 0,
        workouts: [WorkoutSession] = []
    ) {
        self.date = date
        self.waterIntake = waterIntake
        self.workouts = workouts
    }
}
