//
//  SanctuaryWorkoutRow.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import SwiftUI

struct SanctuaryWorkoutRow: View {
    let workout: WorkoutSession

    var body: some View {
        Group {
            if workout.resolvedIsLifeFlowNative {
                nativeRow
            } else {
                importedRow
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Opens workout details.")
    }

    private var nativeRow: some View {
        HStack(alignment: .top, spacing: 14) {
            dateBadge

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(nativeTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .layoutPriority(1)

                    WorkoutSourceBadge(
                        sourceName: workout.resolvedSourceName,
                        bundleID: workout.resolvedSourceBundleID,
                        isNative: true
                    )
                }
                
                Text(completionTimestampLine)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                metricLayout

                if let movementSummaryLine {
                    Text(movementSummaryLine)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if let weather = workout.weatherStampText, !weather.isEmpty {
                    Text(weather)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            if !nativeInsightItems.isEmpty {
                VStack(alignment: .trailing, spacing: 8) {
                    ForEach(nativeInsightItems.prefix(2)) { insight in
                        SanctuaryInsightBadge(
                            label: insight.label,
                            value: insight.value,
                            accent: insight.accent
                        )
                    }
                }
                .frame(minWidth: 78, alignment: .trailing)
            }
        }
        .padding(16)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.22, blue: 0.40),
                        Color(red: 0.02, green: 0.13, blue: 0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [.cyan.opacity(0.25), .clear],
                    center: .topTrailing,
                    startRadius: 24,
                    endRadius: 180
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [.cyan.opacity(0.45), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var importedRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 50, height: 50)

                Image(systemName: importedIconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.green.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(importedTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    WorkoutSourceBadge(
                        sourceName: workout.resolvedSourceName,
                        bundleID: workout.resolvedSourceBundleID,
                        isNative: false
                    )
                }
                
                Text(completionTimestampLine)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack(spacing: 12) {
                    importedMetric(value: workout.formattedDuration, label: "Time")
                    importedMetric(value: "\(Int(workout.calories.rounded()))", label: "kCal")

                    if let distanceMiles = importedDistanceMiles {
                        importedMetric(value: formattedDistance(distanceMiles), label: "Distance")
                    }
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .liquidGlassCard()
    }

    private var dateBadge: some View {
        VStack(spacing: 1) {
            Text(completionAnchorDate.formatted(.dateTime.day()))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text(completionAnchorDate.formatted(.dateTime.month(.abbreviated)))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .textCase(.uppercase)
                .tracking(0.8)
            
            Text(completionAnchorDate.formatted(.dateTime.weekday(.abbreviated)))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.64))
        }
        .frame(width: 60, height: 68)
        .background(
            LinearGradient(
                colors: [
                    .white.opacity(0.22),
                    .white.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.26), lineWidth: 1)
        )
    }

    private var completionAnchorDate: Date {
        workout.endTime ?? workout.startTime
    }

    private var completionTimestampLine: String {
        completionAnchorDate.formatted(
            .dateTime
                .weekday(.abbreviated)
                .month(.abbreviated)
                .day()
                .hour()
                .minute()
        )
    }

    private var metricLayout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(nativeMetricItems) { metric in
                    nativeMetricPill(metric)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ForEach(Array(nativeMetricItems.prefix(2))) { metric in
                        nativeMetricPill(metric)
                    }
                }

                if nativeMetricItems.count > 2 {
                    HStack(spacing: 8) {
                        ForEach(Array(nativeMetricItems.dropFirst(2))) { metric in
                            nativeMetricPill(metric)
                        }
                    }
                }
            }
        }
    }

    private func nativeMetricPill(_ metric: SanctuaryNativeMetric) -> some View {
        HStack(spacing: 4) {
            Text(metric.value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text(metric.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12), in: Capsule())
    }

    private var resolvedCalories: Int {
        let explicit = Int(workout.calories.rounded())
        if explicit > 0 {
            return explicit
        }

        let durationCalories = Int((workout.duration / 60) * 3)
        let setsCalories = completedSetsCount * 5
        return max(0, durationCalories + setsCalories)
    }

    private var completedExercisesCount: Int {
        let completed = workout.sortedExercises.filter { exercise in
            exercise.sortedSets.contains(where: \.isCompleted)
        }.count
        return completed > 0 ? completed : workout.sortedExercises.count
    }

    private var completedSetsCount: Int {
        workout.sortedExercises.reduce(0) { partial, exercise in
            partial + exercise.sortedSets.filter(\.isCompleted).count
        }
    }

    private var movementSummaryLine: String? {
        guard completedExercisesCount > 0 || completedSetsCount > 0 else { return nil }
        return "\(completedExercisesCount) exercises • \(completedSetsCount) completed sets"
    }

    private var nativeMetricItems: [SanctuaryNativeMetric] {
        var items: [SanctuaryNativeMetric] = [
            SanctuaryNativeMetric(value: workout.formattedDuration, label: "Time"),
            SanctuaryNativeMetric(value: "\(resolvedCalories)", label: "kCal")
        ]

        let distance = workout.totalDistanceMiles
        if distance > 0 {
            items.insert(SanctuaryNativeMetric(value: formattedDistance(distance), label: "Distance"), at: 1)
        } else if completedExercisesCount > 0 {
            items.insert(SanctuaryNativeMetric(value: "\(completedExercisesCount)", label: "Moves"), at: 1)
        }

        if completedSetsCount > 0 {
            items.append(SanctuaryNativeMetric(value: "\(completedSetsCount)", label: "Sets"))
        }

        return Array(items.prefix(4))
    }

    private var nativeInsightItems: [SanctuaryNativeInsight] {
        var items: [SanctuaryNativeInsight] = []

        if let delta = workout.resolvedGhostRunnerDelta {
            items.append(
                SanctuaryNativeInsight(
                    label: delta >= 0 ? "Ahead" : "Behind",
                    value: formatDelta(delta),
                    accent: delta >= 0 ? .green : .orange
                )
            )
        }

        if let hydration = workout.resolvedLiquidLossEstimate {
            items.append(
                SanctuaryNativeInsight(
                    label: "Hydration",
                    value: "\(Int(hydration.rounded())) oz",
                    accent: .cyan
                )
            )
        }

        return items
    }

    private var nativeTitle: String {
        let trimmed = workout.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Guided Session" : trimmed
    }

    private var importedTitle: String {
        let trimmed = workout.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        let type = workout.type.trimmingCharacters(in: .whitespacesAndNewlines)
        return type.isEmpty ? "Workout" : type
    }

    private var importedIconName: String {
        let loweredSource = workout.resolvedSourceName.lowercased()
        if loweredSource.contains("apple") {
            return "apple.logo"
        }
        if loweredSource.contains("strava") {
            return "figure.outdoor.cycle"
        }
        return "figure.mixed.cardio"
    }

    private var importedDistanceMiles: Double? {
        if let distance = workout.distanceMiles, distance > 0 {
            return distance
        }

        let summedDistance = workout.totalDistanceMiles
        return summedDistance > 0 ? summedDistance : nil
    }

    private var accessibilitySummary: String {
        var parts: [String] = []
        let title = workout.resolvedIsLifeFlowNative ? nativeTitle : importedTitle
        parts.append(title)
        parts.append("Source \(workout.resolvedSourceName)")
        parts.append("Duration \(workout.formattedDuration)")
        parts.append("Calories \(resolvedCalories)")

        if workout.resolvedIsLifeFlowNative {
            let distance = formattedDistance(workout.totalDistanceMiles)
            parts.append("Distance \(distance)")

            if completedExercisesCount > 0 {
                parts.append("\(completedExercisesCount) exercises")
            }

            if completedSetsCount > 0 {
                parts.append("\(completedSetsCount) sets")
            }

            if let delta = workout.resolvedGhostRunnerDelta {
                let status = delta >= 0 ? "Ahead" : "Behind"
                parts.append("\(status) \(formatDelta(delta))")
            }

            if let hydration = workout.resolvedLiquidLossEstimate {
                parts.append("Hydration \(Int(hydration.rounded())) ounces")
            }
        } else if let distance = importedDistanceMiles {
            parts.append("Distance \(formattedDistance(distance))")
        }

        if let weather = workout.weatherStampText, !weather.isEmpty {
            parts.append(weather)
        }

        return parts.joined(separator: ". ")
    }

    @ViewBuilder
    private func importedMetric(value: String, label: String) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func formattedDistance(_ distanceMiles: Double) -> String {
        if distanceMiles >= 10 {
            return String(format: "%.0f mi", distanceMiles)
        }
        return String(format: "%.1f mi", distanceMiles)
    }

    private func formatDelta(_ delta: Double) -> String {
        let absoluteSeconds = Int(abs(delta).rounded())
        return "\(absoluteSeconds)s"
    }
}

private struct SanctuaryNativeMetric: Identifiable {
    let value: String
    let label: String

    var id: String { "\(value)|\(label)" }
}

private struct SanctuaryNativeInsight: Identifiable {
    let label: String
    let value: String
    let accent: Color

    var id: String { "\(label)|\(value)" }
}

private struct SanctuaryInsightBadge: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .tracking(0.7)

            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accent.opacity(0.45), lineWidth: 1)
        )
    }
}

#Preview {
    let native = WorkoutSession(
        title: "Recovery Run",
        type: "Running",
        duration: 1980,
        calories: 312,
        source: "GymMode",
        timestamp: .now,
        distanceMiles: 3.2,
        sourceName: "LifeFlow",
        sourceBundleID: "com.fezqazi.lifeflow",
        isLifeFlowNative: true,
        liquidLossEstimate: 18,
        ghostRunnerDelta: 34
    )
    native.endTime = .now

    let imported = WorkoutSession(
        title: "Morning Run",
        type: "Running",
        duration: 2260,
        calories: 387,
        source: "HealthKit",
        timestamp: .now.addingTimeInterval(-86400),
        distanceMiles: 4.1,
        averageHeartRate: 152,
        sourceName: "Strava",
        sourceBundleID: "com.strava.run",
        isLifeFlowNative: false
    )
    imported.endTime = .now

    return VStack(spacing: 14) {
        SanctuaryWorkoutRow(workout: native)
        SanctuaryWorkoutRow(workout: imported)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
