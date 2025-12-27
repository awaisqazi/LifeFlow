//
//  ExerciseSet.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation
import SwiftData

/// Represents a single set within a workout exercise.
/// Supports both weight training (reps/weight) and cardio (duration/distance) data.
@Model
final class ExerciseSet {
    /// Unique identifier for the set
    var id: UUID = UUID()
    
    /// Position in the exercise's set list (for maintaining order)
    var orderIndex: Int = 0
    
    /// Whether this set has been completed
    var isCompleted: Bool = false
    
    // MARK: - Weight Training Data
    
    /// Weight lifted in pounds (optional for cardio)
    var weight: Double?
    
    /// Number of repetitions (optional for cardio)
    var reps: Int?
    
    /// Rate of Perceived Exertion (1-10 scale)
    var rpe: Int?
    
    // MARK: - Cardio Data
    
    /// Duration of cardio activity in seconds
    var duration: TimeInterval?
    
    /// Distance covered in miles
    var distance: Double?
    
    /// Speed in mph (for treadmill, bike, etc.)
    var speed: Double?
    
    /// Incline percentage (for treadmill)
    var incline: Double?
    
    // MARK: - Relationships
    
    /// The exercise this set belongs to
    @Relationship(inverse: \WorkoutExercise.sets)
    var exercise: WorkoutExercise?
    
    /// Creates a new exercise set
    /// - Parameters:
    ///   - orderIndex: Position in the set list
    ///   - weight: Weight lifted (for weight training)
    ///   - reps: Number of reps (for weight training)
    init(
        orderIndex: Int = 0,
        weight: Double? = nil,
        reps: Int? = nil,
        rpe: Int? = nil,
        duration: TimeInterval? = nil,
        distance: Double? = nil,
        speed: Double? = nil,
        incline: Double? = nil
    ) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.isCompleted = false
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.duration = duration
        self.distance = distance
        self.speed = speed
        self.incline = incline
    }
}

// MARK: - Formatted Display

extension ExerciseSet {
    /// Formatted string for weight training sets (e.g., "135 lbs × 10")
    var weightDisplay: String? {
        guard let weight = weight, let reps = reps else { return nil }
        return "\(Int(weight)) lbs × \(reps)"
    }
    
    /// Formatted string for cardio sets (e.g., "2.5 mi in 25:00")
    var cardioDisplay: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if let distance = distance {
            return String(format: "%.1f mi in %d:%02d", distance, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
