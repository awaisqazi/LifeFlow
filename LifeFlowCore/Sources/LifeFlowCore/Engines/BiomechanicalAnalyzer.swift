import Foundation

public nonisolated struct MotionSample: Sendable {
    public var verticalAcceleration: Double
    public var lateralBalance: Double

    public init(verticalAcceleration: Double, lateralBalance: Double) {
        self.verticalAcceleration = verticalAcceleration
        self.lateralBalance = lateralBalance
    }
}

public nonisolated struct BiomechanicalAnalyzer: Sendable {
    public init() {}

    @concurrent
    public func calculateMetrics(from samples: [MotionSample]) async -> BiomechanicalMetrics {
        guard !samples.isEmpty else {
            return BiomechanicalMetrics(verticalOscillationCm: 0, groundContactBalancePercent: 50)
        }

        let averageVertical = samples.map(\.verticalAcceleration).reduce(0, +) / Double(samples.count)
        let averageBalance = samples.map(\.lateralBalance).reduce(0, +) / Double(samples.count)

        let verticalOscillation = max(0, averageVertical * 3.0)
        let contactBalance = min(60, max(40, 50 + (averageBalance * 5.0)))

        return BiomechanicalMetrics(
            verticalOscillationCm: verticalOscillation,
            groundContactBalancePercent: contactBalance
        )
    }
}
