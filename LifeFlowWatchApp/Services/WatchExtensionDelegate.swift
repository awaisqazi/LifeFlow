import Foundation
import SwiftData
import SwiftUI
import os

@MainActor
final class WatchExtensionDelegate: NSObject {
    static let shared = WatchExtensionDelegate()
    private let logger = Logger(subsystem: "com.Fez.LifeFlow.watch", category: "ExtensionDelegate")

    private override init() {
        super.init()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // Save the context so CloudKit can sync opportunistically.
            // Do NOT call WKExtension.shared().scheduleBackgroundRefresh()
            // as it triggers _dispatch_assert_queue_fail from CloudKit threads.
            saveContextIfNeeded()
        case .active, .inactive:
            break
        @unknown default:
            break
        }
    }

    private func saveContextIfNeeded() {
        let context = WatchDataStore.shared.modelContainer.mainContext
        do {
            if context.hasChanges {
                try context.save()
                logger.info("Context saved for background CloudKit sync opportunity.")
            }
        } catch {
            logger.error("Context save failed: \(error.localizedDescription)")
        }
    }
}
