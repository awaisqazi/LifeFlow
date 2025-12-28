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
                        } else {
                            Text(context.state.workoutStartDate, style: .timer)
                                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.green)
                                .shadow(color: Color.green.opacity(0.3), radius: 8)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        
                        Text(context.state.isResting ? "Remaining" : "Elapsed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 110, alignment: .trailing)
                    .padding(.trailing, 8)
                    .padding(.top, 8)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        // Progress / Sets
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
                        
                        HStack {
                            Label(context.attributes.workoutTitle, systemImage: "figure.strengthtraining.functional")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            if !context.state.isResting {
                                Text("Next: \(context.state.exerciseName)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: context.state.isResting ? "timer" : "dumbbell.fill")
                        .foregroundStyle(context.state.isResting ? .cyan : .orange)
                    
                    if context.state.isResting, let restEndTime = context.state.restEndTime {
                        Text(restEndTime, style: .timer)
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.cyan)
                    }
                }
            } compactTrailing: {
                if !context.state.isResting {
                    Text(context.state.workoutStartDate, style: .timer)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.cyan)
                }
            } minimal: {
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
            
            HStack(spacing: 20) {
                // Left - Status Visual
                ZStack {
                    Circle()
                        .stroke(context.state.isResting ? Color.cyan.opacity(0.2) : Color.green.opacity(0.2), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(context.state.currentSet) / CGFloat(context.state.totalSets))
                        .stroke(context.state.isResting ? Color.cyan : Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: -2) {
                        Text("\(context.state.currentSet)")
                            .font(.title2.weight(.bold))
                        Text("SET")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.secondary)
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
                    } else {
                        Text(context.state.workoutStartDate, style: .timer)
                            .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.primary)
                            .shadow(color: Color.white.opacity(0.2), radius: 10)
                    }
                    
                    Text(context.state.isResting ? "REST TIMER" : "TOTAL TIME")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                }
        }
        .padding(.horizontal)
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
