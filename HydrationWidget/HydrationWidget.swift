//
//  HydrationWidget.swift
//  HydrationWidget
//
//  Created by Fez Qazi on 12/27/25.
//

import WidgetKit
import SwiftUI
import SwiftData

struct Provider: TimelineProvider {
    // Helper to fetch today's data directly
    func getTodayLog() -> DayLog {
        let context = ModelContext(WidgetDataLayer.shared.modelContainer)
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<DayLog>(
            predicate: #Predicate<DayLog> { $0.date >= today }
        )
        let results = try? context.fetch(descriptor)
        return results?.first ?? DayLog(date: Date())
    }
    
    /// Load hydration goal from shared settings
    private func getDailyGoal() -> Double {
        HydrationSettings.load().dailyOuncesGoal
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), waterIntake: 24, dailyGoal: getDailyGoal())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let log = getTodayLog()
        let entry = SimpleEntry(date: Date(), waterIntake: log.waterIntake, dailyGoal: getDailyGoal())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let log = getTodayLog()
        
        // Create an entry for now
        let entry = SimpleEntry(
            date: Date(),
            waterIntake: log.waterIntake,
            dailyGoal: getDailyGoal()
        )

        // Reload policy: update next time the app is opened or every hour, but Intent will trigger reload too.
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let waterIntake: Double
    let dailyGoal: Double
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
    }
}

#Preview(as: .systemSmall) {
    HydrationWidget()
} timeline: {
    SimpleEntry(date: .now, waterIntake: 12, dailyGoal: 64)
    SimpleEntry(date: .now, waterIntake: 48, dailyGoal: 64)
}
