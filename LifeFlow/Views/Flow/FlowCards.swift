//
//  FlowCards.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData

// MARK: - Hydration Card

struct HydrationCard: View {
    @Bindable var dayLog: DayLog
    
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
                        }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        dayLog.waterIntake += 8
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
    
    /// Environment action to trigger success pulse on the mesh gradient background
    @Environment(\.triggerSuccessPulse) private var triggerSuccessPulse
    
    @State private var offset: CGFloat = 0
    @State private var isDragging: Bool = false
    private let undoThreshold: CGFloat = -80
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Undo background (revealed on swipe)
            if dayLog.hasWorkedOut {
                HStack {
                    Spacer()
                    Button {
                        withAnimation {
                            if let index = dayLog.workouts.lastIndex(where: { $0.source == "Flow" }) {
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
                            .fill(dayLog.hasWorkedOut ? .green.opacity(0.15) : .orange.opacity(0.15))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: dayLog.hasWorkedOut ? "checkmark" : "figure.strengthtraining.traditional")
                            .font(.title2)
                            .foregroundStyle(dayLog.hasWorkedOut ? .green : .orange)
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
                        } else {
                            Text("No workout yet")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Spacer()
                    
                    // Check In button (only when no workout)
                    if !dayLog.hasWorkedOut {
                        Button {
                            // Quick log: Add a generic 45 min workout
                            let workout = WorkoutSession(
                                type: "Quick Log",
                                duration: 45 * 60,
                                calories: 300,
                                source: "Flow"
                            )
                            dayLog.workouts.append(workout)
                            
                            // Trigger celebratory success pulse
                            triggerSuccessPulse()
                            
                            // Haptic feedback
                            let notification = UINotificationFeedbackGenerator()
                            notification.notificationOccurred(.success)
                        } label: {
                            Text("Check In")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.2), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(16)
            }
            .offset(x: offset)
            .gesture(
                dayLog.hasWorkedOut ?
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
                                if let index = dayLog.workouts.lastIndex(where: { $0.source == "Flow" }) {
                                    dayLog.workouts.remove(at: index)
                                } else if !dayLog.workouts.isEmpty {
                                    dayLog.workouts.removeLast()
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
                            if let index = dayLog.workouts.lastIndex(where: { $0.source == "Flow" }) {
                                dayLog.workouts.remove(at: index)
                            } else if !dayLog.workouts.isEmpty {
                                dayLog.workouts.removeLast()
                            }
                            
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        }
                    } label: {
                        Label("Undo Workout", systemImage: "arrow.uturn.backward")
                    }
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
    
    @State private var amountString: String = ""
    @State private var offset: CGFloat = 0
    @State private var isDragging: Bool = false
    private let undoThreshold: CGFloat = -80
    
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
