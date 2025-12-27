//
//  GoalCalculator.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation

/// Smart Goal Calculator service for the Horizon planning tab.
/// Transforms passive tracking into active advising by calculating
/// dynamic daily requirements and detecting schedule status.
struct GoalCalculator {
    
    // MARK: - Configuration
    
    /// Tolerance for determining "on track" status (5% deviation allowed)
    static let onTrackTolerance: Double = 0.05
    
    /// Threshold multiplier for detecting unrealistic catch-up requirements
    static let unrealisticThreshold: Double = 1.5
    
    /// Maximum study hours per day considered realistic
    static let maxRealisticStudyHours: Double = 8.0
    
    /// Maximum savings rate as percentage of assumed income for "unrealistic" flag
    static let maxRealisticSavingsRatio: Double = 0.30
    
    // MARK: - Main Calculation Method
    
    /// Calculate the daily plan for a goal
    /// - Parameters:
    ///   - targetAmount: The goal target (e.g., $2000, 100 hours)
    ///   - currentAmount: Current progress toward the goal
    ///   - deadline: Goal deadline date
    ///   - startDate: When the goal was created
    ///   - frequency: Daily or weekly calculation
    ///   - historicalAverage: Optional historical daily average for unrealistic detection
    ///   - safeThreshold: Optional threshold for unrealistic detection (e.g., 5% of monthly income)
    /// - Returns: A DailyPlan with all calculated values
    static func calculateDailyPlan(
        targetAmount: Double,
        currentAmount: Double,
        deadline: Date,
        startDate: Date,
        frequency: GoalFrequency = .daily,
        historicalAverage: Double? = nil,
        safeThreshold: Double? = nil
    ) -> DailyPlan {
        let now = Date()
        let calendar = Calendar.current
        
        // Calculate remaining amount (Gap Analysis: G)
        let remainingAmount = targetAmount - currentAmount
        
        // Goal already completed
        if remainingAmount <= 0 {
            return .completed
        }
        
        // Calculate days remaining (Time Delta: T)
        let daysRemaining = calendar.dateComponents([.day], from: now, to: deadline).day ?? 0
        
        // Deadline has passed
        if daysRemaining <= 0 {
            return .expired(remaining: remainingAmount)
        }
        
        // Calculate total days from start to deadline
        let totalDays = calendar.dateComponents([.day], from: startDate, to: deadline).day ?? 1
        let totalDaysDouble = max(Double(totalDays), 1.0)
        
        // Calculate days elapsed
        let daysElapsed = calendar.dateComponents([.day], from: startDate, to: now).day ?? 0
        let daysElapsedDouble = Double(max(daysElapsed, 0))
        
        // MARK: - Core Algorithm
        
        // Original baseline rate (G/T at start)
        let baselineRate = targetAmount / totalDaysDouble
        
        // Current adjusted rate (dynamic recalculation)
        let adjustedRate = remainingAmount / Double(daysRemaining)
        
        // Convert to frequency-based amount
        let amountNeededToday = adjustedRate * Double(frequency.daysPerPeriod)
        
        // MARK: - Progress Analysis
        
        // Expected progress at this point (linear interpolation)
        let expectedProgress = (daysElapsedDouble / totalDaysDouble) * targetAmount
        
        // Actual progress percentage
        let progressPercentage = currentAmount / targetAmount
        
        // Deviation from expected (positive = ahead, negative = behind)
        let deviationFromExpected = currentAmount - expectedProgress
        
        // MARK: - Status Determination
        
        let status = determineStatus(
            expectedProgress: expectedProgress,
            actualProgress: currentAmount,
            targetAmount: targetAmount
        )
        
        // MARK: - Unrealistic Detection
        
        let isUnrealistic = checkIfUnrealistic(
            requiredRate: adjustedRate,
            baselineRate: baselineRate,
            historicalAverage: historicalAverage,
            safeThreshold: safeThreshold
        )
        
        // MARK: - Projected Completion
        
        let projectedCompletion = calculateProjectedCompletion(
            currentAmount: currentAmount,
            targetAmount: targetAmount,
            daysElapsed: daysElapsed,
            from: now
        )
        
        // MARK: - Warning Message
        
        let warningMessage = generateWarningMessage(
            status: status,
            adjustedRate: adjustedRate,
            baselineRate: baselineRate,
            isUnrealistic: isUnrealistic,
            daysRemaining: daysRemaining
        )
        
        return DailyPlan(
            amountNeededToday: amountNeededToday,
            status: status,
            baselineRate: baselineRate,
            adjustedRate: adjustedRate,
            daysRemaining: daysRemaining,
            projectedCompletion: projectedCompletion,
            isUnrealistic: isUnrealistic,
            warningMessage: warningMessage,
            progressPercentage: progressPercentage,
            deviationFromExpected: deviationFromExpected
        )
    }
    
    // MARK: - Status Determination
    
    /// Determine goal status based on expected vs actual progress
    private static func determineStatus(
        expectedProgress: Double,
        actualProgress: Double,
        targetAmount: Double
    ) -> GoalStatus {
        // Completed
        if actualProgress >= targetAmount {
            return .completed
        }
        
        // Calculate deviation as percentage of target
        let tolerance = targetAmount * onTrackTolerance
        let deviation = actualProgress - expectedProgress
        
        if deviation > tolerance {
            return .ahead
        } else if deviation < -tolerance * 2 {
            return .behind
        } else {
            return .onTrack
        }
    }
    
    // MARK: - Unrealistic Detection
    
    /// Check if the required rate is unrealistic
    private static func checkIfUnrealistic(
        requiredRate: Double,
        baselineRate: Double,
        historicalAverage: Double?,
        safeThreshold: Double?
    ) -> Bool {
        // Check against historical average (study goals)
        if let historical = historicalAverage, historical > 0 {
            if requiredRate > historical * unrealisticThreshold {
                return true
            }
        }
        
        // Check against safe threshold (financial goals)
        if let threshold = safeThreshold, threshold > 0 {
            if requiredRate > threshold {
                return true
            }
        }
        
        // Check if required rate has spiked significantly from baseline
        if baselineRate > 0 && requiredRate > baselineRate * 2.0 {
            return true
        }
        
        return false
    }
    
    // MARK: - Projected Completion
    
    /// Calculate projected completion date based on current pace
    private static func calculateProjectedCompletion(
        currentAmount: Double,
        targetAmount: Double,
        daysElapsed: Int,
        from now: Date
    ) -> Date? {
        // Avoid division by zero
        guard daysElapsed > 0 && currentAmount > 0 else { return nil }
        
        // Current daily rate
        let currentDailyRate = currentAmount / Double(daysElapsed)
        
        // Remaining amount
        let remaining = targetAmount - currentAmount
        
        // Days needed to complete at current rate
        let daysNeeded = remaining / currentDailyRate
        
        // Projected date
        return Calendar.current.date(
            byAdding: .day,
            value: Int(ceil(daysNeeded)),
            to: now
        )
    }
    
    // MARK: - Warning Messages
    
    /// Generate a human-readable warning message based on status
    private static func generateWarningMessage(
        status: GoalStatus,
        adjustedRate: Double,
        baselineRate: Double,
        isUnrealistic: Bool,
        daysRemaining: Int
    ) -> String? {
        if status == .completed {
            return nil
        }
        
        if isUnrealistic {
            let multiplier = adjustedRate / max(baselineRate, 0.001)
            return String(format: "Required rate is %.1fx higher than planned. Consider extending your deadline.", multiplier)
        }
        
        switch status {
        case .behind:
            if daysRemaining <= 7 {
                return "Only \(daysRemaining) days left. You need to increase your daily effort."
            }
            return "You're behind schedule. Increase daily progress to catch up."
            
        case .ahead:
            return "Great progress! You can maintain this pace or take it easy."
            
        case .onTrack:
            return nil
            
        case .completed:
            return nil
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Calculate expected progress at current date
    /// - Parameters:
    ///   - targetAmount: Goal target amount
    ///   - startDate: When the goal started
    ///   - deadline: Goal deadline
    /// - Returns: Expected progress value at current date
    static func expectedProgress(
        targetAmount: Double,
        startDate: Date,
        deadline: Date
    ) -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        let totalDays = calendar.dateComponents([.day], from: startDate, to: deadline).day ?? 1
        let daysElapsed = calendar.dateComponents([.day], from: startDate, to: now).day ?? 0
        
        let progress = (Double(daysElapsed) / Double(max(totalDays, 1))) * targetAmount
        return max(0, min(progress, targetAmount))
    }
    
    /// Quick check if a goal rate is unrealistic
    /// - Parameters:
    ///   - requiredRate: The current required daily rate
    ///   - safeThreshold: The maximum safe rate
    /// - Returns: True if rate exceeds threshold
    static func isUnrealistic(
        requiredRate: Double,
        safeThreshold: Double
    ) -> Bool {
        return requiredRate > safeThreshold
    }
    
    // MARK: - Study Goal Specific
    
    /// Calculate daily plan for study/time accumulation goals
    /// Includes special logic for "catch-up vs realist" detection
    /// - Parameters:
    ///   - totalHoursNeeded: Total study hours required
    ///   - hoursCompleted: Hours already completed
    ///   - deadline: Target completion date
    ///   - startDate: When studying began
    ///   - historicalDailyAverage: User's typical daily study hours
    /// - Returns: DailyPlan with study-specific calculations
    static func calculateStudyPlan(
        totalHoursNeeded: Double,
        hoursCompleted: Double,
        deadline: Date,
        startDate: Date,
        historicalDailyAverage: Double = 2.0
    ) -> DailyPlan {
        let plan = calculateDailyPlan(
            targetAmount: totalHoursNeeded,
            currentAmount: hoursCompleted,
            deadline: deadline,
            startDate: startDate,
            frequency: .daily,
            historicalAverage: historicalDailyAverage,
            safeThreshold: maxRealisticStudyHours
        )
        
        return plan
    }
    
    // MARK: - Financial Goal Specific
    
    /// Calculate daily plan for financial/savings goals
    /// - Parameters:
    ///   - targetSavings: Target amount to save
    ///   - currentSavings: Current savings toward goal
    ///   - deadline: Target date
    ///   - startDate: When saving began
    ///   - monthlyIncome: Optional monthly income for unrealistic threshold
    /// - Returns: DailyPlan with financial-specific calculations
    static func calculateFinancialPlan(
        targetSavings: Double,
        currentSavings: Double,
        deadline: Date,
        startDate: Date,
        monthlyIncome: Double? = nil
    ) -> DailyPlan {
        // Calculate safe daily threshold as 5% of monthly income spread over 30 days
        let safeThreshold: Double? = monthlyIncome.map { ($0 * 0.05) / 30.0 }
        
        return calculateDailyPlan(
            targetAmount: targetSavings,
            currentAmount: currentSavings,
            deadline: deadline,
            startDate: startDate,
            frequency: .daily,
            historicalAverage: nil,
            safeThreshold: safeThreshold
        )
    }
}
