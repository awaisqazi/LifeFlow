//
//  MarathonCoachManager.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import Foundation
import SwiftData
import SwiftUI

/// Training status categories for UI color coding
enum TrainingStatus {
    case onTrack
    case struggling
    case crushingIt

    var colorName: String {
        switch self {
        case .onTrack: return "green"
        case .struggling: return "orange"
        case .crushingIt: return "purple"
        }
    }

    var label: String {
        switch self {
        case .onTrack: return "On Track"
        case .struggling: return "Needs Attention"
        case .crushingIt: return "Crushing It"
        }
    }
}

/// Orchestrates the marathon coach feature: plan lifecycle,
/// session completion, adaptation, HealthKit matching, and GymMode integration.
@Observable
final class MarathonCoachManager {

    // MARK: - State

    private(set) var activePlan: TrainingPlan?
    private(set) var todaysSession: TrainingSession?
    private(set) var isGeneratingPlan: Bool = false
    private(set) var lastAdaptationSummary: String?
    var showPostRunCheckIn: Bool = false
    var showPreRunAdjustment: Bool = false
    var completedSessionForCheckIn: TrainingSession?
    
    private struct SessionBaseline {
        let targetDistance: Double
        let runType: RunType
    }
    
    private struct AutoCompletionSnapshot {
        let sessionBaselines: [UUID: SessionBaseline]
        let originalActualDistance: Double?
        let originalPerceivedEffort: Int?
        let originalIsCompleted: Bool
        let originalSummary: String?
    }
    
    private var autoCompletionSnapshots: [UUID: AutoCompletionSnapshot] = [:]

    // MARK: - Plan Lifecycle

    /// Create a new training plan and generate all sessions
    func createPlan(
        raceDistance: RaceDistance,
        raceDate: Date,
        weeklyMileage: Double,
        longestRun: Double,
        restDays: [Int],
        modelContext: ModelContext
    ) {
        isGeneratingPlan = true

        let plan = TrainingPlan(
            raceDistance: raceDistance,
            raceDate: raceDate,
            startDate: Date(),
            weeklyMileage: weeklyMileage,
            longestRecentRun: longestRun,
            restDays: restDays
        )

        // Generate training sessions
        let sessions = TrainingPlanGenerator.generateSessions(for: plan)
        for session in sessions {
            session.plan = plan
            plan.sessions.append(session)
        }

        modelContext.insert(plan)
        try? modelContext.save()

        activePlan = plan
        todaysSession = plan.todaysSession
        isGeneratingPlan = false
    }

    /// Load the active training plan from the database
    func loadActivePlan(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<TrainingPlan>(
            predicate: #Predicate { $0.isActive && !$0.isCompleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let plans = try modelContext.fetch(descriptor)
            activePlan = plans.first
            todaysSession = activePlan?.todaysSession
        } catch {
            activePlan = nil
            todaysSession = nil
        }
    }

    /// Cancel and deactivate the current plan
    func cancelPlan(modelContext: ModelContext) {
        guard let plan = activePlan else { return }
        plan.isActive = false
        try? modelContext.save()
        activePlan = nil
        todaysSession = nil
        autoCompletionSnapshots.removeAll()
    }

    // MARK: - Session Completion

    /// Complete a training session and trigger adaptation
    func completeSession(
        _ session: TrainingSession,
        actualDistance: Double,
        effort: Int,
        modelContext: ModelContext
    ) {
        autoCompletionSnapshots[session.id] = nil
        applyCompletion(to: session, actualDistance: actualDistance, effort: effort)
        try? modelContext.save()
    }
    
    /// Immediately auto-complete a session after guided workout finish.
    /// Uses a moderate default effort until user refines in post-run check-in.
    func autoCompleteSession(
        _ session: TrainingSession,
        actualDistance: Double,
        modelContext: ModelContext,
        defaultEffort: Int = 2
    ) {
        guard let plan = activePlan else { return }
        
        let baseline = Dictionary(uniqueKeysWithValues: plan.sessions.map { session in
            (session.id, SessionBaseline(targetDistance: session.targetDistance, runType: session.runType))
        })
        
        autoCompletionSnapshots[session.id] = AutoCompletionSnapshot(
            sessionBaselines: baseline,
            originalActualDistance: session.actualDistance,
            originalPerceivedEffort: session.perceivedEffort,
            originalIsCompleted: session.isCompleted,
            originalSummary: lastAdaptationSummary
        )
        
        applyCompletion(to: session, actualDistance: actualDistance, effort: defaultEffort)
        try? modelContext.save()
    }
    
    /// Refine a previously auto-completed session with user-provided check-in data.
    /// Reverts the auto-adaptation baseline first to avoid compounding adjustments.
    func refineCompletedSession(
        _ session: TrainingSession,
        actualDistance: Double,
        effort: Int,
        modelContext: ModelContext
    ) {
        if let snapshot = autoCompletionSnapshots[session.id],
           let plan = activePlan {
            for planSession in plan.sessions {
                guard let baseline = snapshot.sessionBaselines[planSession.id] else { continue }
                planSession.targetDistance = baseline.targetDistance
                planSession.runType = baseline.runType
            }
            
            session.actualDistance = snapshot.originalActualDistance
            session.perceivedEffort = snapshot.originalPerceivedEffort
            session.isCompleted = snapshot.originalIsCompleted
            lastAdaptationSummary = snapshot.originalSummary
        }
        
        autoCompletionSnapshots[session.id] = nil
        applyCompletion(to: session, actualDistance: actualDistance, effort: effort)
        try? modelContext.save()
    }
    
    /// Log a cross-training day as complete and refresh plan status.
    func markCrossTrainingComplete(
        session: TrainingSession,
        activityName: String,
        durationMinutes: Int,
        modelContext: ModelContext
    ) {
        session.actualDistance = session.actualDistance ?? 0
        session.perceivedEffort = session.perceivedEffort ?? 2
        session.isCompleted = true
        session.notes = "\(activityName) - \(durationMinutes) min"
        
        if let plan = activePlan {
            plan.complianceScore = TrainingAdaptationEngine.calculateComplianceScore(plan: plan)
            plan.confidenceScore = TrainingAdaptationEngine.calculateConfidenceScore(plan: plan)
            lastAdaptationSummary = "\(activityName) logged. Great consistency."
            todaysSession = plan.todaysSession
        }
        
        autoCompletionSnapshots[session.id] = nil
        try? modelContext.save()
    }
    
    private func applyCompletion(
        to session: TrainingSession,
        actualDistance: Double,
        effort: Int
    ) {
        session.actualDistance = actualDistance
        session.perceivedEffort = effort
        session.isCompleted = true
        
        guard let plan = activePlan else { return }
        
        let adjustments = TrainingAdaptationEngine.adaptPlan(
            plan: plan,
            completedSession: session,
            effort: effort
        )
        
        TrainingAdaptationEngine.applyAdjustments(adjustments, to: plan)
        
        plan.complianceScore = TrainingAdaptationEngine.calculateComplianceScore(plan: plan)
        plan.confidenceScore = TrainingAdaptationEngine.calculateConfidenceScore(plan: plan)
        
        if let firstAdjustment = adjustments.first {
            lastAdaptationSummary = firstAdjustment.reason
        } else {
            lastAdaptationSummary = nil
        }
        
        if plan.raceDate < Date() {
            plan.isCompleted = true
        }
        
        if actualDistance > session.targetDistance * 1.15 && effort <= 2 {
            lastAdaptationSummary = "Crushing it! Your confidence score just got a boost."
        }
        
        todaysSession = plan.todaysSession
    }

    /// Apply pre-run feeling adjustment to today's session
    func applyPreRunAdjustment(
        session: TrainingSession,
        feelingScore: Double,
        modelContext: ModelContext
    ) {
        let (adjustedDistance, suggestion) = TrainingAdaptationEngine.preRunAdjustment(
            session: session,
            feelingScore: feelingScore
        )

        let originalTarget = session.targetDistance
        session.targetDistance = adjustedDistance
        session.preRunFeeling = feelingScore

        // Redistribute any deficit
        if let plan = activePlan {
            let redistributions = TrainingAdaptationEngine.redistributePreRunReduction(
                originalTarget: originalTarget,
                adjustedTarget: adjustedDistance,
                plan: plan
            )
            TrainingAdaptationEngine.applyAdjustments(redistributions, to: plan)
        }

        lastAdaptationSummary = suggestion
        try? modelContext.save()
    }

    // MARK: - Life Happens

    /// Shift all future sessions by 1 day
    func lifeHappens(modelContext: ModelContext) -> Bool {
        guard let plan = activePlan else { return false }

        guard TrainingAdaptationEngine.canShiftSchedule(plan: plan, byDays: 1) else {
            return false
        }

        TrainingAdaptationEngine.shiftSchedule(plan: plan, byDays: 1)
        try? modelContext.save()
        todaysSession = plan.todaysSession
        return true
    }

    /// Take target volume from missed runs in the last week and spread across
    /// next 3 Base/Recovery runs, capped at +15% per session.
    func distributeMissedVolume(modelContext: ModelContext) {
        guard let plan = activePlan else { return }
        
        let adjustments = TrainingAdaptationEngine.redistributeMissedVolume(plan: plan)
        guard !adjustments.isEmpty else { return }
        
        TrainingAdaptationEngine.applyAdjustments(adjustments, to: plan)
        lastAdaptationSummary = adjustments.first?.reason
        
        try? modelContext.save()
    }

    // MARK: - HealthKit Matching

    /// Match HealthKit running workouts to training sessions by date
    func matchHealthKitRuns(
        hkWorkouts: [WorkoutSession],
        modelContext: ModelContext
    ) {
        guard let plan = activePlan else { return }
        let calendar = Calendar.current

        let runningWorkouts = hkWorkouts.filter {
            $0.type == "Running" && $0.source == "HealthKit"
        }

        for hkWorkout in runningWorkouts {
            // Find the training session for the same day
            let matchingSession = plan.sessions.first { session in
                calendar.isDate(session.date, inSameDayAs: hkWorkout.timestamp)
                && !session.isCompleted
                && session.runType != .rest
            }

            guard let session = matchingSession else { continue }

            // Get distance from the workout exercises/sets if available
            let distance = hkWorkout.exercises
                .flatMap { $0.sets }
                .compactMap { $0.distance }
                .reduce(0, +)

            if distance > 0 {
                session.actualDistance = distance
                session.healthKitWorkoutID = hkWorkout.id
                // Don't auto-complete: wait for user check-in to get perceived effort
                completedSessionForCheckIn = session
                showPostRunCheckIn = true
            }
        }

        try? modelContext.save()
    }

    // MARK: - GymMode Integration

    /// Build a WorkoutSession pre-populated for a training run
    func buildGymModeSession(for trainingSession: TrainingSession) -> WorkoutSession {
        let workout = WorkoutSession(
            title: "\(trainingSession.runType.displayName) - \(String(format: "%.1f", trainingSession.targetDistance)) mi",
            type: "Running"
        )

        switch trainingSession.runType {
        case .speedWork:
            // Create interval workout: warm-up + repeats + cool-down
            let exercise = workout.addExercise(name: "Treadmill", type: .cardio)

            // Warm-up set
            let warmup = ExerciseSet(orderIndex: 0)
            warmup.duration = 600 // 10 min warm-up
            warmup.speed = 5.0
            exercise.sets.append(warmup)

            // Speed intervals (400m repeats)
            let intervalCount = max(4, Int(trainingSession.targetDistance / 0.5))
            for i in 0..<intervalCount {
                let interval = ExerciseSet(orderIndex: 1 + i)
                interval.duration = 120 // 2 min hard
                interval.speed = 8.0
                exercise.sets.append(interval)

                // Recovery between intervals
                if i < intervalCount - 1 {
                    let recovery = ExerciseSet(orderIndex: 1 + intervalCount + i)
                    recovery.duration = 90 // 1.5 min recovery
                    recovery.speed = 5.0
                    exercise.sets.append(recovery)
                }
            }

            // Cool-down set
            let cooldown = ExerciseSet(orderIndex: 100)
            cooldown.duration = 600
            cooldown.speed = 4.5
            exercise.sets.append(cooldown)

        case .tempo:
            // Sustained effort: warm-up + tempo block + cool-down
            let exercise = workout.addExercise(name: "Treadmill", type: .cardio)

            let warmup = ExerciseSet(orderIndex: 0)
            warmup.duration = 600
            warmup.speed = 5.0
            exercise.sets.append(warmup)

            let tempoBlock = ExerciseSet(orderIndex: 1)
            tempoBlock.distance = trainingSession.targetDistance * 0.7
            tempoBlock.speed = 7.0
            exercise.sets.append(tempoBlock)

            let cooldown = ExerciseSet(orderIndex: 2)
            cooldown.duration = 600
            cooldown.speed = 4.5
            exercise.sets.append(cooldown)

        default:
            // Simple distance-based run
            let exercise = workout.addExercise(name: "Treadmill", type: .cardio)
            let mainSet = ExerciseSet(orderIndex: 0)
            mainSet.distance = trainingSession.targetDistance
            mainSet.speed = trainingSession.runType == .recovery ? 5.0 : 6.0
            exercise.sets.append(mainSet)
        }

        return workout
    }

    // MARK: - Computed Helpers

    /// Current training status based on compliance score
    var trainingStatus: TrainingStatus {
        guard let plan = activePlan else { return .onTrack }
        if plan.complianceScore >= 0.85 {
            return .crushingIt
        } else if plan.complianceScore >= 0.6 {
            return .onTrack
        } else {
            return .struggling
        }
    }

    /// Status color for UI
    var statusColor: Color {
        switch trainingStatus {
        case .onTrack: return .green
        case .struggling: return .orange
        case .crushingIt: return .purple
        }
    }

    /// Formatted confidence score as percentage string
    var confidenceDisplay: String {
        guard let plan = activePlan else { return "0%" }
        return "\(Int(plan.confidenceScore * 100))%"
    }

    /// Refresh today's session reference
    func refreshTodaysSession() {
        todaysSession = activePlan?.todaysSession
    }
}
