//
//  TrainingPlan.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import Foundation
import SwiftData

/// A race training plan with adaptive coaching
@Model
final class TrainingPlan {
    var id: UUID = UUID()
    var raceDistance: RaceDistance
    var raceDate: Date
    var startDate: Date
    var createdAt: Date = Date()

    // Baseline fitness inputs
    var weeklyMileage: Double
    var longestRecentRun: Double

    // Schedule constraints (1=Sun, 2=Mon, ... 7=Sat)
    var restDays: [Int] = []

    // State
    var isActive: Bool = true
    var isCompleted: Bool = false

    // Metrics (updated by adaptation engine)
    var complianceScore: Double = 1.0
    var confidenceScore: Double = 0.5

    @Relationship(deleteRule: .cascade) var sessions: [TrainingSession] = []

    init(
        raceDistance: RaceDistance,
        raceDate: Date,
        startDate: Date = Date(),
        weeklyMileage: Double,
        longestRecentRun: Double,
        restDays: [Int] = []
    ) {
        self.id = UUID()
        self.raceDistance = raceDistance
        self.raceDate = raceDate
        self.startDate = startDate
        self.weeklyMileage = weeklyMileage
        self.longestRecentRun = longestRecentRun
        self.restDays = restDays
    }

    // MARK: - Computed Properties

    /// Total weeks in the training plan
    var totalWeeks: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear], from: startDate, to: raceDate)
        return max(1, components.weekOfYear ?? 1)
    }

    /// Current week number (1-based)
    var currentWeek: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear], from: startDate, to: Date())
        return min(max(1, (components.weekOfYear ?? 0) + 1), totalWeeks)
    }

    /// Total training days
    var totalDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: raceDate)
        return max(1, components.day ?? 1)
    }

    /// Current day number (1-based)
    var currentDay: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: Date())
        return min(max(1, (components.day ?? 0) + 1), totalDays)
    }

    /// Overall plan progress (0.0 to 1.0) based on time elapsed
    var progressPercentage: Double {
        Double(currentDay) / Double(totalDays)
    }

    /// Today's scheduled training session
    var todaysSession: TrainingSession? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return sessions.first { calendar.isDate($0.date, inSameDayAs: today) }
    }

    /// Current training phase based on where we are in the plan
    var currentPhase: TrainingPhase {
        let weeksRemaining = totalWeeks - currentWeek + 1
        let taperWeeks = raceDistance.typicalTaperWeeks
        let peakWeeks = raceDistance.peakWeeks

        if weeksRemaining <= taperWeeks {
            return .taper
        } else if weeksRemaining <= taperWeeks + peakWeeks {
            return .peak
        } else if currentWeek <= max(2, totalWeeks / 4) {
            return .base
        } else {
            return .build
        }
    }

    /// Whether the plan is in its final taper week (locked from adjustments)
    var isTaperLocked: Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: raceDate)
        let daysUntilRace = components.day ?? 0
        return daysUntilRace <= 7
    }

    /// Sessions sorted by date
    var sortedSessions: [TrainingSession] {
        sessions.sorted { $0.date < $1.date }
    }

    /// Completed sessions
    var completedSessions: [TrainingSession] {
        sessions.filter { $0.isCompleted }
    }

    /// Upcoming sessions (today and future, not completed)
    var upcomingSessions: [TrainingSession] {
        let today = Calendar.current.startOfDay(for: Date())
        return sessions
            .filter { $0.date >= today && !$0.isCompleted }
            .sorted { $0.date < $1.date }
    }

    /// Next future run sessions (excluding rest days)
    func nextRunningSessions(count: Int) -> [TrainingSession] {
        let today = Calendar.current.startOfDay(for: Date())
        return sessions
            .filter { $0.date > today && !$0.isCompleted && $0.runType != .rest }
            .sorted { $0.date < $1.date }
            .prefix(count)
            .map { $0 }
    }

    /// Weekly mileage for the current week
    var currentWeekMileage: Double {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return 0
        }
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now

        return sessions
            .filter { $0.date >= weekStart && $0.date < weekEnd && $0.isCompleted }
            .compactMap { $0.actualDistance }
            .reduce(0, +)
    }
}
