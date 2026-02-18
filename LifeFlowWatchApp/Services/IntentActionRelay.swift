import Foundation
import LifeFlowCore

enum PendingWatchIntentKind: String, Codable, Sendable {
    case startRun
    case logNutrition
    case markLap
    case dismissAlert
    case toggleMetrics
}

struct PendingWatchIntentAction: Codable, Sendable {
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

actor IntentActionRelay {
    static let shared = IntentActionRelay()

    private let queueKey = "watchIntentActionQueue"
    private let appGroupID: String

    init(appGroupID: String = LifeFlowSharedConfig.appGroupID) {
        self.appGroupID = appGroupID
    }

    func enqueue(_ action: PendingWatchIntentAction) {
        guard let defaults = defaults else { return }

        var queue = loadQueue(defaults: defaults)
        queue.append(action)

        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: queueKey)
        }
    }

    func consumeAll() -> [PendingWatchIntentAction] {
        guard let defaults = defaults else { return [] }

        let queue = loadQueue(defaults: defaults)
        defaults.removeObject(forKey: queueKey)
        return queue
    }

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private func loadQueue(defaults: UserDefaults) -> [PendingWatchIntentAction] {
        guard let data = defaults.data(forKey: queueKey),
              let queue = try? JSONDecoder().decode([PendingWatchIntentAction].self, from: data) else {
            return []
        }

        return queue
    }
}
