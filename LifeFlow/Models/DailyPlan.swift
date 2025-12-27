//
//  DailyPlan.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation

/// Output struct containing the calculated daily requirements for a goal
struct DailyPlan: Equatable {
    /// Required amount to complete today (dollars, hours, etc.)
    let amountNeededToday: Double
    
    /// Current progress status (.onTrack, .behind, .ahead, .completed)
    let status: GoalStatus
    
    /// Original linear rate calculated at goal creation (G/T)
    let baselineRate: Double
    
    /// Current adjusted rate after dynamic recalculation
    let adjustedRate: Double
    
    /// Number of days remaining until deadline
    let daysRemaining: Int
    
    /// Estimated completion date at current pace
    let projectedCompletion: Date?
    
    /// True if the required rate exceeds a safe threshold
    let isUnrealistic: Bool
    
    /// Human-readable status message for UI display
    let warningMessage: String?
    
    /// Progress percentage (0.0 to 1.0, can exceed 1.0 if ahead)
    let progressPercentage: Double
    
    /// Deviation from expected progress (positive = ahead, negative = behind)
    let deviationFromExpected: Double
    
    // MARK: - Convenience Computed Properties
    
    /// Formatted amount for display
    var formattedAmount: String {
        if amountNeededToday < 1 {
            return String(format: "%.2f", amountNeededToday)
        } else if amountNeededToday < 10 {
            return String(format: "%.1f", amountNeededToday)
        } else {
            return String(format: "%.0f", amountNeededToday)
        }
    }
    
    /// Returns true if user needs to catch up significantly
    var needsCatchUp: Bool {
        return status == .behind && adjustedRate > baselineRate * 1.25
    }
    
    /// Severity level for UI styling (0-3)
    var severityLevel: Int {
        guard status == .behind else { return 0 }
        let ratio = adjustedRate / max(baselineRate, 0.001)
        if ratio > 2.0 { return 3 }      // Critical
        if ratio > 1.5 { return 2 }      // Warning
        if ratio > 1.25 { return 1 }     // Caution
        return 0                          // Normal
    }
    
    // MARK: - Static Defaults
    
    /// Default plan for completed goals
    static let completed = DailyPlan(
        amountNeededToday: 0,
        status: .completed,
        baselineRate: 0,
        adjustedRate: 0,
        daysRemaining: 0,
        projectedCompletion: nil,
        isUnrealistic: false,
        warningMessage: nil,
        progressPercentage: 1.0,
        deviationFromExpected: 0
    )
    
    /// Default plan when deadline has passed
    static func expired(remaining: Double) -> DailyPlan {
        DailyPlan(
            amountNeededToday: remaining,
            status: .behind,
            baselineRate: 0,
            adjustedRate: 0,
            daysRemaining: 0,
            projectedCompletion: nil,
            isUnrealistic: true,
            warningMessage: "Deadline has passed",
            progressPercentage: 0,
            deviationFromExpected: -remaining
        )
    }
}
