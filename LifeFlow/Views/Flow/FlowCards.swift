//
//  FlowCards.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import WidgetKit
import SwiftData

// MARK: - Hydration Card

struct HydrationCard: View {
    @Bindable var dayLog: DayLog
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        GlassCard(cornerRadius: 16) {
            HStack(spacing: 16) {
                // Icon / Status
                ZStack {
                    Circle()
                        .fill(.cyan.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "drop.fill")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hydration")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    Text("\(Int(dayLog.waterIntake)) oz")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 4) {
                    Button {
                        if dayLog.waterIntake >= 8 {
                            dayLog.waterIntake -= 8
                            HydrationSettings.saveCurrentIntake(dayLog.waterIntake)
                            try? modelContext.save()
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        dayLog.waterIntake += 8
                        HydrationSettings.saveCurrentIntake(dayLog.waterIntake)
                        try? modelContext.save()
                        WidgetCenter.shared.reloadAllTimelines()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 32, height: 32)
                            .background(Color.cyan.opacity(0.8), in: Circle())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Gym Card

struct GymCard: View {
    @Bindable var dayLog: DayLog
    @Environment(\.modelContext) private var modelContext
    
    /// Environment action to trigger success pulse on the mesh gradient background
    @Environment(\.triggerSuccessPulse) private var triggerSuccessPulse
    
    /// Environment action to enter Gym Mode
    @Environment(\.enterGymMode) private var enterGymMode
    
    /// Query for incomplete workouts (paused sessions)
    @Query(filter: #Predicate<WorkoutSession> { session in
        session.endTime == nil
    }, sort: \WorkoutSession.startTime, order: .reverse) private var incompleteWorkouts: [WorkoutSession]
    
    /// Query for today's completed workouts
    @Query(filter: #Predicate<WorkoutSession> { session in
        session.endTime != nil
    }, sort: \WorkoutSession.startTime, order: .reverse) private var completedWorkouts: [WorkoutSession]
    
    /// Filter for only today's incomplete workouts (ignore stale sessions from previous days)
    private var todaysIncompleteWorkouts: [WorkoutSession] {
        let calendar = Calendar.current
        return incompleteWorkouts.filter { calendar.isDateInToday($0.startTime) }
    }
    
    @State private var offset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var showWorkoutDetailSheet: Bool = false
    private let undoThreshold: CGFloat = -80
    
    /// Check if there's a paused workout to continue (only from today)
    private var pausedWorkout: WorkoutSession? {
        todaysIncompleteWorkouts.first
    }
    
    private var hasPausedWorkout: Bool {
        pausedWorkout != nil
    }
    
    /// Get today's completed workout session
    private var todaysCompletedWorkout: WorkoutSession? {
        let calendar = Calendar.current
        return completedWorkouts.first { calendar.isDateInToday($0.startTime) }
    }
    
    private var statusColor: Color {
        if dayLog.hasWorkedOut {
            return .green
        } else if hasPausedWorkout {
            return .yellow
        } else {
            return .orange
        }
    }
    
    private var statusIcon: String {
        if dayLog.hasWorkedOut {
            return "checkmark"
        } else if hasPausedWorkout {
            return "pause.circle.fill"
        } else {
            return "figure.strengthtraining.traditional"
        }
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Undo background (revealed on swipe)
            if dayLog.hasWorkedOut || hasPausedWorkout {
                HStack {
                    Spacer()
                    Button {
                        withAnimation {
                            if hasPausedWorkout, let paused = pausedWorkout {
                                // Delete paused workout
                                modelContext.delete(paused)
                                try? modelContext.save()
                            } else if let index = dayLog.workouts.lastIndex(where: { $0.source == "Flow" || $0.source == "GymMode" }) {
                                dayLog.workouts.remove(at: index)
                            } else if !dayLog.workouts.isEmpty {
                                dayLog.workouts.removeLast()
                            }
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        }
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 80)
                            .frame(maxHeight: .infinity)
                    }
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.vertical, 4)
                .opacity(offset < -20 ? 1 : 0)
            }
            
            GlassCard(cornerRadius: 16) {
                HStack(spacing: 16) {
                    // Icon / Status
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.15))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: statusIcon)
                            .font(.title2)
                            .foregroundStyle(statusColor)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Movement")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        if dayLog.hasWorkedOut {
                            Text("Workout Logged")
                                .font(.headline)
                                .foregroundStyle(.green)
                        } else if hasPausedWorkout {
                            Text("Workout Paused")
                                .font(.headline)
                                .foregroundStyle(.yellow)
                        } else {
                            Text("Ready to train?")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Spacer()
                    
                    // Button based on state
                    if dayLog.hasWorkedOut {
                        // Show Completed status with circular icon buttons
                        HStack(spacing: 12) {
                            // View details button
                            Button {
                                showWorkoutDetailSheet = true
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.green.gradient, in: Circle())
                            }
                            
                            // Add More / Continue Training button
                            Button {
                                enterGymMode()
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.orange.gradient, in: Circle())
                            }
                        }
                    } else if hasPausedWorkout {
                        // Continue button
                        Button {
                            enterGymMode()
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.caption)
                                Text("Continue")
                                    .font(.caption.weight(.bold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.yellow.gradient, in: Capsule())
                            .foregroundStyle(.black)
                        }
                    } else {
                        // Start button
                        Button {
                            enterGymMode()
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.caption)
                                Text("Start")
                                    .font(.caption.weight(.bold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange.gradient, in: Capsule())
                            .foregroundStyle(.white)
                        }
                    }
                }
                .padding(16)
            }
            .overlay {
                // Green border when completed for visual emphasis
                if dayLog.hasWorkedOut {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.6), lineWidth: 2)
                }
            }
            .offset(x: offset)
            .gesture(
                (dayLog.hasWorkedOut || hasPausedWorkout) ?
                DragGesture()
                    .onChanged { gesture in
                        isDragging = true
                        // Only allow left swipe
                        if gesture.translation.width < 0 {
                            offset = gesture.translation.width
                        }
                    }
                    .onEnded { gesture in
                        isDragging = false
                        withAnimation(.spring(response: 0.3)) {
                            if offset < undoThreshold {
                                // Delete paused workout or undo completed
                                if hasPausedWorkout, let paused = pausedWorkout {
                                    modelContext.delete(paused)
                                    try? modelContext.save()
                                } else if let todayWorkout = todaysCompletedWorkout {
                                    modelContext.delete(todayWorkout)
                                    // Also remove from dayLog
                                    if let index = dayLog.workouts.lastIndex(where: { $0.source == "Flow" || $0.source == "GymMode" }) {
                                        dayLog.workouts.remove(at: index)
                                    } else if !dayLog.workouts.isEmpty {
                                        dayLog.workouts.removeLast()
                                    }
                                    try? modelContext.save()
                                }
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                            }
                            // Reset position
                            offset = 0
                        }
                    }
                : nil
            )
            .contentShape(Rectangle())
            .contextMenu {
                if dayLog.hasWorkedOut {
                    Button(role: .destructive) {
                        withAnimation {
                            // Remove the most recent Flow workout
                            if let index = dayLog.workouts.lastIndex(where: { $0.source == "Flow" || $0.source == "GymMode" }) {
                                dayLog.workouts.remove(at: index)
                            } else if !dayLog.workouts.isEmpty {
                                dayLog.workouts.removeLast()
                            }
                            
                            // Also delete from WorkoutSession
                            if let todayWorkout = todaysCompletedWorkout {
                                modelContext.delete(todayWorkout)
                                try? modelContext.save()
                            }
                            
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        }
                    } label: {
                        Label("Undo Workout", systemImage: "arrow.uturn.backward")
                    }
                }
            }
            .sheet(isPresented: $showWorkoutDetailSheet) {
                if let workout = todaysCompletedWorkout {
                    WorkoutDetailModal(workout: workout)
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }
}

// MARK: - Goal Action Card

struct GoalActionCard: View {
    @Environment(\.modelContext) private var modelContext
    
    /// Environment action to trigger success pulse on the mesh gradient background
    @Environment(\.triggerSuccessPulse) private var triggerSuccessPulse
    
    let goal: Goal
    @Bindable var dayLog: DayLog
    var onFocus: (() -> Void)? = nil
    
    @State private var amountString: String = ""
    @State private var offset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var completionBurstTrigger: Int = 0
    private let undoThreshold: CGFloat = -80
    
    private var delightIntensity: MicroDelightIntensity {
        LifeFlowExperienceSettings.load().microDelightIntensity
    }
    
    // Find today's entry for this goal
    var todaysEntry: DailyEntry? {
        dayLog.entries.first { $0.goal?.id == goal.id } // Requires Goal to be Identifiable (it is @Model)
    }
    
    var isCompletedToday: Bool {
        todaysEntry != nil
    }
    
    var dailyTarget: Double {
        goal.dailyTarget
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Undo background (revealed on swipe)
            if isCompletedToday {
                HStack {
                    Spacer()
                    Button {
                        if let entry = todaysEntry {
                            undoEntry(entry)
                        }
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 80)
                            .frame(maxHeight: .infinity)
                    }
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.vertical, 4)
                .opacity(offset < -20 ? 1 : 0)
            }
            
            GlassCard(cornerRadius: 16) {
                VStack(spacing: 12) {
                    // Header: Icon + Goal Title
                    HStack {
                        Image(systemName: iconForGoal(goal))
                            .foregroundStyle(colorForGoal(goal))
                        Text(goal.title)
                            .font(.headline)
                        Spacer()
                        if isCompletedToday {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    
                    Divider()
                    
                    // Action Area
                    if isCompletedToday, let entry = todaysEntry {
                        HStack {
                            Text("Today's Progress:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("+\(entry.valueAdded, format: .number) \(unitLabelForGoal(goal))")
                                .font(.headline)
                        }
                        .contentShape(Rectangle())
                    } else {
                        // Input View
                        VStack(alignment: .leading, spacing: 8) {
                            Text(promptForGoal(goal))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            if goal.type == .habit {
                                Button(action: {
                                    saveEntry(value: 1.0)
                                }) {
                                    HStack {
                                        Spacer()
                                        Label("Mark Complete", systemImage: "checkmark")
                                            .font(.headline)
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .background(colorForGoal(goal).opacity(0.15), in: Capsule())
                                    .foregroundStyle(colorForGoal(goal))
                                }
                            } else {
                                HStack(spacing: 12) {
                                    // Styled Input Setup
                                    HStack(spacing: 4) {
                                        TextField("0", text: $amountString)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .font(.title3.weight(.semibold))
                                            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { obj in
                                                if let textField = obj.object as? UITextField {
                                                    // Async dispatch is crucial to beat the system's default cursor placement
                                                    DispatchQueue.main.async {
                                                        textField.selectAll(nil)
                                                    }
                                                    // Notify parent to scroll
                                                    onFocus?()
                                                }
                                            }
                                        
                                        Text(unitLabelForGoal(goal))
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(uiColor: .secondarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    
                                    // Submit Button
                                    Button {
                                        if let value = Double(amountString) {
                                            saveEntry(value: value)
                                            // Dismiss keyboard
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        }
                                    } label: {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 38))
                                            .foregroundStyle(colorForGoal(goal))
                                            .symbolEffect(.bounce, value: amountString)
                                    }
                                    .disabled(Double(amountString) == nil)
                                    .opacity(Double(amountString) == nil ? 0.5 : 1)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .overlay(alignment: .bottom) {
                if delightIntensity.isEnabled {
                    BubbleBurstView(
                        trigger: completionBurstTrigger,
                        tint: colorForGoal(goal),
                        particleCount: max(7, Int((16 * delightIntensity.bubbleParticleScale).rounded())),
                        spread: 108 * delightIntensity.bubbleParticleScale,
                        rise: 150 * delightIntensity.bubbleParticleScale,
                        duration: delightIntensity == .full ? 0.98 : 0.72
                    )
                    .frame(height: 180)
                    .offset(y: 10)
                }
            }
            .offset(x: offset)
            .gesture(
                isCompletedToday ? 
                DragGesture()
                    .onChanged { gesture in
                        isDragging = true
                        // Only allow left swipe
                        if gesture.translation.width < 0 {
                            offset = gesture.translation.width
                        }
                    }
                    .onEnded { gesture in
                        isDragging = false
                        withAnimation(.spring(response: 0.3)) {
                            if offset < undoThreshold {
                                // Trigger undo
                                if let entry = todaysEntry {
                                    undoEntry(entry)
                                }
                            }
                            // Reset position
                            offset = 0
                        }
                    }
                : nil
            )
            .contentShape(Rectangle())
            .contextMenu {
                if isCompletedToday, let entry = todaysEntry {
                    Button(role: .destructive) {
                        undoEntry(entry)
                    } label: {
                        Label("Undo Entry", systemImage: "arrow.uturn.backward")
                    }
                }
            }
        }
        .onAppear {
            if dailyTarget > 0 {
                amountString = String(format: "%.0f", dailyTarget)
            }
        }
    }
    
    private func saveEntry(value: Double) {
        let newEntry = DailyEntry(valueAdded: value)
        newEntry.goal = goal
        newEntry.dayLog = dayLog
        
        // Update Goal total
        goal.currentAmount += value
        
        modelContext.insert(newEntry)
        // Auto-save happens via CloudKit/SwiftData usually, but explicit save is safe
        try? modelContext.save()
        
        // Trigger celebratory success pulse
        triggerSuccessPulse()
        if delightIntensity.isEnabled {
            completionBurstTrigger &+= 1
        }
        
        // Haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }
    
    private func undoEntry(_ entry: DailyEntry) {
        withAnimation {
            // Subtract value from goal
            goal.currentAmount -= entry.valueAdded
            
            // Remove from dayLog
            if let index = dayLog.entries.firstIndex(where: { $0.id == entry.id }) {
                dayLog.entries.remove(at: index)
            }
            
            // Delete entry
            modelContext.delete(entry)
            try? modelContext.save()
            
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        }
    }
    
    private func iconForGoal(_ goal: Goal) -> String {
        goal.type.icon
    }
    
    private func colorForGoal(_ goal: Goal) -> Color {
        switch goal.type {
        case .savings: return .yellow
        case .weightLoss: return .green
        case .habit: return .orange
        case .study: return .purple
        case .raceTraining: return .green
        case .custom: return .blue
        }
    }
    
    private func unitLabelForGoal(_ goal: Goal) -> String {
        switch goal.type {
        case .study: return "hours"
        case .savings: return "$"
        default: return goal.unit.symbol
        }
    }
    
    private func promptForGoal(_ goal: Goal) -> String {
        switch goal.type {
        case .habit:
            return "Did you complete this today?"
        case .study:
            return "Target: \(String(format: "%.1f", goal.dailyTarget)) hours/day. Add progress:"
        case .savings:
            return "Target: $\(String(format: "%.2f", goal.dailyTarget))/day. Add progress:"
        default:
            return "Target: \(String(format: "%.1f", goal.dailyTarget)) \(goal.unit.symbol)/day. Add progress:"
        }
    }
}
