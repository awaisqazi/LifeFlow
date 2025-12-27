//
//  ExerciseType.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation

/// Defines the type of exercise for categorization and UI presentation.
enum ExerciseType: String, Codable, CaseIterable {
    case weight       // Barbell, dumbbell, machine exercises
    case cardio       // Treadmill, bike, elliptical, running
    case calisthenics // Bodyweight exercises (push-ups, pull-ups)
    case flexibility  // Stretching, yoga poses
    
    var title: String {
        switch self {
        case .weight: return "Weight Training"
        case .cardio: return "Cardio"
        case .calisthenics: return "Calisthenics"
        case .flexibility: return "Flexibility"
        }
    }
    
    var icon: String {
        switch self {
        case .weight: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .calisthenics: return "figure.strengthtraining.functional"
        case .flexibility: return "figure.yoga"
        }
    }
}
