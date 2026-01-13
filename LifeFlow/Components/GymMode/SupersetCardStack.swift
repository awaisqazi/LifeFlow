//
//  SupersetCardStack.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI

/// Visual grouping for superset exercises.
/// Shows exercises in a bordered container with circuit indicator.
struct SupersetCardStack: View {
    let exercises: [WorkoutExercise]
    let currentExerciseID: UUID?
    let currentSetIndex: Int
    let onExerciseTap: (WorkoutExercise) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Superset header
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.purple)
                
                Text("SUPERSET")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.purple)
                    .tracking(1.5)
                
                Spacer()
                
                Text("\(exercises.count) exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.purple.opacity(0.1))
            
            // Exercise cards
            VStack(spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    SupersetExerciseRow(
                        exercise: exercise,
                        setIndex: currentSetIndex,
                        isActive: exercise.id == currentExerciseID,
                        isLast: index == exercises.count - 1,
                        onTap: { onExerciseTap(exercise) }
                    )
                    
                    if index < exercises.count - 1 {
                        // Connection line between exercises
                        HStack {
                            Rectangle()
                                .fill(Color.purple.opacity(0.3))
                                .frame(width: 2, height: 20)
                                .padding(.leading, 32)
                            Spacer()
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .stroke(Color.purple.opacity(0.3), lineWidth: 2)
        }
    }
}

// MARK: - Superset Exercise Row

private struct SupersetExerciseRow: View {
    let exercise: WorkoutExercise
    let setIndex: Int
    let isActive: Bool
    let isLast: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(isActive ? Color.purple : Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    if isActive {
                        Circle()
                            .stroke(Color.purple, lineWidth: 2)
                            .frame(width: 48, height: 48)
                            .opacity(0.5)
                    }
                    
                    Image(systemName: exercise.type.icon)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(isActive ? .white : .secondary)
                }
                
                // Exercise info
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isActive ? .primary : .secondary)
                    
                    // Set progress
                    let completedSets = exercise.sets.filter(\.isCompleted).count
                    let totalSets = exercise.sets.count
                    
                    Text("Set \(setIndex + 1) of \(totalSets)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Completion indicator
                if isActive {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.purple)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isActive ? Color.purple.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Single Exercise Card (for non-supersets)

struct SingleExerciseCard: View {
    let exercise: WorkoutExercise
    let currentSetIndex: Int
    let isActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(colorForType(exercise.type).opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: exercise.type.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(colorForType(exercise.type))
                }
                
                // Exercise info
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    // Set progress
                    let completedSets = exercise.sets.filter(\.isCompleted).count
                    let totalSets = exercise.sets.count
                    
                    HStack(spacing: 4) {
                        ForEach(0..<totalSets, id: \.self) { index in
                            Circle()
                                .fill(index < completedSets ? colorForType(exercise.type) : Color.white.opacity(0.2))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                
                Spacer()
                
                // Active indicator
                if isActive {
                    Text("ACTIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(colorForType(exercise.type), in: Capsule())
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .stroke(isActive ? colorForType(exercise.type).opacity(0.5) : Color.white.opacity(0.1), lineWidth: isActive ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
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
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 20) {
            // Mock superset
            let exercise1 = WorkoutExercise(name: "Bench Press", type: .weight)
            let exercise2 = WorkoutExercise(name: "Pull-ups", type: .calisthenics)
            
            SupersetCardStack(
                exercises: [exercise1, exercise2],
                currentExerciseID: exercise1.id,
                currentSetIndex: 0,
                onExerciseTap: { _ in }
            )
            
            SingleExerciseCard(
                exercise: exercise1,
                currentSetIndex: 1,
                isActive: true,
                onTap: {}
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
