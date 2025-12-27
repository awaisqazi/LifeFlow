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
    
    var body: some View {
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
                
                // Action: For now, this just links conceptually or could toggle a "Check-in"
                // Ideally this would open the AddWorkoutSheet, but for simple "Input Stream"
                // we can just have a simple check-in or simple button.
                // Let's make it a simple "Check In" button for "Gym" if no workout, else "Done"
                
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
                        Text("+\(entry.valueAdded, format: .number) \(goal.unit.symbol)")
                            .font(.headline)
                    }
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
                            HStack {
                                TextField("Amount", text: $amountString)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                
                                Text(goal.unit.symbol)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Button("Done") {
                                    if let value = Double(amountString) {
                                        saveEntry(value: value)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(colorForGoal(goal))
                                .disabled(Double(amountString) == nil)
                            }
                        }
                    }
                }
            }
            .padding()
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
    
    private func promptForGoal(_ goal: Goal) -> String {
        if goal.type == .habit {
            return "Did you complete this today?"
        } else {
            return "Target: \(String(format: "%.1f", goal.dailyTarget)) \(goal.unit.symbol). Add progress:"
        }
    }
}
