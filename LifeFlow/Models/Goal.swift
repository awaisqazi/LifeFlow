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
    var title: String
    var targetAmount: Double
    var currentAmount: Double
    var startDate: Date
    var deadline: Date
    var unit: UnitType
    var type: GoalType
    
    @Relationship(deleteRule: .cascade) var entries: [DailyEntry] = []
    
    init(
        title: String,
        targetAmount: Double,
        currentAmount: Double = 0,
        startDate: Date = .now,
        deadline: Date = .now.addingTimeInterval(86400 * 30), // Default 30 days
        unit: UnitType = .count,
        type: GoalType = .targetValue
    ) {
        self.title = title
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.startDate = startDate
        self.deadline = deadline
        self.unit = unit
        self.type = type
    }
    
    var dailyTarget: Double {
        let now = Date.now
        // If deadline is passed or start date is in future, return 0 or remaining
        guard deadline > now else { return 0 }
        
        let remainingAmount = targetAmount - currentAmount
        if remainingAmount <= 0 { return 0 }
        
        // Calculate remaining days
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: now, to: deadline)
        let remainingDays = max(1, Double(components.day ?? 1))
        
        return remainingAmount / remainingDays
    }
}
