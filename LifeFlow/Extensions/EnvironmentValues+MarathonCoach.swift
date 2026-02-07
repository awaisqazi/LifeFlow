//
//  EnvironmentValues+MarathonCoach.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import SwiftUI

// MARK: - MarathonCoachManager Environment Key

/// Environment key for accessing the shared MarathonCoachManager instance
private struct MarathonCoachManagerKey: EnvironmentKey {
    static let defaultValue: MarathonCoachManager = AppDependencyManager.shared.marathonCoachManager
}

extension EnvironmentValues {
    /// The shared MarathonCoachManager instance for race training plans
    var marathonCoachManager: MarathonCoachManager {
        get { self[MarathonCoachManagerKey.self] }
        set { self[MarathonCoachManagerKey.self] = newValue }
    }
}
