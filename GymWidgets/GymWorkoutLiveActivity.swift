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
import Foundation

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
                        
                        Text(context.state.primaryLabel)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(context.state.secondaryLabel)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.hasGhostRunnerContext {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(context.state.distanceString)
                                .font(.title2.weight(.bold).monospacedDigit())
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            
                            Text("Miles")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            if let deltaText = context.state.paceDeltaString {
                                Text(deltaText)
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(context.state.ghostDeltaColor)
                            }
                        }
                        .frame(width: 110, alignment: .trailing)
                        .padding(.trailing, 8)
                        .padding(.top, 8)
                    } else {
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
            if context.state.hasGhostRunnerContext {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.statusText)
                            .font(.caption2.weight(.black))
                            .foregroundStyle(context.state.accentColor)
                            .tracking(1)
                        
                        Text(context.state.distanceString)
                            .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                        
                        Text("Miles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if let delta = context.state.paceDeltaString {
                            Text(delta)
                                .font(.headline.weight(.bold).monospacedDigit())
                                .foregroundStyle(context.state.ghostDeltaColor)
                        }
                        
                        Text("vs Plan")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let target = context.state.formattedTargetPace {
                            Text(target)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.statusText)
                            .font(.caption2.weight(.black))
                            .foregroundStyle(context.state.accentColor)
                            .tracking(1)
                        
                        Text(context.state.primaryLabel)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text(context.state.secondaryLabel)
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
    
    var hasDistanceTarget: Bool {
        guard let total = targetDistanceTotal else { return false }
        return total > 0
    }
    
    var hasGhostRunnerContext: Bool {
        hasDistanceTarget
        && currentDistanceMiles != nil
        && ghostExpectedDistanceMiles != nil
    }
    
    var distanceProgress: Double {
        guard hasDistanceTarget,
              let total = targetDistanceTotal,
              let remaining = targetDistanceRemaining else {
            return 0
        }
        return min(max((total - remaining) / total, 0), 1)
    }
    
    var ghostRunnerProgress: Double {
        guard hasDistanceTarget,
              let total = targetDistanceTotal,
              let currentDistanceMiles else {
            return 0
        }
        return min(max(currentDistanceMiles / total, 0), 1)
    }
    
    var ghostTargetProgress: Double {
        guard hasDistanceTarget,
              let total = targetDistanceTotal,
              let expected = ghostExpectedDistanceMiles else {
            return 0
        }
        return min(max(expected / total, 0), 1)
    }
    
    var ghostDeltaColor: Color {
        guard let delta = ghostDeltaMiles else { return accentColor }
        return delta >= 0 ? .green : .red
    }
    
    var distanceString: String {
        if let currentDistanceMiles {
            return String(format: "%.2f", max(0, currentDistanceMiles))
        }
        
        if let targetDistanceTotal, let targetDistanceRemaining {
            let completed = max(0, targetDistanceTotal - targetDistanceRemaining)
            return String(format: "%.2f", completed)
        }
        
        return "--"
    }
    
    var paceDelta: Double? {
        ghostDeltaMiles
    }
    
    var paceDeltaString: String? {
        guard let delta = paceDelta else { return nil }
        return String(format: "%+.2f", delta)
    }
    
    var ghostDeltaText: String? {
        guard let delta = ghostDeltaMiles else { return nil }
        if abs(delta) < 0.01 {
            return "On target pace"
        }
        if delta > 0 {
            return String(format: "Ahead %.2f mi", delta)
        }
        return String(format: "Behind %.2f mi", abs(delta))
    }
    
    var formattedTargetPace: String? {
        guard let targetPaceMinutesPerMile, targetPaceMinutesPerMile > 0 else { return nil }
        let totalSeconds = Int((targetPaceMinutesPerMile * 60).rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "Target %d:%02d/mi", minutes, seconds)
    }
    
    var primaryLabel: String {
        currentIntervalName ?? exerciseName
    }
    
    var secondaryLabel: String {
        if let ghostDeltaText {
            if let formattedTargetPace {
                return "\(ghostDeltaText) • \(formattedTargetPace)"
            }
            return ghostDeltaText
        }
        if let remaining = targetDistanceRemaining {
            return String(format: "%.2f mi remaining", max(0, remaining))
        }
        return "Set \(currentSet) of \(totalSets)"
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
        
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if state.hasGhostRunnerContext {
                    LiveActivityGhostRunnerBar(
                        progress: state.ghostRunnerProgress,
                        ghostProgress: state.ghostTargetProgress,
                        color: state.ghostDeltaColor
                    )
                } else if state.hasDistanceTarget {
                    ProgressView(value: state.distanceProgress)
                        .progressViewStyle(.linear)
                        .tint(tint)
                } else if let intervalProgress = state.intervalProgress {
                    ProgressView(value: intervalProgress, total: 1)
                        .progressViewStyle(.linear)
                        .tint(tint)
                } else if state.isPaused {
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
            
            if let ghostDeltaText = state.ghostDeltaText {
                HStack(spacing: 6) {
                    Text(ghostDeltaText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(state.ghostDeltaColor)
                    if let pace = state.formattedTargetPace {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(pace)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct LiveActivityGhostRunnerBar: View {
    let progress: Double
    let ghostProgress: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let safeGhost = min(max(ghostProgress, 0), 1)
            let safeRunner = min(max(progress, 0), 1)
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: width * safeGhost)
                
                Capsule()
                    .fill(color)
                    .frame(width: width * safeRunner)
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
