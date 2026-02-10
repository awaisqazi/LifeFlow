import Foundation
import SwiftData
import LifeFlowCore

@Model
final class WatchWorkoutSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?

    var totalEnergyBurned: Double
    var totalDistanceMiles: Double
    var averageHeartRate: Double?
    var healthKitWorkoutID: UUID?
    var postRunEffort: Int?
    var postRunReflection: String?
    var requiresRefinementSync: Bool

    var isCloudSynced: Bool

    @Relationship(deleteRule: .cascade)
    var telemetryPoints: [TelemetryPoint] = []

    @Relationship(deleteRule: .cascade)
    var runEvents: [RunEvent] = []

    @Relationship(deleteRule: .cascade)
    var stateSnapshots: [WatchRunStateSnapshot] = []

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        totalEnergyBurned: Double = 0,
        totalDistanceMiles: Double = 0,
        averageHeartRate: Double? = nil,
        healthKitWorkoutID: UUID? = nil,
        postRunEffort: Int? = nil,
        postRunReflection: String? = nil,
        requiresRefinementSync: Bool = false,
        isCloudSynced: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalEnergyBurned = totalEnergyBurned
        self.totalDistanceMiles = totalDistanceMiles
        self.averageHeartRate = averageHeartRate
        self.healthKitWorkoutID = healthKitWorkoutID
        self.postRunEffort = postRunEffort
        self.postRunReflection = postRunReflection
        self.requiresRefinementSync = requiresRefinementSync
        self.isCloudSynced = isCloudSynced
    }
}

@Model
final class TelemetryPoint {
    var id: UUID
    var timestamp: Date

    var distanceMiles: Double
    var heartRateBPM: Double?
    var paceSecondsPerMile: Double?
    var cadenceSPM: Double?
    var gradePercent: Double?
    var fuelRemainingGrams: Double?

    @Relationship(inverse: \WatchWorkoutSession.telemetryPoints)
    var workoutSession: WatchWorkoutSession?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        distanceMiles: Double,
        heartRateBPM: Double? = nil,
        paceSecondsPerMile: Double? = nil,
        cadenceSPM: Double? = nil,
        gradePercent: Double? = nil,
        fuelRemainingGrams: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.distanceMiles = distanceMiles
        self.heartRateBPM = heartRateBPM
        self.paceSecondsPerMile = paceSecondsPerMile
        self.cadenceSPM = cadenceSPM
        self.gradePercent = gradePercent
        self.fuelRemainingGrams = fuelRemainingGrams
    }
}

enum RunEventKind: String, Codable {
    case started
    case paused
    case resumed
    case ended
    case fuelLogged
    case lapMarked
    case alertAcknowledged
    case paceAdjustment
}

@Model
final class RunEvent {
    var id: UUID
    var timestamp: Date
    var kindRawValue: String
    var payloadJSON: String?

    @Relationship(inverse: \WatchWorkoutSession.runEvents)
    var workoutSession: WatchWorkoutSession?

    var kind: RunEventKind {
        get { RunEventKind(rawValue: kindRawValue) ?? .paceAdjustment }
        set { kindRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date,
        kind: RunEventKind,
        payloadJSON: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kindRawValue = kind.rawValue
        self.payloadJSON = payloadJSON
    }
}

@Model
final class WatchRunStateSnapshot {
    var id: UUID
    var timestamp: Date

    var lifecycleStateRawValue: String
    var elapsedSeconds: TimeInterval
    var distanceMiles: Double
    var heartRateBPM: Double?
    var paceSecondsPerMile: Double?
    var fuelRemainingGrams: Double?

    @Relationship(inverse: \WatchWorkoutSession.stateSnapshots)
    var workoutSession: WatchWorkoutSession?

    var lifecycleState: WatchRunLifecycleState {
        get { WatchRunLifecycleState(rawValue: lifecycleStateRawValue) ?? .idle }
        set { lifecycleStateRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date,
        lifecycleState: WatchRunLifecycleState,
        elapsedSeconds: TimeInterval,
        distanceMiles: Double,
        heartRateBPM: Double? = nil,
        paceSecondsPerMile: Double? = nil,
        fuelRemainingGrams: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.lifecycleStateRawValue = lifecycleState.rawValue
        self.elapsedSeconds = elapsedSeconds
        self.distanceMiles = distanceMiles
        self.heartRateBPM = heartRateBPM
        self.paceSecondsPerMile = paceSecondsPerMile
        self.fuelRemainingGrams = fuelRemainingGrams
    }
}
