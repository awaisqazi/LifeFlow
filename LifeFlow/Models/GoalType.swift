//
//  GoalType.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import Foundation

enum GoalType: String, Codable, CaseIterable {
    case targetValue
    case frequency
    case dailyHabit
    
    var title: String {
        switch self {
        case .targetValue: return "Target Value"
        case .frequency: return "Frequency"
        case .dailyHabit: return "Daily Habit"
        }
    }
    
    var icon: String {
        switch self {
        case .targetValue: return "target"
        case .frequency: return "repeat"
        case .dailyHabit: return "checkmark.circle"
        }
    }
    
    var description: String {
        switch self {
        case .targetValue: return "Track progress toward a specific target"
        case .frequency: return "Complete a set number of times"
        case .dailyHabit: return "Build consistent daily habits"
        }
    }
}

