import Foundation

public struct LiveRunMetrics: Codable, Sendable, Equatable {
    public var timestamp: Date
    public var heartRateBPM: Double?
    public var paceSecondsPerMile: Double?
    public var distanceMiles: Double
    public var cadenceSPM: Double?
    public var gradePercent: Double?
    public var caloriesPerMinute: Double?
    public var heartRateZone: Int?

    public init(
        timestamp: Date,
        heartRateBPM: Double? = nil,
        paceSecondsPerMile: Double? = nil,
        distanceMiles: Double,
        cadenceSPM: Double? = nil,
        gradePercent: Double? = nil,
        caloriesPerMinute: Double? = nil,
        heartRateZone: Int? = nil
    ) {
        self.timestamp = timestamp
        self.heartRateBPM = heartRateBPM
        self.paceSecondsPerMile = paceSecondsPerMile
        self.distanceMiles = distanceMiles
        self.cadenceSPM = cadenceSPM
        self.gradePercent = gradePercent
        self.caloriesPerMinute = caloriesPerMinute
        self.heartRateZone = heartRateZone
    }
}

public struct BiomechanicalMetrics: Codable, Sendable, Equatable {
    public var verticalOscillationCm: Double
    public var groundContactBalancePercent: Double
    /// Ground Contact Time in milliseconds (typical: 160–300ms)
    public var groundContactTimeMs: Double
    /// Estimated running power in watts (simplified model, 0–600W range)
    public var runningPowerWatts: Double

    public init(
        verticalOscillationCm: Double,
        groundContactBalancePercent: Double,
        groundContactTimeMs: Double = 0,
        runningPowerWatts: Double = 0
    ) {
        self.verticalOscillationCm = verticalOscillationCm
        self.groundContactBalancePercent = groundContactBalancePercent
        self.groundContactTimeMs = groundContactTimeMs
        self.runningPowerWatts = runningPowerWatts
    }
}

public struct FuelingStatus: Codable, Sendable, Equatable {
    public enum Level: String, Codable, Sendable {
        case nominal
        case warning
        case critical
    }

    public var remainingGlycogenGrams: Double
    public var level: Level

    public init(remainingGlycogenGrams: Double, level: Level) {
        self.remainingGlycogenGrams = remainingGlycogenGrams
        self.level = level
    }
}

public enum EngineAlert: String, Codable, Sendable, CaseIterable {
    case fuelWarning
    case fuelCritical
    case highHeartRate
    case cardiacDrift
    case paceVariance
    case split
}

public struct EngineDecision: Codable, Sendable, Equatable {
    public var timestamp: Date
    public var fatigueCoefficient: Double
    public var paceAdjustmentPercent: Double
    public var fuelingStatus: FuelingStatus
    public var driftSlopePerMinute: Double
    public var alerts: [EngineAlert]

    public init(
        timestamp: Date,
        fatigueCoefficient: Double,
        paceAdjustmentPercent: Double,
        fuelingStatus: FuelingStatus,
        driftSlopePerMinute: Double,
        alerts: [EngineAlert]
    ) {
        self.timestamp = timestamp
        self.fatigueCoefficient = fatigueCoefficient
        self.paceAdjustmentPercent = paceAdjustmentPercent
        self.fuelingStatus = fuelingStatus
        self.driftSlopePerMinute = driftSlopePerMinute
        self.alerts = alerts
    }
}

public struct CoachingPrompt: Codable, Sendable, Equatable {
    public enum Urgency: String, Codable, Sendable {
        case low
        case medium
        case high
    }

    public var message: String
    public var urgency: Urgency
    public var source: EngineAlert

    public init(message: String, urgency: Urgency, source: EngineAlert) {
        self.message = message
        self.urgency = urgency
        self.source = source
    }
}

public struct TelemetrySnapshotDTO: Codable, Sendable, Equatable {
    public var timestamp: Date
    public var distanceMiles: Double
    public var heartRateBPM: Double?
    public var paceSecondsPerMile: Double?
    public var cadenceSPM: Double?
    public var gradePercent: Double?
    public var fuelRemainingGrams: Double?

    public init(
        timestamp: Date,
        distanceMiles: Double,
        heartRateBPM: Double? = nil,
        paceSecondsPerMile: Double? = nil,
        cadenceSPM: Double? = nil,
        gradePercent: Double? = nil,
        fuelRemainingGrams: Double? = nil
    ) {
        self.timestamp = timestamp
        self.distanceMiles = distanceMiles
        self.heartRateBPM = heartRateBPM
        self.paceSecondsPerMile = paceSecondsPerMile
        self.cadenceSPM = cadenceSPM
        self.gradePercent = gradePercent
        self.fuelRemainingGrams = fuelRemainingGrams
    }
}
