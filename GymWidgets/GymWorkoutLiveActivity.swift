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
                    HStack(spacing: 8) {
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.exerciseName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            
                            Text("Set \(context.state.currentSet)/\(context.state.totalSets)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if context.state.isResting {
                            Text(context.state.formattedRestTime)
                                .font(.title3.weight(.bold).monospacedDigit())
                                .foregroundStyle(.cyan)
                        } else {
                            Text(context.state.formattedElapsedTime)
                                .font(.title3.weight(.bold).monospacedDigit())
                                .foregroundStyle(.green)
                        }
                        
                        Text(context.state.isResting ? "Rest" : "Active")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    // Progress indicator
                    if context.state.isResting {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .foregroundStyle(.cyan)
                            Text("Resting...")
                                .font(.caption)
                                .foregroundStyle(.cyan)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.workoutTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("⏱ \(context.state.formattedElapsedTime)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Compact leading - icon
                Image(systemName: context.state.isResting ? "timer" : "dumbbell.fill")
                    .foregroundStyle(context.state.isResting ? .cyan : .orange)
            } compactTrailing: {
                // Compact trailing - time
                Text(context.state.isResting ? context.state.formattedRestTime : context.state.formattedElapsedTime)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(context.state.isResting ? .cyan : .green)
            } minimal: {
                // Minimal - just the icon
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<GymWorkoutAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            // Left - Workout icon
            ZStack {
                Circle()
                    .fill(context.state.isResting ? Color.cyan.opacity(0.2) : Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: context.state.isResting ? "timer" : "dumbbell.fill")
                    .font(.title2)
                    .foregroundStyle(context.state.isResting ? .cyan : .orange)
            }
            
            // Middle - Exercise info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.workoutTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(context.state.exerciseName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("Set \(context.state.currentSet) of \(context.state.totalSets)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Right - Timer
            VStack(alignment: .trailing, spacing: 4) {
                if context.state.isResting {
                    Text("REST")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.cyan)
                    
                    Text(context.state.formattedRestTime)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.cyan)
                } else {
                    Text("ACTIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                    
                    Text(context.state.formattedElapsedTime)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(16)
        .background(Color.black)
    }
}

// MARK: - Preview

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: GymWorkoutAttributes(workoutTitle: "Push Day", totalExercises: 5)) {
    GymWorkoutLiveActivity()
} contentStates: {
    GymWorkoutAttributes.ContentState(
        exerciseName: "Bench Press",
        currentSet: 2,
        totalSets: 3,
        elapsedTime: 1234,
        isResting: false
    )
    GymWorkoutAttributes.ContentState(
        exerciseName: "Bench Press",
        currentSet: 2,
        totalSets: 3,
        elapsedTime: 1234,
        isResting: true,
        restTimeRemaining: 90
    )
}
