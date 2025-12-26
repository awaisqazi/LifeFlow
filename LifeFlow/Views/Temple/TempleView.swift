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
    @Query(sort: \DayLog.date, order: .reverse) private var allLogs: [DayLog]
    
    /// Get today's metrics by filtering in Swift
    private var todayLog: DayLog? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allLogs.first { $0.date >= startOfDay }
    }
    
    /// Today's workouts
    private var todaysWorkouts: [WorkoutSession] {
        todayLog?.workouts ?? []
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
    
    /// Get or create today's DayLog record
                // Workout Tracking Section
                GlassEffectContainer(spacing: 16) {
                    WorkoutLogView(
                        workouts: todaysWorkouts
                    )
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100) // Space for tab bar
            }
            .padding(.top, 60)
        }
    }
}

// MARK: - Workout Log View

/// Displays today's workouts with sync and add controls
struct WorkoutLogView: View {
    let workouts: [WorkoutSession]
    
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
                        WorkoutCard(workout: workout)
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
    }
}

#Preview {
    ZStack {
        LiquidBackgroundView()
        TempleView()
    }
    .modelContainer(for: [DayLog.self, WorkoutSession.self], inMemory: true)
    .preferredColorScheme(.dark)
}
