//
//  DailyMetrics.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import Foundation
import SwiftData

/// Tracks daily wellness metrics for the LifeFlow momentum tracker.
/// This model persists water intake, gym attendance, and workout notes.
@Model
final class DailyMetrics {
    /// The date this record represents (unique per day)
    var date: Date
    
    /// Water consumed in ounces
    var waterIntake: Double
    
    /// Whether the user attended the gym
    var gymAttendance: Bool
    
    /// Optional notes about the workout session
    var gymNotes: String?
    
    /// Creates a new daily metrics record
    /// - Parameters:
    ///   - date: The date for this record
    ///   - waterIntake: Starting water intake (default 0)
    ///   - gymAttendance: Whether gym was attended (default false)
    ///   - gymNotes: Optional workout notes
    init(
        date: Date = .now,
        waterIntake: Double = 0,
        gymAttendance: Bool = false,
        gymNotes: String? = nil
    ) {
        self.date = date
        self.waterIntake = waterIntake
        self.gymAttendance = gymAttendance
        self.gymNotes = gymNotes
    }
}
