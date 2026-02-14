import AppIntents
import Foundation
import LifeFlowCore

enum WidgetPendingIntentKind: String, Codable {
    case startRun
    case logNutrition
    case toggleMetrics
}

struct WidgetPendingIntentAction: Codable, Sendable {
    var id: UUID
    var kind: WidgetPendingIntentKind
    var timestamp: Date
    var value: Double?

    init(kind: WidgetPendingIntentKind, value: Double? = nil) {
        self.id = UUID()
        self.kind = kind
        self.timestamp = Date()
        self.value = value
    }
}

enum WidgetIntentRelay {
    private static let queueKey = "watchIntentActionQueue"

    static func enqueue(_ action: WidgetPendingIntentAction) {
        guard let defaults = UserDefaults(suiteName: LifeFlowSharedConfig.appGroupID) else { return }

        var queue: [WidgetPendingIntentAction] = []
        if let data = defaults.data(forKey: queueKey),
           let decoded = try? JSONDecoder().decode([WidgetPendingIntentAction].self, from: data) {
            queue = decoded
        }

        queue.append(action)

        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: queueKey)
        }
    }
}

struct WidgetStartRunIntent: AppIntent, Sendable {
    static let title: LocalizedStringResource = "Start LifeFlow Run"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            WidgetIntentRelay.enqueue(WidgetPendingIntentAction(kind: .startRun))
        }
        return .result()
    }
}

struct WidgetLogNutritionIntent: AppIntent, Sendable {
    static let title: LocalizedStringResource = "Log Gel"

    @Parameter(title: "Carbs", default: 25)
    var carbs: Double

    init() {}

    init(carbs: Double) {
        self.carbs = carbs
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            WidgetIntentRelay.enqueue(
                WidgetPendingIntentAction(
                    kind: .logNutrition,
                    value: max(15, min(40, carbs))
                )
            )
        }
        return .result()
    }
}
