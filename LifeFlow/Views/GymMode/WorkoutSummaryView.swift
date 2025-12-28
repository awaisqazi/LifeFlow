//
//  WorkoutSummaryView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI
import HealthKit

/// Post-workout summary with stats and HealthKit save option.
struct GymWorkoutSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    
    let session: WorkoutSession
    let onDone: () -> Void
    
    @State private var saveToHealthKit: Bool = true
    @State private var isSaving: Bool = false
    @State private var healthKitManager = HealthKitManager()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Celebration header
                    celebrationHeader
                    
                    // Stats grid
                    statsGrid
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Exercise breakdown
                    exerciseBreakdown
                    
                    // HealthKit toggle
                    healthKitSection
                    
                    Spacer(minLength: 80)
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Workout Complete")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                doneButton
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Celebration Header
    
    private var celebrationHeader: some View {
        VStack(spacing: 16) {
            // Trophy icon with animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
            }
            
            Text("Great Work! 💪")
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)
            
            Text(session.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Duration",
                value: formattedDuration,
                icon: "clock.fill",
                color: .blue
            )
            
            StatCard(
                title: "Exercises",
                value: "\(session.exercises.count)",
                icon: "dumbbell.fill",
                color: .orange
            )
            
            StatCard(
                title: "Sets",
                value: "\(totalSets)",
                icon: "repeat",
                color: .purple
            )
            
            StatCard(
                title: "Est. Calories",
                value: "\(estimatedCalories)",
                icon: "flame.fill",
                color: .red
            )
        }
    }
    
    // MARK: - Exercise Breakdown
    
    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXERCISE BREAKDOWN")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            
            VStack(spacing: 8) {
                ForEach(session.exercises, id: \.id) { exercise in
                    ExerciseSummaryRow(exercise: exercise)
                }
            }
        }
    }
    
    // MARK: - HealthKit Section
    
    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APPLE HEALTH")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            
            HStack {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save to Health")
                        .font(.subheadline.weight(.medium))
                    Text("Adds workout to Apple Health")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $saveToHealthKit)
                    .labelsHidden()
            }
            .padding(16)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
    }
    
    // MARK: - Done Button
    
    private var doneButton: some View {
        Button {
            completeWorkout()
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                    Text("Done")
                        .font(.headline.weight(.bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.green.gradient, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Computed Properties
    
    private var formattedDuration: String {
        let hours = Int(session.duration) / 3600
        let minutes = (Int(session.duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var totalSets: Int {
        session.exercises.reduce(0) { $0 + $1.sets.count }
    }
    
    private var estimatedCalories: Int {
        // Rough estimate: ~5 calories per set for strength training
        let setsCalories = totalSets * 5
        // Plus ~3 calories per minute of workout
        let durationCalories = Int(session.duration / 60) * 3
        return setsCalories + durationCalories
    }
    
    // MARK: - Actions
    
    private func completeWorkout() {
        isSaving = true
        
        Task {
            // Update session with estimated calories
            session.calories = Double(estimatedCalories)
            
            // Save to HealthKit if enabled
            if saveToHealthKit {
                // Note: Full HealthKit save would use the live workout session
                // For now, we just mark as complete
            }
            
            await MainActor.run {
                isSaving = false
                onDone()
                dismiss()
            }
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Exercise Summary Row

private struct ExerciseSummaryRow: View {
    let exercise: WorkoutExercise
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: exercise.type.icon)
                .font(.callout)
                .foregroundStyle(colorForType(exercise.type))
                .frame(width: 32, height: 32)
                .background(colorForType(exercise.type).opacity(0.15), in: Circle())
            
            // Name
            Text(exercise.name)
                .font(.subheadline.weight(.medium))
            
            Spacer()
            
            // Best set (if weight training)
            if let bestSet = bestSet {
                Text(bestSet)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15), in: Capsule())
            }
            
            // Set count
            Text("\(exercise.sets.filter(\.isCompleted).count)/\(exercise.sets.count) sets")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var bestSet: String? {
        let completedSets = exercise.sets.filter(\.isCompleted)
        
        // Find set with highest weight
        if let best = completedSets.max(by: { ($0.weight ?? 0) < ($1.weight ?? 0) }),
           let weight = best.weight, let reps = best.reps {
            return "\(Int(weight))×\(reps)"
        }
        
        return nil
    }
    
    private func colorForType(_ type: ExerciseType) -> Color {
        switch type {
        case .weight: return .orange
        case .cardio: return .green
        case .calisthenics: return .blue
        case .flexibility: return .purple
        }
    }
}

#Preview {
    let session = WorkoutSession(title: "Push Day", type: "Strength Training")
    session.duration = 45 * 60
    
    return GymWorkoutSummaryView(session: session, onDone: {})
}
