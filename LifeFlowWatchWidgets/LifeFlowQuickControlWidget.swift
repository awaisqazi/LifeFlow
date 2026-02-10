import AppIntents
import SwiftUI
import WidgetKit
import LifeFlowCore

struct LifeFlowQuickControlWidget: ControlWidget {
    static let kind = LifeFlowWidgetKinds.quickControl

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: RunControlProvider()
        ) { value in
            ControlWidgetToggle(
                "Quick Run",
                isOn: value.isRunning,
                action: ToggleRunStateIntent()
            ) { isRunning in
                Label(
                    isRunning ? "Resume" : "Start",
                    systemImage: isRunning ? "play.fill" : "figure.run"
                )
            }
        }
        .displayName("Quick Start")
        .description("Start or resume your LifeFlow watch run.")
    }
}

extension LifeFlowQuickControlWidget {
    struct Value {
        var isRunning: Bool
    }

    struct RunControlProvider: AppIntentControlValueProvider {
        func previewValue(configuration: RunControlConfigurationIntent) -> Value {
            Value(isRunning: false)
        }

        func currentValue(configuration: RunControlConfigurationIntent) async throws -> Value {
            let state = WatchWidgetStateStore.load()
            let running = state.lifecycleState == .running || state.lifecycleState == .paused
            return Value(isRunning: running)
        }
    }
}

struct RunControlConfigurationIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Run Control"
}

struct ToggleRunStateIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Run State"

    @Parameter(title: "Run Active")
    var value: Bool

    init() {}

    init(value: Bool) {
        self.value = value
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            WidgetIntentRelay.enqueue(WidgetPendingIntentAction(kind: .startRun))
        }

        return .result()
    }
}

struct LifeFlowFuelControlWidget: ControlWidget {
    static let kind = "\(LifeFlowWidgetKinds.quickControl).fuel"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: WidgetLogNutritionIntent(carbs: 25)) {
                Label("Log Gel", systemImage: "drop.fill")
            }
        }
        .displayName("Log Gel")
        .description("Log nutrition without opening the app.")
    }
}
