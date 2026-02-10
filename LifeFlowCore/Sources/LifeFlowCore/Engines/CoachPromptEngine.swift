import Foundation

public struct CoachPromptEngine: Sendable {
    private let maxWords = 10
    private let cooldown: TimeInterval

    public init(cooldown: TimeInterval = 25) {
        self.cooldown = cooldown
    }

    public func prompt(
        for decision: EngineDecision,
        now: Date = Date(),
        lastPromptAt: Date?
    ) -> CoachingPrompt? {
        if let lastPromptAt, now.timeIntervalSince(lastPromptAt) < cooldown {
            return nil
        }

        let ordered = prioritizedAlerts(decision.alerts)
        guard let top = ordered.first else { return nil }

        switch top {
        case .fuelCritical:
            return makePrompt("Fuel now, ease pace.", urgency: .high, source: top)
        case .fuelWarning:
            return makePrompt("Fuel soon. Stay smooth.", urgency: .medium, source: top)
        case .highHeartRate:
            return makePrompt("Heart rate high. Back off.", urgency: .high, source: top)
        case .cardiacDrift:
            return makePrompt("Cardiac drift rising. Slow slightly.", urgency: .medium, source: top)
        case .paceVariance:
            return makePrompt("Pace drifting. Re-center rhythm.", urgency: .low, source: top)
        case .split:
            return makePrompt("Strong split. Hold form.", urgency: .low, source: top)
        }
    }

    private func prioritizedAlerts(_ alerts: [EngineAlert]) -> [EngineAlert] {
        let ranking: [EngineAlert: Int] = [
            .fuelCritical: 0,
            .highHeartRate: 1,
            .fuelWarning: 2,
            .cardiacDrift: 3,
            .paceVariance: 4,
            .split: 5
        ]

        return alerts
            .uniqued()
            .sorted { (ranking[$0] ?? 99) < (ranking[$1] ?? 99) }
    }

    private func makePrompt(_ message: String, urgency: CoachingPrompt.Urgency, source: EngineAlert) -> CoachingPrompt {
        let compactMessage = message
            .split(whereSeparator: \.isWhitespace)
            .prefix(maxWords)
            .joined(separator: " ")

        return CoachingPrompt(message: compactMessage, urgency: urgency, source: source)
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        var output: [Element] = []

        for element in self where seen.insert(element).inserted {
            output.append(element)
        }

        return output
    }
}
