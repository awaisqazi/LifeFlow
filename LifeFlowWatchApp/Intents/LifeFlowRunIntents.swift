import AppIntents
import Foundation

@available(watchOS 26.0, *)
enum LifeFlowWorkoutStyle: String, AppEnum {
    case easy
    case base
    case longRun
    case tempo
    case speed

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "LifeFlow Run")
    }

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [
            .easy: DisplayRepresentation(title: "Easy"),
            .base: DisplayRepresentation(title: "Base"),
            .longRun: DisplayRepresentation(title: "Long Run"),
            .tempo: DisplayRepresentation(title: "Tempo"),
            .speed: DisplayRepresentation(title: "Speed")
        ]
    }

    var runTypeRawValue: String {
        switch self {
        case .easy:
            return "recovery"
        case .base:
            return "base"
        case .longRun:
            return "longRun"
        case .tempo:
            return "tempo"
        case .speed:
            return "speedWork"
        }
    }
}

@available(watchOS 26.0, *)
struct StartLifeFlowRunIntent: StartWorkoutIntent {
    static let title: LocalizedStringResource = "Start LifeFlow Run"
    static let description = IntentDescription("Start a standalone LifeFlow run on Apple Watch.")

    static let openAppWhenRun = true

    static var suggestedWorkouts: [StartLifeFlowRunIntent] {
        [
            StartLifeFlowRunIntent(style: .base),
            StartLifeFlowRunIntent(style: .longRun),
            StartLifeFlowRunIntent(style: .tempo)
        ]
    }

    @Parameter(title: "Workout")
    var workoutStyle: LifeFlowWorkoutStyle

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Start \(workoutStyle.rawValue.capitalized)")
    }

    init() {
        workoutStyle = .base
    }

    init(style: LifeFlowWorkoutStyle) {
        workoutStyle = style
    }

    func perform() async throws -> some IntentResult {
        await IntentActionRelay.shared.enqueue(PendingWatchIntentAction(kind: .startRun))
        return .result(dialog: "Run ready")
    }
}

@available(watchOS 26.0, *)
struct LogNutritionIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Gel"
    static let description = IntentDescription("Log a fueling intake while running.")

    @Parameter(title: "Carbs (g)", default: 25)
    var carbs: Double

    init() {}

    init(carbs: Double) {
        self.carbs = carbs
    }

    func perform() async throws -> some IntentResult {
        await IntentActionRelay.shared.enqueue(
            PendingWatchIntentAction(
                kind: .logNutrition,
                value: max(15, min(40, carbs))
            )
        )
        return .result(dialog: "Fuel logged")
    }
}

@available(watchOS 26.0, *)
struct MarkLapIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Lap"
    static let description = IntentDescription("Insert a lap marker in the active workout.")

    func perform() async throws -> some IntentResult {
        await IntentActionRelay.shared.enqueue(PendingWatchIntentAction(kind: .markLap))
        return .result(dialog: "Lap marked")
    }
}

@available(watchOS 26.0, *)
struct DismissRunAlertIntent: AppIntent {
    static let title: LocalizedStringResource = "Dismiss Alert"
    static let description = IntentDescription("Dismiss the active run alert.")

    func perform() async throws -> some IntentResult {
        await IntentActionRelay.shared.enqueue(PendingWatchIntentAction(kind: .dismissAlert))
        return .result()
    }
}

@available(watchOS 26.0, *)
struct ToggleMetricsIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Metrics"
    static let description = IntentDescription("Switch between primary and secondary metric stacks.")

    func perform() async throws -> some IntentResult {
        await IntentActionRelay.shared.enqueue(PendingWatchIntentAction(kind: .toggleMetrics))
        return .result()
    }
}
