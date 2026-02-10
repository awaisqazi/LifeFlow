import Foundation

public actor FuelingEngine {
    public let warningThresholdGrams: Double
    public let criticalThresholdGrams: Double
    public let defaultGelCarbsGrams: Double

    private(set) var remainingGlycogenGrams: Double

    public init(
        weightKg: Double,
        warningThresholdGrams: Double = 35,
        criticalThresholdGrams: Double = 20,
        defaultGelCarbsGrams: Double = 25
    ) {
        self.warningThresholdGrams = warningThresholdGrams
        self.criticalThresholdGrams = criticalThresholdGrams
        self.defaultGelCarbsGrams = defaultGelCarbsGrams

        let starting = min(500, max(300, weightKg * 6.0))
        self.remainingGlycogenGrams = starting
    }

    @discardableResult
    public func ingest(kcalPerMinute: Double, intensityZone: Int) -> FuelingStatus {
        let safeKcalPerMinute = max(0, kcalPerMinute)
        let carbFraction = Self.carbFraction(for: intensityZone)
        let gramsPerMinute = (safeKcalPerMinute * carbFraction) / 4.0
        remainingGlycogenGrams = max(0, remainingGlycogenGrams - gramsPerMinute)

        return status()
    }

    @discardableResult
    public func logGel(carbsGrams: Double? = nil) -> FuelingStatus {
        let refill = max(0, carbsGrams ?? defaultGelCarbsGrams)
        remainingGlycogenGrams = min(500, remainingGlycogenGrams + refill)
        return status()
    }

    public func status() -> FuelingStatus {
        let level: FuelingStatus.Level
        if remainingGlycogenGrams <= criticalThresholdGrams {
            level = .critical
        } else if remainingGlycogenGrams <= warningThresholdGrams {
            level = .warning
        } else {
            level = .nominal
        }

        return FuelingStatus(
            remainingGlycogenGrams: remainingGlycogenGrams,
            level: level
        )
    }

    private static func carbFraction(for zone: Int) -> Double {
        switch zone {
        case ...1:
            return 0.40
        case 2:
            return 0.50
        case 3:
            return 0.60
        case 4:
            return 0.75
        default:
            return 0.85
        }
    }
}
