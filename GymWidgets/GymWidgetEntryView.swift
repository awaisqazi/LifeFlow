//
//  GymWidgetEntryView.swift
//  GymWidgets
//
//  Widget entry views for small, medium, and large workout widgets.
//  Display-only views with tap-to-open functionality.
//

import SwiftUI
import WidgetKit

struct GymWidgetEntryView: View {
    let entry: WorkoutEntry
    
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    
    private var isFullColor: Bool {
        renderingMode == .fullColor
    }
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(state: entry.state, isFullColor: isFullColor, referenceDate: entry.date)
            case .systemMedium:
                MediumWidgetView(state: entry.state, isFullColor: isFullColor, referenceDate: entry.date)
            case .systemLarge:
                LargeWidgetView(state: entry.state, referenceDate: entry.date)
            default:
                SmallWidgetView(state: entry.state, isFullColor: isFullColor, referenceDate: entry.date)
            }
        }
        .containerBackground(for: .widget) {
            // Let system handle tinted/glass background in accented mode
            // Only provide a subtle background in full-color mode
            if isFullColor {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.9),
                        entry.state.accentColor.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - Small Widget

private struct SmallWidgetView: View {
    let state: WorkoutWidgetState
    let isFullColor: Bool
    let referenceDate: Date
    
    var body: some View {
        if state.isActive {
            VStack(spacing: 8) {
                StatusBadge(
                    state: state,
                    isFullColor: isFullColor,
                    font: .system(size: 9, weight: .bold),
                    dotSize: 6
                )
                
                Spacer(minLength: 4)
                
                WorkoutTimerText(
                    state: state,
                    referenceDate: referenceDate,
                    fontSize: 36,
                    isFullColor: isFullColor
                )
                
                Spacer(minLength: 4)
                
                VStack(spacing: 4) {
                    Text(state.exerciseName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    
                    if state.isCardio {
                        CardioMetricsView(
                            state: state,
                            isFullColor: isFullColor,
                            valueFont: .caption2,
                            iconFont: .system(size: 8),
                            spacing: 8
                        )
                        .foregroundStyle(.secondary)
                    } else if state.totalSets > 0 {
                        Text("Set \(state.currentSet)/\(state.totalSets)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    StateProgressBar(
                        state: state,
                        isFullColor: isFullColor,
                        height: 5
                    )
                    
                    if state.totalExercises > 0 {
                        Text("Exercise \(state.currentExerciseIndex + 1)/\(state.totalExercises)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .widgetURL(URL(string: "lifeflow://gym"))
        } else {
            VStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                
                Text("Start Workout")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(URL(string: "lifeflow://gym"))
        }
    }
}

// MARK: - Medium Widget

private struct MediumWidgetView: View {
    let state: WorkoutWidgetState
    let isFullColor: Bool
    let referenceDate: Date
    
    var body: some View {
        if state.isActive {
            HStack(spacing: 16) {
                // Left Column: Status & Timer
                VStack(spacing: 6) {
                    StatusBadge(
                        state: state,
                        isFullColor: isFullColor,
                        font: .system(size: 10, weight: .black),
                        dotSize: 6
                    )
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .glassEffect(.regular, in: .capsule)
                    
                    Spacer()
                    
                    WorkoutTimerText(
                        state: state,
                        referenceDate: referenceDate,
                        fontSize: 34,
                        isFullColor: isFullColor
                    )
                    
                    Text(state.timerLabel)
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.secondary.opacity(0.6))
                    
                    StateProgressBar(
                        state: state,
                        isFullColor: isFullColor,
                        height: 6
                    )
                    .padding(.horizontal, 6)
                    
                    Spacer()
                }
                .frame(width: 118)
                
                // Right Column: Exercise Details
                VStack(alignment: .leading, spacing: 6) {
                    Text(state.workoutTitle.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.secondary)
                    
                    Text(state.exerciseName)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.9)
                    
                    if state.isCardio {
                        CardioMetricsView(
                            state: state,
                            isFullColor: isFullColor,
                            valueFont: .caption2.weight(.bold),
                            iconFont: .system(size: 9),
                            spacing: 10
                        )
                        .foregroundStyle(.secondary)
                    } else if state.totalSets > 0 {
                        Text("Set \(state.currentSet) of \(state.totalSets)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    
                    if let next = state.nextExerciseName {
                        HStack(spacing: 4) {
                            Text("NEXT:")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.tertiary)
                            Text(next)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 2)
                    }
                    
                    if state.totalExercises > 0 {
                        WorkoutProgressView(
                            label: "Exercise \(state.currentExerciseIndex + 1) of \(state.totalExercises)",
                            progress: state.workoutProgress,
                            tint: state.accentColor,
                            isFullColor: isFullColor
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .widgetURL(URL(string: "lifeflow://gym"))
        } else {
            HStack(spacing: 16) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("No Active Workout")
                        .font(.headline)
                    Text("Tap to start your session")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange.opacity(0.6))
            }
            .padding()
            .widgetURL(URL(string: "lifeflow://gym"))
        }
    }
}

// MARK: - Large Widget (Exercise Queue Dashboard)

private struct LargeWidgetView: View {
    let state: WorkoutWidgetState
    let referenceDate: Date
    
    @Environment(\.widgetRenderingMode) private var renderingMode
    
    private var isFullColor: Bool {
        renderingMode == .fullColor
    }
    
    var body: some View {
        Group {
            if state.isActive {
                exerciseQueueDashboard
            } else {
                idleStatePlaceholder
            }
        }
        .widgetURL(URL(string: "lifeflow://gym"))
        // Removed containerBackground - parent handles this
    }
    
    // MARK: - Exercise Queue Dashboard
    
    private var exerciseQueueDashboard: some View {
        VStack(spacing: 10) {
            // Header with workout title and timer
            headerSection
            
            // Exercise Queue (Previous → Current → Next)
            VStack(spacing: 8) {
                // Previous Exercise (if exists)
                if let prevName = state.previousExerciseName {
                    ExerciseCard(
                        position: .previous,
                        exerciseName: prevName,
                        setsCompleted: state.previousSetsCompleted,
                        totalSets: state.previousTotalSets,
                        isComplete: state.previousIsComplete,
                        isFullColor: isFullColor
                    )
                }
                
                // Current Exercise (Hero)
                CurrentExerciseCard(
                    state: state,
                    isFullColor: isFullColor
                )
                
                // Next Exercise (if exists)
                if let nextName = state.nextExerciseName {
                    ExerciseCard(
                        position: .next,
                        exerciseName: nextName,
                        setsCompleted: state.nextSetsCompleted,
                        totalSets: state.nextTotalSets,
                        isComplete: false,
                        isFullColor: isFullColor
                    )
                }
            }
        }
        .padding(12)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            // Full-width header bar: title left, timer right
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.workoutTitle.isEmpty ? "WORKOUT" : state.workoutTitle.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)

                    if state.totalExercises > 0 {
                        Text("Exercise \(state.currentExerciseIndex + 1) of \(state.totalExercises)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    WorkoutTimerText(
                        state: state,
                        referenceDate: referenceDate,
                        fontSize: 16,
                        isFullColor: isFullColor
                    )

                    Text(state.timerLabel)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(isFullColor ? 0.06 : 0.1))
            }

            if state.totalExercises > 0 {
                WorkoutProgressView(
                    label: "Workout \(state.currentExerciseIndex + 1) of \(state.totalExercises)",
                    progress: state.workoutProgress,
                    tint: state.accentColor,
                    isFullColor: isFullColor
                )
            }
        }
    }
    
    // MARK: - Idle State Placeholder
    
    private var idleStatePlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
                .widgetAccentable()
            
            Text("Start Workout")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text("Tap to begin")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}

// MARK: - Exercise Card Position

private enum CardPosition {
    case previous, next
}

// MARK: - Exercise Card (Previous/Next)

private struct ExerciseCard: View {
    let position: CardPosition
    let exerciseName: String
    let setsCompleted: Int
    let totalSets: Int
    let isComplete: Bool
    let isFullColor: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion/Status Icon
            statusIcon
            
            // Exercise Info
            VStack(alignment: .leading, spacing: 2) {
                // Position label
                Text(position == .previous ? "PREVIOUS" : "UP NEXT")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)
                
                // Exercise name
                Text(exerciseName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(position == .previous ? .secondary : .primary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Sets Progress or Completion Badge
            setsIndicator
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            if isFullColor {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(isFullColor ? 0.08 : 0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var statusIcon: some View {
        Group {
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(isFullColor ? .green : .primary)
                    .widgetAccentable()
            } else if position == .previous {
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var setsIndicator: some View {
        Group {
            if isComplete {
                Text("DONE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isFullColor ? .green : .primary)
                    .widgetAccentable()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(isFullColor ? 0.15 : 0.1), in: Capsule())
            } else {
                Text("\(setsCompleted)/\(totalSets)")
                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Current Exercise Card (Hero)

private struct CurrentExerciseCard: View {
    let state: WorkoutWidgetState
    let isFullColor: Bool
    
    private var accentColor: Color {
        state.accentColor
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Status Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(state.isPaused ? .gray : accentColor)
                    .frame(width: 6, height: 6)
                
                Text(state.isPaused ? "PAUSED" : (state.isResting ? "REST" : "ACTIVE"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1)
            }
            .foregroundStyle(state.isPaused ? .secondary : (isFullColor ? accentColor : .primary))
            .widgetAccentable()
            
            // Exercise Name (Hero)
            Text(state.exerciseName)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
            
            // Timer Section
            timerSection
            
            // Progress Bar
            progressBar
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background {
            if isFullColor {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(isFullColor ? 0.12 : 0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    
    private var timerSection: some View {
        Group {
            if state.isResting, let restEnd = state.restEndTime {
                // Rest Countdown
                VStack(spacing: 2) {
                    Text("REST TIME")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    
                    Text(restEnd, style: .timer)
                        .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(isFullColor ? .cyan : .primary)
                        .widgetAccentable()
                }
            } else if state.isCardio {
                // Cardio: show speed and incline
                VStack(spacing: 8) {
                    CardioMetricsView(
                        state: state,
                        isFullColor: isFullColor,
                        valueFont: .system(size: 24, weight: .bold, design: .rounded).monospacedDigit(),
                        iconFont: .system(size: 12),
                        spacing: 16
                    )
                    .foregroundStyle(.secondary)
                }
            } else {
                // Set Progress (weights)
                VStack(spacing: 4) {
                    Text("Set \(state.currentSet) of \(state.totalSets)")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    // Sets completed indicator
                    HStack(spacing: 4) {
                        ForEach(0..<min(state.totalSets, 8), id: \.self) { i in
                            Circle()
                                .fill(i < state.currentSet ? 
                                    (isFullColor ? accentColor : Color.primary) : 
                                    Color.white.opacity(0.2))
                                .frame(width: 8, height: 8)
                                .widgetAccentable()
                        }
                    }
                }
            }
        }
    }
    
    private var progressBar: some View {
        StateProgressBar(
            state: state,
            isFullColor: isFullColor,
            height: 6
        )
    }
    
}

// MARK: - Shared Components

private enum WorkoutPhase {
    case paused
    case resting
    case cardioTimed
    case cardioFreestyle
    case active
}

private extension WorkoutWidgetState {
    var phase: WorkoutPhase {
        if isPaused { return .paused }
        if isResting { return .resting }
        if isCardio && cardioModeIndex == 0 { return .cardioTimed }
        if isCardio { return .cardioFreestyle }
        return .active
    }
    
    var statusText: String {
        switch phase {
        case .paused: return "PAUSED"
        case .resting: return "RESTING"
        case .cardioTimed, .cardioFreestyle: return "CARDIO"
        case .active: return "ACTIVE"
        }
    }
    
    var timerLabel: String {
        switch phase {
        case .paused: return "PAUSED"
        case .resting: return "REST TIMER"
        case .cardioTimed: return "COUNTDOWN"
        case .cardioFreestyle: return "ELAPSED"
        case .active: return "ELAPSED"
        }
    }
    
    var accentColor: Color {
        switch phase {
        case .paused: return .gray
        case .resting: return .cyan
        case .cardioTimed: return .orange
        case .cardioFreestyle: return .green
        case .active: return .green
        }
    }
    
    var timerColor: Color {
        switch phase {
        case .paused: return .secondary
        case .resting: return .cyan
        case .cardioTimed: return .orange
        case .cardioFreestyle: return .green
        case .active: return .green
        }
    }
    
    var workoutProgress: Double {
        guard totalExercises > 0 else { return 0 }
        return min(Double(currentExerciseIndex + 1) / Double(totalExercises), 1)
    }
    
    var setProgress: Double {
        guard totalSets > 0 else { return 0 }
        return min(Double(currentSet) / Double(totalSets), 1)
    }
    
    var restInterval: ClosedRange<Date>? {
        guard isResting, let restEndTime, let restDuration, restDuration > 0 else { return nil }
        return restEndTime.addingTimeInterval(-restDuration)...restEndTime
    }
    
    var cardioInterval: ClosedRange<Date>? {
        guard isCardio, cardioModeIndex == 0, let cardioEndTime, cardioDuration > 0 else { return nil }
        return cardioEndTime.addingTimeInterval(-cardioDuration)...cardioEndTime
    }
    
    var freestyleCardioProgress: Double {
        let goal = cardioDuration > 0 ? cardioDuration : 1800
        return min(cardioElapsedTime / goal, 1)
    }
}

private struct StatusBadge: View {
    let state: WorkoutWidgetState
    let isFullColor: Bool
    let font: Font
    let dotSize: CGFloat

    var body: some View {
        let tint = isFullColor ? state.timerColor : Color.primary
        let content = HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: dotSize, height: dotSize)
                .widgetAccentable()
            Text(state.statusText)
                .font(font)
                .foregroundStyle(tint)
                .widgetAccentable()
        }

        if isFullColor {
            content
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .stroke(tint.opacity(0.42), lineWidth: 0.8)
                        }
                }
        } else {
            content
        }
    }
}

private struct WorkoutTimerText: View {
    let state: WorkoutWidgetState
    let referenceDate: Date
    let fontSize: CGFloat
    let isFullColor: Bool
    
    var body: some View {
        let font = Font.system(size: fontSize, weight: .bold, design: .rounded).monospacedDigit()
        let tint = isFullColor ? state.timerColor : Color.primary
        
        Group {
            switch state.phase {
            case .paused:
                Text(state.pausedDisplayTime ?? "--:--")
            case .resting:
                if let restEnd = state.restEndTime {
                    Text(restEnd, style: .timer)
                } else {
                    Text("--:--")
                }
            case .cardioTimed:
                if let cardioEnd = state.cardioEndTime {
                    Text(cardioEnd, style: .timer)
                } else {
                    Text("--:--")
                }
            case .cardioFreestyle:
                let cardioStart = referenceDate.addingTimeInterval(-state.cardioElapsedTime)
                Text(cardioStart, style: .timer)
            case .active:
                Text(state.workoutStartDate, style: .timer)
            }
        }
        .font(font)
        .foregroundStyle(tint)
        .multilineTextAlignment(.center)
        .widgetAccentable()
    }
}

private struct StateProgressBar: View {
    let state: WorkoutWidgetState
    let isFullColor: Bool
    let height: CGFloat
    
    var body: some View {
        let tint = isFullColor ? state.accentColor : Color.primary
        
        Group {
            if let restInterval = state.restInterval {
                ProgressView(timerInterval: restInterval, countsDown: true)
                    .progressViewStyle(.linear)
                    .tint(tint)
            } else if let cardioInterval = state.cardioInterval {
                ProgressView(timerInterval: cardioInterval, countsDown: true)
                    .progressViewStyle(.linear)
                    .tint(tint)
            } else if state.isCardio {
                ProgressView(value: state.freestyleCardioProgress)
                    .progressViewStyle(.linear)
                    .tint(tint)
            } else {
                ProgressView(value: state.setProgress)
                    .progressViewStyle(.linear)
                    .tint(tint)
            }
        }
        .frame(height: height)
        .widgetAccentable()
    }
}

private struct WorkoutProgressView: View {
    let label: String
    let progress: Double
    let tint: Color
    let isFullColor: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(isFullColor ? tint : .primary)
                .frame(height: 4)
                .widgetAccentable()
        }
    }
}

private struct CardioMetricsView: View {
    let state: WorkoutWidgetState
    let isFullColor: Bool
    let valueFont: Font
    let iconFont: Font
    let spacing: CGFloat
    
    var body: some View {
        let hasSpeed = state.cardioSpeed > 0
        let hasIncline = state.cardioIncline > 0
        
        if hasSpeed || hasIncline {
            let speedColor: Color = isFullColor ? .green : .primary
            let inclineColor: Color = isFullColor ? .orange : .primary
            
            HStack(spacing: spacing) {
                if hasSpeed {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(iconFont)
                            .foregroundStyle(speedColor)
                            .widgetAccentable()
                        Text(String(format: "%.1f", state.cardioSpeed))
                            .font(valueFont)
                        Text("mph")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if hasIncline {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(iconFont)
                            .foregroundStyle(inclineColor)
                            .widgetAccentable()
                        Text(String(format: "%.1f", state.cardioIncline))
                            .font(valueFont)
                        Text("%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            Text(state.cardioModeIndex == 0 ? "Timed Cardio" : "Freestyle Cardio")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
