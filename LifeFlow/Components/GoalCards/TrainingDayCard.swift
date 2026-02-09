//
//  TrainingDayCard.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import SwiftUI

/// "Day-Of" card displayed on the Flow dashboard showing today's training session.
/// Shows run type, target distance, pre-run feeling slider, and guided run button.
struct TrainingDayCard: View {
    let plan: TrainingPlan
    let session: TrainingSession
    let statusColor: Color
    let onStartGuidedRun: () -> Void
    let onLifeHappens: () -> Void
    let onCheckIn: () -> Void

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

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Liquid background glow
            AnimatedMeshGradientView(theme: meshTheme)
                .opacity(0.12)
                .mask {
                    RoundedRectangle(cornerRadius: 20)
                }
                .blur(radius: 20)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
            // Header: Day counter + run type
            HStack {
                Image(systemName: session.runType.icon)
                    .font(.title2)
                    .foregroundStyle(runTypeColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(plan.currentDay)/\(plan.totalDays)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(session.runType.displayName)
                        .font(.headline)
                }

                Spacer()

                if session.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }

            if session.runType == .rest {
                // Rest day content
                VStack(spacing: 8) {
                    Text("Rest Day")
                        .font(.title3.weight(.medium))
                    Text(session.runType.effortDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else if session.runType == .crossTraining && !session.isCompleted {
                crossTrainingView
            } else if session.isCompleted {
                // Completed run summary
                completedView
            } else {
                // Active training content
                activeTrainingView
            }
            
            if canShowFuelStrategy {
                HStack {
                    fuelStrategyButton
                    Spacer()
                }
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
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
    }

    // MARK: - Active Training View

    private var activeTrainingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(session.runType.displayName, systemImage: session.runType.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(runTypeColor)
                
                Spacer()
                
                if let estimatedMinutes {
                    Label("\(estimatedMinutes) min", systemImage: "clock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.1f", displayDistance))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: displayDistance))
                    .animation(.spring(response: 0.3), value: displayDistance)
                Text("miles")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(session.runType.effortDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(guidedRunCTA)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            // Pre-run feeling slider
            if showFeelingSlider {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How are you feeling?")
                        .font(.subheadline.weight(.medium))

                    HStack {
                        Image(systemName: "face.dashed")
                            .foregroundStyle(.orange)
                        Slider(value: $feelingScore, in: 0...1, step: 0.1)
                            .tint(feelingSliderColor)
                            .onChange(of: feelingScore) { _, newValue in
                                let (adjusted, _) = TrainingAdaptationEngine.preRunAdjustment(
                                    session: session,
                                    feelingScore: newValue
                                )
                                withAnimation(.spring(response: 0.3)) {
                                    adjustedDistance = adjusted
                                }
                            }
                        Image(systemName: "face.smiling.fill")
                            .foregroundStyle(.green)
                    }

                    Text(feelingLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showFeelingSlider.toggle()
                    }
                } label: {
                    Label(
                        showFeelingSlider ? "Hide" : "Adjust",
                        systemImage: showFeelingSlider ? "chevron.up" : "slider.horizontal.3"
                    )
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.1), in: Capsule())
                    .foregroundStyle(.primary)
                }

                Button(action: onStartGuidedRun) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.subheadline.weight(.bold))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start Guided Run")
                                .font(.subheadline.weight(.bold))
                            if let estimatedMinutes {
                                Text(String(format: "%.1f mi target • %d min est", displayDistance, estimatedMinutes))
                                    .font(.caption2.weight(.semibold))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                        .background(runTypeColor, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    private var crossTrainingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cross-Training Day")
                .font(.title3.weight(.bold))
                .foregroundStyle(runTypeColor)
            
            Text("Log strength, yoga, cycling, or swimming to keep your plan on track.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button(action: onStartGuidedRun) {
                Label("Log Cross Training", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(runTypeColor, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
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
                        .foregroundStyle(.secondary)
                } else {
                    Text("Great consistency. Recovery and strength work support your run performance.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if let effort = session.perceivedEffort {
                    HStack(spacing: 4) {
                        Text("Effort:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(effortLabel(effort))
                            .font(.caption.weight(.semibold))
                    }
                }
            }
            .padding()
            .glassEffect(in: .rect(cornerRadius: 20))
        }
        
        VStack(alignment: .leading, spacing: 12) {
            // Visual delta: planned vs actual
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Planned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f mi", session.targetDistance))
                        .font(.subheadline)
                }

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    Text("Actual")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f mi", session.actualDistance ?? 0))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(deltaColor)
                }

                Spacer()

                // Delta indicator
                if let actual = session.actualDistance {
                    let delta = actual - session.targetDistance
                    Text(String(format: "%+.1f mi", delta))
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(deltaColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(deltaColor)
                }
            }

            // Effort display
            if let effort = session.perceivedEffort {
                HStack(spacing: 4) {
                    Text("Effort:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(effortLabel(effort))
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
        .animation(.spring(response: 0.4), value: session.runType)
    }

    // MARK: - Helpers

    private var meshTheme: MeshGradientTheme {
        switch session.runType {
        case .recovery, .base: return .flow
        case .longRun, .crossTraining: return .horizon
        case .speedWork, .tempo: return .temple
        case .rest: return .temple // Subtle orange/purple for rest
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
        return "Take it easy. Consider a light recovery or rest."
    }
    
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
                .background(.ultraThinMaterial, in: Capsule())
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
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
