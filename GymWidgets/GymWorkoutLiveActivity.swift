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

/// Live Activity widget configuration for Gym Workouts
struct GymWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GymWorkoutAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: context.state.isResting ? "timer" : "dumbbell.fill")
                                .foregroundStyle(context.state.isResting ? .cyan : .orange)
                                .font(.headline)
                            
                            Text(context.state.isResting ? "RESTING" : "ACTIVE")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(context.state.isResting ? .cyan : .orange)
                                .tracking(1)
                        }
                        
                        Text(context.state.exerciseName)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    .padding(.leading, 8)
                    .padding(.top, 8)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        if context.state.isResting, let restEndTime = context.state.restEndTime {
                            Text(restEndTime, style: .timer)
                                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.cyan)
                                .shadow(color: Color.cyan.opacity(0.3), radius: 8)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        } else if context.state.isCardio, context.state.cardioModeIndex == 0, let cardioEnd = context.state.cardioEndTime {
                            // Timed Cardio: Countdown
                            Text(cardioEnd, style: .timer)
                                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.orange)
                                .shadow(color: Color.orange.opacity(0.3), radius: 8)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        } else {
                            Text(context.state.workoutStartDate, style: .timer)
                                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.green)
                                .shadow(color: Color.green.opacity(0.3), radius: 8)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        
                        Text(context.state.isResting ? "Remaining" : (context.state.isCardio && context.state.cardioModeIndex == 0 ? "Countdown" : "Elapsed"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 110, alignment: .trailing)
                    .padding(.trailing, 8)
                    .padding(.top, 8)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        // Progress indicator - cardio vs sets
                        if context.state.isCardio, context.state.cardioModeIndex == 0, 
                           let cardioEnd = context.state.cardioEndTime,
                           context.state.cardioDuration > 0 {
                            // Timed Cardio: Countdown progress bar
                            let remaining = max(0, cardioEnd.timeIntervalSinceNow)
                            let progress = remaining / context.state.cardioDuration
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // Background track
                                    Capsule()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 6)
                                    
                                    // Progress fill (decreasing)
                                    Capsule()
                                        .fill(Color.orange.gradient)
                                        .frame(width: geo.size.width * progress, height: 6)
                                }
                            }
                            .frame(height: 6)
                        } else {
                            // Standard sets progress
                            HStack(spacing: 4) {
                                ForEach(0..<context.state.totalSets, id: \.self) { index in
                                    Capsule()
                                        .fill(index < context.state.currentSet ? 
                                              (context.state.isResting ? Color.cyan : Color.green) : 
                                              Color.gray.opacity(0.3))
                                        .frame(height: 4)
                                }
                                
                                Text("Set \(context.state.currentSet)/\(context.state.totalSets)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                            }
                        }
                        
                        HStack {
                            Label(context.attributes.workoutTitle, systemImage: "figure.strengthtraining.functional")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            if context.state.isCardio {
                                // Show cardio info
                                HStack(spacing: 8) {
                                    if context.state.cardioSpeed > 0 {
                                        Text(String(format: "%.1f mph", context.state.cardioSpeed))
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                    if context.state.cardioIncline > 0 {
                                        Text(String(format: "%.0f%%", context.state.cardioIncline))
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                // Timer on the left
                if context.state.isResting, let restEndTime = context.state.restEndTime {
                    Text(restEndTime, style: .timer)
                        .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.cyan)
                } else if context.state.isCardio, context.state.cardioModeIndex == 0, let cardioEnd = context.state.cardioEndTime {
                    // Timed Cardio: Countdown
                    Text(cardioEnd, style: .timer)
                        .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.orange)
                } else {
                    Text(context.state.workoutStartDate, style: .timer)
                        .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.green)
                }
            } compactTrailing: {
                // Dynamic icon on the right edge
                if context.state.isResting {
                    Image(systemName: "timer")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.cyan)
                } else {
                    Image(systemName: context.state.exerciseIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            } minimal: {
                // Dynamic icon in minimal view
                if context.state.isResting {
                    Image(systemName: "timer")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.cyan)
                } else {
                    Image(systemName: context.state.exerciseIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<GymWorkoutAttributes>
    
    var stateColor: Color {
        context.state.isResting ? .cyan : .orange
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left: Status & Info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.isResting ? "RESTING" : "ACTIVE")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(stateColor)
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
            
            // Right: Timer (Large & Clear)
            if context.state.isResting, let restEndTime = context.state.restEndTime {
                Text(restEndTime, style: .timer)
                    .font(.system(.largeTitle, design: .rounded).monospacedDigit())
                    .fontWeight(.bold)
                    .foregroundStyle(.cyan)
                    .multilineTextAlignment(.trailing)
            } else if context.state.isCardio, context.state.cardioModeIndex == 0, let cardioEnd = context.state.cardioEndTime {
                Text(cardioEnd, style: .timer)
                    .font(.system(.largeTitle, design: .rounded).monospacedDigit())
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.trailing)
            } else {
                Text(context.state.workoutStartDate, style: .timer)
                    .font(.system(.largeTitle, design: .rounded).monospacedDigit())
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        // No background - let the system Live Activity container handle it
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
        elapsedTime: 20
    )
    GymWorkoutAttributes.ContentState(
        exerciseName: "Squat",
        currentSet: 1,
        totalSets: 3,
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
        elapsedTime: 650
    )
}
