//
//  Goal.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import Foundation
import SwiftData

@Model
final class Goal {
    /// Unique identifier for the goal
    var id: UUID = UUID()
    
    var title: String
    var targetAmount: Double
    var currentAmount: Double
    var startDate: Date
    var deadline: Date?
    var unit: UnitType
    var type: GoalType
    
    // Enhanced tracking properties
    /// Starting value for calculating progress percentage
    var startValue: Double?
    
    /// Whether the goal has been archived
    var isArchived: Bool = false
    
    /// Optional notes for the goal
    var notes: String?
    
    /// Custom SF Symbol icon name
    var iconName: String?
    
    @Relationship(deleteRule: .cascade) var entries: [DailyEntry] = []
    
    init(
        title: String,
        targetAmount: Double,
        currentAmount: Double = 0,
        startDate: Date = .now,
        deadline: Date? = .now.addingTimeInterval(86400 * 30), // Default 30 days
        unit: UnitType = .count,
        type: GoalType = .custom,
        startValue: Double? = nil,
        iconName: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.startDate = startDate
        self.deadline = deadline
        self.unit = unit
        self.type = type
        self.startValue = startValue ?? currentAmount
        self.isArchived = false
        self.iconName = iconName
    }
    
    var dailyTarget: Double {
        let now = Date.now
        // If deadline is nil or passed, return 0
        guard let deadline = deadline, deadline > now else { return 0 }
        
        let remainingAmount = targetAmount - currentAmount
        if remainingAmount <= 0 { return 0 }
        
        // Calculate remaining days
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: now, to: deadline)
        let remainingDays = max(1, Double(components.day ?? 1))
        
        return remainingAmount / remainingDays
    }
    
    // MARK: - Smart Goal Calculations
    
    /// Get the full daily plan using GoalCalculator
    var dailyPlan: DailyPlan {
        GoalCalculator.calculateDailyPlan(
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            deadline: deadline ?? Date.distantFuture,
            startDate: startDate,
            frequency: .daily,
            historicalAverage: calculateHistoricalAverage(),
            safeThreshold: nil
        )
    }
    
    /// Calculate historical daily average from entries
    func calculateHistoricalAverage() -> Double? {
        guard !entries.isEmpty else { return nil }
        
        // Get unique days with entries
        let calendar = Calendar.current
        let entriesByDay = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }
        
        guard entriesByDay.count > 0 else { return nil }
        
        // Sum values per day, then average across days
        let dailyTotals = entriesByDay.values.map { dayEntries in
            dayEntries.reduce(0) { $0 + $1.valueAdded }
        }
        
        return dailyTotals.reduce(0, +) / Double(dailyTotals.count)
    }
    
    /// Current status based on GoalCalculator
    var status: GoalStatus {
        dailyPlan.status
    }
    
    /// Progress percentage (0.0 to 1.0)
    var progressPercentage: Double {
        guard targetAmount > 0 else { return 0 }
        return min(currentAmount / targetAmount, 1.0)
    }
}

