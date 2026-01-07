//
//  GymWidgetEntryView.swift
//  GymWidgets
//
//  Widget entry views for small, medium, and large workout widgets.
//  Display-only views with tap-to-open functionality.
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Shared Styles

/// A reusable glassmorphic modifier for the LifeFlow aesthetic
struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var borderColor: Color = .white.opacity(0.15)
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(
                // Subtle inner glow
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.05), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 10)
    }
}

extension View {
    func liquidGlassStyle(cornerRadius: CGFloat = 20) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }
}

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

// MARK: - Large Widget Components

struct HeroExerciseCard: View {
    let state: WorkoutWidgetState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(state.isResting ? "REST PERIOD" : (state.isPaused ? "PAUSED" : "ACTIVE EXERCISE"))
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(state.isResting ? .cyan : (state.isPaused ? .secondary : .orange))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        state.isResting ? Color.cyan.opacity(0.1) : 
                        (state.isPaused ? Color.secondary.opacity(0.1) : Color.orange.opacity(0.1)), 
                        in: Capsule()
                    )
                
                Spacer()
                
                if state.isResting {
                    if let restEnd = state.restEndTime {
                        Text(restEnd, style: .timer)
                            .font(.system(.title3, design: .monospaced, weight: .bold))
                            .foregroundStyle(.cyan)
                    }
                } else {
                    Text("\(state.currentSet) / \(state.totalSets)")
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(state.exerciseName)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    
                    Capsule()
                        .fill(state.isResting ? Color.cyan : Color.orange)
                        .frame(width: geo.size.width * (Double(state.currentSet) / Double(max(state.totalSets, 1))))
                }
            }
            .frame(height: 6)
            
            // Interactive Controls
            HStack(spacing: 12) {
                if state.isResting {
                    Button(intent: AddRestTimeIntent(seconds: 30)) {
                        Label("+30s", systemImage: "plus.circle.fill")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.cyan)
                    
                    Button(intent: SkipRestIntent()) {
                        Label("Skip", systemImage: "forward.end.fill")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                } else if state.isPaused {
                     Button(intent: ResumeWorkoutIntent()) {
                        Label("Resume", systemImage: "play.fill")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    Button(intent: PauseWorkoutIntent()) {
                         Label("Pause", systemImage: "pause.fill")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    
                    Spacer()
                    
                    Button(intent: AddRepsIntent(count: 1)) {
                        Label("Log Set", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .liquidGlassStyle(cornerRadius: 24)
    }
}

struct SecondaryExerciseRow: View {
    let title: String
    let exercise: String
    let details: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isCompleted ? Color.green : Color.white.opacity(0.1))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                
                Text(exercise)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(details)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct LargeWidgetView: View {
    let state: WorkoutWidgetState
    
    var body: some View {
        Stack {
            if state.isActive {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Label {
                            Text(state.workoutTitle)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                        } icon: {
                            Image(systemName: "figure.strengthtraining.traditional")
                        }
                        .foregroundStyle(.white)
                        
                        Spacer()
                        
                        // Live Indicator
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1), in: Capsule())
                    }
                    
                    // Hero Card
                    HeroExerciseCard(state: state)
                    
                    // Secondary Info Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        if let prev = state.previousExerciseName {
                            SecondaryExerciseRow(
                                title: "Completed",
                                exercise: prev,
                                details: "\(state.previousSetsCompleted) Sets",
                                isCompleted: true
                            )
                        }
                        
                        if let next = state.nextExerciseName {
                            SecondaryExerciseRow(
                                title: "Up Next",
                                exercise: next,
                                details: "\(state.nextTotalSets) Sets",
                                isCompleted: false
                            )
                        }
                    }
                }
                .padding()
            } else {
                // Empty State with Call to Action
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: .orange.opacity(0.3), radius: 20)
                    
                    VStack(spacing: 8) {
                        Text("Start Training")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Tap to launch your workout session")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(intent: StartWorkoutIntent()) {
                        Text("Begin Workout")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .clipShape(Capsule())
                    
                    Spacer()
                }
                .padding(30)
                .liquidGlassStyle()
            }
        }
        .containerBackground(for: .widget) {
            // Liquid Mesh Background approximation
            ZStack {
                Color.black // Base
                
                // Deep fluid gradients
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.0, blue: 0.3), // Deep purple
                        Color(red: 0.0, green: 0.1, blue: 0.3)  // Deep teal
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Accents
                GeometryReader { geo in
                    Circle()
                        .fill(Color.orange.opacity(0.3))
                        .blur(radius: 60)
                        .offset(x: -geo.size.width/4, y: -geo.size.height/4)
                    
                    Circle()
                        .fill(Color.cyan.opacity(0.2))
                        .blur(radius: 50)
                        .offset(x: geo.size.width/3, y: geo.size.height/3)
                }
            }
        }
    }
    
    // Helper Stack to handle older iOS versions if needed, though containerBackground implies iOS 17+
    // Using simple ViewBuilder to conditionalize could be better but sticking to direct body for now
    func Stack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
    }
}
