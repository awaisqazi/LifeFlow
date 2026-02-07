//
//  TrainingPhase.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import Foundation

/// Training phases in a backwards-planned race program
enum TrainingPhase: String, Codable, CaseIterable {
    case base
    case build
    case peak
    case taper

    var displayName: String {
        switch self {
        case .base: return "Base"
        case .build: return "Build"
        case .peak: return "Peak"
        case .taper: return "Taper"
        }
    }

    var description: String {
        switch self {
        case .base: return "Building your aerobic foundation at a comfortable level."
        case .build: return "Progressively increasing mileage by ~10% per week."
        case .peak: return "Highest training volume. Your longest runs happen here."
        case .taper: return "Reducing volume to arrive at race day fresh and ready."
        }
    }

    var colorName: String {
        switch self {
        case .base: return "blue"
        case .build: return "green"
        case .peak: return "purple"
        case .taper: return "orange"
        }
    }

    var icon: String {
        switch self {
        case .base: return "square.stack.3d.up"
        case .build: return "arrow.up.right"
        case .peak: return "mountain.2.fill"
        case .taper: return "arrow.down.right"
        }
    }
}
