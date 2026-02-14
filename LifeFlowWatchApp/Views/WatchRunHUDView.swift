import SwiftUI
import LifeFlowCore

struct WatchRunHUDView: View {
    @Bindable var coordinator: WatchAppCoordinator

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var currentPage: Int = 0

    var body: some View {
        let manager = coordinator.workoutManager

        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                // ─── Page 1: Time + Status ───
                timeCard(manager)
                    .tag(0)

                // ─── Page 2: Pace ───
                paceCard(manager)
                    .tag(1)

                // ─── Page 3: Heart Rate ───
                heartRateCard(manager)
                    .tag(2)

                // ─── Page 4: Fuel ───
                fuelCard(manager)
                    .tag(3)

                // ─── Page 5: Controls ───
                controlsPage(manager)
                    .tag(4)
            }
            .tabViewStyle(.verticalPage)
            .animation(
                isLuminanceReduced
                    ? .linear(duration: 0.1)
                    : .spring(response: 0.4, dampingFraction: 0.85),
                value: currentPage
            )

            // Alert overlay — slides over current page
            if let alert = manager.activeAlert {
                alertOverlay(for: alert)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: manager.activeAlert != nil)
        .onChange(of: manager.lifecycleState) { _, _ in
            coordinator.syncRouteFromRunState()
        }
    }

    // MARK: - Card Pages

    @ViewBuilder
    private func timeCard(_ m: WatchWorkoutManager) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            // Status pill
            Text(m.lifecycleState.rawValue.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(statusColor(m.lifecycleState))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(statusColor(m.lifecycleState).opacity(0.15))
                )
                .padding(.bottom, 6)

            // Hero time
            Text(WatchFormatting.duration(m.elapsedSeconds))
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText(countsDown: false))
                .animation(.easeInOut(duration: 0.15), value: m.elapsedSeconds)

            // Distance subtitle
            HStack(spacing: 4) {
                Image(systemName: "figure.run")
                    .font(.system(size: 12))
                Text(WatchFormatting.distance(m.currentDistanceMiles))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
            .padding(.top, 4)

            Spacer(minLength: 8)

            // Page dots hint
            pageIndicator(current: 0, total: 5)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func paceCard(_ m: WatchWorkoutManager) -> some View {
        RunCardPageView(
            icon: "speedometer",
            label: "Pace",
            heroValue: WatchFormatting.pace(m.currentPaceSecondsPerMile),
            unit: "min/mi",
            accent: .mint,
            subtitle: m.currentCadenceSPM.map { "\(Int($0)) spm" }
        )
    }

    @ViewBuilder
    private func heartRateCard(_ m: WatchWorkoutManager) -> some View {
        let bpm = m.currentHeartRateBPM
        let zone = bpm.map(Self.zoneInfo)

        RunCardPageView(
            icon: "heart.fill",
            label: "Heart Rate",
            heroValue: WatchFormatting.heartRate(bpm),
            unit: "bpm",
            accent: zone?.color ?? .red,
            subtitle: zone?.label,
            progress: zone?.progress
        )
    }

    @ViewBuilder
    private func fuelCard(_ m: WatchWorkoutManager) -> some View {
        let fuel = m.fuelingStatus.remainingGlycogenGrams
        let maxFuel: Double = 420
        let fuelProgress = min(fuel / maxFuel, 1.0)

        RunCardPageView(
            icon: "flame.fill",
            label: "Fuel",
            heroValue: WatchFormatting.fuel(fuel),
            unit: "glycogen",
            accent: fuelColor(fuel),
            subtitle: fuelLevelLabel(m.fuelingStatus.level),
            progress: fuelProgress
        )
    }

    @ViewBuilder
    private func controlsPage(_ m: WatchWorkoutManager) -> some View {
        VStack(spacing: 10) {
            Spacer(minLength: 4)

            // Pause / Resume
            Button {
                if m.lifecycleState == .paused {
                    m.resumeRun()
                } else {
                    m.pauseRun()
                }
            } label: {
                Label(
                    m.lifecycleState == .paused ? "Resume" : "Pause",
                    systemImage: m.lifecycleState == .paused ? "play.fill" : "pause.fill"
                )
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(m.lifecycleState == .paused ? .green : .orange)
            .clipShape(Capsule())

            // Fuel
            Button {
                m.logNutrition()
            } label: {
                Label("Fuel", systemImage: "flame.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .clipShape(Capsule())
            .handGestureShortcut(.primaryAction)

            // End
            Button(role: .destructive) {
                Task { await coordinator.endRun() }
            } label: {
                Label("End Run", systemImage: "stop.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.8))
            .clipShape(Capsule())

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Alert Overlay

    @ViewBuilder
    private func alertOverlay(for alert: EngineAlert) -> some View {
        VStack(spacing: 10) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: alertIcon(alert))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(alertColor(alert))
                    .symbolEffect(.pulse, isActive: true)

                Text(alertTitle(alert))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(alertMessage(alert))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Dismiss") {
                    coordinator.workoutManager.dismissActiveAlert()
                }
                .buttonStyle(.borderedProminent)
                .tint(alertColor(alert).opacity(0.7))
                .clipShape(Capsule())
                .handGestureShortcut(.primaryAction)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: alertColor(alert).opacity(0.3), radius: 12, y: 4)
            )
            .padding(.horizontal, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5))
    }

    // MARK: - Page Indicator

    private func pageIndicator(current: Int, total: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i == current ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 4, height: 4)
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let alert = coordinator.workoutManager.activeAlert

        let colors: [Color]
        switch alert {
        case .fuelCritical, .highHeartRate:
            colors = [.red.opacity(0.25), .black]
        case .cardiacDrift:
            colors = [.orange.opacity(0.20), .black]
        default:
            colors = [
                Color(hue: 0.6, saturation: 0.4, brightness: isLuminanceReduced ? 0.08 : 0.15),
                .black
            ]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Heart Rate Zones

    private struct ZoneInfo {
        let label: String
        let color: Color
        let progress: Double
    }

    private static func zoneInfo(for bpm: Double) -> ZoneInfo {
        switch bpm {
        case ..<100:
            return ZoneInfo(label: "Zone 1 · Easy", color: .blue, progress: 0.2)
        case 100..<130:
            return ZoneInfo(label: "Zone 2 · Aerobic", color: .green, progress: 0.4)
        case 130..<155:
            return ZoneInfo(label: "Zone 3 · Tempo", color: .yellow, progress: 0.6)
        case 155..<175:
            return ZoneInfo(label: "Zone 4 · Threshold", color: .orange, progress: 0.8)
        default:
            return ZoneInfo(label: "Zone 5 · Max", color: .red, progress: 1.0)
        }
    }

    // MARK: - Fuel Helpers

    private func fuelColor(_ grams: Double) -> Color {
        switch grams {
        case ..<80: return .red
        case ..<200: return .orange
        default: return .green
        }
    }

    private func fuelLevelLabel(_ level: FuelingStatus.Level) -> String {
        switch level {
        case .nominal: return "Nominal"
        case .warning: return "Getting Low"
        case .critical: return "Critical — Refuel!"
        }
    }

    private func statusColor(_ state: WatchRunLifecycleState) -> Color {
        switch state {
        case .running: return .green
        case .paused: return .orange
        case .ended: return .red
        case .idle, .preparing: return .secondary
        }
    }

    // MARK: - Alert Metadata

    private func alertIcon(_ alert: EngineAlert) -> String {
        switch alert {
        case .fuelCritical: return "exclamationmark.triangle.fill"
        case .fuelWarning: return "flame.fill"
        case .highHeartRate: return "heart.fill"
        case .cardiacDrift: return "waveform.path.ecg"
        case .paceVariance: return "gauge.with.dots.needle.33percent"
        case .split: return "flag.fill"
        }
    }

    private func alertColor(_ alert: EngineAlert) -> Color {
        switch alert {
        case .fuelCritical, .highHeartRate: return .red
        case .fuelWarning, .cardiacDrift: return .orange
        case .paceVariance: return .yellow
        case .split: return .cyan
        }
    }

    private func alertTitle(_ alert: EngineAlert) -> String {
        switch alert {
        case .fuelCritical: return "Fuel Critical"
        case .fuelWarning: return "Fuel Soon"
        case .highHeartRate: return "Heart Rate High"
        case .cardiacDrift: return "Cardiac Drift"
        case .paceVariance: return "Pace Variance"
        case .split: return "Split"
        }
    }

    private func alertMessage(_ alert: EngineAlert) -> String {
        switch alert {
        case .fuelCritical: return "Take fuel now and ease pace."
        case .fuelWarning: return "Fuel in the next few minutes."
        case .highHeartRate: return "Back off effort to stabilize."
        case .cardiacDrift: return "Heat or fatigue drift detected."
        case .paceVariance: return "Re-center rhythm and form."
        case .split: return "Lap marker logged. Stay smooth."
        }
    }
}

// MARK: - Run Card Page

/// Full-screen metric card for the Digital Crown run HUD.
struct RunCardPageView: View {
    let icon: String
    let label: String
    let heroValue: String
    let unit: String
    var accent: Color = .mint
    var subtitle: String? = nil
    var progress: Double? = nil

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4)

            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(accent.opacity(isLuminanceReduced ? 0.5 : 0.7))
                .padding(.bottom, 4)

            Text(heroValue)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText(countsDown: false))
                .animation(.easeInOut(duration: 0.3), value: heroValue)

            Text(unit)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.top, 1)

            if let progress {
                ZoneProgressBar(progress: progress, accent: accent)
                    .padding(.top, 10)
                    .padding(.horizontal, 24)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(accent.opacity(0.8))
                    .padding(.top, 6)
            }

            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(heroValue) \(unit)")
    }
}

/// Horizontal zone/progress bar with animated fill.
struct ZoneProgressBar: View {
    let progress: Double
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(accent.opacity(0.15))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.6), accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
                    .animation(.easeInOut(duration: 0.5), value: progress)
            }
        }
        .frame(height: 6)
    }
}
