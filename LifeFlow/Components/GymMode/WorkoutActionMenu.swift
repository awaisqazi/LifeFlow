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
    
    @State private var isAppearing = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with animated icon
            VStack(spacing: 12) {
                // Animated hand icon with glow
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(.orange.opacity(0.3))
                        .frame(width: 70, height: 70)
                        .blur(radius: 20)
                    
                    // Icon background
                    Circle()
                        .fill(.orange.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.orange.gradient)
                        .symbolEffect(.pulse, options: .repeating)
                }
                .scaleEffect(isAppearing ? 1.0 : 0.5)
                .opacity(isAppearing ? 1.0 : 0)
                
                Text("Workout Paused")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text("Your progress is safe. What would you like to do?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.top, 8)
            
            // Action buttons
            VStack(spacing: 10) {
                GlassActionButton(
                    title: "Pause & Continue Later",
                    subtitle: "Keep session active in background",
                    icon: "pause.fill",
                    color: .orange,
                    action: onPause
                )
                
                GlassActionButton(
                    title: "End & Complete Workout",
                    subtitle: "Save and see summary",
                    icon: "checkmark.seal.fill",
                    color: .green,
                    action: onEnd
                )
                
                GlassActionButton(
                    title: "Discard Workout",
                    subtitle: "Delete this entire session",
                    icon: "trash.fill",
                    color: .red,
                    isDestructive: true,
                    action: onDiscard
                )
            }
            
            // Return button
            Button(action: onCancel) {
                Text("Return to Workout")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            }
                    }
            }
            .buttonStyle(GlassButtonStyle())
            .padding(.top, 4)
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 36)
                .fill(.ultraThinMaterial)
        }
        .shadow(color: .black.opacity(0.4), radius: 40, x: 0, y: 20)
        .shadow(color: .orange.opacity(0.1), radius: 30, x: 0, y: 0) // Subtle warm glow
        .padding(16)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isAppearing = true
            }
        }
    }
}

// MARK: - Glass Action Button

private struct GlassActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon with colored ring
                ZStack {
                    // Progress ring style background
                    Circle()
                        .stroke(color.opacity(0.4), lineWidth: 2)
                        .frame(width: 46, height: 46)
                    
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(GlassButtonStyle())
    }
}

// MARK: - Glass Button Style

private struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        AnimatedMeshGradientView(theme: .flow)
            .ignoresSafeArea()
        
        WorkoutActionMenu(
            onPause: {},
            onEnd: {},
            onDiscard: {},
            onCancel: {}
        )
    }
    .preferredColorScheme(.dark)
}
