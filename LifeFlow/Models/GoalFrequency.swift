//
//  GoalFrequency.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation

/// Frequency at which goal progress is calculated and displayed
enum GoalFrequency: String, Codable, CaseIterable {
    case daily
    case weekly
    
    var title: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
    
    var daysPerPeriod: Int {
        switch self {
        case .daily: return 1
        case .weekly: return 7
        }
    }
}
