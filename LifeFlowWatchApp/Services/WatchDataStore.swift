import Foundation
import SwiftData
import LifeFlowCore

final class WatchDataStore {
    static let shared = WatchDataStore()

    let modelContainer: ModelContainer

    private init() {
        let schema = Schema([
            WatchWorkoutSession.self,
            TelemetryPoint.self,
            RunEvent.self,
            WatchRunStateSnapshot.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            url: Self.storeURL(appGroupID: LifeFlowSharedConfig.appGroupID)
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
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
