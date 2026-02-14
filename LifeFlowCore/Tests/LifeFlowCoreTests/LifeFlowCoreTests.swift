import XCTest
@testable import LifeFlowCore

final class LifeFlowCoreTests: XCTestCase {
    func testReadinessThresholds() {
        let estimator = ReadinessEstimator()

        let overreaching = estimator.evaluate(
            ReadinessInput(
                acuteLoad: 130,
                chronicLoad: 90,
                restingHeartRateDelta: 7,
                hrvDeltaPercent: -12
            )
        )
        XCTAssertEqual(overreaching.paceAdjustmentPercent, -5)
        XCTAssertGreaterThan(overreaching.fatigueCoefficient, 1.3)

        let slightOverreach = estimator.evaluate(
            ReadinessInput(
                acuteLoad: 116,
                chronicLoad: 100,
                restingHeartRateDelta: 0,
                hrvDeltaPercent: 0
            )
        )
        XCTAssertEqual(slightOverreach.paceAdjustmentPercent, -2)

        let underloaded = estimator.evaluate(
            ReadinessInput(
                acuteLoad: 70,
                chronicLoad: 100,
                restingHeartRateDelta: -3,
                hrvDeltaPercent: 8
            )
        )
        XCTAssertEqual(underloaded.paceAdjustmentPercent, 1)
    }

    func testFuelingDepletionAndRefillThresholds() async {
        let engine = FuelingEngine(weightKg: 70)

        for _ in 0..<190 {
            _ = await engine.ingest(kcalPerMinute: 12, intensityZone: 4)
        }

        let depleted = await engine.status()
        XCTAssertEqual(depleted.level, .critical)
        XCTAssertLessThanOrEqual(depleted.remainingGlycogenGrams, 20)

        let recovered = await engine.logGel(carbsGrams: 30)
        XCTAssertNotEqual(recovered.level, .critical)
        XCTAssertGreaterThan(recovered.remainingGlycogenGrams, depleted.remainingGlycogenGrams)
    }

    func testCardiacDriftDetection() async {
        let engine = AdaptiveMarathonEngine(
            weightKg: 70,
            baseline: ReadinessInput(
                acuteLoad: 100,
                chronicLoad: 100,
                restingHeartRateDelta: 0,
                hrvDeltaPercent: 0
            )
        )

        let start = Date()
        var driftingDecision: EngineDecision?

        for second in 0..<300 {
            let sample = LiveRunMetrics(
                timestamp: start.addingTimeInterval(TimeInterval(second)),
                heartRateBPM: 138 + (Double(second) * 0.2),
                paceSecondsPerMile: 600,
                distanceMiles: Double(second) / 360.0,
                cadenceSPM: 172,
                gradePercent: 0,
                caloriesPerMinute: 11,
                heartRateZone: 3
            )
            driftingDecision = await engine.ingest(metrics: sample)
        }

        guard let driftingDecision else {
            XCTFail("No decision produced")
            return
        }

        XCTAssertTrue(driftingDecision.alerts.contains(.cardiacDrift))
        XCTAssertGreaterThan(driftingDecision.driftSlopePerMinute, 0.015)
    }

    func testCardiacDriftIgnoresLowSampleCounts() async {
        let engine = AdaptiveMarathonEngine(
            weightKg: 70,
            baseline: ReadinessInput(
                acuteLoad: 100,
                chronicLoad: 100,
                restingHeartRateDelta: 0,
                hrvDeltaPercent: 0
            )
        )

        let start = Date()
        var decision: EngineDecision?
        for second in 0..<10 {
            let sample = LiveRunMetrics(
                timestamp: start.addingTimeInterval(TimeInterval(second)),
                heartRateBPM: 150,
                paceSecondsPerMile: 600,
                distanceMiles: 0.1,
                cadenceSPM: 170,
                gradePercent: 0,
                caloriesPerMinute: 11,
                heartRateZone: 3
            )
            decision = await engine.ingest(metrics: sample)
        }

        let drift = decision?.driftSlopePerMinute ?? 0
        XCTAssertEqual(drift, 0, accuracy: 0.0001)
        XCTAssertFalse(decision?.alerts.contains(.cardiacDrift) ?? true)
    }

    func testCoachPromptPriorityAndCooldown() {
        let promptEngine = CoachPromptEngine(cooldown: 25)
        let baseDate = Date()

        let decision = EngineDecision(
            timestamp: baseDate,
            fatigueCoefficient: 1.2,
            paceAdjustmentPercent: -2,
            fuelingStatus: FuelingStatus(remainingGlycogenGrams: 15, level: .critical),
            driftSlopePerMinute: 0.02,
            alerts: [.paceVariance, .fuelCritical, .highHeartRate]
        )

        let first = promptEngine.prompt(for: decision, now: baseDate, lastPromptAt: nil)
        XCTAssertEqual(first?.source, .fuelCritical)
        XCTAssertNotNil(first)

        let second = promptEngine.prompt(for: decision, now: baseDate.addingTimeInterval(5), lastPromptAt: baseDate)
        XCTAssertNil(second)

        let third = promptEngine.prompt(for: decision, now: baseDate.addingTimeInterval(30), lastPromptAt: baseDate)
        XCTAssertNotNil(third)
    }

    func testWatchRunMessageRoundTrip() {
        let message = WatchRunMessage(
            event: .metricSnapshot,
            runID: UUID(),
            lifecycleState: .running,
            metricSnapshot: TelemetrySnapshotDTO(
                timestamp: Date(),
                distanceMiles: 3.1,
                heartRateBPM: 154,
                paceSecondsPerMile: 520,
                cadenceSPM: 176,
                gradePercent: 1.8,
                fuelRemainingGrams: 42
            ),
            heartRateBPM: 154
        )

        let context = message.toWCContext()
        let decoded = WatchRunMessage.fromWCContext(context)
        XCTAssertEqual(decoded, message)
    }

    // MARK: - BiomechanicalAnalyzer Tests

    func testBiomechanicalGCTAndPower() async {
        let analyzer = BiomechanicalAnalyzer()

        // Generate synthetic motion samples simulating running oscillation.
        // Vertical acceleration oscillates between positive (flight) and negative (ground contact).
        // The zero-crossings in this pattern should produce measurable GCT values.
        var samples: [MotionSample] = []
        for i in 0..<100 {
            let t = Double(i) * 0.01 // 100 Hz for 1 second
            let verticalAccel = sin(t * 2 * .pi * 3.0) // 3 Hz oscillation (~3 strides/sec)
            let lateralBalance = sin(t * .pi) * 0.1
            samples.append(MotionSample(
                verticalAcceleration: verticalAccel,
                lateralBalance: lateralBalance,
                timestamp: t
            ))
        }

        let metrics = await analyzer.calculateMetrics(from: samples)

        // GCT should be positive for oscillating input with clear zero-crossings
        XCTAssertGreaterThan(metrics.groundContactTimeMs, 0, "GCT should be positive for oscillating motion data")

        // Running power should be positive for non-trivial acceleration
        XCTAssertGreaterThan(metrics.runningPowerWatts, 0, "Running power should be positive for non-trivial input")

        // Vertical oscillation should be positive
        XCTAssertGreaterThan(metrics.verticalOscillationCm, 0)

        // Ground contact balance should be near 50% for symmetric oscillation
        XCTAssertGreaterThan(metrics.groundContactBalancePercent, 40)
        XCTAssertLessThan(metrics.groundContactBalancePercent, 60)
    }

    func testBiomechanicalEmptyInput() async {
        let analyzer = BiomechanicalAnalyzer()
        let metrics = await analyzer.calculateMetrics(from: [])

        // All values should be zero/default for empty input
        XCTAssertEqual(metrics.verticalOscillationCm, 0)
        XCTAssertEqual(metrics.groundContactBalancePercent, 50)
        XCTAssertEqual(metrics.groundContactTimeMs, 0)
        XCTAssertEqual(metrics.runningPowerWatts, 0)
    }
}
