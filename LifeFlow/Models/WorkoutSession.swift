//
//  WorkoutSession.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import Foundation
import SwiftData

struct RunAnalysisMetadata: Hashable {
    var healthKitWorkoutID: UUID?
    var weatherSummary: String?
    var targetPaceMinutesPerMile: Double?
    var targetDistanceMiles: Double?
    var completedDistanceMiles: Double?
    var generatedAt: Date
    
    private static let generatedAtThresholdForUnixEpoch: TimeInterval = 1_000_000_000
    private static let iso8601Formatter = ISO8601DateFormatter()
    
    func encodeToJSONString() -> String? {
        var dictionary: [String: Any] = [
            "generatedAt": generatedAt.timeIntervalSince1970
        ]
        
        if let healthKitWorkoutID {
            dictionary["healthKitWorkoutID"] = healthKitWorkoutID.uuidString
        }
        if let weatherSummary {
            dictionary["weatherSummary"] = weatherSummary
        }
        if let targetPaceMinutesPerMile {
            dictionary["targetPaceMinutesPerMile"] = targetPaceMinutesPerMile
        }
        if let targetDistanceMiles {
            dictionary["targetDistanceMiles"] = targetDistanceMiles
        }
        if let completedDistanceMiles {
            dictionary["completedDistanceMiles"] = completedDistanceMiles
        }
        
        guard JSONSerialization.isValidJSONObject(dictionary),
              let data = try? JSONSerialization.data(withJSONObject: dictionary, options: []),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return jsonString
    }
    
    static func decode(from jsonString: String) -> RunAnalysisMetadata? {
        guard let data = jsonString.data(using: .utf8),
              let rawObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = rawObject as? [String: Any] else {
            return nil
        }
        
        let generatedAt = decodeDate(from: dictionary["generatedAt"])
        let healthKitWorkoutID = (dictionary["healthKitWorkoutID"] as? String).flatMap(UUID.init(uuidString:))
        let weatherSummary = dictionary["weatherSummary"] as? String
        let targetPaceMinutesPerMile = dictionary["targetPaceMinutesPerMile"] as? Double
        let targetDistanceMiles = dictionary["targetDistanceMiles"] as? Double
        let completedDistanceMiles = dictionary["completedDistanceMiles"] as? Double
        
        return RunAnalysisMetadata(
            healthKitWorkoutID: healthKitWorkoutID,
            weatherSummary: weatherSummary,
            targetPaceMinutesPerMile: targetPaceMinutesPerMile,
            targetDistanceMiles: targetDistanceMiles,
            completedDistanceMiles: completedDistanceMiles,
            generatedAt: generatedAt
        )
    }
    
    private static func decodeDate(from rawValue: Any?) -> Date {
        if let seconds = rawValue as? TimeInterval {
            if seconds > generatedAtThresholdForUnixEpoch {
                return Date(timeIntervalSince1970: seconds)
            } else {
                return Date(timeIntervalSinceReferenceDate: seconds)
            }
        }
        
        if let stringValue = rawValue as? String {
            if let numeric = TimeInterval(stringValue) {
                if numeric > generatedAtThresholdForUnixEpoch {
                    return Date(timeIntervalSince1970: numeric)
                } else {
                    return Date(timeIntervalSinceReferenceDate: numeric)
                }
            }
            
            if let parsed = iso8601Formatter.date(from: stringValue) {
                return parsed
            }
        }
        
        return .now
    }
}

/// Represents a single workout session logged manually or synced from HealthKit.
/// Contains a hierarchical structure: Session -> Exercises -> Sets
@Model
final class WorkoutSession {
    /// Unique identifier for the workout
    var id: UUID
    
    /// Title of the workout session (e.g., "Leg Day", "Morning Cardio")
    var title: String = ""
    
    /// Legacy type field for backwards compatibility with HealthKit synced workouts
    var type: String
    
    /// Duration of the workout in seconds
    var duration: TimeInterval
    
    /// Active calories burned during the workout
    var calories: Double
    
    /// Source of the workout data: "Manual" or "HealthKit"
    var source: String
    
    /// When the workout occurred (legacy field for HealthKit sync)
    var timestamp: Date
    
    /// When the workout session started
    var startTime: Date = Date()
    
    /// When the workout session ended (nil if still in progress)
    var endTime: Date?
    
    /// Optional notes for the session
    var notes: String?
    
    // MARK: - Relationships
    
    /// The daily metrics record this workout belongs to
    @Relationship(inverse: \DayLog.workouts) var dayLog: DayLog?
    
    /// Exercises performed in this workout session
    @Relationship(deleteRule: .cascade)
    var exercises: [WorkoutExercise] = []
    
    /// Creates a new workout session
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - title: Session title (e.g., "Leg Day")
    ///   - type: Workout type name (for HealthKit compatibility)
    ///   - duration: Duration in seconds
    ///   - calories: Active calories burned
    ///   - source: Data source ("Manual" or "HealthKit")
    ///   - timestamp: When the workout occurred
    init(
        id: UUID = UUID(),
        title: String = "",
        type: String = "",
        duration: TimeInterval = 0,
        calories: Double = 0,
        source: String = "Manual",
        timestamp: Date = .now
    ) {
        self.id = id
        self.title = title.isEmpty ? type : title
        self.type = type
        self.duration = duration
        self.calories = calories
        self.source = source
        self.timestamp = timestamp
        self.startTime = timestamp
    }
    
    /// Returns exercises sorted by orderIndex for consistent UI display
    var sortedExercises: [WorkoutExercise] {
        exercises.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    /// Adds a new exercise to the workout with the next available orderIndex
    func addExercise(name: String, type: ExerciseType = .weight) -> WorkoutExercise {
        let nextIndex = (exercises.map(\.orderIndex).max() ?? -1) + 1
        let exercise = WorkoutExercise(name: name, type: type, orderIndex: nextIndex)
        exercises.append(exercise)
        return exercise
    }
}

// MARK: - Workout Type Presets

extension WorkoutSession {
    private static let runMetadataPrefix = "lifeflow.runmeta:"
    
    var totalDistanceMiles: Double {
        exercises
            .flatMap(\.sets)
            .compactMap(\.distance)
            .reduce(0, +)
    }
    
    var runAnalysisMetadata: RunAnalysisMetadata? {
        guard let notes else { return nil }
        guard notes.hasPrefix(Self.runMetadataPrefix) else { return nil }
        
        let payload = String(notes.dropFirst(Self.runMetadataPrefix.count))
        return RunAnalysisMetadata.decode(from: payload)
    }
    
    var weatherStampText: String? {
        runAnalysisMetadata?.weatherSummary
    }
    
    func setRunAnalysisMetadata(_ metadata: RunAnalysisMetadata) {
        guard let json = metadata.encodeToJSONString() else {
            return
        }
        notes = Self.runMetadataPrefix + json
    }
    
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
