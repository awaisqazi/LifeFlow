//
//  EnvironmentValues+GymMode.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI

// MARK: - Gym Mode Environment Actions

/// Environment key for entering Gym Mode
private struct EnterGymModeKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

/// Environment key for exiting Gym Mode
private struct ExitGymModeKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Action to enter Gym Mode from any child view
    var enterGymMode: () -> Void {
        get { self[EnterGymModeKey.self] }
        set { self[EnterGymModeKey.self] = newValue }
    }
    
    /// Action to exit Gym Mode from any child view
    var exitGymMode: () -> Void {
        get { self[ExitGymModeKey.self] }
        set { self[ExitGymModeKey.self] = newValue }
    }
}
