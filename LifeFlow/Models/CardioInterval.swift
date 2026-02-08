//
//  CardioInterval.swift
//  LifeFlow
//
//  Created by Fez Qazi on 1/10/26.
//

import Foundation

/// Tracks speed/incline changes during freestyle cardio workouts
struct CardioInterval: Codable, Identifiable {
    let id: UUID
    let timestamp: Date      // When this interval started
    let speed: Double        // mph or resistance level
    let incline: Double      // % or resistance level
    var duration: TimeInterval?  // Filled when interval ends
    
    init(speed: Double, incline: Double) {
        self.id = UUID()
        self.timestamp = Date()
        self.speed = speed
        self.incline = incline
        self.duration = nil
    }
}

/// Mode selection for cardio exercises
enum CardioWorkoutMode: String, Codable {
    case timed      // Fixed duration countdown
    case freestyle  // Open-ended with interval tracking
    case distance   // Target distance goal (for Marathon Coach)
}
