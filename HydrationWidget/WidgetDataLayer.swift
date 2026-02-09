//
//  WidgetDataLayer.swift
//  HydrationWidgetExtension
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation
import SwiftData

// Duplicate URL extension for Widget target
extension URL {
    static func storeURL(for appGroup: String) -> URL {
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            fatalError("Shared file container could not be created for App Group: \(appGroup)")
        }
        return fileContainer.appendingPathComponent("LifeFlow.sqlite")
    }
}

/// Singleton to manage ModelContainer for the Widget
final class WidgetDataLayer {
    static let shared = WidgetDataLayer()
    
    let modelContainer: ModelContainer
    
    private init() {
        let appGroupIdentifier = "group.com.Fez.LifeFlow"
        let schema = Schema([
            DayLog.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            ExerciseSet.self,
            Goal.self,
            DailyEntry.self,
        ])
        
        let modelConfiguration = ModelConfiguration(
            url: URL.storeURL(for: appGroupIdentifier)
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Widget ModelContainer creation failed: \(error)")
        }
    }
    
    /// Fast path used by widget timeline rendering.
    func todayWaterIntake() -> Double {
        if let cached = HydrationSettings.loadCurrentIntake() {
            return max(0, cached)
        }
        
        let context = ModelContext(modelContainer)
        guard let log = fetchTodayLog(in: context) else { return 0 }
        let intake = max(0, log.waterIntake)
        HydrationSettings.saveCurrentIntake(intake)
        return intake
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
