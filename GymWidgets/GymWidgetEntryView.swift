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

// MARK: - Large Widget (Exercise Queue Dashboard)

private struct LargeWidgetView: View {
    let state: WorkoutWidgetState
    
    @Environment(\.widgetRenderingMode) var renderingMode
    
    var body: some View {
        Group {
            if state.isActive {
                exerciseQueueDashboard
            } else {
                idleStatePlaceholder
            }
        }
        .containerBackground(for: .widget) {
            Color.black.opacity(0.95)
        }
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
                        renderingMode: renderingMode
                    )
                }
                
                // Current Exercise (Hero)
                CurrentExerciseCard(
                    state: state,
                    renderingMode: renderingMode
                )
                
                // Next Exercise (if exists)
                if let nextName = state.nextExerciseName {
                    ExerciseCard(
                        position: .next,
                        exerciseName: nextName,
                        setsCompleted: state.nextSetsCompleted,
                        totalSets: state.nextTotalSets,
                        isComplete: false,
                        renderingMode: renderingMode
                    )
                }
            }
        }
        .padding(12)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            // Workout Title
            VStack(alignment: .leading, spacing: 2) {
                Text(state.workoutTitle.isEmpty ? "WORKOUT" : state.workoutTitle.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Text("Exercise \(state.currentExerciseIndex + 1) of \(state.totalExercises)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // Elapsed Timer
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                
                if state.isPaused {
                    Text(state.pausedDisplayTime ?? "--:--")
                        .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text(state.workoutStartDate, style: .timer)
                        .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                        .widgetAccentable()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08), in: Capsule())
        }
    }
    
    // MARK: - Idle State Placeholder
    
    private var idleStatePlaceholder: some View {
        Link(destination: URL(string: "lifeflow://gym")!) {
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
        }
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
    let renderingMode: WidgetRenderingMode
    
    private var isFullColor: Bool {
        renderingMode == .fullColor
    }
    
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
        .background(cardBackground)
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
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(position == .previous ? 0.04 : 0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
    }
}

// MARK: - Current Exercise Card (Hero)

private struct CurrentExerciseCard: View {
    let state: WorkoutWidgetState
    let renderingMode: WidgetRenderingMode
    
    private var isFullColor: Bool {
        renderingMode == .fullColor
    }
    
    private var accentColor: Color {
        state.isResting ? .cyan : .green
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
        .background(heroCardBackground)
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
            } else {
                // Set Progress
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
        Group {
            if state.isResting, let restEnd = state.restEndTime {
                // Rest mode: Use ProgressView with timerInterval for animated countdown
                let totalDuration = state.restDuration ?? 90
                let restStart = restEnd.addingTimeInterval(-totalDuration)
                
                ProgressView(
                    timerInterval: restStart...restEnd,
                    countsDown: true
                ) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .tint(isFullColor ? .cyan : .primary)
            } else {
                // Work mode: show set progress (bar increases)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 6)
                        
                        if state.totalSets > 0 {
                            let progress = Double(state.currentSet) / Double(state.totalSets)
                            Capsule()
                                .fill(isFullColor ? accentColor : Color.primary)
                                .frame(width: max(geo.size.width * progress, 0), height: 6)
                                .widgetAccentable()
                        }
                    }
                }
                .frame(height: 6)
            }
        }
    }
    
    private var heroCardBackground: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.white.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}
