//
//  WidgetDataLayer.swift
//  HydrationWidgetExtension
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation
import SwiftData
import os

// Duplicate URL extension for Widget target
extension URL {
    static func storeURL(for appGroup: String) -> URL {
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            // Fallback to temp dir instead of fatalError — widget will degrade gracefully
            return FileManager.default.temporaryDirectory.appendingPathComponent("LifeFlowHydrationWidget.sqlite")
        }
        // Keep the widget store isolated to avoid schema conflicts with the main app.
        return fileContainer.appendingPathComponent("LifeFlowHydrationWidget.sqlite")
    }
}

/// Singleton to manage ModelContainer for the Widget
final class WidgetDataLayer {
    static let shared = WidgetDataLayer()
    
    let modelContainer: ModelContainer
    private let logger = Logger(subsystem: "com.Fez.LifeFlow.widget", category: "DataLayer")
    
    private init() {
        let appGroupIdentifier = HydrationSettings.appGroupID
        let schema = Schema([
            DayLog.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            ExerciseSet.self,
            Goal.self,
            DailyEntry.self,
        ])
        
        let modelConfiguration = ModelConfiguration(
            url: URL.storeURL(for: appGroupIdentifier),
            cloudKitDatabase: .none
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            logger.error("Widget ModelContainer creation failed: \(error.localizedDescription). Using in-memory fallback.")
            // Graceful degradation: in-memory container so the widget still renders
            modelContainer = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
            )
        }
    }
    
    /// Returns today's water intake, preferring the App Group UserDefaults cache.
    /// Falls back to the widget's local SwiftData only if no cached value exists,
    /// but does NOT overwrite UserDefaults from the fallback (the main app owns that value).
    func todayWaterIntake() -> Double {
        if let cached = HydrationSettings.loadCurrentIntake() {
            return max(0, cached)
        }

        let context = ModelContext(modelContainer)
        guard let log = fetchTodayLog(in: context) else { return 0 }
        return max(0, log.waterIntake)
    }
    
    /// Updates both App Group defaults and SwiftData for consistency with the main app.
    @discardableResult
    func updateTodayWaterIntake(by delta: Double) -> Double {
        let newValue = max(0, todayWaterIntake() + delta)
        persistTodayWaterIntake(newValue)
        return newValue
    }
    
    func persistTodayWaterIntake(_ intake: Double) {
        let clampedIntake = max(0, intake)
        HydrationSettings.saveCurrentIntake(clampedIntake)
        
        let context = ModelContext(modelContainer)
        let dayLog = fetchTodayLog(in: context) ?? DayLog(date: Date())
        if dayLog.modelContext == nil {
            context.insert(dayLog)
        }
        dayLog.waterIntake = clampedIntake
        try? context.save()
    }
    
    private func fetchTodayLog(in context: ModelContext) -> DayLog? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }
        
        let descriptor = FetchDescriptor<DayLog>(
            predicate: #Predicate<DayLog> { log in
                log.date >= startOfDay && log.date < endOfDay
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }
}
