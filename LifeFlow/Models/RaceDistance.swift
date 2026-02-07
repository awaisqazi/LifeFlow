//
//  RaceDistance.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import Foundation

/// Supported race distances for the Marathon Coach feature
enum RaceDistance: String, Codable, CaseIterable {
    case oneMile
    case fiveK
    case eightK
    case halfMarathon
    case marathon

    var displayName: String {
        switch self {
        case .oneMile: return "1 Mile"
        case .fiveK: return "5K"
        case .eightK: return "8K"
        case .halfMarathon: return "Half Marathon"
        case .marathon: return "Marathon"
        }
    }

    /// Distance in miles
    var distanceInMiles: Double {
        switch self {
        case .oneMile: return 1.0
        case .fiveK: return 3.1
        case .eightK: return 5.0
        case .halfMarathon: return 13.1
        case .marathon: return 26.2
        }
    }

    /// Recommended taper weeks before race day
    var typicalTaperWeeks: Int {
        switch self {
        case .oneMile: return 1
        case .fiveK: return 1
        case .eightK: return 1
        case .halfMarathon: return 2
        case .marathon: return 3
        }
    }

    /// Minimum weeks needed to safely train for this distance
    var minimumWeeksNeeded: Int {
        switch self {
        case .oneMile: return 4
        case .fiveK: return 6
        case .eightK: return 8
        case .halfMarathon: return 12
        case .marathon: return 16
        }
    }

    /// Peak weeks (highest volume) before taper
    var peakWeeks: Int {
        switch self {
        case .oneMile: return 1
        case .fiveK: return 2
        case .eightK: return 2
        case .halfMarathon: return 3
        case .marathon: return 3
        }
    }

    /// Suggested long run cap as percentage of race distance
    var longRunCapFraction: Double {
        switch self {
        case .oneMile: return 2.0
        case .fiveK: return 1.5
        case .eightK: return 1.3
        case .halfMarathon: return 0.85
        case .marathon: return 0.75
        }
    }

    /// SF Symbol icon
    var icon: String {
        switch self {
        case .oneMile: return "figure.run"
        case .fiveK: return "figure.run"
        case .eightK: return "figure.run.circle"
        case .halfMarathon: return "figure.run.circle.fill"
        case .marathon: return "figure.run.square.stack"
        }
    }
}
