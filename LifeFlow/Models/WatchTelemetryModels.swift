import Foundation
import SwiftData

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

    @Relationship(inverse: \WorkoutSession.telemetryPoints)
    var workoutSession: WorkoutSession?

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

@Model
final class RunEvent {
    var id: UUID
    var timestamp: Date
    var kind: String
    var payloadJSON: String?

    @Relationship(inverse: \WorkoutSession.runEvents)
    var workoutSession: WorkoutSession?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        kind: String,
        payloadJSON: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.payloadJSON = payloadJSON
    }
}

@Model
final class WatchRunStateSnapshot {
    var id: UUID
    var timestamp: Date
    var lifecycleState: String

    var elapsedSeconds: TimeInterval
    var distanceMiles: Double
    var heartRateBPM: Double?
    var paceSecondsPerMile: Double?
    var fuelRemainingGrams: Double?

    @Relationship(inverse: \WorkoutSession.stateSnapshots)
    var workoutSession: WorkoutSession?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        lifecycleState: String,
        elapsedSeconds: TimeInterval,
        distanceMiles: Double,
        heartRateBPM: Double? = nil,
        paceSecondsPerMile: Double? = nil,
        fuelRemainingGrams: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.lifecycleState = lifecycleState
        self.elapsedSeconds = elapsedSeconds
        self.distanceMiles = distanceMiles
        self.heartRateBPM = heartRateBPM
        self.paceSecondsPerMile = paceSecondsPerMile
        self.fuelRemainingGrams = fuelRemainingGrams
    }
}
