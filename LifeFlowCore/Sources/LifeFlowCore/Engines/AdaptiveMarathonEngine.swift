import Foundation

public actor AdaptiveMarathonEngine {
    private let readinessEstimator: ReadinessEstimator
    private let fuelingEngine: FuelingEngine

    private var baseline: ReadinessInput
    private var recentSamples: [LiveRunMetrics] = []
    private let maxRecentSamples = 300
    private var lastSplitMile: Int = 0

    public init(weightKg: Double, baseline: ReadinessInput) {
        self.readinessEstimator = ReadinessEstimator()
        self.fuelingEngine = FuelingEngine(weightKg: weightKg)
        self.baseline = baseline
    }

    public func updateBaseline(_ baseline: ReadinessInput) {
        self.baseline = baseline
    }

    public func logGel(carbsGrams: Double? = nil) async -> FuelingStatus {
        await fuelingEngine.logGel(carbsGrams: carbsGrams)
    }

    public func ingest(metrics: LiveRunMetrics) async -> EngineDecision {
        recentSamples.append(metrics)
        if recentSamples.count > maxRecentSamples {
            recentSamples.removeFirst(recentSamples.count - maxRecentSamples)
        }

        let readiness = readinessEstimator.evaluate(baseline)

        let fuelingStatus: FuelingStatus
        if let kcalPerMinute = metrics.caloriesPerMinute {
            fuelingStatus = await fuelingEngine.ingest(
                kcalPerMinute: kcalPerMinute,
                intensityZone: metrics.heartRateZone ?? 2
            )
        } else {
            fuelingStatus = await fuelingEngine.status()
        }

        let drift = cardiacDriftSlopePerMinute()

        var alerts: [EngineAlert] = []
        if fuelingStatus.level == .critical {
            alerts.append(.fuelCritical)
        } else if fuelingStatus.level == .warning {
            alerts.append(.fuelWarning)
        }

        if let zone = metrics.heartRateZone, zone >= 4, let pace = metrics.paceSecondsPerMile, pace > 0 {
            alerts.append(.highHeartRate)
        }

        if drift > 0.015, (metrics.heartRateZone ?? 0) >= 3 {
            alerts.append(.cardiacDrift)
        }

        if let pace = metrics.paceSecondsPerMile, pace > 0 {
            let movingPace = movingAveragePace()
            if movingPace > 0 {
                let ratio = abs((pace - movingPace) / movingPace)
                if ratio >= 0.05 {
                    alerts.append(.paceVariance)
                }
            }
        }

        let currentSplit = Int(metrics.distanceMiles.rounded(.down))
        if currentSplit > 0, currentSplit > lastSplitMile {
            lastSplitMile = currentSplit
            alerts.append(.split)
        }

        return EngineDecision(
            timestamp: metrics.timestamp,
            fatigueCoefficient: readiness.fatigueCoefficient,
            paceAdjustmentPercent: readiness.paceAdjustmentPercent,
            fuelingStatus: fuelingStatus,
            driftSlopePerMinute: drift,
            alerts: alerts
        )
    }

    private func movingAveragePace() -> Double {
        let paces = recentSamples.compactMap(\.paceSecondsPerMile).suffix(30)
        guard !paces.isEmpty else { return 0 }
        return paces.reduce(0, +) / Double(paces.count)
    }

    private func cardiacDriftSlopePerMinute() -> Double {
        let samples = recentSamples.suffix(300).compactMap { sample -> (Double, Double)? in
            guard let hr = sample.heartRateBPM,
                  let pace = sample.paceSecondsPerMile,
                  pace > 0 else {
                return nil
            }
            return (sample.timestamp.timeIntervalSince1970, hr / pace)
        }

        guard samples.count >= 15 else { return 0 }

        let baseTime = samples.first?.0 ?? 0
        let points = samples.map { ((($0.0 - baseTime) / 60.0), $0.1) }

        let xs = points.map(\.0)
        let ys = points.map(\.1)
        let meanX = xs.reduce(0, +) / Double(xs.count)
        let meanY = ys.reduce(0, +) / Double(ys.count)

        let numerator = zip(xs, ys).map { ($0.0 - meanX) * ($0.1 - meanY) }.reduce(0, +)
        let denominator = xs.map { pow($0 - meanX, 2) }.reduce(0, +)

        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }
}
