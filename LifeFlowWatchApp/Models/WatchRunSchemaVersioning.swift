import Foundation
import SwiftData

/// Schema versioning for LifeFlow Watch models
enum WatchRunSchemaVersion: String, Codable {
    case v1 = "1.0"
    case v2 = "2.0"
}

/// V1 Schema - Initial release
enum WatchRunSchemaV1: VersionedSchema {
    static let versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [
            WatchWorkoutSession.self,
            TelemetryPoint.self,
            RunEvent.self,
            WatchRunStateSnapshot.self
        ]
    }
    
    @Model
    final class WatchWorkoutSession {
        var id: UUID = UUID()
        var startedAt: Date = Date()
        var endedAt: Date?
        
        var totalEnergyBurned: Double = 0
        var totalDistanceMiles: Double = 0
        var averageHeartRate: Double?
        var healthKitWorkoutID: UUID?
        var postRunEffort: Int?
        var postRunReflection: String?
        var requiresRefinementSync: Bool = false
        var isCloudSynced: Bool = false
        
        @Relationship(deleteRule: .cascade)
        var telemetryPoints: [TelemetryPoint]? = []
        
        @Relationship(deleteRule: .cascade)
        var runEvents: [RunEvent]? = []
        
        @Relationship(deleteRule: .cascade)
        var stateSnapshots: [WatchRunStateSnapshot]? = []
        
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
        var id: UUID = UUID()
        var timestamp: Date = Date()
        var distanceMiles: Double = 0
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
    
    @Model
    final class RunEvent {
        var id: UUID = UUID()
        var timestamp: Date = Date()
        var kindRawValue: String = "started"
        var payloadJSON: String?
        
        @Relationship(inverse: \WatchWorkoutSession.runEvents)
        var workoutSession: WatchWorkoutSession?
        
        init(
            id: UUID = UUID(),
            timestamp: Date,
            kindRawValue: String,
            payloadJSON: String? = nil
        ) {
            self.id = id
            self.timestamp = timestamp
            self.kindRawValue = kindRawValue
            self.payloadJSON = payloadJSON
        }
    }
    
    @Model
    final class WatchRunStateSnapshot {
        var id: UUID = UUID()
        var timestamp: Date = Date()
        var lifecycleStateRawValue: String = "idle"
        var elapsedSeconds: TimeInterval = 0
        var distanceMiles: Double = 0
        var heartRateBPM: Double?
        var paceSecondsPerMile: Double?
        var fuelRemainingGrams: Double?
        
        @Relationship(inverse: \WatchWorkoutSession.stateSnapshots)
        var workoutSession: WatchWorkoutSession?
        
        init(
            id: UUID = UUID(),
            timestamp: Date,
            lifecycleStateRawValue: String,
            elapsedSeconds: TimeInterval,
            distanceMiles: Double,
            heartRateBPM: Double? = nil,
            paceSecondsPerMile: Double? = nil,
            fuelRemainingGrams: Double? = nil
        ) {
            self.id = id
            self.timestamp = timestamp
            self.lifecycleStateRawValue = lifecycleStateRawValue
            self.elapsedSeconds = elapsedSeconds
            self.distanceMiles = distanceMiles
            self.heartRateBPM = heartRateBPM
            self.paceSecondsPerMile = paceSecondsPerMile
            self.fuelRemainingGrams = fuelRemainingGrams
        }
    }
}

/// Migration plan for schema versions
enum WatchRunMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WatchRunSchemaV1.self]
    }
    
    static var stages: [MigrationStage] {
        [
            // Future migrations will be added here
            // Example:
            // migrateV1toV2
        ]
    }
    
    // Example migration stage (for future use)
    // static let migrateV1toV2 = MigrationStage.custom(
    //     fromVersion: WatchRunSchemaV1.self,
    //     toVersion: WatchRunSchemaV2.self,
    //     willMigrate: { context in
    //         // Pre-migration logic
    //     },
    //     didMigrate: { context in
    //         // Post-migration logic
    //     }
    // )
}
