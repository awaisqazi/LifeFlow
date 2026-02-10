import SwiftUI
import WidgetKit
import LifeFlowCore

private struct RunComplicationEntry: TimelineEntry {
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
        switch state.lifecycleState {
        case .running, .paused:
            return TimelineEntryRelevance(score: 100)
        case .preparing:
            return TimelineEntryRelevance(score: 80)
        case .ended:
            return TimelineEntryRelevance(score: 30)
        case .idle:
            return nil
        }
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

private struct RunComplicationView: View {
    @Environment(\.widgetFamily) private var family

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
        Text("\(statusPrefix) \(paceText)")
    }

    private var cornerView: some View {
        VStack(spacing: 2) {
            Text(paceText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Text("HR \(heartRateText)")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(statusTitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(distanceText) • \(elapsedText)")
                .font(.caption)
                .monospacedDigit()
            Text("Pace \(paceText)  Fuel \(fuelText)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var statusPrefix: String {
        switch entry.state.lifecycleState {
        case .running: return "RUN"
        case .paused: return "PAUSE"
        case .preparing: return "READY"
        case .ended: return "DONE"
        case .idle: return "IDLE"
        }
    }

    private var statusTitle: String {
        switch entry.state.lifecycleState {
        case .running:
            return "In Progress"
        case .paused:
            return "Paused"
        case .preparing:
            return "Preparing"
        case .ended:
            return "Completed"
        case .idle:
            return "Ready"
        }
    }

    private var paceText: String {
        WidgetFormatting.pace(entry.state.paceSecondsPerMile)
    }

    private var heartRateText: String {
        WidgetFormatting.heartRate(entry.state.heartRateBPM)
    }

    private var distanceText: String {
        WidgetFormatting.distance(entry.state.distanceMiles)
    }

    private var elapsedText: String {
        WidgetFormatting.duration(entry.state.elapsedSeconds)
    }

    private var fuelText: String {
        WidgetFormatting.fuel(entry.state.fuelRemainingGrams ?? 0)
    }
}
