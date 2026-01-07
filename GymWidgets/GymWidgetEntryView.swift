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
    var entry: WorkoutEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(state: entry.state)
        case .systemMedium:
            MediumWidgetView(state: entry.state)
        case .systemLarge:
            LargeWidgetView(state: entry.state)
        default:
            SmallWidgetView(state: entry.state)
        }
    }
}

// MARK: - Small Widget

private struct SmallWidgetView: View {
    let state: WorkoutWidgetState
    
    var body: some View {
        if state.isActive {
            // Active workout view
            Link(destination: URL(string: "lifeflow://gym")!) {
                VStack(spacing: 0) {
                    // Status badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(state.isPaused ? Color.secondary : (state.isResting ? Color.cyan : Color.green))
                            .frame(width: 6, height: 6)
                        Text(state.isPaused ? "PAUSED" : (state.isResting ? "RESTING" : "ACTIVE"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(state.isPaused ? Color.secondary : (state.isResting ? Color.cyan : Color.green))
                    }
                    
                    Spacer()
                    
                    // Timer
                    if state.isPaused {
                        Text(state.pausedDisplayTime ?? "--:--")
                            .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    } else if state.isResting, let restEnd = state.restEndTime {
                        Text(restEnd, style: .timer)
                            .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.cyan)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(state.workoutStartDate, style: .timer)
                            .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.green)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    
                    Spacer()
                    
                    // Exercise info
                    VStack(spacing: 2) {
                        Text(state.exerciseName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        
                        Text("Set \(state.currentSet)/\(state.totalSets)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
            }
        } else {
            // Idle view - Start workout button
            Link(destination: URL(string: "lifeflow://gym")!) {
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                    
                    Text("Start Workout")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Medium Widget

private struct MediumWidgetView: View {
    let state: WorkoutWidgetState
    
    var body: some View {
        if state.isActive {
            Link(destination: URL(string: "lifeflow://gym")!) {
                HStack(spacing: 16) {
                    // Left Column: Status & Timer
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: state.isPaused ? "pause.fill" : (state.isResting ? "timer" : "dumbbell.fill"))
                                .font(.system(size: 10, weight: .bold))
                            Text(state.isPaused ? "PAUSED" : (state.isResting ? "RESTING" : "ACTIVE"))
                                .font(.system(size: 10, weight: .black))
                        }
                        .foregroundStyle(state.isPaused ? Color.secondary : (state.isResting ? Color.cyan : Color.orange))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(state.isPaused ? Color.secondary.opacity(0.1) : (state.isResting ? Color.cyan.opacity(0.1) : Color.orange.opacity(0.1)), in: Capsule())
                        
                        Spacer()
                        
                        if state.isPaused {
                            Text(state.pausedDisplayTime ?? "--:--")
                                .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color.secondary)
                        } else if state.isResting, let restEnd = state.restEndTime {
                            Text(restEnd, style: .timer)
                                .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color.cyan)
                        } else {
                            Text(state.workoutStartDate, style: .timer)
                                .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color.green)
                        }
                        
                        Text(state.isResting ? "REST TIMER" : (state.isPaused ? "STATIONARY" : "ELAPSED"))
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.secondary.opacity(0.6))
                        
                        Spacer()
                    }
                    .frame(width: 110)
                    
                    // Right Column: Exercise Details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.workoutTitle.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.secondary)
                        
                        Text(state.exerciseName)
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .minimumScaleFactor(0.9)
                        
                        Text("Set \(state.currentSet) of \(state.totalSets)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        
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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
        } else {
            // Idle view
            Link(destination: URL(string: "lifeflow://gym")!) {
                HStack(spacing: 16) {
                    // Icon
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
            }
        }
    }
}

// MARK: - Large Widget

private struct LargeWidgetView: View {
    let state: WorkoutWidgetState
    
    var body: some View {
        if state.isActive {
            Link(destination: URL(string: "lifeflow://gym")!) {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.workoutTitle.uppercased())
                                .font(.caption.weight(.black))
                                .foregroundStyle(state.isPaused ? Color.secondary : Color.orange)
                            
                            HStack(spacing: 4) {
                                Text("Exercise \(state.currentExerciseIndex) of \(state.totalExercises)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if state.isPaused {
                                    Text("• PAUSED")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Timer
                        VStack(alignment: .trailing, spacing: 0) {
                            if state.isPaused {
                                Text(state.pausedDisplayTime ?? "--:--")
                                    .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text("PAUSED")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(.secondary.opacity(0.7))
                            } else if state.isResting, let restEnd = state.restEndTime {
                                Text(restEnd, style: .timer)
                                    .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(.cyan)
                                Text("REST")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(.cyan.opacity(0.7))
                            } else {
                                Text(state.workoutStartDate, style: .timer)
                                    .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(.green)
                                Text("ELAPSED")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Exercise Flow
                    VStack(spacing: 12) {
                        // Previous exercise
                        if let previous = state.previousExerciseName {
                            HStack {
                                Image(systemName: state.previousIsComplete ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(state.previousIsComplete ? Color.green : Color.secondary.opacity(0.5))
                                Text(previous)
                                    .font(.subheadline)
                                    .foregroundStyle(state.previousIsComplete ? Color.secondary : Color.secondary.opacity(0.5))
                                    .strikethrough(state.previousIsComplete, color: .secondary)
                                Spacer()
                                Text("\(state.previousSetsCompleted)/\(state.previousTotalSets)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(state.previousIsComplete ? Color.green : Color.secondary.opacity(0.5))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(state.previousIsComplete ? Color.green.opacity(0.05) : Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                        }
                        
                        // Current exercise (highlighted)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CURRENT")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(state.isResting ? .cyan : .orange)
                                
                                Text(state.exerciseName)
                                    .font(.title2.weight(.bold))
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Set indicator
                            VStack(spacing: 0) {
                                Text("\(state.currentSet)")
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(state.isResting ? .cyan : .primary)
                                Text("of \(state.totalSets)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 50)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(state.isResting ? Color.cyan.opacity(0.1) : Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(state.isResting ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        
                        // Next exercise (if any)
                        if let next = state.nextExerciseName {
                            HStack {
                                Image(systemName: "arrow.right.circle")
                                    .foregroundStyle(.tertiary)
                                Text(next)
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Text("\(state.nextSetsCompleted)/\(state.nextTotalSets)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
        } else {
            // Idle view
            Link(destination: URL(string: "lifeflow://gym")!) {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange)
                    
                    VStack(spacing: 8) {
                        Text("Ready to Train?")
                            .font(.title2.weight(.bold))
                        Text("Tap to start tracking your workout")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Visual hint
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .foregroundStyle(.orange)
                        Text("Tap to begin")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1), in: Capsule())
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
}
