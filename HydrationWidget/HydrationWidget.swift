//
//  HydrationWidget.swift
//  HydrationWidget
//
//  Created by Fez Qazi on 12/27/25.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    /// Load hydration goal from shared settings
    private func getDailyGoal() -> Double {
        HydrationSettings.load().dailyOuncesGoal
    }
    
    private func makeEntry(for date: Date) -> SimpleEntry {
        // Read directly from App Group UserDefaults — the single source of truth
        // shared by both the main app and LogWaterIntent.
        // Avoid WidgetDataLayer.todayWaterIntake() which can fall back to a
        // separate SQLite database and return stale data.
        let intake = HydrationSettings.loadCurrentIntake() ?? 0
        return SimpleEntry(
            date: date,
            waterIntake: max(0, intake),
            dailyGoal: getDailyGoal()
        )
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), waterIntake: 24, dailyGoal: getDailyGoal())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entry = makeEntry(for: Date())

        // Refresh passively every 30 minutes. Interactive intent updates trigger immediate reloads.
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800)))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let waterIntake: Double
    let dailyGoal: Double
    
    var progress: Double {
        guard dailyGoal > 0 else { return 0 }
        return max(0, min(waterIntake / dailyGoal, 1))
    }
}

struct HydrationWidget: Widget {
    let kind: String = "HydrationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HydrationWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Hydration Tracker")
        .description("Log water and track your daily progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    HydrationWidget()
} timeline: {
    SimpleEntry(date: .now, waterIntake: 12, dailyGoal: 64)
    SimpleEntry(date: .now, waterIntake: 48, dailyGoal: 64)
}
