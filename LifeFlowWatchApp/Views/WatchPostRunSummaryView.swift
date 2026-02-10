import SwiftUI

struct WatchPostRunSummaryView: View {
    @Bindable var coordinator: WatchAppCoordinator

    @State private var effort: Int = 3
    @State private var reflection: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let session = coordinator.workoutManager.lastCompletedSession {
                    VStack(spacing: 6) {
                        Text("Run Complete")
                            .font(.headline)
                        Text(WatchFormatting.duration(session.endedAt?.timeIntervalSince(session.startedAt) ?? 0))
                            .font(.title3.monospacedDigit())
                        Text(WatchFormatting.distance(session.totalDistanceMiles))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Effort")
                            Spacer()
                            Stepper(value: $effort, in: 1...5) {
                                Text("\(effort)/5")
                                    .monospacedDigit()
                            }
                        }

                        TextField("Reflection", text: $reflection)
                            .textInputAutocapitalization(.sentences)
                    }
                    .padding(10)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))

                    Button("Save Check-In") {
                        coordinator.workoutManager.savePostRunCheckIn(
                            effort: effort,
                            reflection: reflection
                        )
                    }
                    .buttonStyle(.glassProminent)
                } else {
                    Text("No recent run available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Back to Dashboard") {
                    coordinator.route = .dashboard
                }
                .buttonStyle(.glass)
            }
            .padding(10)
        }
        .navigationTitle("Summary")
        .onAppear {
            if let session = coordinator.workoutManager.lastCompletedSession {
                effort = session.postRunEffort ?? 3
                reflection = session.postRunReflection ?? ""
            }
        }
    }
}
