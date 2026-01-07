//
//  HydrationSettings.swift
//  LifeFlow
//
//  Shared hydration goal settings between main app and widget extension.
//  Must have target membership for BOTH LifeFlow AND HydrationWidgetExtension.
//

import Foundation
import WidgetKit

/// Shared hydration settings between main app and widget extension.
/// Uses App Group UserDefaults for communication.
struct HydrationSettings: Codable {
    /// Daily hydration goal in 8oz cups (default: 8 cups = 64oz)
    var dailyCupsGoal: Int
    
    /// Computed property: total daily goal in ounces
    var dailyOuncesGoal: Double {
        Double(dailyCupsGoal * 8)
    }
    
    /// Default settings (8 cups = 64oz)
    static var `default`: HydrationSettings {
        HydrationSettings(dailyCupsGoal: 8)
    }
    
    init(dailyCupsGoal: Int = 8) {
        // Clamp to valid range: 4-16 cups (32oz - 128oz)
        self.dailyCupsGoal = max(4, min(16, dailyCupsGoal))
    }
}

// MARK: - App Group Storage

extension HydrationSettings {
    private static let appGroupID = "group.com.Fez.LifeFlow"
    private static let storageKey = "hydrationSettings"
    
    /// Save settings to App Group UserDefaults and trigger widget reload
    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        
        if let encoded = try? JSONEncoder().encode(self) {
            defaults.set(encoded, forKey: Self.storageKey)
            WidgetCenter.shared.reloadTimelines(ofKind: "HydrationWidget")
        }
    }
    
    /// Load settings from App Group UserDefaults
    static func load() -> HydrationSettings {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(HydrationSettings.self, from: data) else {
            return .default
        }
        return settings
    }
}
