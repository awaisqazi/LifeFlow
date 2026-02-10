import Foundation
import SwiftData
import LifeFlowCore

final class WatchDataStore {
    static let shared = WatchDataStore()

    let modelContainer: ModelContainer

    private init() {
        // Use versioned schema with migration plan
        let schema = Schema(versionedSchema: WatchRunSchemaV1.self)

        // Enable CloudKit sync with offline-first architecture
        let configuration = ModelConfiguration(
            schema: schema,
            url: Self.storeURL(appGroupID: LifeFlowSharedConfig.appGroupID),
            cloudKitDatabase: .private("iCloud.com.Fez.LifeFlow")
        )

        do {
            // Initialize with migration plan for automatic schema versioning
            modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: WatchRunMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Unable to create watch SwiftData container: \(error)")
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
