//
//  GymWidgetEntryView.swift
//  GymWidgets
//
//  Widget entry views for small, medium, and large workout widgets.
//

import SwiftUI
import WidgetKit
import AppIntents

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
            VStack(spacing: 8) {
                // Status badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(state.isResting ? Color.cyan : Color.green)
                        .frame(width: 6, height: 6)
                    Text(state.isResting ? "RESTING" : "ACTIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(state.isResting ? .cyan : .green)
                }
                
                Spacer()
                
                // Timer
                if state.isResting, let restEnd = state.restEndTime {
                    Text(restEnd, style: .timer)
                        .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.cyan)
                } else {
                    Text(state.workoutStartDate, style: .timer)
                        .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.green)
                }
                
                // Set indicator
                Text("Set \(state.currentSet)/\(state.totalSets)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                // Exercise name
                Text(state.exerciseName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding()
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
            HStack(spacing: 0) {
                // Left: Status and timer
                VStack(alignment: .leading, spacing: 8) {
                    // Status
                    HStack(spacing: 6) {
                        Image(systemName: state.isResting ? "timer" : "dumbbell.fill")
                            .foregroundStyle(state.isResting ? .cyan : .orange)
                        Text(state.workoutTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Timer
                    if state.isResting, let restEnd = state.restEndTime {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("REST")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.cyan.opacity(0.7))
                            Text(restEnd, style: .timer)
                                .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.cyan)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ELAPSED")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.secondary)
                            Text(state.workoutStartDate, style: .timer)
                                .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.green)
                        }
                    }
                    
                    // Exercise info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.exerciseName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text("Set \(state.currentSet) of \(state.totalSets)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1)
                    .padding(.vertical, 16)
                
                // Right: Action buttons
                VStack(spacing: 8) {
                    if state.isResting {
                        // Rest controls
                        Button(intent: AddRestTimeIntent(seconds: 15)) {
                            Label("+15s", systemImage: "plus")
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.cyan.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.cyan)
                        }
                        .buttonStyle(.plain)
                        
                        Button(intent: SkipRestIntent()) {
                            Label("Skip", systemImage: "forward.fill")
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Active workout controls
                        Button(intent: AddRepsIntent(count: 1)) {
                            Text("+1 Rep")
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                        
                        Button(intent: AddRepsIntent(count: 5)) {
                            Text("+5 Reps")
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Open app link
                    Link(destination: URL(string: "lifeflow://gym")!) {
                        Label("Open", systemImage: "arrow.up.forward")
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
                .frame(width: 100)
            }
        } else {
            // Idle view
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
                
                Link(destination: URL(string: "lifeflow://gym")!) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .frame(width: 50, height: 50)
                        .background(Color.orange.opacity(0.2), in: Circle())
                        .foregroundStyle(.orange)
                }
            }
            .padding()
        }
    }
}

// MARK: - Large Widget

private struct LargeWidgetView: View {
    let state: WorkoutWidgetState
    
    var body: some View {
        if state.isActive {
            VStack(spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.workoutTitle.uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                        
                        if state.isResting, let restEnd = state.restEndTime {
                            HStack(spacing: 4) {
                                Text("Rest:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(restEnd, style: .timer)
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(.cyan)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Text("Elapsed:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(state.workoutStartDate, style: .timer)
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Link(destination: URL(string: "lifeflow://gym")!) {
                        Image(systemName: "arrow.up.forward.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Current exercise card
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CURRENT EXERCISE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            
                            Text(state.exerciseName)
                                .font(.title2.weight(.bold))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Set progress ring
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 4)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(state.currentSet) / CGFloat(max(state.totalSets, 1)))
                                .stroke(state.isResting ? Color.cyan : Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            
                            VStack(spacing: -2) {
                                Text("\(state.currentSet)")
                                    .font(.title3.weight(.bold))
                                Text("SET")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 56, height: 56)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    if state.isResting {
                        Button(intent: AddRestTimeIntent(seconds: 15)) {
                            Label("+15s", systemImage: "plus")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.cyan.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.cyan)
                        }
                        .buttonStyle(.plain)
                        
                        Button(intent: SkipRestIntent()) {
                            Label("Skip Rest", systemImage: "forward.fill")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(intent: AddRepsIntent(count: 1)) {
                            Text("+1 Rep")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                        
                        Button(intent: AddRepsIntent(count: 5)) {
                            Text("+5 Reps")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        } else {
            // Idle view
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                
                VStack(spacing: 8) {
                    Text("Ready to Train?")
                        .font(.title2.weight(.bold))
                    Text("Start a workout to track your progress")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Link(destination: URL(string: "lifeflow://gym")!) {
                    Label("Start Workout", systemImage: "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.orange, in: Capsule())
                        .foregroundStyle(.white)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}
