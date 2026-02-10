import Foundation

public enum WatchRunEvent: String, Codable, Sendable, CaseIterable {
    case runStarted
    case runPaused
    case runResumed
    case runEnded
    case fuelLogged
    case lapMarked
    case metricSnapshot
}

public enum WatchRunLifecycleState: String, Codable, Sendable {
    case idle
    case preparing
    case running
    case paused
    case ended
}

public struct WatchRunMessage: Codable, Sendable, Equatable {
    public static let payloadKey = "watchRunMessageJSON"

    public var id: UUID
    public var event: WatchRunEvent
    public var timestamp: Date
    public var runID: UUID?

    public var lifecycleState: WatchRunLifecycleState?
    public var metricSnapshot: TelemetrySnapshotDTO?
    public var heartRateBPM: Double?
    public var carbsGrams: Double?
    public var lapIndex: Int?
    public var discarded: Bool?

    public init(
        id: UUID = UUID(),
        event: WatchRunEvent,
        timestamp: Date = Date(),
        runID: UUID? = nil,
        lifecycleState: WatchRunLifecycleState? = nil,
        metricSnapshot: TelemetrySnapshotDTO? = nil,
        heartRateBPM: Double? = nil,
        carbsGrams: Double? = nil,
        lapIndex: Int? = nil,
        discarded: Bool? = nil
    ) {
        self.id = id
        self.event = event
        self.timestamp = timestamp
        self.runID = runID
        self.lifecycleState = lifecycleState
        self.metricSnapshot = metricSnapshot
        self.heartRateBPM = heartRateBPM
        self.carbsGrams = carbsGrams
        self.lapIndex = lapIndex
        self.discarded = discarded
    }

    public func toWCContext() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return [:]
        }

        return [Self.payloadKey: json]
    }

    public static func fromWCContext(_ context: [String: Any]) -> WatchRunMessage? {
        if let json = context[Self.payloadKey] as? String,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(WatchRunMessage.self, from: data) {
            return decoded
        }

        return fromLegacyContext(context)
    }

    private static func fromLegacyContext(_ context: [String: Any]) -> WatchRunMessage? {
        guard let eventRaw = context["event"] as? String else { return nil }

        let mappedEvent: WatchRunEvent?
        switch eventRaw {
        case "guided_run_started":
            mappedEvent = .runStarted
        case "guided_run_paused":
            mappedEvent = .runPaused
        case "guided_run_resumed":
            mappedEvent = .runResumed
        case "guided_run_ended":
            mappedEvent = .runEnded
        default:
            mappedEvent = WatchRunEvent(rawValue: eventRaw)
        }

        guard let event = mappedEvent else { return nil }

        let timestampSeconds = (context["timestamp"] as? TimeInterval) ??
            (context["startedAt"] as? TimeInterval) ?? Date().timeIntervalSince1970

        let runID = (context["runID"] as? String).flatMap(UUID.init(uuidString:))
        let heartRateBPM = context["heartRate"] as? Double
        let carbsGrams = context["carbsGrams"] as? Double
        let discarded = context["discarded"] as? Bool

        var snapshot: TelemetrySnapshotDTO?
        if let distance = context["distanceMiles"] as? Double {
            snapshot = TelemetrySnapshotDTO(
                timestamp: Date(timeIntervalSince1970: timestampSeconds),
                distanceMiles: distance,
                heartRateBPM: heartRateBPM,
                paceSecondsPerMile: context["paceSecondsPerMile"] as? Double,
                cadenceSPM: context["cadenceSPM"] as? Double,
                gradePercent: context["gradePercent"] as? Double,
                fuelRemainingGrams: context["fuelRemainingGrams"] as? Double
            )
        }

        return WatchRunMessage(
            event: event,
            timestamp: Date(timeIntervalSince1970: timestampSeconds),
            runID: runID,
            metricSnapshot: snapshot,
            heartRateBPM: heartRateBPM,
            carbsGrams: carbsGrams,
            lapIndex: context["lapIndex"] as? Int,
            discarded: discarded
        )
    }
}
