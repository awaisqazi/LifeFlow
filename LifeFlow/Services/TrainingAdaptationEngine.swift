//
//  TrainingAdaptationEngine.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import Foundation

/// Describes a modification to a future training session
struct SessionAdjustment {
    let sessionID: UUID
    let newTargetDistance: Double?
    let newRunType: RunType?
    let reason: String
}

/// Pure function service that handles adaptive logic for race training plans.
/// Adjusts future sessions based on performance, effort, and compliance.
struct TrainingAdaptationEngine {

    // MARK: - Post-Run Adaptation

    /// Adapt upcoming sessions based on a completed run
    static func adaptPlan(
        plan: TrainingPlan,
        completedSession: TrainingSession,
        effort: Int
    ) -> [SessionAdjustment] {
        // Taper lock: no adjustments in the final week
        guard !plan.isTaperLocked else { return [] }

        guard let actualDistance = completedSession.actualDistance else { return [] }
        let targetDistance = completedSession.targetDistance

        // Skip adaptation for rest days or zero-target sessions
        guard targetDistance > 0 else { return [] }

        if actualDistance > targetDistance * 1.2 {
            return handleOverAchiever(
                plan: plan,
                completedSession: completedSession,
                actualDistance: actualDistance,
                effort: effort
            )
        } else if actualDistance < targetDistance * 0.8 {
            return handleUnderAchiever(
                plan: plan,
                completedSession: completedSession,
                actualDistance: actualDistance,
                targetDistance: targetDistance
            )
        }

        return []
    }

    // MARK: - Over-Achiever Logic

    /// When user exceeds target by 20%+: don't increase next run (injury risk).
    /// Boost next long run by 5% if recovered. Force rest if back-to-back hard.
    private static func handleOverAchiever(
        plan: TrainingPlan,
        completedSession: TrainingSession,
        actualDistance: Double,
        effort: Int
    ) -> [SessionAdjustment] {
        var adjustments: [SessionAdjustment] = []

        let futureSessions = plan.nextRunningSessions(count: 5)

        // Check if previous day was also a hard effort
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: completedSession.date)
        let previousHard = plan.sessions.first {
            if let y = yesterday {
                return calendar.isDate($0.date, inSameDayAs: y)
                    && $0.isCompleted
                    && ($0.perceivedEffort ?? 2) >= 3
            }
            return false
        }

        if previousHard != nil {
            // Back-to-back hard days: suggest rest for next session
            if let nextSession = futureSessions.first {
                adjustments.append(SessionAdjustment(
                    sessionID: nextSession.id,
                    newTargetDistance: 0,
                    newRunType: .recovery,
                    reason: "Back-to-back hard efforts. Recovery day recommended."
                ))
            }
        } else if effort <= 2 {
            // Effort was easy/moderate: boost next long run by 5%
            if let nextLongRun = futureSessions.first(where: { $0.runType == .longRun }) {
                let boosted = nextLongRun.targetDistance * 1.05
                adjustments.append(SessionAdjustment(
                    sessionID: nextLongRun.id,
                    newTargetDistance: boosted,
                    newRunType: nil,
                    reason: "Strong performance. Long run boosted by 5%."
                ))
            }
        }

        return adjustments
    }

    // MARK: - Under-Achiever Logic

    /// When user falls short: distribute 80% of missed volume across next 3 easy/recovery runs.
    private static func handleUnderAchiever(
        plan: TrainingPlan,
        completedSession: TrainingSession,
        actualDistance: Double,
        targetDistance: Double
    ) -> [SessionAdjustment] {
        let missedVolume = targetDistance - actualDistance
        let redistributeAmount = missedVolume * 0.8
        let addOn = redistributeAmount / 3.0

        let futureSessions = plan.nextRunningSessions(count: 10)
        let easyRuns = futureSessions.filter {
            $0.runType == .recovery || $0.runType == .base
        }.prefix(3)

        return easyRuns.map { session in
            SessionAdjustment(
                sessionID: session.id,
                newTargetDistance: session.targetDistance + addOn,
                newRunType: nil,
                reason: String(format: "Volume redistribution: +%.1f mi from missed run.", addOn)
            )
        }
    }

    // MARK: - Pre-Run Adjustment

    /// Adjust today's session based on "How are you feeling?" slider
    /// - Returns: Adjusted target distance
    static func preRunAdjustment(
        session: TrainingSession,
        feelingScore: Double
    ) -> (adjustedDistance: Double, suggestion: String) {
        let target = session.targetDistance

        if feelingScore >= 0.7 {
            return (target, "Feeling great! Stick to the plan.")
        } else if feelingScore >= 0.3 {
            // Reduce by up to 20% based on how low the feeling is
            let reductionFactor = 1.0 - ((0.7 - feelingScore) / 0.4) * 0.2
            let adjusted = target * reductionFactor
            return (adjusted, String(format: "Adjusted to %.1f mi. Volume moves to your next easy run.", adjusted))
        } else {
            // Very tired: suggest swapping to recovery or rest
            let adjusted = target * 0.5
            return (adjusted, "Take it easy today. Consider a light recovery run or rest.")
        }
    }

    /// Calculate volume to redistribute after a pre-run reduction
    static func redistributePreRunReduction(
        originalTarget: Double,
        adjustedTarget: Double,
        plan: TrainingPlan
    ) -> [SessionAdjustment] {
        let deficit = originalTarget - adjustedTarget
        guard deficit > 0.25 else { return [] }

        // Push to the next weekend long run or easy run
        let futureSessions = plan.nextRunningSessions(count: 5)
        let candidates = futureSessions.filter {
            $0.runType == .base || $0.runType == .recovery || $0.runType == .longRun
        }.prefix(2)

        let addOn = deficit / Double(max(1, candidates.count))

        return candidates.map { session in
            SessionAdjustment(
                sessionID: session.id,
                newTargetDistance: session.targetDistance + addOn,
                newRunType: nil,
                reason: String(format: "Pre-run adjustment redistribution: +%.1f mi.", addOn)
            )
        }
    }

    // MARK: - Compliance Score

    /// Rolling 7-day compliance score (0.0-1.0)
    /// Measures how well the user followed the plan over the last week
    static func calculateComplianceScore(plan: TrainingPlan) -> Double {
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return 1.0
        }

        let recentSessions = plan.sessions.filter {
            $0.date >= weekAgo && $0.date <= now && $0.runType != .rest
        }

        guard !recentSessions.isEmpty else { return 1.0 }

        let scores: [Double] = recentSessions.map { session in
            if session.isSkipped { return 0.0 }
            if !session.isCompleted && session.wasMissed { return 0.0 }
            if !session.isCompleted { return 0.5 } // Future session, neutral
            return min(session.completionRatio, 1.5) / 1.5 // Cap at 1.0 for 150%+
        }

        return scores.reduce(0, +) / Double(scores.count)
    }

    // MARK: - Confidence Score

    /// Overall readiness percentage based on cumulative training compliance
    static func calculateConfidenceScore(plan: TrainingPlan) -> Double {
        let completedRuns = plan.sessions.filter { $0.isCompleted && $0.runType != .rest }
        let pastScheduledRuns = plan.sessions.filter {
            $0.runType != .rest && $0.date < Date()
        }

        guard !pastScheduledRuns.isEmpty else { return 0.5 }

        // Factor 1: Completion rate (weight: 50%)
        let completionRate = Double(completedRuns.count) / Double(pastScheduledRuns.count)

        // Factor 2: Volume accuracy (weight: 30%)
        let volumeAccuracy: Double = {
            let accuracies = completedRuns.compactMap { session -> Double? in
                guard session.targetDistance > 0 else { return nil }
                return min(session.completionRatio, 1.5) / 1.5
            }
            guard !accuracies.isEmpty else { return 0.5 }
            return accuracies.reduce(0, +) / Double(accuracies.count)
        }()

        // Factor 3: Plan progress (weight: 20%)
        let progressFactor = plan.progressPercentage

        let confidence = (completionRate * 0.5) + (volumeAccuracy * 0.3) + (progressFactor * 0.2)
        return min(max(confidence, 0.0), 1.0)
    }

    // MARK: - Life Happens

    /// Shift all future sessions forward by the specified number of days
    static func shiftSchedule(plan: TrainingPlan, byDays days: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for session in plan.sessions where session.date >= today && !session.isCompleted {
            if let newDate = calendar.date(byAdding: .day, value: days, to: session.date) {
                session.date = newDate
            }
        }
    }

    /// Check if shifting would push sessions past the race date
    static func canShiftSchedule(plan: TrainingPlan, byDays days: Int) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let futureSessions = plan.sessions.filter { $0.date >= today && !$0.isCompleted }
        guard let lastSession = futureSessions.max(by: { $0.date < $1.date }) else {
            return true
        }

        guard let shiftedDate = calendar.date(byAdding: .day, value: days, to: lastSession.date) else {
            return false
        }

        return shiftedDate <= plan.raceDate
    }

    // MARK: - Apply Adjustments

    /// Apply a set of adjustments to the plan's sessions
    static func applyAdjustments(_ adjustments: [SessionAdjustment], to plan: TrainingPlan) {
        for adjustment in adjustments {
            guard let session = plan.sessions.first(where: { $0.id == adjustment.sessionID }) else {
                continue
            }
            if let newDistance = adjustment.newTargetDistance {
                session.targetDistance = newDistance
            }
            if let newType = adjustment.newRunType {
                session.runType = newType
            }
        }
    }
}
