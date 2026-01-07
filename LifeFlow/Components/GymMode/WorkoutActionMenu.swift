//
//  WorkoutActionMenu.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/28/25.
//

import SwiftUI

struct WorkoutActionMenu: View {
    let onPause: () -> Void
    let onEnd: () -> Void
    let onDiscard: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange.gradient)
                    .padding(.bottom, 4)
                
                Text("Workout Paused")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text("Your progress is safe. What would you like to do?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            VStack(spacing: 10) {
                // Main Actions
                ActionButton(
                    title: "Pause & Continue Later",
                    subtitle: "Keep session active in background",
                    icon: "pause.fill",
                    color: .orange,
                    action: onPause
                )
                
                ActionButton(
                    title: "End & Complete Workout",
                    subtitle: "Save and see summary",
                    icon: "checkmark.seal.fill",
                    color: .green,
                    action: onEnd
                )
                
                ActionButton(
                    title: "Discard Workout",
                    subtitle: "Delete this entire session",
                    icon: "trash.fill",
                    color: .red,
                    action: onDiscard
                )
            }
            
            // Cancel button
            Button(action: onCancel) {
                Text("Return to Workout")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background {
                        if #available(iOS 18.0, *) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.clear)
                                .glassEffect()
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 4)
        }
        .padding(24)
        .background {
            if #available(iOS 18.0, *) {
                RoundedRectangle(cornerRadius: 32)
                    .fill(.clear)
                    .glassEffect()
            } else {
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 20)
        .padding(16)
    }
}

private struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon backing
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.interactiveSpring(), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        WorkoutActionMenu(
            onPause: {},
            onEnd: {},
            onDiscard: {},
            onCancel: {}
        )
    }
    .preferredColorScheme(.dark)
}
