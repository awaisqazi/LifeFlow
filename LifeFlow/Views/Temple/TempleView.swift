//
//  TempleView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData
import HealthKit

/// The Temple tab - your body is a temple.
/// Features the showpiece HydrationView and comprehensive workout tracking.
struct TempleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyMetrics.date, order: .reverse) private var allMetrics: [DailyMetrics]
    
    @State private var healthKitManager = HealthKitManager()
    @State private var showingAddWorkout = false
    
    /// Get today's metrics by filtering in Swift
    private var todayMetrics: DailyMetrics? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allMetrics.first { $0.date >= startOfDay }
    }
    
    /// Today's workouts
    private var todaysWorkouts: [WorkoutSession] {
        todayMetrics?.workouts ?? []
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                HeaderView(
                    title: "Temple",
                    subtitle: "Honor Your Body"
                )
                
                // Main Hydration Vessel - the showpiece
                GlassEffectContainer(spacing: 20) {
                    HydrationView()
                }
                
                // Workout Tracking Section
                GlassEffectContainer(spacing: 16) {
                    WorkoutLogView(
                        workouts: todaysWorkouts,
                        healthKitManager: healthKitManager,
                        onAddWorkout: { showingAddWorkout = true },
                        onSyncHealth: syncHealthKitWorkouts,
                        onDeleteWorkout: deleteWorkout
                    )
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100) // Space for tab bar
            }
            .padding(.top, 60)
        }
        .sheet(isPresented: $showingAddWorkout) {
            AddWorkoutSheet(onSave: saveManualWorkout)
        }
    }
    
    // MARK: - Actions
    
    /// Sync workouts from HealthKit
    private func syncHealthKitWorkouts() {
        Task {
            do {
                // Request authorization if needed
                if healthKitManager.authorizationStatus == .notDetermined {
                    try await healthKitManager.requestAuthorization()
                }
                
                // Fetch today's workouts
                let hkWorkouts = try await healthKitManager.fetchTodaysWorkouts()
                
                // Get or create today's metrics
                let today = getOrCreateTodayMetrics()
                
                // Add new workouts (avoid duplicates by checking UUID)
                let existingIds = Set(today.workouts.map { $0.id })
                
                for workout in hkWorkouts {
                    if !existingIds.contains(workout.id) {
                        workout.dailyMetrics = today
                        modelContext.insert(workout)
                    }
                }
                
                try? modelContext.save()
                
                // Haptic feedback for success
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.success)
                
            } catch {
                // Haptic feedback for error
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.error)
            }
        }
    }
    
    /// Save a manually added workout
    private func saveManualWorkout(type: String, duration: TimeInterval, calories: Double) {
        let today = getOrCreateTodayMetrics()
        
        let workout = WorkoutSession(
            type: type,
            duration: duration,
            calories: calories,
            source: "Manual"
        )
        workout.dailyMetrics = today
        modelContext.insert(workout)
        
        try? modelContext.save()
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    /// Delete a workout
    private func deleteWorkout(_ workout: WorkoutSession) {
        modelContext.delete(workout)
        try? modelContext.save()
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    /// Get or create today's DailyMetrics record
    private func getOrCreateTodayMetrics() -> DailyMetrics {
        if let today = todayMetrics {
            return today
        }
        
        let newMetrics = DailyMetrics(date: Date(), waterIntake: 0)
        modelContext.insert(newMetrics)
        return newMetrics
    }
}

// MARK: - Workout Log View

/// Displays today's workouts with sync and add controls
struct WorkoutLogView: View {
    let workouts: [WorkoutSession]
    let healthKitManager: HealthKitManager
    let onAddWorkout: () -> Void
    let onSyncHealth: () -> Void
    let onDeleteWorkout: (WorkoutSession) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                Text("Workouts")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Control buttons
                HStack(spacing: 10) {
                    // Sync from HealthKit - Apple Health branded
                    if healthKitManager.isAvailable {
                        Button {
                            onSyncHealth()
                        } label: {
                            Label {
                                Text("Sync")
                                    .font(.subheadline.weight(.semibold))
                            } icon: {
                                ZStack {
                                    // Mini Health app icon
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 1.0, green: 0.23, blue: 0.19),
                                                    Color(red: 1.0, green: 0.38, blue: 0.42)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 22, height: 22)
                                    
                                    if healthKitManager.isSyncing {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.glass)
                        .disabled(healthKitManager.isSyncing)
                    }
                    
                    // Add manual workout
                    Button {
                        onAddWorkout()
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.cyan)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                }
            }
            
            // Workouts list or empty state
            if workouts.isEmpty {
                EmptyWorkoutState()
            } else {
                // Summary
                HStack(spacing: 16) {
                    StatPill(
                        icon: "flame.fill",
                        value: "\(Int(workouts.reduce(0) { $0 + $1.calories }))",
                        label: "cal",
                        color: .orange
                    )
                    
                    StatPill(
                        icon: "clock.fill",
                        value: formatTotalDuration(workouts.reduce(0) { $0 + $1.duration }),
                        label: "",
                        color: .cyan
                    )
                    
                    StatPill(
                        icon: "checkmark.circle.fill",
                        value: "\(workouts.count)",
                        label: workouts.count == 1 ? "workout" : "workouts",
                        color: .green
                    )
                }
                
                // Workout cards
                VStack(spacing: 8) {
                    ForEach(workouts, id: \.id) { workout in
                        WorkoutCard(workout: workout, onDelete: { onDeleteWorkout(workout) })
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }
    
    private func formatTotalDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Views

/// Empty state when no workouts logged
struct EmptyWorkoutState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.wave")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("No workouts yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Tap + to log or sync from Health")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

/// Stat pill for workout summary
struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            
            Text(value)
                .font(.caption.weight(.semibold))
            
            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

/// Individual workout card
struct WorkoutCard: View {
    let workout: WorkoutSession
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: WorkoutSession.icon(for: workout.type))
                .font(.title3)
                .foregroundStyle(.cyan)
                .frame(width: 40, height: 40)
                .background(.cyan.opacity(0.15), in: Circle())
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.type)
                    .font(.subheadline.weight(.medium))
                
                HStack(spacing: 8) {
                    Text(workout.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if workout.calories > 0 {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text("\(Int(workout.calories)) cal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Source badge
            Text(workout.source)
                .font(.caption2.weight(.medium))
                .foregroundStyle(workout.source == "HealthKit" ? .pink : .cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (workout.source == "HealthKit" ? Color.pink : Color.cyan)
                        .opacity(0.15),
                    in: Capsule()
                )
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Workout Sheet

/// Sheet for manually adding a workout
struct AddWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let onSave: (String, TimeInterval, Double) -> Void
    
    @State private var selectedType = "Weightlifting"
    @State private var hours: Int = 0
    @State private var minutes: Int = 30
    @State private var calories: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                // Workout Type
                Section("Activity") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(WorkoutSession.workoutTypes, id: \.self) { type in
                            HStack {
                                Image(systemName: WorkoutSession.icon(for: type))
                                Text(type)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                // Duration
                Section("Duration") {
                    HStack {
                        Picker("Hours", selection: $hours) {
                            ForEach(0..<6) { hour in
                                Text("\(hour)h").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        
                        Picker("Minutes", selection: $minutes) {
                            ForEach(0..<60) { min in
                                Text("\(min)m").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                    }
                    .frame(height: 120)
                }
                
                // Calories (optional)
                Section("Calories Burned (Optional)") {
                    TextField("e.g., 250", text: $calories)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let totalSeconds = TimeInterval(hours * 3600 + minutes * 60)
                        let calorieValue = Double(calories) ?? 0
                        onSave(selectedType, totalSeconds, calorieValue)
                        dismiss()
                    }
                    .disabled(hours == 0 && minutes == 0)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ZStack {
        LiquidBackgroundView()
        TempleView()
    }
    .modelContainer(for: [DailyMetrics.self, WorkoutSession.self], inMemory: true)
    .preferredColorScheme(.dark)
}
