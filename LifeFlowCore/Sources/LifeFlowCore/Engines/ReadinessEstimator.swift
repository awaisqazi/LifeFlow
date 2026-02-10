import Foundation

public struct ReadinessInput: Sendable, Equatable {
    public var acuteLoad: Double
    public var chronicLoad: Double
    public var restingHeartRateDelta: Double
    public var hrvDeltaPercent: Double

    public init(
        acuteLoad: Double,
        chronicLoad: Double,
        restingHeartRateDelta: Double,
        hrvDeltaPercent: Double
    ) {
        self.acuteLoad = acuteLoad
        self.chronicLoad = chronicLoad
        self.restingHeartRateDelta = restingHeartRateDelta
        self.hrvDeltaPercent = hrvDeltaPercent
    }
}

public struct ReadinessResult: Sendable, Equatable {
    public var fatigueCoefficient: Double
    public var paceAdjustmentPercent: Double

    public init(fatigueCoefficient: Double, paceAdjustmentPercent: Double) {
        self.fatigueCoefficient = fatigueCoefficient
        self.paceAdjustmentPercent = paceAdjustmentPercent
    }
}

public struct ReadinessEstimator: Sendable {
    public init() {}

    public func evaluate(_ input: ReadinessInput) -> ReadinessResult {
        let chronic = max(0.1, input.chronicLoad)
        var coefficient = input.acuteLoad / chronic

        if input.restingHeartRateDelta > 5 {
            coefficient += 0.05
        }

        if input.hrvDeltaPercent < -10 {
            coefficient += 0.05
        }

        coefficient = min(2.0, max(0.4, coefficient))

        let adjustment: Double
        if coefficient > 1.30 {
            adjustment = -5.0
        } else if coefficient >= 1.15 {
            adjustment = -2.0
        } else if coefficient < 0.80 {
            adjustment = 1.0
        } else {
            adjustment = 0.0
        }

        return ReadinessResult(fatigueCoefficient: coefficient, paceAdjustmentPercent: adjustment)
    }
}
