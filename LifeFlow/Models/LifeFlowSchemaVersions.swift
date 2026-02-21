//
//  LifeFlowSchemaVersions.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation
import SwiftData

/// Schema versioning for LifeFlow data models.
/// Used for migration planning when schema changes are introduced.
/// App target only: HydrationWidgetExtension maintains its own schema in
/// HydrationWidget/WidgetDataLayer.swift.
enum LifeFlowSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [
            Goal.self,
            DailyEntry.self,
            DayLog.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            ExerciseSet.self,
            WorkoutRoutine.self,
            TrainingPlan.self,
            TrainingSession.self,
            TelemetryPoint.self,
            RunEvent.self,
            WatchRunStateSnapshot.self
        ]
    }
}

/// Migration plan for future schema updates.
/// Add new version schemas and migration stages as needed.
enum LifeFlowMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LifeFlowSchemaV1.self]
    }
    
    static var stages: [MigrationStage] {
        // Add migration stages here when schema changes are needed
        // Example:
        // .lightweight(fromVersion: LifeFlowSchemaV1.self, toVersion: LifeFlowSchemaV2.self)
        []
    }
}
