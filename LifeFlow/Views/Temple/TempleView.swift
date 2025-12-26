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
    
    @State private var selectedScope: TimeScope = .week
    @State private var healthKitWorkouts: [WorkoutSession] = []
    @State private var showingHealthKitAlert = false
    
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

#Preview {
    ZStack {
        LiquidBackgroundView()
        TempleView()
    }
    .modelContainer(for: [DayLog.self, WorkoutSession.self, Goal.self], inMemory: true)
    .preferredColorScheme(.dark)
}
