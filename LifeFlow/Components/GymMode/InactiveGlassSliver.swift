//
//  InactiveGlassSliver.swift
//  LifeFlow
//
//  Compact glass row for inactive/completed exercises in the Liquid Dashboard.
//

import SwiftUI

struct InactiveGlassSliver: View {
    let exercise: WorkoutExercise
    let completedSets: Int
    let totalSets: Int
    
    var body: some View {
        HStack {
            Text(exercise.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer()
            
            if completedSets >= totalSets {
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
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .contentShape(Rectangle()) // CRITICAL: Makes the empty glass space tappable
    }
}
