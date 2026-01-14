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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label(context.attributes.workoutTitle.uppercased(), systemImage: "bolt.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1), in: Capsule())
                
                Spacer()
                
                Text("LIVE WORKOUT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            HStack(spacing: 16) {
                // Left - Static State Indicator (no animation needed)
                ZStack {
                    // Background circle with state-based color
                    Circle()
                        .fill(context.state.isResting ? 
                              Color.cyan.opacity(0.15) : 
                              Color.green.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    // Border ring
                    Circle()
                        .stroke(context.state.isResting ? Color.cyan : Color.green, lineWidth: 3)
                        .frame(width: 64, height: 64)
                    
                    // State icon + set info
                    VStack(spacing: 2) {
                        Image(systemName: context.state.isResting ? "timer" : "dumbbell.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(context.state.isResting ? .cyan : .green)
                        
                        Text("\(context.state.currentSet)/\(context.state.totalSets)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }
                
                // Middle - Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.isResting ? "Currently Resting" : "Active Exercise")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(context.state.isResting ? .cyan : .orange)
                    
                    Text(context.state.exerciseName)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                    
                    Text("Session: ")
                        .font(.caption)
                        .foregroundStyle(.secondary) +
                    Text(context.state.workoutStartDate, style: .timer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Right - Big Timer
                VStack(alignment: .trailing, spacing: 0) {
                    if context.state.isResting, let restEndTime = context.state.restEndTime {
                        Text(restEndTime, style: .timer)
                            .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.cyan)
                            .shadow(color: Color.cyan.opacity(0.2), radius: 10)
                            .multilineTextAlignment(.trailing)
                    } else if context.state.isCardio, context.state.cardioModeIndex == 0, let cardioEnd = context.state.cardioEndTime {
                        // Timed Cardio: Countdown
                        Text(cardioEnd, style: .timer)
                            .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.orange)
                            .shadow(color: Color.orange.opacity(0.2), radius: 10)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(context.state.workoutStartDate, style: .timer)
                            .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.primary)
                            .shadow(color: Color.white.opacity(0.2), radius: 10)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Text(context.state.isResting ? "REST TIMER" : (context.state.isCardio && context.state.cardioModeIndex == 0 ? "COUNTDOWN" : "TOTAL TIME"))
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.secondary)
                }
                .frame(alignment: .trailing)
            }
            .padding(16)
        }
        // Note: Removed custom background - iOS provides the Live Activity container automatically
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
