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
    static let defaultMantra = "Relentless Forward Motion"

    var voiceCoachStartupMode: VoiceCoachStartupMode
    var isVoiceCoachEnabled: Bool
    var announceDistance: Bool
    var announcePace: Bool
    var mantra: String

    private enum CodingKeys: String, CodingKey {
        case voiceCoachStartupMode
        case isVoiceCoachEnabled
        case announceDistance
        case announcePace
        case mantra
    }

    init(
        voiceCoachStartupMode: VoiceCoachStartupMode,
        isVoiceCoachEnabled: Bool,
        announceDistance: Bool,
        announcePace: Bool,
        mantra: String
    ) {
        self.voiceCoachStartupMode = voiceCoachStartupMode
        self.isVoiceCoachEnabled = isVoiceCoachEnabled
        self.announceDistance = announceDistance
        self.announcePace = announcePace
        self.mantra = Self.normalizeMantra(mantra)
    }

    static var `default`: MarathonCoachSettings {
        MarathonCoachSettings(
            voiceCoachStartupMode: .enabled,
            isVoiceCoachEnabled: true,
            announceDistance: true,
            announcePace: true,
            mantra: defaultMantra
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        voiceCoachStartupMode = try container.decodeIfPresent(VoiceCoachStartupMode.self, forKey: .voiceCoachStartupMode) ?? .enabled
        isVoiceCoachEnabled = try container.decodeIfPresent(Bool.self, forKey: .isVoiceCoachEnabled) ?? true
        announceDistance = try container.decodeIfPresent(Bool.self, forKey: .announceDistance) ?? true
        announcePace = try container.decodeIfPresent(Bool.self, forKey: .announcePace) ?? true
        let decodedMantra = try container.decodeIfPresent(String.self, forKey: .mantra) ?? Self.defaultMantra
        mantra = Self.normalizeMantra(decodedMantra)
    }

    private static func normalizeMantra(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultMantra }
        return String(trimmed.prefix(80))
    }
}

extension MarathonCoachSettings {
    private static let appGroupID = HydrationSettings.appGroupID
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
