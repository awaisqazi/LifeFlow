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
    var isEditMode: Bool = false
    let namespace: Namespace.ID
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    // Morph the title for smooth transition
                    .matchedGeometryEffect(id: "\(exercise.id.uuidString)_title", in: namespace)
                
                Spacer()
                
                if isEditMode {
                    // Drag Handle for Edit Mode
                    Image(systemName: "line.3.horizontal")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                } else {
                    // Progress Display
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
            }
            .padding()
            .frame(height: 60)
            .contentShape([.dragPreview, .interaction], RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(GlassSliverButtonStyle(namespace: namespace, id: exercise.id.uuidString))
    }
}

// Custom Button Style to handle the Glow/Press state and Glass Morph
struct GlassSliverButtonStyle: ButtonStyle {
    let namespace: Namespace.ID
    let id: String
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                // The Glass Background that morphs
                // using glassEffectID allows it to match the active card
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear) // Placeholder, the effect handles the visual
                    .glassEffectID(id, in: namespace)
                    
                // Glow overlay on press
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                }
            }
            // Scale effect for tactile feel
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
