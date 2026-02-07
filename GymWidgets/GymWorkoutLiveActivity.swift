//
//  GymWorkoutLiveActivity.swift
//  GymWidgets
//
//  Live Activity widget for active workouts.
//  Shows in Dynamic Island and on Lock Screen during workout.
//

import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

/// Live Activity widget configuration for Gym Workouts
struct GymWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GymWorkoutAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
                .activityBackgroundTint(context.state.accentColor.opacity(0.2))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: context.state.isResting ? "timer" : "dumbbell.fill")
                                .foregroundStyle(context.state.accentColor)
                                .font(.headline)
                            
                            Text(context.state.statusText)
                                .font(.caption2.weight(.black))
                                .foregroundStyle(context.state.accentColor)
                                .tracking(1)
                        }
                        
                        Text(context.state.exerciseName)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text("Set \(context.state.currentSet) of \(context.state.totalSets)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        LiveActivityTimerText(
                            state: context.state,
                            fontSize: 32,
                            showsShadow: true
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        
                        Text(context.state.timerLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 110, alignment: .trailing)
                    .padding(.trailing, 8)
                    .padding(.top, 8)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        LiveActivityStateProgressBar(state: context.state)
                        LiveActivityControls(state: context.state, isCompact: true)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                // Timer on the left
                LiveActivityTimerText(
                    state: context.state,
                    fontSize: 14,
                    showsShadow: false
                )
            } compactTrailing: {
                // Dynamic icon on the right edge
                if context.state.isResting {
                    Image(systemName: "timer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(context.state.accentColor)
                } else {
                    Image(systemName: context.state.exerciseIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(context.state.accentColor)
                }
            } minimal: {
                // Dynamic icon in minimal view
                if context.state.isResting {
                    Image(systemName: "timer")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(context.state.accentColor)
                } else {
                    Image(systemName: context.state.exerciseIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(context.state.accentColor)
                }
            }
            .keylineTint(context.state.accentColor)
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<GymWorkoutAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.statusText)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(context.state.accentColor)
                        .tracking(1)
                    
                    Text(context.state.exerciseName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text("Set \(context.state.currentSet) of \(context.state.totalSets)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                LiveActivityTimerText(
                    state: context.state,
                    fontSize: 32,
                    showsShadow: false
                )
            }
            
            LiveActivityStateProgressBar(state: context.state)
            
            LiveActivityControls(state: context.state, isCompact: false)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        // No background - let the system Live Activity container handle it
    }
}

// MARK: - Live Activity Helpers

private enum LiveActivityPhase {
    case paused
    case pausedResting // Paused during rest - shows frozen rest countdown
    case pausedCardioTimed // Paused during timed cardio - shows frozen countdown
    case resting
    case cardioTimed
    case cardioFreestyle
    case active
}

private extension GymWorkoutAttributes.ContentState {
    var phase: LiveActivityPhase {
        if isPaused {
            // For resting, use special paused phase to show frozen countdown
            if isResting && restTimeRemaining > 0 {
                return .pausedResting
            }
            // For timed cardio, use special paused phase to show frozen countdown
            if isCardio && cardioModeIndex == 0 && cardioTimeRemaining != nil {
                return .pausedCardioTimed
            }
            return .paused
        }
        if isResting { return .resting }
        if isCardio && cardioModeIndex == 0 { return .cardioTimed }
        if isCardio { return .cardioFreestyle }
        return .active
    }
    
    var statusText: String {
        switch phase {
        case .paused, .pausedResting, .pausedCardioTimed: return "PAUSED"
        case .resting: return "RESTING"
        case .cardioTimed, .cardioFreestyle: return "CARDIO"
        case .active: return "ACTIVE"
        }
    }
    
    var timerLabel: String {
        switch phase {
        case .paused: return "Paused"
        case .pausedResting: return "Remaining"
        case .pausedCardioTimed: return "Countdown"
        case .resting: return "Remaining"
        case .cardioTimed: return "Countdown"
        case .cardioFreestyle: return "Elapsed"
        case .active: return "Elapsed"
        }
    }
    
    var accentColor: Color {
        switch phase {
        case .paused, .pausedResting, .pausedCardioTimed: return .gray
        case .resting: return .cyan
        case .cardioTimed: return .orange
        case .cardioFreestyle: return .green
        case .active: return .green
        }
    }
    
    var isTimedCardio: Bool {
        isCardio && cardioModeIndex == 0 && cardioEndTime != nil
    }
}

private struct LiveActivityTimerText: View {
    let state: GymWorkoutAttributes.ContentState
    let fontSize: CGFloat
    let showsShadow: Bool
    
    var body: some View {
        let font = Font.system(size: fontSize, weight: .bold, design: .rounded).monospacedDigit()
        let tint = state.accentColor
        
        Group {
            switch state.phase {
            case .paused:
                Text(state.formattedElapsedTime)
            case .pausedResting:
                // Show frozen rest countdown
                Text(state.formattedRestTime)
            case .pausedCardioTimed:
                // Show frozen cardio countdown
                Text(state.formattedCardioTime)
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
            case .cardioFreestyle, .active:
                Text(state.workoutStartDate, style: .timer)
            }
        }
        .font(font)
        .foregroundStyle(tint)
        .shadow(color: showsShadow ? tint.opacity(0.3) : .clear, radius: showsShadow ? 8 : 0)
        .multilineTextAlignment(.trailing)
    }
}

private struct LiveActivityStateProgressBar: View {
    let state: GymWorkoutAttributes.ContentState
    
    var body: some View {
        let tint = state.accentColor
        
        Group {
            if state.isPaused {
                ProgressView(
                    value: Double(state.currentSet),
                    total: Double(max(state.totalSets, 1))
                )
                .progressViewStyle(.linear)
                .tint(tint)
            } else if state.isResting, let restEnd = state.restEndTime {
                let remaining = max(0, TimeInterval(state.restTimeRemaining))
                let restStart = restEnd.addingTimeInterval(-remaining)
                ProgressView(timerInterval: restStart...restEnd, countsDown: true)
                    .progressViewStyle(.linear)
                    .tint(tint)
            } else if state.isTimedCardio, let cardioEnd = state.cardioEndTime, state.cardioDuration > 0 {
                let startTime = cardioEnd.addingTimeInterval(-state.cardioDuration)
                ProgressView(timerInterval: startTime...cardioEnd, countsDown: true)
                    .progressViewStyle(.linear)
                    .tint(tint)
            } else if state.isCardio {
                let goal = state.cardioDuration > 0 ? state.cardioDuration : 1800
                let progress = min(Double(state.elapsedTime) / goal, 1)
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(tint)
            } else {
                ProgressView(
                    value: Double(state.currentSet),
                    total: Double(max(state.totalSets, 1))
                )
                .progressViewStyle(.linear)
                .tint(tint)
            }
        }
        .frame(height: 6)
    }
}

private struct LiveActivityControls: View {
    let state: GymWorkoutAttributes.ContentState
    let isCompact: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            styledLabel(pauseResumeButton)
            
            if state.isResting {
                styledLabel(skipRestButton)
            }
        }
        .font(isCompact ? .caption2 : .body)
    }
    
    @ViewBuilder
    private func styledLabel<Content: View>(_ content: Content) -> some View {
        if isCompact {
            content
                .labelStyle(.iconOnly)
        } else {
            content
                .labelStyle(.titleAndIcon)
        }
    }
    
    @ViewBuilder
    private var pauseResumeButton: some View {
        if state.isPaused {
            Button(intent: ResumeWorkoutIntent()) {
                Label("Resume", systemImage: "play.fill")
            }
            .buttonStyle(.bordered)
            .tint(state.accentColor)
            .controlSize(isCompact ? .mini : .regular)
        } else {
            Button(intent: PauseWorkoutIntent()) {
                Label("Pause", systemImage: "pause.fill")
            }
            .buttonStyle(.bordered)
            .tint(state.accentColor)
            .controlSize(isCompact ? .mini : .regular)
        }
    }
    
    private var skipRestButton: some View {
        Button(intent: SkipRestIntent()) {
            Label("Skip Rest", systemImage: "forward.fill")
        }
        .buttonStyle(.bordered)
        .tint(.orange)
        .controlSize(isCompact ? .mini : .regular)
    }
}

// MARK: - Preview

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: GymWorkoutAttributes(workoutTitle: "Full Body", totalExercises: 5)) {
    GymWorkoutLiveActivity()
} contentStates: {
    GymWorkoutAttributes.ContentState(
        exerciseName: "Squat",
        currentSet: 1,
        totalSets: 3,
        currentExerciseIndex: 1,
        elapsedTime: 20
    )
    GymWorkoutAttributes.ContentState(
        exerciseName: "Squat",
        currentSet: 1,
        totalSets: 3,
        currentExerciseIndex: 1,
        elapsedTime: 45,
        isResting: true,
        restTimeRemaining: 85
    )
}

#Preview("Lock Screen", as: .content, using: GymWorkoutAttributes(workoutTitle: "Full Body", totalExercises: 5)) {
    GymWorkoutLiveActivity()
} contentStates: {
    GymWorkoutAttributes.ContentState(
        exerciseName: "Bench Press",
        currentSet: 2,
        totalSets: 4,
        currentExerciseIndex: 2,
        elapsedTime: 650
    )
}
