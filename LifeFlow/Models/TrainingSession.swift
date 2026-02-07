//
//  TrainingSession.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import Foundation
import SwiftData

/// A single training day within a race plan
@Model
final class TrainingSession {
    var id: UUID = UUID()
    var date: Date
    var runType: RunType
    var targetDistance: Double
    var actualDistance: Double?
    var perceivedEffort: Int?
    var preRunFeeling: Double?
    var isCompleted: Bool = false
    var isSkipped: Bool = false
    var notes: String?
    var healthKitWorkoutID: UUID?

    @Relationship(inverse: \TrainingPlan.sessions) var plan: TrainingPlan?

    init(
        date: Date,
        runType: RunType,
        targetDistance: Double
    ) {
        self.id = UUID()
        self.date = date
        self.runType = runType
        self.targetDistance = targetDistance
    }

    /// Ratio of actual to target distance (1.0 = exactly on target)
    var completionRatio: Double {
        guard let actual = actualDistance, targetDistance > 0 else { return 0 }
        return actual / targetDistance
    }

    /// User exceeded target by 20% or more
    var wasOverAchieved: Bool {
        completionRatio > 1.2
    }

    /// User fell short of target (less than 80%)
    var wasUnderAchieved: Bool {
        guard isCompleted else { return false }
        return completionRatio < 0.8
    }

    /// Whether this session is in the past and wasn't completed
    var wasMissed: Bool {
        !isCompleted && !isSkipped && date < Calendar.current.startOfDay(for: Date())
    }
}
