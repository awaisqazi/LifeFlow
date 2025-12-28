//
//  RestTimerAttributes.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation
import ActivityKit

/// Activity attributes for the rest timer Live Activity.
/// Displayed in Dynamic Island and Lock Screen during rest periods.
struct RestTimerAttributes: ActivityAttributes {
    /// Content that updates during the Live Activity
    public struct ContentState: Codable, Hashable {
        /// Time remaining in seconds
        var timeRemaining: Int
        
        /// Whether the timer is paused
        var isPaused: Bool
        
        /// The formatted time string (MM:SS)
        var formattedTime: String {
            let minutes = timeRemaining / 60
            let seconds = timeRemaining % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// Exercise name to display
    var exerciseName: String
    
    /// Next set number
    var nextSetNumber: Int
    
    /// Total rest duration for progress calculation
    var totalDuration: Int
}
