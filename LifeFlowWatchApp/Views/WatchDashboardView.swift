import SwiftUI
import LifeFlowCore

struct WatchDashboardView: View {
    @Bindable var coordinator: WatchAppCoordinator

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Session")
                        .font(.headline)
                    Picker("Workout", selection: $coordinator.preferredRunType) {
                        ForEach(RunType.allCases, id: \.self) { runType in
                            Text(runType.watchTitle).tag(runType)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Toggle("Indoor", isOn: $coordinator.isIndoorRun)
                        .font(.caption)
                }
                .padding(10)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))

                Button {
                    coordinator.savePreferences()
                    Task { await coordinator.startRun() }
                } label: {
                    Label("Quick Start", systemImage: "figure.run")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)

                if let lastSession = coordinator.workoutManager.lastCompletedSession {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Last Run")
                            .font(.headline)
                        Text(WatchFormatting.duration(lastSession.endedAt?.timeIntervalSince(lastSession.startedAt) ?? 0))
                            .font(.headline.monospacedDigit())
                        Text(WatchFormatting.distance(lastSession.totalDistanceMiles))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))
                }

                Button("Settings") {
                    coordinator.route = .settings
                }
                .buttonStyle(.glass)
            }
            .padding(10)
        }
        .navigationTitle("LifeFlow")
    }
}

private extension RunType {
    var watchTitle: String {
        switch self {
        case .recovery:
            return "Recovery"
        case .base:
            return "Base"
        case .longRun:
            return "Long Run"
        case .speedWork:
            return "Speed"
        case .tempo:
            return "Tempo"
        case .crossTraining:
            return "Cross Train"
        case .rest:
            return "Rest"
        }
    }
}
