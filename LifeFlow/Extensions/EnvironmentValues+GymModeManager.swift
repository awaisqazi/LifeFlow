//
//  EnvironmentValues+GymModeManager.swift
//  LifeFlow
//
//  Created by Fez Qazi on 1/6/26.
//

import SwiftUI

// MARK: - GymModeManager Environment Key

/// Environment key for accessing the shared GymModeManager instance
private struct GymModeManagerKey: EnvironmentKey {
    static let defaultValue: GymModeManager = AppDependencyManager.shared.gymModeManager
}

extension EnvironmentValues {
    /// The shared GymModeManager instance for managing workout state
    var gymModeManager: GymModeManager {
        get { self[GymModeManagerKey.self] }
        set { self[GymModeManagerKey.self] = newValue }
    }
}
