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
}
