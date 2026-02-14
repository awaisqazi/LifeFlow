import Foundation
import SwiftData
import LifeFlowCore
import os

@MainActor
final class WatchDataStore: Sendable {
    static let shared = WatchDataStore()

    let modelContainer: ModelContainer
    private let logger = Logger(subsystem: "com.Fez.LifeFlow.watch", category: "DataStore")

    private init() {
        let schema = Schema(versionedSchema: WatchRunSchemaV1.self)
        let storeURL = Self.storeURL(appGroupID: LifeFlowSharedConfig.appGroupID)

        // Attempt 1: CloudKit sync (preferred)
        let cloudConfig = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .private("iCloud.com.Fez.LifeFlow")
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: WatchRunMigrationPlan.self,
                configurations: [cloudConfig]
            )
            logger.info("CloudKit ModelContainer initialized successfully.")
        } catch {
            logger.error("CloudKit init failed: \(error.localizedDescription). Falling back to local store.")

            // Attempt 2: Local-only persistence
            let localConfig = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )

            do {
                modelContainer = try ModelContainer(
                    for: schema,
                    migrationPlan: WatchRunMigrationPlan.self,
                    configurations: [localConfig]
                )
                logger.info("Local ModelContainer initialized successfully.")
            } catch {
                logger.fault("Local store failed: \(error.localizedDescription). Using in-memory container.")

                // Attempt 3: In-memory fallback to prevent crash loops
                let memoryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                modelContainer = try! ModelContainer(
                    for: schema,
                    migrationPlan: WatchRunMigrationPlan.self,
                    configurations: [memoryConfig]
                )
            }
        }
    }

    private static func storeURL(appGroupID: String) -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            fatalError("Missing App Group container for \(appGroupID)")
        }

        return container.appendingPathComponent("LifeFlowWatch.sqlite")
    }
}
