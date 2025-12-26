//
//  WorkoutSession.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import Foundation
import SwiftData

/// Represents a single workout session logged manually or synced from HealthKit.
@Model
final class WorkoutSession {
    /// Unique identifier for the workout
    var id: UUID
    
    /// Type of workout (e.g., "Running", "Weightlifting", "Yoga")
    var type: String
    
    /// Duration of the workout in seconds
    var duration: TimeInterval
    
    /// Active calories burned during the workout
    var calories: Double
    
    /// Source of the workout data: "Manual" or "HealthKit"
    var source: String
    
    /// When the workout occurred
    var timestamp: Date
    
    /// The daily metrics record this workout belongs to
    @Relationship(inverse: \DayLog.workouts) var dayLog: DayLog?
    
    /// Creates a new workout session
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - type: Workout type name
    ///   - duration: Duration in seconds
    ///   - calories: Active calories burned
    ///   - source: Data source ("Manual" or "HealthKit")
    ///   - timestamp: When the workout occurred
    init(
        id: UUID = UUID(),
        type: String,
        duration: TimeInterval,
        calories: Double = 0,
        source: String = "Manual",
        timestamp: Date = .now
    ) {
        self.id = id
        self.type = type
        self.duration = duration
        self.calories = calories
        self.source = source
        self.timestamp = timestamp
    }
}

// MARK: - Workout Type Presets

extension WorkoutSession {
    /// Common workout types for manual entry
    static let workoutTypes: [String] = [
        "Weightlifting",
        "Running",
        "Yoga",
        "Cycling",
        "Swimming",
        "HIIT",
        "Walking",
        "Pilates",
        "Dance",
        "Other"
    ]
    
    /// SF Symbol icon for each workout type
    static func icon(for type: String) -> String {
        switch type {
        case "Weightlifting": return "figure.strengthtraining.traditional"
        case "Running": return "figure.run"
        case "Yoga": return "figure.yoga"
        case "Cycling": return "figure.outdoor.cycle"
        case "Swimming": return "figure.pool.swim"
        case "HIIT": return "figure.highintensity.intervaltraining"
        case "Walking": return "figure.walk"
        case "Pilates": return "figure.pilates"
        case "Dance": return "figure.dance"
        default: return "figure.mixed.cardio"
        }
    }
    
    /// Format duration as human-readable string
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
