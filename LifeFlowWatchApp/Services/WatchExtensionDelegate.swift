import Foundation
import SwiftData
import SwiftUI

final class WatchExtensionDelegate: NSObject {
    static let shared = WatchExtensionDelegate()

    private override init() {
        super.init()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // When app enters background, trigger CloudKit sync
            Task {
                await performCloudKitSync()
            }
        case .active, .inactive:
            break
        @unknown default:
            break
        }
    }

    private func performCloudKitSync() async {
        // SwiftData with CloudKit handles sync automatically when using
        // ModelConfiguration with cloudKitDatabase parameter.
        // This method ensures the context is saved and gives CloudKit
        // an opportunity to sync during background refresh.

        let context = WatchDataStore.shared.modelContainer.mainContext

        do {
            // Force save to trigger CloudKit sync
            try context.save()

            // Schedule next refresh for 6 hours later
            let nextRefresh = Date().addingTimeInterval(6 * 60 * 60)
            WKExtension.shared().scheduleBackgroundRefresh(
                withPreferredDate: nextRefresh,
                userInfo: nil
            ) { error in
                if let error = error {
                    print("Failed to schedule background refresh: \(error.localizedDescription)")
                }
            }
        } catch {
            print("CloudKit sync save failed: \(error.localizedDescription)")
        }
    }
}
