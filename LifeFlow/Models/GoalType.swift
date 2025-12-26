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
}
