//
//  LifeFlowTab.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import Foundation

/// Represents the three main tabs in LifeFlow
enum LifeFlowTab: String, CaseIterable {
    case flow = "Flow"
    case temple = "Temple"
    case horizon = "Horizon"
    
    var orderIndex: Int {
        switch self {
        case .flow: return 0
        case .temple: return 1
        case .horizon: return 2
        }
    }
    
    /// SF Symbol icon for each tab
    var icon: String {
        switch self {
        case .flow: return "drop.fill"
        case .temple: return "figure.strengthtraining.traditional"
        case .horizon: return "mountain.2.fill"
        }
    }
    
    /// Descriptive subtitle for each tab
    var subtitle: String {
        switch self {
        case .flow: return "Dashboard"
        case .temple: return "Fitness"
        case .horizon: return "Goals"
        }
    }
}
