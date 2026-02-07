//
//  GoalType.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import Foundation

enum GoalType: String, CaseIterable {
    case savings      // Financial targets → Jar visualization
    case weightLoss   // Weight/fitness → Line chart
    case habit        // Daily habits → Heatmap
    case study        // Time accumulation → Progress bar
    case custom       // Generic → Simple progress
    case raceTraining // Marathon/race training → RaceTrackCard

    var title: String {
        switch self {
        case .savings: return "Savings Goal"
        case .weightLoss: return "Weight Loss"
        case .habit: return "Daily Habit"
        case .study: return "Study Goal"
        case .custom: return "Custom Goal"
        case .raceTraining: return "Race Training"
        }
    }

    var icon: String {
        switch self {
        case .savings: return "banknote.fill"
        case .weightLoss: return "scalemass.fill"
        case .habit: return "flame.fill"
        case .study: return "book.fill"
        case .custom: return "target"
        case .raceTraining: return "figure.run"
        }
    }

    var description: String {
        switch self {
        case .savings: return "Track progress toward a financial target"
        case .weightLoss: return "Monitor weight loss journey"
        case .habit: return "Build consistent daily habits"
        case .study: return "Accumulate study hours"
        case .custom: return "Track any custom goal"
        case .raceTraining: return "Train for a race with adaptive coaching"
        }
    }

    var accentColor: String {
        switch self {
        case .savings: return "gold"
        case .weightLoss: return "green"
        case .habit: return "orange"
        case .study: return "purple"
        case .custom: return "blue"
        case .raceTraining: return "green"
        }
    }
}

// MARK: - Codable (Backwards Compatibility)

extension GoalType: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        // Map old values to new types for backwards compatibility
        switch rawValue {
        case "targetValue":
            self = .savings  // Old targetValue → savings
        case "frequency":
            self = .habit    // Old frequency → habit
        case "dailyHabit":
            self = .habit    // Old dailyHabit → habit
        case "raceTraining":
            self = .raceTraining
        default:
            // Try to decode as new value
            if let type = GoalType(rawValue: rawValue) {
                self = type
            } else {
                self = .custom  // Default fallback
            }
        }
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

