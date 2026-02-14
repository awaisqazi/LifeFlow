import Foundation

// MARK: - BiomechanicalAnalyzer
// Isolated, Sendable struct for processing accelerometer data into
// running biomechanics. Designed for energy-efficient batch processing
// via CMBatchedSensorManager on watchOS, or sample-by-sample on iOS.

public nonisolated struct MotionSample: Sendable {
    public var verticalAcceleration: Double
    public var lateralBalance: Double
    /// Timestamp of the sample for temporal analysis (zero-crossing detection)
    public var timestamp: TimeInterval

    public init(verticalAcceleration: Double, lateralBalance: Double, timestamp: TimeInterval = 0) {
        self.verticalAcceleration = verticalAcceleration
        self.lateralBalance = lateralBalance
        self.timestamp = timestamp
    }
}

public nonisolated struct BiomechanicalAnalyzer: Sendable {
    public init() {}

    // MARK: - Primary Analysis Entry Point

    /// Processes a batch of motion samples into biomechanical metrics.
    /// On watchOS, this is called with batches from `CMBatchedSensorManager.deviceMotionUpdates()`.
    /// On iOS, it can be called with accumulated samples from `CMMotionManager`.
    ///
    /// Runs on the concurrent thread pool (`@concurrent`) to avoid blocking
    /// the MainActor during heavy vector math.
    @concurrent
    public func calculateMetrics(from samples: [MotionSample]) async -> BiomechanicalMetrics {
        guard !samples.isEmpty else {
            return BiomechanicalMetrics(
                verticalOscillationCm: 0,
                groundContactBalancePercent: 50,
                groundContactTimeMs: 0,
                runningPowerWatts: 0
            )
        }

        let averageVertical = samples.map(\.verticalAcceleration).reduce(0, +) / Double(samples.count)
        let averageBalance = samples.map(\.lateralBalance).reduce(0, +) / Double(samples.count)

        let verticalOscillation = max(0, averageVertical * 3.0)
        let contactBalance = min(60, max(40, 50 + (averageBalance * 5.0)))

        // MARK: Ground Contact Time (GCT)
        // Estimated by detecting zero-crossings in vertical acceleration.
        // Each time the vertical acceleration crosses zero from positive (flight)
        // to negative (ground contact), we measure the contact duration.
        let gct = calculateGCT(from: samples)

        // MARK: Running Power (simplified)
        // Approximated from the RMS of vertical acceleration, which correlates
        // with the mechanical work done against gravity during each stride.
        let power = calculateRunningPower(from: samples)

        return BiomechanicalMetrics(
            verticalOscillationCm: verticalOscillation,
            groundContactBalancePercent: contactBalance,
            groundContactTimeMs: gct,
            runningPowerWatts: power
        )
    }

    // MARK: - Ground Contact Time

    /// Estimates Ground Contact Time (GCT) in milliseconds from vertical
    /// acceleration zero-crossings. A zero-crossing from positive → negative
    /// marks the start of ground contact; negative → positive marks toe-off.
    ///
    /// Typical GCT values: 200–300ms for recreational runners, 160–200ms for elite.
    private func calculateGCT(from samples: [MotionSample]) -> Double {
        guard samples.count >= 4 else { return 0 }

        var contactDurations: [Double] = []
        var contactStartTime: TimeInterval?

        for i in 1..<samples.count {
            let prev = samples[i - 1].verticalAcceleration
            let curr = samples[i].verticalAcceleration

            // Positive → negative crossing = landing (contact begins)
            if prev >= 0 && curr < 0 {
                contactStartTime = samples[i].timestamp
            }
            // Negative → positive crossing = toe-off (contact ends)
            else if prev < 0 && curr >= 0, let start = contactStartTime {
                let duration = (samples[i].timestamp - start) * 1000 // Convert to ms
                if duration > 50 && duration < 500 {
                    // Sanity bounds: GCT should be 50–500ms
                    contactDurations.append(duration)
                }
                contactStartTime = nil
            }
        }

        guard !contactDurations.isEmpty else { return 0 }
        return contactDurations.reduce(0, +) / Double(contactDurations.count)
    }

    // MARK: - Running Power

    /// Estimates running power in watts from a simplified model:
    /// Power ≈ mass (assumed 70kg) × RMS(vertical_accel) × stride_velocity_proxy
    ///
    /// This is a simulated approximation. Real running power requires
    /// GPS velocity integration, but this gives a useful relative metric
    /// for coaching cues like "your power is dropping."
    private func calculateRunningPower(from samples: [MotionSample]) -> Double {
        guard samples.count >= 2 else { return 0 }

        let assumedMassKg = 70.0

        // RMS of vertical acceleration
        let sumSquares = samples.map { $0.verticalAcceleration * $0.verticalAcceleration }.reduce(0, +)
        let rms = sqrt(sumSquares / Double(samples.count))

        // Time span of the batch
        let timeSpan = samples.last!.timestamp - samples.first!.timestamp
        guard timeSpan > 0 else { return 0 }

        // Vertical displacement proxy from double-integration (simplified)
        let avgAccel = samples.map { abs($0.verticalAcceleration) }.reduce(0, +) / Double(samples.count)
        let verticalVelocityProxy = avgAccel * 9.81 * 0.1 // scaled approximation m/s

        // Power = Force × Velocity ≈ mass × g × rms_accel × velocity_proxy
        let power = assumedMassKg * rms * verticalVelocityProxy
        return min(600, max(0, power)) // Clamp to reasonable range (0–600W)
    }
}
