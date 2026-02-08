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
    
    /// Target distance in miles for distance-based cardio (Marathon Coach integration)
    var targetDistance: Double?
    
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

// MARK: - Comprehensive Exercise Library

extension WorkoutExercise {
    
    // MARK: - Cardio Zone Equipment
    
    /// Cardio machines and exercises
    static let cardioExercises: [String] = [
        "Treadmill",
        "Elliptical",
        "Stair Climber (StairMaster)",
        "Arc Trainer",
        "Rowing Machine",
        "Stationary Bike (Upright)",
        "Recumbent Bike",
        "Arm Cycle (SciFit)"
    ]
    
    // MARK: - Selectorized Machines
    
    /// Gym machines with pin-selected weight stacks
    static let machineExercises: [String] = [
        // Leg Machines
        "Leg Press",
        "Leg Extension",
        "Seated Leg Curl",
        "Prone Leg Curl",
        "Hip Abduction",
        "Hip Adduction",
        "Glute Kickback Machine",
        "Calf Extension",
        
        // Upper Body Machines
        "Chest Press",
        "Pectoral Fly",
        "Rear Delt (Reverse Fly)",
        "Shoulder Press Machine",
        "Lateral Raise Machine",
        "Lat Pulldown",
        "Seated Row",
        "Back Extension",
        "Bicep Curl Machine",
        "Tricep Extension Machine",
        "Abdominal Crunch Machine",
        "Torso Rotation"
    ]
    
    // MARK: - Free Weights
    
    /// Dumbbells, fixed barbells, and Smith machine exercises
    static let weightExercises: [String] = [
        // Smith Machine Exercises
        "Smith Squat",
        "Smith Bench Press",
        "Smith Shoulder Press",
        "Smith Lunges",
        "Smith Deadlift",
        
        // Dumbbell Exercises
        "Dumbbell Bench Press",
        "Dumbbell Lunges",
        "Dumbbell Shoulder Press",
        "Dumbbell Curl",
        "Dumbbell Row",
        "Dumbbell Fly",
        "Goblet Squat",
        "Tricep Kickback",
        
        // Fixed Barbell Exercises
        "Barbell Curl",
        "Skullcrushers",
        "Upright Row",
        
        // Assisted Machine
        "Assisted Pull-Up",
        "Assisted Dip"
    ]
    
    // MARK: - Functional / Cable Exercises
    
    /// Cable towers and PF 360/Synergy equipment
    static let functionalExercises: [String] = [
        // Cable Tower Exercises
        "Tricep Pushdown",
        "Cable Bicep Curl",
        "Face Pull",
        "Cable Woodchopper",
        "Cable Chest Fly",
        
        // PF 360 / Synergy Exercises
        "TRX Row",
        "TRX Suspended Lunge",
        "Kettlebell Swing",
        "Medicine Ball Slam",
        "Wall Ball",
        "Box Jump",
        "Step-Up (Plyo Box)",
        "Battle Ropes",
        "Monkey Bar Traverse"
    ]
    
    // MARK: - Calisthenics / Bodyweight
    
    /// Bodyweight exercises
    static let calisthenicsExercises: [String] = [
        "Push-Up",
        "Pull-Up",
        "Dip",
        "Burpee",
        "Mountain Climber",
        "Sit-Up",
        "Leg Raise",
        "Jumping Jack"
    ]
    
    // MARK: - Flexibility / Stretching
    
    /// Stretching and abs area exercises
    static let flexibilityExercises: [String] = [
        // Abs Equipment
        "Decline Sit-Up",
        "Hyper-Extension (Roman Chair)",
        "Hanging Leg Raise (Captain's Chair)",
        
        // Mat Work
        "Plank Hold",
        "Hamstring Stretch",
        "Quad Stretch",
        "Hip Flexor Stretch",
        "Shoulder Stretch",
        "Yoga Flow"
    ]
    
    // MARK: - All Exercises
    
    /// Combined list of all available exercises
    static var allExercises: [String] {
        cardioExercises + machineExercises + weightExercises + functionalExercises + calisthenicsExercises + flexibilityExercises
    }
    
    /// Returns the correct ExerciseType for a given exercise name
    static func exerciseType(for name: String) -> ExerciseType {
        if cardioExercises.contains(name) { return .cardio }
        if machineExercises.contains(name) { return .machine }
        if weightExercises.contains(name) { return .weight }
        if functionalExercises.contains(name) { return .functional }
        if calisthenicsExercises.contains(name) { return .calisthenics }
        if flexibilityExercises.contains(name) { return .flexibility }
        return .weight // Default fallback
    }
}
