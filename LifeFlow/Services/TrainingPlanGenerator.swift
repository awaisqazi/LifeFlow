//
//  TrainingPlanGenerator.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import Foundation

/// Pure function service that generates a race training plan using backwards planning.
/// Base -> Build (+10%/week) -> Peak (highest volume) -> Taper (volume reduction) -> Race Day
struct TrainingPlanGenerator {

    // MARK: - Main Generation

    /// Generate all training sessions for a plan
    static func generateSessions(for plan: TrainingPlan) -> [TrainingSession] {
        let calendar = Calendar.current
        let totalWeeks = weeksUntilRace(from: plan.startDate, to: plan.raceDate)

        guard totalWeeks >= 2 else { return [] }

        // Phase allocation (backwards from race date)
        let taperWeeks = min(plan.raceDistance.typicalTaperWeeks, totalWeeks - 1)
        let peakWeeks = min(plan.raceDistance.peakWeeks, max(0, totalWeeks - taperWeeks - 1))
        let remainingWeeks = totalWeeks - taperWeeks - peakWeeks
        let buildWeeks = max(0, remainingWeeks * 2 / 3)
        let baseWeeks = max(1, remainingWeeks - buildWeeks)

        let phaseSchedule = buildPhaseSchedule(
            baseWeeks: baseWeeks,
            buildWeeks: buildWeeks,
            peakWeeks: peakWeeks,
            taperWeeks: taperWeeks
        )

        var sessions: [TrainingSession] = []
        var currentWeekMileage = plan.weeklyMileage

        for (weekIndex, phase) in phaseSchedule.enumerated() {
            let weekStartDate = calendar.date(byAdding: .weekOfYear, value: weekIndex, to: plan.startDate) ?? plan.startDate

            // Calculate this week's target mileage
            currentWeekMileage = weeklyMileage(
                baseMileage: plan.weeklyMileage,
                phase: phase,
                weekIndex: weekIndex,
                baseWeeks: baseWeeks,
                buildWeeks: buildWeeks,
                peakWeeks: peakWeeks,
                taperWeeks: taperWeeks,
                raceDistance: plan.raceDistance
            )

            // Get available training days for this week (excluding rest days)
            let weekSessions = generateWeekSessions(
                weekStart: weekStartDate,
                weeklyMiles: currentWeekMileage,
                phase: phase,
                raceDistance: plan.raceDistance,
                restDays: Set(plan.restDays),
                calendar: calendar
            )

            sessions.append(contentsOf: weekSessions)
        }

        return sessions
    }

    // MARK: - Phase Schedule

    private static func buildPhaseSchedule(
        baseWeeks: Int,
        buildWeeks: Int,
        peakWeeks: Int,
        taperWeeks: Int
    ) -> [TrainingPhase] {
        var schedule: [TrainingPhase] = []
        schedule.append(contentsOf: Array(repeating: .base, count: baseWeeks))
        schedule.append(contentsOf: Array(repeating: .build, count: buildWeeks))
        schedule.append(contentsOf: Array(repeating: .peak, count: peakWeeks))
        schedule.append(contentsOf: Array(repeating: .taper, count: taperWeeks))
        return schedule
    }

    // MARK: - Weekly Mileage Calculation

    private static func weeklyMileage(
        baseMileage: Double,
        phase: TrainingPhase,
        weekIndex: Int,
        baseWeeks: Int,
        buildWeeks: Int,
        peakWeeks: Int,
        taperWeeks: Int,
        raceDistance: RaceDistance
    ) -> Double {
        switch phase {
        case .base:
            // Maintain current mileage, gentle ramp if very low
            let minBase = max(baseMileage, raceDistance.distanceInMiles * 0.5)
            return minBase

        case .build:
            // +10% per week from base
            let buildWeekNumber = weekIndex - baseWeeks
            let multiplier = pow(1.10, Double(buildWeekNumber + 1))
            return baseMileage * multiplier

        case .peak:
            // Highest volume: full build multiplied out
            let fullBuildMultiplier = pow(1.10, Double(buildWeeks))
            let peakMileage = baseMileage * fullBuildMultiplier
            return peakMileage

        case .taper:
            // Progressive reduction: 75%, 50%, 30% of peak
            let fullBuildMultiplier = pow(1.10, Double(buildWeeks))
            let peakMileage = baseMileage * fullBuildMultiplier
            let taperWeekNumber = weekIndex - baseWeeks - buildWeeks - peakWeeks
            let taperFractions = [0.75, 0.50, 0.30]
            let fraction = taperWeekNumber < taperFractions.count
                ? taperFractions[taperWeekNumber]
                : 0.30
            return peakMileage * fraction
        }
    }

    // MARK: - Week Session Generation

    private static func generateWeekSessions(
        weekStart: Date,
        weeklyMiles: Double,
        phase: TrainingPhase,
        raceDistance: RaceDistance,
        restDays: Set<Int>,
        calendar: Calendar
    ) -> [TrainingSession] {
        var sessions: [TrainingSession] = []

        // Generate 7 days for this week
        for dayOffset in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: dayDate)

            // Check if this is a user-specified rest day
            if restDays.contains(weekday) {
                sessions.append(TrainingSession(date: dayDate, runType: .rest, targetDistance: 0))
                continue
            }

            sessions.append(TrainingSession(date: dayDate, runType: .rest, targetDistance: 0))
        }

        // Now assign run types to non-rest days
        let availableIndices = sessions.enumerated()
            .filter { !restDays.contains(calendar.component(.weekday, from: $0.element.date)) }
            .map { $0.offset }

        guard !availableIndices.isEmpty else { return sessions }

        // Assign run types based on phase
        let runAssignments = assignRunTypes(
            availableDayCount: availableIndices.count,
            phase: phase,
            raceDistance: raceDistance
        )

        // Distribute mileage across assigned run types
        let mileageDistribution = distributeMileage(
            weeklyMiles: weeklyMiles,
            assignments: runAssignments,
            longRunCap: raceDistance.distanceInMiles * raceDistance.longRunCapFraction
        )

        // Apply assignments to available days
        for (i, dayIndex) in availableIndices.enumerated() {
            if i < runAssignments.count {
                sessions[dayIndex] = TrainingSession(
                    date: sessions[dayIndex].date,
                    runType: runAssignments[i],
                    targetDistance: mileageDistribution[i]
                )
            }
        }

        return sessions
    }

    // MARK: - Run Type Assignment

    private static func assignRunTypes(
        availableDayCount: Int,
        phase: TrainingPhase,
        raceDistance: RaceDistance
    ) -> [RunType] {
        guard availableDayCount > 0 else { return [] }

        var types: [RunType] = []

        switch phase {
        case .base:
            // 1 long run, rest are base/recovery
            types.append(.longRun)
            if availableDayCount > 2 { types.append(.recovery) }
            while types.count < availableDayCount {
                types.append(.base)
            }

        case .build:
            // 1 long run, 1 speed work, rest are base/recovery
            types.append(.longRun)
            if availableDayCount > 1 { types.append(.speedWork) }
            if availableDayCount > 3 { types.append(.recovery) }
            while types.count < availableDayCount {
                types.append(.base)
            }

        case .peak:
            // 1 long run, 1 speed work, 1 tempo, rest are base/recovery
            types.append(.longRun)
            if availableDayCount > 1 { types.append(.speedWork) }
            if availableDayCount > 2 { types.append(.tempo) }
            if availableDayCount > 4 { types.append(.recovery) }
            while types.count < availableDayCount {
                types.append(.base)
            }

        case .taper:
            // 1 shorter long run, 1 easy speed session, rest recovery
            types.append(.longRun)
            if availableDayCount > 2 { types.append(.speedWork) }
            while types.count < availableDayCount {
                types.append(.recovery)
            }
        }

        // Reorder: put long run later in the week (index 4-5 = Fri/Sat),
        // speed work mid-week, recovery spread out
        return reorderForWeek(types, availableDays: availableDayCount)
    }

    /// Reorder run types so long run is near the end of the week,
    /// speed work is mid-week, and recovery days are spread out
    private static func reorderForWeek(_ types: [RunType], availableDays: Int) -> [RunType] {
        var result = Array(repeating: RunType.base, count: types.count)
        let count = types.count

        // Place long run near end of available days
        let longRunIndex = max(0, count - 2)
        // Place speed work in middle
        let speedIndex = count > 3 ? 2 : (count > 1 ? 1 : 0)
        // Place tempo after speed work
        let tempoIndex = count > 3 ? 3 : (count > 2 ? 2 : 0)

        var placed: Set<Int> = []

        // Place long run
        if types.contains(.longRun) {
            result[longRunIndex] = .longRun
            placed.insert(longRunIndex)
        }

        // Place speed work
        if types.contains(.speedWork) {
            let idx = placed.contains(speedIndex) ? findFreeIndex(in: result, placed: placed) : speedIndex
            result[idx] = .speedWork
            placed.insert(idx)
        }

        // Place tempo
        if types.contains(.tempo) {
            let idx = placed.contains(tempoIndex) ? findFreeIndex(in: result, placed: placed) : tempoIndex
            result[idx] = .tempo
            placed.insert(idx)
        }

        // Fill remaining with recovery/base from original assignments
        let remaining = types.filter { $0 != .longRun && $0 != .speedWork && $0 != .tempo }
        var remainingIterator = remaining.makeIterator()
        for i in 0..<count where !placed.contains(i) {
            result[i] = remainingIterator.next() ?? .base
        }

        return result
    }

    private static func findFreeIndex(in array: [RunType], placed: Set<Int>) -> Int {
        for i in 0..<array.count where !placed.contains(i) {
            return i
        }
        return 0
    }

    // MARK: - Mileage Distribution

    private static func distributeMileage(
        weeklyMiles: Double,
        assignments: [RunType],
        longRunCap: Double
    ) -> [Double] {
        guard !assignments.isEmpty else { return [] }

        // Weight each run type for proportional mileage distribution
        let weights: [Double] = assignments.map { type in
            switch type {
            case .longRun: return 0.30
            case .tempo: return 0.20
            case .speedWork: return 0.15
            case .base: return 0.20
            case .recovery: return 0.10
            case .crossTraining: return 0.0
            case .rest: return 0.0
            }
        }

        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else {
            return assignments.map { _ in 0 }
        }

        var distances = weights.map { ($0 / totalWeight) * weeklyMiles }

        // Cap long run distance
        for (i, type) in assignments.enumerated() where type == .longRun {
            if distances[i] > longRunCap {
                let excess = distances[i] - longRunCap
                distances[i] = longRunCap
                // Redistribute excess to base/recovery runs
                let redistributeIndices = assignments.enumerated()
                    .filter { $0.element == .base || $0.element == .recovery }
                    .map { $0.offset }
                if !redistributeIndices.isEmpty {
                    let addOn = excess / Double(redistributeIndices.count)
                    for idx in redistributeIndices {
                        distances[idx] += addOn
                    }
                }
            }
        }

        // Round to nearest 0.25 mile
        distances = distances.map { (($0 * 4).rounded() / 4) }

        // Zero out non-mileage types
        for (i, type) in assignments.enumerated() {
            if !type.countsAsMileage {
                distances[i] = 0
            }
        }

        return distances
    }

    // MARK: - Helpers

    static func weeksUntilRace(from start: Date, to raceDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear], from: start, to: raceDate)
        return max(1, components.weekOfYear ?? 1)
    }
}
