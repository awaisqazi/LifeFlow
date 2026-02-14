import SwiftUI
import WidgetKit
import LifeFlowCore

private struct RunComplicationEntry: TimelineEntry, Sendable {
    let date: Date
    let state: WatchWidgetState
    let relevance: TimelineEntryRelevance?
}

private struct RunComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> RunComplicationEntry {
        RunComplicationEntry(
            date: Date(),
            state: WatchWidgetState(
                lifecycleState: .running,
                elapsedSeconds: 760,
                distanceMiles: 1.2,
                heartRateBPM: 152,
                paceSecondsPerMile: 520,
                fuelRemainingGrams: 44
            ),
            relevance: TimelineEntryRelevance(score: 90)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (RunComplicationEntry) -> Void) {
        let state = WatchWidgetStateStore.load()
        completion(
            RunComplicationEntry(
                date: Date(),
                state: state,
                relevance: relevance(for: state)
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RunComplicationEntry>) -> Void) {
        let now = Date()
        let state = WatchWidgetStateStore.load()
        let next = Calendar.current.date(byAdding: .minute, value: 1, to: now) ?? now.addingTimeInterval(60)

        let entry = RunComplicationEntry(date: now, state: state, relevance: relevance(for: state))
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func relevance(for state: WatchWidgetState) -> TimelineEntryRelevance? {
        // Use enhanced Smart Stack relevance provider
        return SmartStackRelevanceProvider.relevance(for: state)
    }

    func relevances() async -> WidgetRelevances<Void> {
        let state = WatchWidgetStateStore.load()

        let calendar = Calendar.current
        let now = Date()
        var entries: [WidgetRelevanceEntry<Void>] = []

        // Active workout: max relevance for the next hour
        if state.lifecycleState == .running || state.lifecycleState == .paused {
            let end = now.addingTimeInterval(3600)
            entries.append(
                WidgetRelevanceEntry(
                    context: .date(from: now, to: end),
                    score: 100
                )
            )
        }

        // Morning window (5-9 AM): moderate promotion
        if let morningStart = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: now),
           let morningEnd = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) {
            entries.append(
                WidgetRelevanceEntry(
                    context: .date(from: morningStart, to: morningEnd),
                    score: 40
                )
            )
        }

        // Evening window (5-8 PM): moderate promotion
        if let eveningStart = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now),
           let eveningEnd = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now) {
            entries.append(
                WidgetRelevanceEntry(
                    context: .date(from: eveningStart, to: eveningEnd),
                    score: 40
                )
            )
        }

        return WidgetRelevances(entries)
    }
}

struct LifeFlowRunComplicationWidget: Widget {
    static let kind = LifeFlowWidgetKinds.runStatus

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: RunComplicationProvider()) { entry in
            RunComplicationView(entry: entry)
        }
        .configurationDisplayName("LifeFlow Run")
        .description("Current run status, pace, and fuel state.")
        .supportedFamilies([.accessoryInline, .accessoryCorner, .accessoryRectangular])
    }
}

private struct RunComplicationStatusStyle {
    let shortLabel: String
    let title: String
    let symbol: String
    let tint: Color
}

private extension WatchRunLifecycleState {
    var complicationStyle: RunComplicationStatusStyle {
        switch self {
        case .running:
            return RunComplicationStatusStyle(
                shortLabel: "RUN",
                title: "In Progress",
                symbol: "figure.run",
                tint: .mint
            )
        case .paused:
            return RunComplicationStatusStyle(
                shortLabel: "PAU",
                title: "Paused",
                symbol: "pause.fill",
                tint: .yellow
            )
        case .preparing:
            return RunComplicationStatusStyle(
                shortLabel: "RDY",
                title: "Preparing",
                symbol: "hourglass",
                tint: .cyan
            )
        case .ended:
            return RunComplicationStatusStyle(
                shortLabel: "DONE",
                title: "Completed",
                symbol: "flag.checkered",
                tint: .gray
            )
        case .idle:
            return RunComplicationStatusStyle(
                shortLabel: "IDLE",
                title: "Ready",
                symbol: "figure.run.circle",
                tint: .blue
            )
        }
    }
}

private struct RunComplicationView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: RunComplicationEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            inlineView
        case .accessoryCorner:
            cornerView
        case .accessoryRectangular:
            rectangularView
        default:
            rectangularView
        }
    }

    private var inlineView: some View {
        Text("\(statusStyle.shortLabel) \(inlineMetricText)")
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }

    private var cornerView: some View {
        VStack(spacing: 1) {
            HStack(spacing: 2) {
                Image(systemName: statusStyle.symbol)
                    .font(.system(size: 7, weight: .semibold))
                Text(statusStyle.shortLabel)
                    .font(.system(size: 7, weight: .black, design: .rounded))
                    .tracking(0.3)
            }
            .foregroundStyle(accentTint)
            .widgetAccentable()

            Text(cornerPrimaryMetric)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accentTint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .widgetAccentable()

            Text(cornerSecondaryMetric)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: statusStyle.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accentTint)
                    .widgetAccentable()

                Text(statusStyle.title.uppercased())
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(elapsedText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Text(rectangularPrimaryMetric)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accentTint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .widgetAccentable()

            HStack(spacing: 8) {
                Text("Dist \(distanceCompactText)")
                Text(rectangularFooterRightMetric)
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(renderingMode == .accented ? 0.14 : 0.24))
                .overlay {
                    LinearGradient(
                        colors: [
                            statusStyle.tint.opacity(renderingMode == .accented ? 0.18 : 0.12),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(statusStyle.tint.opacity(renderingMode == .accented ? 0.42 : 0.28), lineWidth: 0.7)
                }
        }
    }
}

private extension RunComplicationView {
    var statusStyle: RunComplicationStatusStyle {
        entry.state.lifecycleState.complicationStyle
    }

    var accentTint: Color {
        renderingMode == .accented ? .white : statusStyle.tint
    }

    var hasPace: Bool {
        guard let pace = entry.state.paceSecondsPerMile else { return false }
        return pace > 0
    }

    var inlineMetricText: String {
        switch entry.state.lifecycleState {
        case .running:
            return hasPace ? "\(paceText)/mi" : elapsedCompactText
        case .paused:
            return elapsedCompactText
        case .preparing:
            return distanceCompactText
        case .ended:
            return distanceCompactText
        case .idle:
            return "--"
        }
    }

    var cornerPrimaryMetric: String {
        hasPace ? paceText : elapsedCompactText
    }

    var cornerSecondaryMetric: String {
        if let heartRate = heartRateCompactText {
            return "HR \(heartRate)"
        }
        return "Dist \(distanceCompactText)"
    }

    var rectangularPrimaryMetric: String {
        hasPace ? "\(paceText)/mi" : elapsedText
    }

    var rectangularFooterRightMetric: String {
        if let heartRate = heartRateCompactText {
            return "HR \(heartRate)"
        }
        if let fuel = fuelCompactText {
            return "Fuel \(fuel)"
        }
        return "Fuel --"
    }

    var paceText: String {
        WidgetFormatting.pace(entry.state.paceSecondsPerMile)
    }

    var elapsedText: String {
        WidgetFormatting.duration(entry.state.elapsedSeconds)
    }

    var elapsedCompactText: String {
        WidgetFormatting.duration(entry.state.elapsedSeconds)
    }

    var distanceCompactText: String {
        let miles = max(0, entry.state.distanceMiles)
        if miles >= 10 {
            return String(format: "%.1fmi", miles)
        }
        return String(format: "%.2fmi", miles)
    }

    var heartRateCompactText: String? {
        guard let bpm = entry.state.heartRateBPM, bpm > 0 else { return nil }
        return String(format: "%.0f", bpm)
    }

    var fuelCompactText: String? {
        guard let grams = entry.state.fuelRemainingGrams, grams > 0 else { return nil }
        return String(format: "%.0fg", grams)
    }
}
