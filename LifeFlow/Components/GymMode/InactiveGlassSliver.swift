//
//  InactiveGlassSliver.swift
//  LifeFlow
//
//  Compact glass row for inactive/completed exercises in the Liquid Dashboard.
//

import SwiftUI

/// A compact, touchable glass row representing a future or completed exercise.
/// Used in the morphing dashboard alongside the active `ExerciseInputCard`.
struct InactiveGlassSliver: View {
    let exercise: WorkoutExercise
    let completedSets: Int
    let totalSets: Int
    
    private var isComplete: Bool {
        completedSets >= totalSets
    }
    
    var body: some View {
        HStack {
            Text(exercise.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer()
            
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Text("\(completedSets)/\(totalSets)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(height: 60)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview("Incomplete") {
    ZStack {
        AnimatedMeshGradientView(theme: .flow)
        VStack(spacing: 16) {
            InactiveGlassSliver(
                exercise: WorkoutExercise(name: "Bench Press", type: .weight, orderIndex: 0),
                completedSets: 1,
                totalSets: 3
            )
            InactiveGlassSliver(
                exercise: WorkoutExercise(name: "Squats", type: .weight, orderIndex: 1),
                completedSets: 3,
                totalSets: 3
            )
        }
        .padding()
    }
}
