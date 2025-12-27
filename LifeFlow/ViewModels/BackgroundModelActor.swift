//
//  BackgroundModelActor.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation
import SwiftData

/// ModelActor for performing heavy database operations off the main thread.
/// This prevents UI stutter during complex calculations or batch updates.
@ModelActor
actor BackgroundModelActor {
    
    // MARK: - Goal Operations
    
    /// Recalculates progress for all active (non-archived) goals.
    /// Call this after bulk data imports or when entries are batch-updated.
    func recalculateAllGoalProgress() async throws {
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { !$0.isArchived }
        )
        let goals = try modelContext.fetch(descriptor)
        
        for goal in goals {
            // Sum all entry values for this goal
            let totalValue = goal.entries.reduce(0.0) { $0 + $1.valueAdded }
            goal.currentAmount = (goal.startValue ?? 0) + totalValue
        }
        
        try modelContext.save()
    }
    
    /// Archives all completed goals (where currentAmount >= targetAmount)
    func archiveCompletedGoals() async throws {
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { !$0.isArchived }
        )
        let goals = try modelContext.fetch(descriptor)
        
        for goal in goals {
            if goal.currentAmount >= goal.targetAmount {
                goal.isArchived = true
            }
        }
        
        try modelContext.save()
    }
    
    // MARK: - Workout Operations
    
    /// Updates workout statistics for a given date range.
    /// Recalculates duration and calories from exercise sets.
    func updateWorkoutStatistics(for dateRange: ClosedRange<Date>) async throws {
        let startDate = dateRange.lowerBound
        let endDate = dateRange.upperBound
        
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.timestamp >= startDate && session.timestamp <= endDate
            }
        )
        let sessions = try modelContext.fetch(descriptor)
        
        for session in sessions {
            // Calculate total duration from all exercise sets
            var totalDuration: TimeInterval = 0
            for exercise in session.exercises {
                for set in exercise.sets where set.isCompleted {
                    totalDuration += set.duration ?? 0
                }
            }
            
            // Update session duration if we have calculated data
            if totalDuration > 0 {
                session.duration = totalDuration
            }
        }
        
        try modelContext.save()
    }
    
    /// Deletes all archived goals older than the specified date
    func purgeOldArchivedGoals(before date: Date) async throws {
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { goal in
                goal.isArchived && goal.startDate < date
            }
        )
        let goals = try modelContext.fetch(descriptor)
        
        for goal in goals {
            modelContext.delete(goal)
        }
        
        try modelContext.save()
    }
    
    // MARK: - Data Aggregation
    
    /// Fetches aggregated hydration data for analytics.
    /// Returns an array of (date, totalOunces) tuples.
    func fetchHydrationData(for dateRange: ClosedRange<Date>) async throws -> [(Date, Double)] {
        let startDate = dateRange.lowerBound
        let endDate = dateRange.upperBound
        
        let descriptor = FetchDescriptor<DayLog>(
            predicate: #Predicate { log in
                log.date >= startDate && log.date <= endDate
            },
            sortBy: [SortDescriptor(\.date)]
        )
        let logs = try modelContext.fetch(descriptor)
        
        return logs.map { ($0.date, $0.waterIntake) }
    }
}
