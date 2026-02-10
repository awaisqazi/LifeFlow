//
//  DailyMetrics.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import Foundation
import SwiftData

/// Tracks daily wellness metrics for the LifeFlow momentum tracker.
/// This model persists water intake, workout sessions, and goal progress.
@Model
final class DayLog {
    /// The date this record represents (unique per day)
    var date: Date
    
    /// Water consumed in ounces
    var waterIntake: Double
    
    /// Workout sessions logged for this day
    @Relationship(deleteRule: .cascade) var workouts: [WorkoutSession]
    
    /// Daily entries for goals
    @Relationship(deleteRule: .cascade) var entries: [DailyEntry] = []
    
    /// Serialized per-session Fuel Station checklist state for this day.
    /// Key: session UUID string, Value: checked fuel item IDs.
    var fuelChecklistStateJSON: String?
    
    /// Total active calories burned from all workouts
    var totalActiveCalories: Double {
        workouts.reduce(0) { $0 + $1.calories }
    }
    
    /// Total workout duration for the day in seconds
    var totalWorkoutDuration: TimeInterval {
        workouts.reduce(0) { $0 + $1.duration }
    }
    
    /// Whether any workouts have been logged today
    var hasWorkedOut: Bool {
        workouts.contains { $0.isMeaningfullyCompleted }
    }
    
    /// Creates a new daily metrics record
    /// - Parameters:
    ///   - date: The date for this record
    ///   - waterIntake: Starting water intake (default 0)
    ///   - workouts: Initial workout sessions (default empty)
    init(
        date: Date = .now,
        waterIntake: Double = 0,
        workouts: [WorkoutSession] = [],
        entries: [DailyEntry] = [],
        fuelChecklistStateJSON: String? = nil
    ) {
        self.date = date
        self.waterIntake = waterIntake
        self.workouts = workouts
        self.entries = entries
        self.fuelChecklistStateJSON = fuelChecklistStateJSON
    }
    
    func fuelChecklist(for sessionID: UUID) -> Set<String> {
        let store = decodeFuelChecklistStore()
        let key = sessionID.uuidString
        return Set(store.bySessionID[key] ?? [])
    }
    
    func setFuelChecklist(_ itemIDs: Set<String>, for sessionID: UUID) {
        var store = decodeFuelChecklistStore()
        let key = sessionID.uuidString
        
        if itemIDs.isEmpty {
            store.bySessionID.removeValue(forKey: key)
        } else {
            store.bySessionID[key] = Array(itemIDs).sorted()
        }
        
        encodeFuelChecklistStore(store)
    }
    
    private struct FuelChecklistStore: Codable {
        var bySessionID: [String: [String]] = [:]
    }
    
    private func decodeFuelChecklistStore() -> FuelChecklistStore {
        guard let fuelChecklistStateJSON,
              let data = fuelChecklistStateJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(FuelChecklistStore.self, from: data) else {
            return FuelChecklistStore()
        }
        return decoded
    }
    
    private func encodeFuelChecklistStore(_ store: FuelChecklistStore) {
        if store.bySessionID.isEmpty {
            fuelChecklistStateJSON = nil
            return
        }
        
        if let data = try? JSONEncoder().encode(store),
           let json = String(data: data, encoding: .utf8) {
            fuelChecklistStateJSON = json
        }
    }
}
