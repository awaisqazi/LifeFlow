import SwiftUI
import LifeFlowCore

struct WatchRunHUDView: View {
    @Bindable var coordinator: WatchAppCoordinator

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Namespace private var glassNamespace

    var body: some View {
        let manager = coordinator.workoutManager

        ScrollView {
            VStack(spacing: 10) {
                header

                GlassEffectContainer(spacing: 10) {
                    if let activeAlert = manager.activeAlert {
                        alertCard(for: activeAlert)
                            .glassEffectID("alert", in: glassNamespace)
                    } else {
                        metricsGrid
                            .glassEffectID("metrics", in: glassNamespace)
                    }
                }
                .animation(
                    isLuminanceReduced ? .linear(duration: 0.1) : .spring(response: 0.46, dampingFraction: 0.82),
                    value: manager.activeAlert != nil
                )

                controls
            }
            .padding(10)
        }
        .background(backgroundGradient)
        .navigationTitle("Run")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: coordinator.workoutManager.lifecycleState) { _, _ in
            coordinator.syncRouteFromRunState()
        }
    }

    private var header: some View {
        HStack {
            Text(WatchFormatting.duration(coordinator.workoutManager.elapsedSeconds))
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .monospacedDigit()
            Spacer()
            Text(coordinator.workoutManager.lifecycleState.rawValue.capitalized)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var metricsGrid: some View {
        let manager = coordinator.workoutManager

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                MetricPlatter(
                    title: "Pace",
                    value: WatchFormatting.pace(manager.currentPaceSecondsPerMile),
                    accent: .mint
                )

                MetricPlatter(
                    title: "Distance",
                    value: WatchFormatting.distance(manager.currentDistanceMiles),
                    accent: .cyan
                )
            }

            if manager.metricSet == .secondary {
                HStack(spacing: 8) {
                    MetricPlatter(
                        title: "HR",
                        value: WatchFormatting.heartRate(manager.currentHeartRateBPM),
                        accent: .orange
                    )

                    MetricPlatter(
                        title: "Fuel",
                        value: WatchFormatting.fuel(manager.fuelingStatus.remainingGlycogenGrams),
                        accent: .yellow
                    )
                }

                HStack(spacing: 8) {
                    MetricPlatter(
                        title: "Cadence",
                        value: WatchFormatting.cadence(manager.currentCadenceSPM),
                        accent: .green
                    )

                    MetricPlatter(
                        title: "Grade",
                        value: manager.currentGradePercent.map { String(format: "%.1f%%", $0) } ?? "--",
                        accent: .blue
                    )
                }
            }
        }
        .opacity(isLuminanceReduced ? 0.94 : 1)
    }

    @ViewBuilder
    private func alertCard(for alert: EngineAlert) -> some View {
        VStack(spacing: 8) {
            Text(alertTitle(alert))
                .font(.headline)
            Text(alertMessage(alert))
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Acknowledge") {
                coordinator.workoutManager.dismissActiveAlert()
            }
            .buttonStyle(.glassProminent)
            .handGestureShortcut(.primaryAction)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .glassEffect(.regular.tint(.red.opacity(0.30)), in: .rect(cornerRadius: 20))
    }

    private var controls: some View {
        let manager = coordinator.workoutManager

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(manager.lifecycleState == .paused ? "Resume" : "Pause") {
                    if manager.lifecycleState == .paused {
                        manager.resumeRun()
                    } else {
                        manager.pauseRun()
                    }
                }
                .buttonStyle(.glass)

                Button("Fuel") {
                    manager.logNutrition()
                }
                .buttonStyle(.glassProminent)
                .handGestureShortcut(.primaryAction)
            }

            HStack(spacing: 8) {
                Button("Toggle") {
                    manager.toggleMetricSet()
                }
                .buttonStyle(.glass)

                Button(role: .destructive) {
                    Task { await coordinator.endRun() }
                } label: {
                    Text("End")
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var backgroundGradient: some View {
        let zone = coordinator.workoutManager.latestDecision?.alerts.first

        let colors: [Color]
        switch zone {
        case .fuelCritical, .highHeartRate:
            colors = [.red.opacity(0.28), .black]
        case .cardiacDrift:
            colors = [.orange.opacity(0.25), .black]
        default:
            colors = [.blue.opacity(isLuminanceReduced ? 0.10 : 0.20), .black]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    private func alertTitle(_ alert: EngineAlert) -> String {
        switch alert {
        case .fuelCritical:
            return "Fuel Critical"
        case .fuelWarning:
            return "Fuel Soon"
        case .highHeartRate:
            return "Heart Rate High"
        case .cardiacDrift:
            return "Cardiac Drift"
        case .paceVariance:
            return "Pace Variance"
        case .split:
            return "Split"
        }
    }

    private func alertMessage(_ alert: EngineAlert) -> String {
        switch alert {
        case .fuelCritical:
            return "Take fuel now and ease pace."
        case .fuelWarning:
            return "Fuel in the next few minutes."
        case .highHeartRate:
            return "Back off effort to stabilize."
        case .cardiacDrift:
            return "Heat or fatigue drift detected."
        case .paceVariance:
            return "Re-center rhythm and form."
        case .split:
            return "Lap marker logged. Stay smooth."
        }
    }
}
