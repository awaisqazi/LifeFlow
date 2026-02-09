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
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(workout.startTime.formatted(.dateTime.day()))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text(workout.startTime.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .textCase(.uppercase)
            }
            .frame(width: 52, height: 56)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(nativeTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    WorkoutSourceBadge(
                        sourceName: workout.resolvedSourceName,
                        bundleID: workout.resolvedSourceBundleID,
                        isNative: true
                    )
                }

                HStack(spacing: 10) {
                    sanctuaryMetric(value: workout.formattedDuration, label: "Time")
                    sanctuaryMetric(value: formattedDistance(workout.totalDistanceMiles), label: "Distance")
                    sanctuaryMetric(value: "\(Int(workout.calories.rounded()))", label: "kCal")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))

                if let weather = workout.weatherStampText, !weather.isEmpty {
                    Text(weather)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 10) {
                if let delta = workout.resolvedGhostRunnerDelta {
                    SanctuaryInsightBadge(
                        label: delta >= 0 ? "Ahead" : "Behind",
                        value: formatDelta(delta),
                        accent: delta >= 0 ? .green : .red
                    )
                }

                if let hydration = workout.resolvedLiquidLossEstimate {
                    SanctuaryInsightBadge(
                        label: "Hydration",
                        value: "\(Int(hydration.rounded())) oz",
                        accent: .cyan
                    )
                }
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
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
        parts.append("Calories \(Int(workout.calories.rounded()))")
        
        if workout.resolvedIsLifeFlowNative {
            let distance = formattedDistance(workout.totalDistanceMiles)
            parts.append("Distance \(distance)")
            
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
    private func sanctuaryMetric(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .fontWeight(.semibold)
            Text(label)
                .foregroundStyle(.white.opacity(0.7))
        }
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
