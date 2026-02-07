//
//  RunType.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import Foundation

/// Types of training runs in a race plan
enum RunType: String, Codable, CaseIterable {
    case recovery
    case base
    case longRun
    case speedWork
    case tempo
    case crossTraining
    case rest

    var displayName: String {
        switch self {
        case .recovery: return "Recovery"
        case .base: return "Base Run"
        case .longRun: return "Long Run"
        case .speedWork: return "Speed Work"
        case .tempo: return "Tempo Run"
        case .crossTraining: return "Cross Training"
        case .rest: return "Rest Day"
        }
    }

    var icon: String {
        switch self {
        case .recovery: return "leaf.fill"
        case .base: return "figure.run"
        case .longRun: return "road.lanes"
        case .speedWork: return "bolt.fill"
        case .tempo: return "gauge.with.dots.needle.67percent"
        case .crossTraining: return "figure.strengthtraining.traditional"
        case .rest: return "bed.double.fill"
        }
    }

    var colorName: String {
        switch self {
        case .recovery: return "green"
        case .base: return "blue"
        case .longRun: return "purple"
        case .speedWork: return "orange"
        case .tempo: return "red"
        case .crossTraining: return "cyan"
        case .rest: return "gray"
        }
    }

    var effortDescription: String {
        switch self {
        case .recovery: return "Easy pace, conversational. Let your body rebuild."
        case .base: return "Comfortable pace. The foundation of endurance."
        case .longRun: return "Steady pace, building distance. Your endurance builder."
        case .speedWork: return "Intervals at high intensity. Builds speed and VO2 max."
        case .tempo: return "Comfortably hard. Sustained effort below race pace."
        case .crossTraining: return "Strength, cycling, or swimming. Active recovery."
        case .rest: return "Full rest. Your body adapts and grows stronger."
        }
    }

    /// Whether this run type contributes to weekly mileage
    var countsAsMileage: Bool {
        switch self {
        case .rest, .crossTraining: return false
        default: return true
        }
    }

    /// Effort intensity (0.0-1.0) for adaptation calculations
    var intensityFactor: Double {
        switch self {
        case .rest: return 0.0
        case .recovery: return 0.3
        case .crossTraining: return 0.4
        case .base: return 0.5
        case .longRun: return 0.6
        case .tempo: return 0.75
        case .speedWork: return 0.85
        }
    }
}
