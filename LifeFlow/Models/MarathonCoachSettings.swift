//
//  MarathonCoachSettings.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import Foundation

enum VoiceCoachStartupMode: String, Codable, CaseIterable {
    case enabled
    case muted

    var displayName: String {
        switch self {
        case .enabled: return "On"
        case .muted: return "Muted"
        }
    }
}

struct MarathonCoachSettings: Codable {
    var voiceCoachStartupMode: VoiceCoachStartupMode
    var isVoiceCoachEnabled: Bool
    var announceDistance: Bool
    var announcePace: Bool

    static var `default`: MarathonCoachSettings {
        MarathonCoachSettings(
            voiceCoachStartupMode: .enabled,
            isVoiceCoachEnabled: true,
            announceDistance: true,
            announcePace: true
        )
    }
}

extension MarathonCoachSettings {
    private static let appGroupID = "group.com.Fez.LifeFlow"
    private static let storageKey = "marathonCoachSettings"

    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else { return }
        guard let encoded = try? JSONEncoder().encode(self) else { return }
        defaults.set(encoded, forKey: Self.storageKey)
    }

    static func load() -> MarathonCoachSettings {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(MarathonCoachSettings.self, from: data) else {
            return .default
        }
        return settings
    }
}

enum MarathonPaceDefaults {
    static func targetPaceMinutesPerMile(for runType: RunType) -> Double? {
        switch runType {
        case .recovery:
            return 11.5
        case .base:
            return 10.5
        case .longRun:
            return 11.0
        case .tempo:
            return 8.75
        case .speedWork:
            return 8.0
        case .crossTraining, .rest:
            return nil
        }
    }

    static func estimatedDurationMinutes(distanceMiles: Double, runType: RunType) -> Int? {
        guard let pace = targetPaceMinutesPerMile(for: runType), pace > 0, distanceMiles > 0 else {
            return nil
        }
        return Int((distanceMiles * pace).rounded())
    }
}
