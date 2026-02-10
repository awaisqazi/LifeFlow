import Foundation
import LifeFlowCore

enum PendingWatchIntentKind: String, Codable {
    case startRun
    case logNutrition
    case markLap
    case dismissAlert
    case toggleMetrics
}

struct PendingWatchIntentAction: Codable {
    var id: UUID
    var kind: PendingWatchIntentKind
    var timestamp: Date
    var value: Double?

    init(kind: PendingWatchIntentKind, value: Double? = nil) {
        self.id = UUID()
        self.kind = kind
        self.timestamp = Date()
        self.value = value
    }
}

enum IntentActionRelay {
    private static let queueKey = "watchIntentActionQueue"

    static func enqueue(_ action: PendingWatchIntentAction, appGroupID: String = LifeFlowSharedConfig.appGroupID) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        var queue = loadQueue(defaults: defaults)
        queue.append(action)

        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: queueKey)
        }
    }

    static func consumeAll(appGroupID: String = LifeFlowSharedConfig.appGroupID) -> [PendingWatchIntentAction] {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return [] }

        let queue = loadQueue(defaults: defaults)
        defaults.removeObject(forKey: queueKey)
        return queue
    }

    private static func loadQueue(defaults: UserDefaults) -> [PendingWatchIntentAction] {
        guard let data = defaults.data(forKey: queueKey),
              let queue = try? JSONDecoder().decode([PendingWatchIntentAction].self, from: data) else {
            return []
        }

        return queue
    }
}
