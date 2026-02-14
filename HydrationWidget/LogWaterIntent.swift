//
//  LogWaterIntent.swift
//  HydrationWidgetExtension
//
//  Created by Fez Qazi on 12/27/25.
//  Updated for iOS 26: WCSession sync to iPhone after widget water log.
//

import AppIntents
import WidgetKit
import WatchConnectivity

struct LogWaterIntent: AppIntent, Sendable {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Adds water to today's hydration log.")

    @Parameter(title: "Amount")
    var amount: Double

    init() {
        self.amount = 8.0
    }

    init(amount: Double) {
        self.amount = amount
    }

    func perform() async throws -> some IntentResult {
        // Allow negative amounts (e.g. -8 oz undo button).
        // The data layer clamps the final total to >= 0.
        guard amount != 0 else { return .result() }

        // 1. Update the widget's local data store
        let newTotal = WidgetDataLayer.shared.updateTodayWaterIntake(by: amount)

        // 2. Reload widget timelines so the glanceable UI reflects the change
        WidgetCenter.shared.reloadTimelines(ofKind: "HydrationWidget")

        // 3. Sync the updated total to the iPhone companion app via WCSession.
        //    updateApplicationContext is fire-and-forget, so it's safe to call
        //    from the widget extension process. The iPhone's WatchConnectivityManager
        //    will pick this up and update its local SwiftData store.
        if WCSession.isSupported() {
            let session = WCSession.default
            if session.activationState == .activated {
                do {
                    try session.updateApplicationContext([
                        "action": "HYDRATION_UPDATE",
                        "totalOz": newTotal,
                        "timestamp": Date().timeIntervalSince1970
                    ])
                } catch {
                    // Non-fatal — the iPhone will eventually sync via other paths.
                }
            }
        }

        return .result()
    }
}
