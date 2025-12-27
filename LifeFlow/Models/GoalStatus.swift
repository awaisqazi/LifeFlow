//
//  GoalStatus.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation

/// Represents the user's progress status toward their goal
enum GoalStatus: String, Codable, CaseIterable {
    /// User is meeting the expected pace
    case onTrack
    /// User has fallen behind schedule and requires catch-up
    case behind
    /// User is ahead of schedule and can reduce daily effort
    case ahead
    /// Goal has been completed
    case completed
    
    var title: String {
        switch self {
        case .onTrack: return "On Track"
        case .behind: return "Behind"
        case .ahead: return "Ahead"
        case .completed: return "Completed"
        }
    }
    
    var icon: String {
        switch self {
        case .onTrack: return "checkmark.circle"
        case .behind: return "exclamationmark.triangle"
        case .ahead: return "arrow.up.circle"
        case .completed: return "star.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .onTrack: return "blue"
        case .behind: return "orange"
        case .ahead: return "green"
        case .completed: return "purple"
        }
    }
}
