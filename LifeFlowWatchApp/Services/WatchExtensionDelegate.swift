import Foundation
import WatchKit

final class WatchExtensionDelegate: NSObject, WKExtensionDelegate {
    func applicationDidFinishLaunching() {}

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                // Reserved for post-run CloudKit catch-up.
                refreshTask.setTaskCompletedWithSnapshot(false)
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
