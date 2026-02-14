import SwiftUI
import LifeFlowCore

struct WatchPostRunSummaryView: View {
    @Bindable var coordinator: WatchAppCoordinator

    @State private var effort: Int = 3
    @State private var reflection: String = ""
    @State private var showCelebration: Bool = false

    var body: some View {
        let session = coordinator.workoutManager.lastCompletedSession

        ZStack {
            // Ambient gradient
            LinearGradient(
                colors: [
                    Color(hue: 0.55, saturation: 0.4, brightness: 0.18),
                    .black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if let session {
                TabView {
                    // ─── Page 1: Celebration ───
                    celebrationPage(session)
                        .tag(0)

                    // ─── Page 2: Metrics ───
                    metricsPage(session)
                        .tag(1)

                    // ─── Page 3: Rate Effort ───
                    effortPage()
                        .tag(2)

                    // ─── Page 4: Save ───
                    savePage()
                        .tag(3)
                }
                .tabViewStyle(.verticalPage)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "figure.run.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No recent run")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Button("Dashboard") {
                        coordinator.route = .dashboard
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue.opacity(0.7))
                    .clipShape(Capsule())
                }
            }
        }
        .onAppear {
            if let session {
                effort = session.postRunEffort ?? 3
                reflection = session.postRunReflection ?? ""
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                showCelebration = true
            }
        }
    }

    // MARK: - Page 1: Celebration

    @ViewBuilder
    private func celebrationPage(_ session: WatchWorkoutSession) -> some View {
        let duration = session.endedAt?.timeIntervalSince(session.startedAt) ?? 0

        VStack(spacing: 0) {
            Spacer(minLength: 8)

            // Checkmark burst
            ZStack {
                // Radial glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.green.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(showCelebration ? 1.0 : 0.3)
                    .opacity(showCelebration ? 1.0 : 0.0)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: showCelebration)
                    .scaleEffect(showCelebration ? 1.0 : 0.5)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showCelebration)

            Text("Run Complete")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.top, 8)

            // Hero time
            Text(WatchFormatting.duration(duration))
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .padding(.top, 4)

            // Distance subtitle
            HStack(spacing: 4) {
                Image(systemName: "figure.run")
                    .font(.system(size: 11))
                Text(WatchFormatting.distance(session.totalDistanceMiles))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
            .padding(.top, 2)

            Spacer(minLength: 8)

            // Scroll hint
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Page 2: Metrics

    @ViewBuilder
    private func metricsPage(_ session: WatchWorkoutSession) -> some View {
        let duration = session.endedAt?.timeIntervalSince(session.startedAt) ?? 0
        let avgPace = session.totalDistanceMiles > 0
            ? duration / session.totalDistanceMiles
            : nil

        VStack(spacing: 8) {
            Spacer(minLength: 4)

            Text("STATS")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(2)

            // Metric grid — 2x2
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6)
            ], spacing: 6) {
                // Avg Pace
                metricTile(
                    icon: "speedometer",
                    value: WatchFormatting.pace(avgPace),
                    label: "AVG PACE",
                    accent: .mint
                )

                // Avg HR
                metricTile(
                    icon: "heart.fill",
                    value: WatchFormatting.heartRate(session.averageHeartRate),
                    label: "AVG HR",
                    accent: .red
                )

                // Calories
                metricTile(
                    icon: "flame.fill",
                    value: String(format: "%.0f", session.totalEnergyBurned),
                    label: "KCAL",
                    accent: .orange
                )

                // Distance
                metricTile(
                    icon: "map.fill",
                    value: String(format: "%.2f", session.totalDistanceMiles),
                    label: "MILES",
                    accent: .blue
                )
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func metricTile(icon: String, value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(accent.opacity(0.8))

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.08))
        )
    }

    // MARK: - Page 3: Effort

    @ViewBuilder
    private func effortPage() -> some View {
        VStack(spacing: 6) {
            Spacer(minLength: 4)

            Text("HOW DID IT FEEL?")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(2)

            // Effort ring
            ZStack {
                // Background track
                Circle()
                    .stroke(effortColor.opacity(0.15), lineWidth: 6)
                    .frame(width: 72, height: 72)

                // Fill arc
                Circle()
                    .trim(from: 0, to: Double(effort) / 5.0)
                    .stroke(
                        effortColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: effort)

                // Center value
                VStack(spacing: 0) {
                    Text("\(effort)")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(effortColor)
                        .contentTransition(.numericText(countsDown: false))
                        .animation(.spring(response: 0.3), value: effort)

                    Text("of 5")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)

            // Effort label
            Text(effortLabel)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(effortColor.opacity(0.9))
                .animation(.easeInOut(duration: 0.2), value: effort)

            // ± Buttons
            HStack(spacing: 16) {
                Button {
                    if effort > 1 { effort -= 1 }
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 40, height: 34)
                }
                .buttonStyle(.borderedProminent)
                .tint(effort > 1 ? effortColor.opacity(0.5) : .gray.opacity(0.3))
                .clipShape(Capsule())
                .disabled(effort <= 1)

                Button {
                    if effort < 5 { effort += 1 }
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 40, height: 34)
                }
                .buttonStyle(.borderedProminent)
                .tint(effort < 5 ? effortColor.opacity(0.5) : .gray.opacity(0.3))
                .clipShape(Capsule())
                .disabled(effort >= 5)
            }
            .padding(.top, 4)

            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .digitalCrownRotation(
            detent: $effort,
            from: 1,
            through: 5,
            by: 1,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
    }

    // MARK: - Page 4: Save

    @ViewBuilder
    private func savePage() -> some View {
        VStack(spacing: 10) {
            Spacer(minLength: 8)

            // Quick note — TextField triggers watchOS dictation/scribble
            HStack {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.blue)
                TextField("Add a note…", text: $reflection)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .lineLimit(2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 8)

            // Save button
            Button {
                coordinator.workoutManager.savePostRunCheckIn(
                    effort: effort,
                    reflection: reflection
                )
                WKInterfaceDevice.current().play(.success)
                coordinator.route = .dashboard
            } label: {
                Label("Save", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .clipShape(Capsule())
            .padding(.horizontal, 16)

            // Skip button
            Button {
                coordinator.route = .dashboard
            } label: {
                Text("Skip")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Effort Helpers

    private var effortColor: Color {
        switch effort {
        case 1: return .green
        case 2: return .mint
        case 3: return .yellow
        case 4: return .orange
        default: return .red
        }
    }

    private var effortLabel: String {
        switch effort {
        case 1: return "Easy"
        case 2: return "Moderate"
        case 3: return "Steady"
        case 4: return "Hard"
        default: return "All Out"
        }
    }
}
