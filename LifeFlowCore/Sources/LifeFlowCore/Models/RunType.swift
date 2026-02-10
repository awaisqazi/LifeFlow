import Foundation

public enum RunType: String, Codable, CaseIterable, Sendable {
    case recovery
    case base
    case longRun
    case speedWork
    case tempo
    case crossTraining
    case rest

    public var countsAsMileage: Bool {
        switch self {
        case .rest, .crossTraining:
            return false
        default:
            return true
        }
    }

    public var intensityFactor: Double {
        switch self {
        case .rest:
            return 0.0
        case .recovery:
            return 0.3
        case .crossTraining:
            return 0.4
        case .base:
            return 0.5
        case .longRun:
            return 0.6
        case .tempo:
            return 0.75
        case .speedWork:
            return 0.85
        }
    }
}

public enum MarathonPaceDefaults {
    public static func targetPaceMinutesPerMile(for runType: RunType) -> Double? {
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

    public static func estimatedDurationMinutes(distanceMiles: Double, runType: RunType) -> Int? {
        guard let pace = targetPaceMinutesPerMile(for: runType), pace > 0, distanceMiles > 0 else {
            return nil
        }
        return Int((distanceMiles * pace).rounded())
    }
}
