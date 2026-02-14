//
//  LogWaterIntent.swift
//  HydrationWidgetExtension
//
//  Created by Fez Qazi on 12/27/25.
//

import AppIntents
import WidgetKit

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
        _ = WidgetDataLayer.shared.updateTodayWaterIntake(by: amount)
        WidgetCenter.shared.reloadTimelines(ofKind: "HydrationWidget")
        return .result()
    }
}
