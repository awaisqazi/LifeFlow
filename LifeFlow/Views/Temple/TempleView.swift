//
//  TempleView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData
import HealthKit
import Charts

/// The Temple tab - Analytics Dashboard.
/// Read-only view displaying health metrics, charts, and consistency data.
struct TempleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DayLog.date, order: .reverse) private var allLogs: [DayLog]
    @Query(sort: \Goal.deadline, order: .forward) private var goals: [Goal]
    
    /// Query for completed workouts (with endTime set)
    @Query(filter: #Predicate<WorkoutSession> { session in
        session.endTime != nil
    }, sort: \WorkoutSession.startTime, order: .reverse) private var completedWorkouts: [WorkoutSession]
    
    @State private var selectedScope: TimeScope = .week
    @State private var healthKitWorkouts: [WorkoutSession] = []
    @State private var showingHealthKitAlert = false
    @State private var selectedWorkoutForDetail: WorkoutSession? = nil
    
    private let healthKitManager = HealthKitManager()
    
    /// Filtered logs based on selected time scope
    private var filteredLogs: [DayLog] {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch selectedScope {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now)!
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now)!
        }
        
        return allLogs.filter { $0.date >= startDate }.sorted { $0.date < $1.date }
    }
    
    /// Aggregate workout stats for the selected scope
    private var workoutStats: (count: Int, calories: Double, duration: TimeInterval) {
        let workouts = filteredLogs.flatMap { $0.workouts }
        return (
            count: workouts.count,
            calories: workouts.reduce(0) { $0 + $1.calories },
            duration: workouts.reduce(0) { $0 + $1.duration }
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HeaderView(
                    title: "Temple",
                    subtitle: "Analytics Dashboard"
                )
                
                // Time Scope Picker
                Picker("Time Scope", selection: $selectedScope) {
                    ForEach(TimeScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Analytics Container
                GlassEffectContainer(spacing: 20) {
                    VStack(spacing: 20) {
                        // Hydration Chart
                        HydrationChart(logs: allLogs, scope: selectedScope)
                        
                        // Goal Progress Chart
                        if let firstGoal = goals.first {
                            GoalProgressChart(goal: firstGoal)
                        } else {
                            EmptyGoalChartState()
                        }
                        
                        // Consistency Heatmap
                        ConsistencyHeatmap(logs: allLogs)
                    }
                }
                .padding(.horizontal)
                
                // Workout Summary (Read-only)
                GlassEffectContainer(spacing: 16) {
                    WorkoutSummaryView(
                        stats: workoutStats,
                        isSyncing: healthKitManager.isSyncing,
                        onSyncTap: syncHealthKit
                    )
                }
                .padding(.horizontal)
                
                // Recent Workouts Section
                if !completedWorkouts.isEmpty {
                    RecentWorkoutsSection(
                        workouts: Array(completedWorkouts.prefix(5)),
                        onWorkoutTap: { workout in
                            selectedWorkoutForDetail = workout
                        },
                        onWorkoutDelete: { workout in
                            modelContext.delete(workout)
                            try? modelContext.save()
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        }
                    )
                    .padding(.horizontal)
                }
                
                // Goal Progress Visualization Section
                if !goals.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .font(.title2)
                                .foregroundStyle(.purple)
                            
                            Text("Goal Progress")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        ForEach(goals) { goal in
                            GoalVisualizationCard(goal: goal)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 100) // Space for tab bar
            }
            .padding(.top, 60)
        }
        .onAppear {
            syncHealthKitOnAppear()
        }
        .alert("HealthKit", isPresented: $showingHealthKitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(healthKitManager.lastError?.localizedDescription ?? "Unable to sync with HealthKit")
        }
        .sheet(item: $selectedWorkoutForDetail) { workout in
            WorkoutDetailModal(workout: workout)
                .presentationDetents([.medium, .large])
        }
    }
    
    private func syncHealthKitOnAppear() {
        Task {
            do {
                try await healthKitManager.requestAuthorization()
                let workouts = try await healthKitManager.fetchWorkouts(for: selectedScope)
                await MainActor.run {
                    healthKitWorkouts = workouts
                    mergeHealthKitWorkouts(workouts)
                }
            } catch {
                // Silently fail on initial sync - user can manually sync
                print("HealthKit sync error: \(error)")
            }
        }
    }
    
    private func syncHealthKit() {
        Task {
            do {
                try await healthKitManager.requestAuthorization()
                let workouts = try await healthKitManager.fetchWorkouts(for: selectedScope)
                await MainActor.run {
                    healthKitWorkouts = workouts
                    mergeHealthKitWorkouts(workouts)
                }
            } catch {
                await MainActor.run {
                    showingHealthKitAlert = true
                }
            }
        }
    }
    
    /// Merge HealthKit workouts into DayLog records
    private func mergeHealthKitWorkouts(_ workouts: [WorkoutSession]) {
        let calendar = Calendar.current
        
        for workout in workouts {
            let startOfDay = calendar.startOfDay(for: workout.timestamp)
            
            // Find or create DayLog for this date
            if let dayLog = allLogs.first(where: { calendar.isDate($0.date, inSameDayAs: startOfDay) }) {
                // Check if workout already exists (by ID)
                let exists = dayLog.workouts.contains { $0.id == workout.id }
                if !exists {
                    dayLog.workouts.append(workout)
                }
            } else {
                // Create new DayLog for this date
                let newLog = DayLog(date: startOfDay, workouts: [workout])
                modelContext.insert(newLog)
            }
        }
        
        try? modelContext.save()
    }
}

// MARK: - Empty States

struct EmptyGoalChartState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("No Goals Set")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Add goals in Horizon to see progress charts")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Workout Summary View (Read-Only)

struct WorkoutSummaryView: View {
    let stats: (count: Int, calories: Double, duration: TimeInterval)
    let isSyncing: Bool
    let onSyncTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with sync button
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                Text("Workout Summary")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button(action: onSyncTap) {
                    HStack(spacing: 4) {
                        if isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text("Sync")
                            .font(.caption)
                    }
                    .foregroundStyle(.pink)
                }
                .disabled(isSyncing)
            }
            
            // Stats
            if stats.count == 0 {
                Text("No workouts in this period")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                HStack(spacing: 16) {
                    StatPill(
                        icon: "flame.fill",
                        value: "\(Int(stats.calories))",
                        label: "cal",
                        color: .orange
                    )
                    
                    StatPill(
                        icon: "clock.fill",
                        value: formatDuration(stats.duration),
                        label: "",
                        color: .cyan
                    )
                    
                    StatPill(
                        icon: "checkmark.circle.fill",
                        value: "\(stats.count)",
                        label: stats.count == 1 ? "workout" : "workouts",
                        color: .green
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Stat Pill Component

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

// MARK: - Recent Workouts Section

struct RecentWorkoutsSection: View {
    let workouts: [WorkoutSession]
    let onWorkoutTap: (WorkoutSession) -> Void
    let onWorkoutDelete: (WorkoutSession) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                
                Text("Recent Workouts")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("\(workouts.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan, in: Capsule())
            }
            
            ForEach(workouts) { workout in
                SwipeableWorkoutCard(
                    workout: workout,
                    onTap: { onWorkoutTap(workout) },
                    onDelete: { onWorkoutDelete(workout) }
                )
            }
        }
    }
}

// MARK: - Swipeable Workout Card

struct SwipeableWorkoutCard: View {
    let workout: WorkoutSession
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    private let deleteThreshold: CGFloat = -80
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background
            HStack {
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 70)
                        .frame(maxHeight: .infinity)
                }
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .opacity(offset < -20 ? 1 : 0)
            
            RecentWorkoutCard(workout: workout)
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            if gesture.translation.width < 0 {
                                offset = gesture.translation.width
                            }
                        }
                        .onEnded { gesture in
                            withAnimation(.spring(response: 0.3)) {
                                if offset < deleteThreshold {
                                    onDelete()
                                }
                                offset = 0
                            }
                        }
                )
                .onTapGesture(perform: onTap)
        }
    }
}

// MARK: - Recent Workout Card

struct RecentWorkoutCard: View {
    let workout: WorkoutSession
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter.string(from: workout.startTime)
    }
    
    private var formattedDuration: String {
        let mins = Int(workout.duration) / 60
        return "\(mins)m"
    }
    
    private var exerciseCount: Int {
        workout.exercises.count
    }
    
    private var completedSetsCount: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }
    
    /// Whether this workout was synced from Apple Health
    private var isFromHealthKit: Bool {
        workout.source == "HealthKit"
    }
    
    /// Source indicator color
    private var sourceColor: Color {
        isFromHealthKit ? .pink : .cyan
    }
    
    /// Source indicator icon
    private var sourceIcon: String {
        isFromHealthKit ? "heart.fill" : "figure.run"
    }
    
    /// Source label text
    private var sourceLabel: String {
        isFromHealthKit ? "Health" : "LifeFlow"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with source indicator overlay
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
                
                // Small source indicator badge
                ZStack {
                    Circle()
                        .fill(sourceColor)
                        .frame(width: 16, height: 16)
                    
                    Image(systemName: sourceIcon)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(x: 4, y: 4)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(workout.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    // Source label pill
                    Text(sourceLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(sourceColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(sourceColor.opacity(0.15), in: Capsule())
                }
                
                HStack(spacing: 8) {
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text("\(exerciseCount) exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text("\(completedSetsCount) sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Duration and chevron
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedDuration)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.cyan)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            // Subtle left edge accent for HealthKit workouts
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isFromHealthKit 
                        ? LinearGradient(colors: [.pink.opacity(0.4), .pink.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.clear, .clear], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Workout Detail Modal

struct WorkoutDetailModal: View {
    let workout: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: workout.startTime)
    }
    
    private var formattedDuration: String {
        let hours = Int(workout.duration) / 3600
        let mins = (Int(workout.duration) % 3600) / 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats header
                    HStack(spacing: 16) {
                        StatBubble(icon: "clock.fill", value: formattedDuration, label: "Duration", color: .cyan)
                        StatBubble(icon: "dumbbell.fill", value: "\(workout.exercises.count)", label: "Exercises", color: .orange)
                        StatBubble(icon: "flame.fill", value: "\(Int(workout.calories))", label: "Calories", color: .red)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Exercises list
                    VStack(alignment: .leading, spacing: 12) {
                        Text("EXERCISES")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                            .padding(.horizontal)
                        
                        ForEach(workout.sortedExercises) { exercise in
                            ExerciseDetailCard(exercise: exercise)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(workout.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Stat Bubble

private struct StatBubble: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Exercise Detail Card

private struct ExerciseDetailCard: View {
    let exercise: WorkoutExercise
    
    private var completedSets: [ExerciseSet] {
        exercise.sortedSets.filter(\.isCompleted)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: exercise.type.icon)
                    .font(.callout)
                    .foregroundStyle(colorForType(exercise.type))
                    .frame(width: 28, height: 28)
                    .background(colorForType(exercise.type).opacity(0.15), in: Circle())
                
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                
                Spacer()
                
                Text("\(completedSets.count)/\(exercise.sets.count) sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Sets list
            if !completedSets.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(completedSets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("Set \(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            // Weight and reps
                            if let weight = set.weight, let reps = set.reps {
                                Text("\(Int(weight)) lbs × \(reps) reps")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)
                            } else if let reps = set.reps {
                                Text("\(reps) reps")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)
                            } else if let duration = set.duration {
                                Text("\(Int(duration / 60))m")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
    
    private func colorForType(_ type: ExerciseType) -> Color {
        switch type {
        case .weight: return .orange
        case .cardio: return .green
        case .calisthenics: return .blue
        case .flexibility: return .purple
        case .machine: return .red
        case .functional: return .cyan
        }
    }
}

#Preview {
    ZStack {
        LiquidBackgroundView()
        TempleView()
    }
    .modelContainer(for: [DayLog.self, WorkoutSession.self, Goal.self], inMemory: true)
    .preferredColorScheme(.dark)
}

