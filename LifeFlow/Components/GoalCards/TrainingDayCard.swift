//
//  TrainingDayCard.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import SwiftUI

/// "Day-Of" card displayed on the Flow dashboard showing today's training session.
/// Uses a sanctuary visual language aligned with Temple while preserving existing behavior.
struct TrainingDayCard: View {
    let plan: TrainingPlan
    let session: TrainingSession
    let statusColor: Color
    let onStartGuidedRun: () -> Void
    let onLifeHappens: () -> Void
    let onCheckIn: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var feelingScore: Double = 0.7
    @State private var showFeelingSlider: Bool = false
    @State private var adjustedDistance: Double? = nil
    @State private var showFuelSheet: Bool = false

    private var displayDistance: Double {
        adjustedDistance ?? session.targetDistance
    }

    private var guidedRunCTA: String {
        guard let estimatedMinutes = MarathonPaceDefaults.estimatedDurationMinutes(
            distanceMiles: displayDistance,
            runType: session.runType
        ) else {
            return "Start Guided Run"
        }
        return String(format: "Target: %.1f mi • est %d mins", displayDistance, estimatedMinutes)
    }

    private var estimatedMinutes: Int? {
        MarathonPaceDefaults.estimatedDurationMinutes(
            distanceMiles: displayDistance,
            runType: session.runType
        )
    }

    private var runTypeColor: Color {
        switch session.runType {
        case .recovery: return .green
        case .base: return .blue
        case .longRun: return .indigo
        case .speedWork: return .orange
        case .tempo: return .red
        case .crossTraining: return .cyan
        case .rest: return .gray
        }
    }

    private var cardAccentColor: Color {
        session.isCompleted ? .green : statusColor
    }
    
    private var springAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            sanctuaryBackground

            VStack(alignment: .leading, spacing: 16) {
                headerView

                if session.runType == .rest {
                    restDayView
                } else if session.runType == .crossTraining && !session.isCompleted {
                    crossTrainingView
                } else if session.isCompleted {
                    completedView
                } else {
                    activeTrainingView
                }

                if canShowFuelStrategy {
                    HStack {
                        fuelStrategyButton
                        Spacer()
                    }
                }
            }
            .padding(18)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [cardAccentColor.opacity(0.55), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .contextMenu {
            Button {
                onLifeHappens()
            } label: {
                Label("Life Happens (Push +1 Day)", systemImage: "calendar.badge.plus")
            }
        }
        .sheet(isPresented: $showFuelSheet) {
            FuelingStrategyView(session: session)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var sanctuaryBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.11, blue: 0.22),
                            Color(red: 0.03, green: 0.15, blue: 0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RadialGradient(
                colors: [runTypeColor.opacity(0.42), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 260
            )

            AnimatedMeshGradientView(theme: meshTheme)
                .opacity(0.16)
                .blur(radius: 18)
                .mask(RoundedRectangle(cornerRadius: 24))
        }
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: session.runType.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(runTypeColor)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("DAY \(plan.currentDay)/\(plan.totalDays)")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.7))

                Text(session.runType.displayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(cardAccentColor)
                    .frame(width: 8, height: 8)
                Text(session.isCompleted ? "Completed" : "Today")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.14), in: Capsule())
        }
    }

    // MARK: - Active Training View

    private var activeTrainingView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", displayDistance))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: displayDistance))
                        .animation(springAnimation, value: displayDistance)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("mi")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }

                Text(session.runType.effortDescription)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                HStack(spacing: 8) {
                    Label(session.runType.displayName, systemImage: session.runType.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.86))

                    if let estimatedMinutes {
                        Text("•")
                            .foregroundStyle(.white.opacity(0.45))
                        Label("\(estimatedMinutes) min est", systemImage: "clock.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.86))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(runTypeColor.opacity(0.35), lineWidth: 1)
            )

            Text(guidedRunCTA)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.76))

            if showFeelingSlider {
                feelingSliderPanel
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
                        showFeelingSlider.toggle()
                    }
                } label: {
                    Label(
                        showFeelingSlider ? "Done" : "Adjust",
                        systemImage: showFeelingSlider ? "checkmark" : "slider.horizontal.3"
                    )
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(.white.opacity(0.16), in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showFeelingSlider ? "Finish Run Adjustment" : "Adjust Run Plan")
                .accessibilityHint("Adjusts today's distance based on how you feel.")

                Button(action: onStartGuidedRun) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.subheadline.weight(.bold))

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Start Guided Run")
                                .font(.subheadline.weight(.bold))
                                .lineLimit(1)

                            if let estimatedMinutes {
                                Text(String(format: "%.1f mi • %d min est", displayDistance, estimatedMinutes))
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 4)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [runTypeColor.opacity(0.95), cardAccentColor.opacity(0.86)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
                    .shadow(color: runTypeColor.opacity(0.38), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start Guided Run")
                .accessibilityHint("Begins your scheduled distance run.")
            }
        }
    }

    private var feelingSliderPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How are you feeling today?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                Image(systemName: "face.dashed")
                    .foregroundStyle(.orange)

                Slider(value: $feelingScore, in: 0...1, step: 0.1)
                    .tint(feelingSliderColor)
                    .onChange(of: feelingScore) { _, newValue in
                        let (adjusted, _) = TrainingAdaptationEngine.preRunAdjustment(
                            session: session,
                            feelingScore: newValue
                        )
                        withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
                            adjustedDistance = adjusted
                        }
                    }
                    .accessibilityLabel("How are you feeling")
                    .accessibilityValue(feelingLabel)

                Image(systemName: "face.smiling.fill")
                    .foregroundStyle(.green)
            }

            Text(feelingLabel)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.74))
        }
        .padding(12)
        .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))
    }

    private var restDayView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rest & Restore")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text(session.runType.effortDescription)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var crossTrainingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cross-Training Day")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text("Log strength, yoga, cycling, or swimming to keep your plan on track.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Button(action: onStartGuidedRun) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Log Cross Training")
                        .fontWeight(.bold)
                }
                .font(.subheadline)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(
                        colors: [runTypeColor.opacity(0.95), cardAccentColor.opacity(0.82)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log Cross Training")
            .accessibilityHint("Records a cross-training workout for today's plan.")
        }
        .padding(14)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Completed View

    @ViewBuilder
    private var completedView: some View {
        if session.runType == .crossTraining {
            VStack(alignment: .leading, spacing: 12) {
                Label("Cross-Training Logged", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Text("Great consistency. Recovery and strength work support your run performance.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }

                if let effort = session.perceivedEffort {
                    HStack(spacing: 4) {
                        Text("Effort:")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(effortLabel(effort))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(14)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        }

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Planned")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                    Text(String(format: "%.1f mi", session.targetDistance))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Image(systemName: "arrow.right")
                    .foregroundStyle(.white.opacity(0.55))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Actual")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                    Text(String(format: "%.1f mi", session.actualDistance ?? 0))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(deltaColor)
                }

                Spacer()

                if let actual = session.actualDistance {
                    let delta = actual - session.targetDistance
                    Text(String(format: "%+.1f mi", delta))
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(deltaColor.opacity(0.20), in: Capsule())
                        .foregroundStyle(deltaColor)
                }
            }

            HStack(spacing: 8) {
                if let effort = session.perceivedEffort {
                    Label(effortLabel(effort), systemImage: "bolt.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                }

                Spacer()

                Button {
                    onCheckIn()
                } label: {
                    Label("Update Check-In", systemImage: "square.and.pencil")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.15), in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Refine distance and effort for this completed session.")
            }
        }
        .padding(14)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .animation(reduceMotion ? nil : .spring(response: 0.4), value: session.runType)
    }

    // MARK: - Helpers

    private var meshTheme: MeshGradientTheme {
        switch session.runType {
        case .recovery, .base: return .flow
        case .longRun, .crossTraining: return .horizon
        case .speedWork, .tempo: return .temple
        case .rest: return .temple
        }
    }

    private var deltaColor: Color {
        guard let actual = session.actualDistance else { return .secondary }
        if actual >= session.targetDistance { return .green }
        if actual >= session.targetDistance * 0.8 { return .orange }
        return .red
    }

    private var feelingSliderColor: Color {
        if feelingScore >= 0.7 { return .green }
        if feelingScore >= 0.3 { return .orange }
        return .red
    }

    private var feelingLabel: String {
        if feelingScore >= 0.7 { return "Feeling great! Stick to the plan." }
        if feelingScore >= 0.3 { return "Adjusted distance. Volume redistributed to your next easy run." }
        return "Take it easy. Consider a light recovery or rest." }

    private var canShowFuelStrategy: Bool {
        session.runType != .rest
    }

    private var fuelStrategyButton: some View {
        Button {
            showFuelSheet = true
        } label: {
            Label("Fuel Strategy", systemImage: "fork.knife.circle.fill")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white.opacity(0.15), in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows a fueling timeline for this session.")
    }

    private func effortLabel(_ effort: Int) -> String {
        switch effort {
        case 1: return "Easy"
        case 2: return "Moderate"
        case 3: return "Hard"
        default: return "Unknown"
        }
    }
}
