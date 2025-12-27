//
//  WorkoutExercise.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation
import SwiftData

/// Represents an individual exercise within a workout session.
/// Supports supersets and maintains order through orderIndex.
@Model
final class WorkoutExercise {
    /// Unique identifier for the exercise
    var id: UUID = UUID()
    
    /// Name of the exercise (e.g., "Bench Press", "Squats")
    var name: String = ""
    
    /// Position in the workout's exercise list (critical for UI sorting)
    var orderIndex: Int = 0
    
    // MARK: - Superset Logic
    
    /// Whether this exercise is part of a superset
    var isSuperset: Bool = false
    
    /// Groups exercises in the same circuit/superset
    var supersetGroupID: UUID?
    
    // MARK: - Exercise Classification
    
    /// Type of exercise for categorization
    var type: ExerciseType = ExerciseType.weight
    
    /// Optional notes for this specific exercise
    var notes: String?
    
    // MARK: - Relationships
    
    /// Sets performed for this exercise
    @Relationship(deleteRule: .cascade)
    var sets: [ExerciseSet] = []
    
    /// The session this exercise belongs to
    @Relationship(inverse: \WorkoutSession.exercises)
    var session: WorkoutSession?
    
    /// Creates a new workout exercise
    /// - Parameters:
    ///   - name: Exercise name
    ///   - type: Type of exercise
    ///   - orderIndex: Position in workout
    init(
        name: String,
        type: ExerciseType = .weight,
        orderIndex: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.orderIndex = orderIndex
        self.isSuperset = false
    }
    
    /// Returns sets sorted by orderIndex for consistent UI display
    var sortedSets: [ExerciseSet] {
        sets.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    /// Adds a new set to the exercise with the next available orderIndex
    func addSet(weight: Double? = nil, reps: Int? = nil) -> ExerciseSet {
        let nextIndex = (sets.map(\.orderIndex).max() ?? -1) + 1
        let newSet = ExerciseSet(orderIndex: nextIndex, weight: weight, reps: reps)
        sets.append(newSet)
        return newSet
    }
}

// MARK: - Common Exercises Library

extension WorkoutExercise {
    /// Common weight training exercises for quick selection
    static let weightExercises: [String] = [
        "Bench Press", "Squat", "Deadlift", "Overhead Press",
        "Barbell Row", "Pull-ups", "Dumbbell Curl", "Tricep Extension",
        "Leg Press", "Lat Pulldown", "Cable Fly", "Lunges"
    ]
    
    /// Common cardio exercises
    static let cardioExercises: [String] = [
        "Treadmill", "Stationary Bike", "Elliptical", "Rowing Machine",
        "Stair Climber", "Jump Rope"
    ]
    
    /// Common calisthenics exercises
    static let calisthenicsExercises: [String] = [
        "Push-ups", "Pull-ups", "Dips", "Burpees",
        "Mountain Climbers", "Planks", "Sit-ups", "Leg Raises"
    ]
}
