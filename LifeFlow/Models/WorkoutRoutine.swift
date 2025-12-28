//
//  WorkoutRoutine.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation
import SwiftData

/// A saved workout routine/template that appears in Quick Start.
/// Favorites appear first in the list.
@Model
final class WorkoutRoutine {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "dumbbell.fill"
    var color: String = "orange" // Color name for UI
    var isFavorite: Bool = false
    var createdAt: Date = Date()
    var lastUsedAt: Date?
    
    /// Exercises in this routine (stored as JSON for flexibility)
    var exercisesData: Data?
    
    init(name: String, icon: String = "dumbbell.fill", color: String = "orange", exercises: [RoutineExercise] = []) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.color = color
        self.isFavorite = false
        self.createdAt = Date()
        
        // Encode exercises
        if let data = try? JSONEncoder().encode(exercises) {
            self.exercisesData = data
        }
    }
    
    /// Decoded exercises
    var exercises: [RoutineExercise] {
        get {
            guard let data = exercisesData else { return [] }
            return (try? JSONDecoder().decode([RoutineExercise].self, from: data)) ?? []
        }
        set {
            exercisesData = try? JSONEncoder().encode(newValue)
        }
    }
}

/// Lightweight exercise definition for routines (not SwiftData)
struct RoutineExercise: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var type: String // ExerciseType raw value
    var setCount: Int
    
    init(name: String, type: ExerciseType, setCount: Int = 3) {
        self.id = UUID()
        self.name = name
        self.type = type.rawValue
        self.setCount = setCount
    }
    
    var exerciseType: ExerciseType {
        ExerciseType(rawValue: type) ?? .weight
    }
}
