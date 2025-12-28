//
//  RestTimerView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI

/// Floating rest timer overlay with circular progress.
/// Auto-starts between sets and provides visual + haptic feedback.
struct RestTimerView: View {
    @Binding var isActive: Bool
    @Binding var timeRemaining: TimeInterval
    let totalTime: TimeInterval
    let onSkip: () -> Void
    let onComplete: () -> Void
    var onAddTime: ((TimeInterval) -> Void)? = nil
    
    @State private var pulseAnimation: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Timer ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timeRemaining)
                
                // Time display
                VStack(spacing: 4) {
                    Text(formattedTime)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: timeRemaining)
                    
                    Text("REST")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(2)
                }
            }
            .frame(width: 180, height: 180)
            .scaleEffect(pulseAnimation ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulseAnimation)
            .onAppear { pulseAnimation = true }
            
            // Quick presets
            HStack(spacing: 12) {
                PresetButton(seconds: 30, action: { addTime(30) })
                PresetButton(seconds: 60, action: { addTime(60) })
                PresetButton(seconds: 90, action: { addTime(90) })
                PresetButton(seconds: 120, action: { addTime(120) })
            }
            
            // Skip button
            Button {
                onSkip()
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            } label: {
                Text("Skip Rest")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.3), radius: 20)
        .onChange(of: timeRemaining) { oldValue, newValue in
            if newValue <= 0 && oldValue > 0 {
                onComplete()
            }
        }
    }
    
    private var progress: Double {
        guard totalTime > 0 else { return 0 }
        return timeRemaining / totalTime
    }
    
    private var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func addTime(_ seconds: TimeInterval) {
        if let onAddTime = onAddTime {
            onAddTime(seconds)
        } else {
            timeRemaining += seconds
        }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}

// MARK: - Preset Button

private struct PresetButton: View {
    let seconds: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(seconds)s")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 44)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Rest Timer (for inline display)

struct CompactRestTimer: View {
    let timeRemaining: TimeInterval
    let onSkip: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Timer display
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.title3)
                    .foregroundStyle(.orange)
                
                Text(formattedTime)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }
            
            Spacer()
            
            // Skip button
            Button {
                onSkip()
            } label: {
                Text("Skip")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.2), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        }
    }
    
    private var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 40) {
            RestTimerView(
                isActive: .constant(true),
                timeRemaining: .constant(45),
                totalTime: 60,
                onSkip: {},
                onComplete: {}
            )
            
            CompactRestTimer(timeRemaining: 45, onSkip: {})
                .padding(.horizontal)
        }
    }
    .preferredColorScheme(.dark)
}
