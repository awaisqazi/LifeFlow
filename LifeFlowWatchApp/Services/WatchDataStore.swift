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
        // Use the actual top-level @Model types — NOT the nested VersionedSchema copies.
        // Using Schema(versionedSchema:) registers WatchRunSchemaV1.WatchWorkoutSession,
        // which is a different type than the top-level WatchWorkoutSession used throughout the app.
        let schema = Schema([
            WatchWorkoutSession.self,
            TelemetryPoint.self,
            RunEvent.self,
            WatchRunStateSnapshot.self
        ])
        let storeURL = Self.storeURL(appGroupID: LifeFlowSharedConfig.appGroupID)

        // watchOS: Use local-only persistence.
        //
        // CloudKit on watchOS causes _dispatch_assert_queue_fail crashes because
        // CloudKit's push notification registration internally runs on the
        // WatchConnectivity background queue instead of the main queue.
        // The iPhone app handles CloudKit sync; the watch syncs via WatchConnectivity.
        let localConfig = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [localConfig]
            )
            logger.info("Local ModelContainer initialized successfully.")
        } catch {
            logger.error("Local store init failed: \(error.localizedDescription). Deleting corrupted store and retrying.")

            // Attempt 2: Delete corrupted store files and retry
            Self.deleteStoreFiles(at: storeURL)

            let freshConfig = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )

            do {
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [freshConfig]
                )
                logger.info("Fresh local ModelContainer initialized after store reset.")
            } catch {
                // Attempt 3: In-memory fallback to prevent crash loops
                logger.fault("All persistent stores failed. Using in-memory container.")
                let memoryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                modelContainer = try! ModelContainer(
                    for: schema,
                    configurations: [memoryConfig]
                )
            }
        }
    }

    /// Deletes the SQLite store and its companion -wal/-shm files.
    private static func deleteStoreFiles(at url: URL) {
        let fm = FileManager.default
        let suffixes = ["", "-wal", "-shm"]
        for suffix in suffixes {
            let fileURL = URL(fileURLWithPath: url.path + suffix)
            try? fm.removeItem(at: fileURL)
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
