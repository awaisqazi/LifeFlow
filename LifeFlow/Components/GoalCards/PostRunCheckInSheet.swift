//
//  PostRunCheckInSheet.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import SwiftUI

/// Post-run feedback sheet that collects actual distance and perceived effort.
/// Triggers the adaptation engine to adjust the training plan.
struct PostRunCheckInSheet: View {
    let session: TrainingSession
    let onSubmit: (Double, Int) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var actualDistanceString: String
    @State private var selectedEffort: Int = 2

    init(session: TrainingSession, onSubmit: @escaping (Double, Int) -> Void) {
        self.session = session
        self.onSubmit = onSubmit
        // Pre-fill with actual distance from HealthKit if available, or target
        let prefill = session.actualDistance ?? session.targetDistance
        _actualDistanceString = State(initialValue: String(format: "%.1f", prefill))
    }

    private var actualDistance: Double {
        Double(actualDistanceString) ?? session.targetDistance
    }

    private var delta: Double {
        actualDistance - session.targetDistance
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Run summary header
                    VStack(spacing: 8) {
                        Image(systemName: session.runType.icon)
                            .font(.system(size: 40))
                            .foregroundStyle(.green)

                        Text(session.runType.displayName)
                            .font(.title2.weight(.bold))

                        Text("Target: \(String(format: "%.1f", session.targetDistance)) mi")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)

                    // Visual delta
                    deltaVisualization

                    // Actual distance input
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "ruler")
                                .foregroundStyle(.green)
                            Text("Actual Distance")
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding()

                        Divider().padding(.leading)

                        HStack {
                            TextField("0.0", text: $actualDistanceString)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .frame(maxWidth: 120)
                            Text("miles")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Spacer()

                            // Delta badge
                            Text(String(format: "%+.1f", delta))
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(deltaColor.opacity(0.15), in: Capsule())
                                .foregroundStyle(deltaColor)
                        }
                        .padding()
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // How did that feel?
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How did that feel?")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack(spacing: 12) {
                            EffortButton(
                                label: "Easy",
                                icon: "face.smiling.fill",
                                color: .green,
                                isSelected: selectedEffort == 1
                            ) { selectedEffort = 1 }

                            EffortButton(
                                label: "Moderate",
                                icon: "face.dashed",
                                color: .orange,
                                isSelected: selectedEffort == 2
                            ) { selectedEffort = 2 }

                            EffortButton(
                                label: "Hard",
                                icon: "flame.fill",
                                color: .red,
                                isSelected: selectedEffort == 3
                            ) { selectedEffort = 3 }
                        }
                        .padding(.horizontal)
                    }

                    // Submit button
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        onSubmit(actualDistance, selectedEffort)
                        dismiss()
                    } label: {
                        Text("Log Run")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Post-Run Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
            }
        }
    }

    // MARK: - Delta Visualization

    private var deltaVisualization: some View {
        GeometryReader { geo in
            let barWidth = geo.size.width - 32
            let targetRatio = min(session.targetDistance / max(actualDistance, session.targetDistance, 0.1), 1.0)
            let actualRatio = min(actualDistance / max(actualDistance, session.targetDistance, 0.1), 1.0)

            VStack(alignment: .leading, spacing: 8) {
                // Planned (ghost outline)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 12)
                    Capsule()
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        .frame(width: barWidth * targetRatio, height: 12)
                }

                // Actual (solid fill)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 12)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [deltaColor.opacity(0.7), deltaColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: barWidth * actualRatio, height: 12)
                        .animation(.spring(response: 0.4), value: actualDistance)
                }

                HStack {
                    HStack(spacing: 4) {
                        Circle().stroke(Color.gray, lineWidth: 1).frame(width: 8, height: 8)
                        Text("Planned").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(deltaColor).frame(width: 8, height: 8)
                        Text("Actual").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 60)
        .padding(.horizontal)
    }

    private var deltaColor: Color {
        if delta >= 0 { return .green }
        if delta >= -(session.targetDistance * 0.2) { return .orange }
        return .red
    }
}

// MARK: - Effort Button

private struct EffortButton: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected ? color.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : .clear, lineWidth: 2)
            )
            .foregroundStyle(isSelected ? color : .primary)
        }
    }
}
