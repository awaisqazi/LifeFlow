import SwiftUI

struct WatchSettingsView: View {
    @Bindable var coordinator: WatchAppCoordinator

    var body: some View {
        Form {
            Section("Fueling") {
                Slider(
                    value: $coordinator.workoutManager.configuredGelCarbsGrams,
                    in: 15...40,
                    step: 1
                )

                Text("Default gel: \(Int(coordinator.workoutManager.configuredGelCarbsGrams)) g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Run Defaults") {
                Toggle("Indoor", isOn: $coordinator.isIndoorRun)
            }

            Section {
                Button("Done") {
                    coordinator.savePreferences()
                    coordinator.route = .dashboard
                }
                .buttonStyle(.glassProminent)
            }
        }
        .navigationTitle("Settings")
    }
}
