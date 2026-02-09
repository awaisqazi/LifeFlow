//
//  LifeFlowExperienceSettings.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import Foundation

enum MicroDelightIntensity: String, Codable, CaseIterable, Identifiable {
    case full
    case subtle
    case off
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .full: return "Full"
        case .subtle: return "Subtle"
        case .off: return "Off"
        }
    }
    
    var successPulseScale: Double {
        switch self {
        case .full: return 1.0
        case .subtle: return 0.45
        case .off: return 0.0
        }
    }
    
    var bubbleParticleScale: Double {
        switch self {
        case .full: return 1.0
        case .subtle: return 0.55
        case .off: return 0.0
        }
    }
    
    var isEnabled: Bool {
        self != .off
    }
}

struct LifeFlowExperienceSettings: Codable {
    var microDelightIntensity: MicroDelightIntensity
    
    static var `default`: LifeFlowExperienceSettings {
        LifeFlowExperienceSettings(microDelightIntensity: .full)
    }
}

extension LifeFlowExperienceSettings {
    private static let appGroupID = "group.com.Fez.LifeFlow"
    private static let storageKey = "lifeFlowExperienceSettings"
    
    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let encoded = try? JSONEncoder().encode(self) else {
            return
        }
        defaults.set(encoded, forKey: Self.storageKey)
    }
    
    static func load() -> LifeFlowExperienceSettings {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let data = defaults.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(LifeFlowExperienceSettings.self, from: data) else {
            return .default
        }
        return settings
    }
}
