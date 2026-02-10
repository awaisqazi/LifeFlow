import Foundation

public enum LifeFlowSharedConfig {
    public static let appGroupID = "group.com.Fez.LifeFlow"
}

public struct WatchWidgetState: Codable, Sendable, Equatable {
    public static let storageKey = "watchWidgetState"

    public var lastUpdated: Date
    public var lifecycleState: WatchRunLifecycleState
    public var elapsedSeconds: TimeInterval
    public var distanceMiles: Double
    public var heartRateBPM: Double?
    public var paceSecondsPerMile: Double?
    public var fuelRemainingGrams: Double?

    public init(
        lastUpdated: Date = Date(),
        lifecycleState: WatchRunLifecycleState = .idle,
        elapsedSeconds: TimeInterval = 0,
        distanceMiles: Double = 0,
        heartRateBPM: Double? = nil,
        paceSecondsPerMile: Double? = nil,
        fuelRemainingGrams: Double? = nil
    ) {
        self.lastUpdated = lastUpdated
        self.lifecycleState = lifecycleState
        self.elapsedSeconds = elapsedSeconds
        self.distanceMiles = distanceMiles
        self.heartRateBPM = heartRateBPM
        self.paceSecondsPerMile = paceSecondsPerMile
        self.fuelRemainingGrams = fuelRemainingGrams
    }
}

public enum WatchWidgetStateStore {
    public static func save(_ state: WatchWidgetState, appGroupID: String = LifeFlowSharedConfig.appGroupID) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(state) else {
            return
        }

        defaults.set(data, forKey: WatchWidgetState.storageKey)
    }

    public static func load(appGroupID: String = LifeFlowSharedConfig.appGroupID) -> WatchWidgetState {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: WatchWidgetState.storageKey),
              let state = try? JSONDecoder().decode(WatchWidgetState.self, from: data) else {
            return WatchWidgetState()
        }

        return state
    }
}
