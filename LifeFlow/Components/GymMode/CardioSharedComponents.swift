//
//  CardioSharedComponents.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import SwiftUI

// MARK: - Setting Input (Setup Phase)

/// Stepper-style input for cardio setup screens
struct SettingInput: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let color: Color
    let step: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        VStack(spacing: 12) {
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            
            HStack(spacing: 16) {
                Button {
                    if value > range.lowerBound {
                        value = max(range.lowerBound, value - step)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(color)
                        .frame(width: 44, height: 44)
                        .background(color.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", value))
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 60)
                
                Button {
                    if value < range.upperBound {
                        value = min(range.upperBound, value + step)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(color.gradient, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Live Setting Control (Active Phase)

/// Live controls for adjusting speed/incline during workout
struct LiveSettingControl: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let color: Color
    let step: Double
    let range: ClosedRange<Double>
    var onChange: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 20) {
                Button {
                    if value > range.lowerBound {
                        value = max(range.lowerBound, value - step)
                        onChange?()
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(color)
                        .frame(width: 50, height: 50)
                        .background(color.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                
                VStack(spacing: 0) {
                    Text(String(format: "%.1f", value))
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 80)
                
                Button {
                    if value < range.upperBound {
                        value = min(range.upperBound, value + step)
                        onChange?()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(color.gradient, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Celebration Particles

/// Confetti particle animation for workout completion
struct CelebrationParticles: View {
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        let color: Color
        let size: CGFloat
        var velocity: CGPoint
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        let colors: [Color] = [.green, .cyan, .yellow, .orange, .pink, .purple]
        
        for _ in 0..<50 {
            let particle = Particle(
                x: size.width / 2,
                y: size.height / 2,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...14),
                velocity: CGPoint(
                    x: CGFloat.random(in: -8 ... 8),
                    y: CGFloat.random(in: -15 ... -5)
                )
            )
            particles.append(particle)
        }
        
        // Animate particles
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            for i in particles.indices {
                particles[i].x += particles[i].velocity.x
                particles[i].y += particles[i].velocity.y
                particles[i].velocity.y += 0.3 // gravity
            }
            
            // Remove off-screen particles
            particles.removeAll { $0.y > size.height + 50 }
            
            if particles.isEmpty {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Metric Column

/// Vertically stacked metric display for the floating workout platter.
struct MetricColumn: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title, design: .rounded, weight: .black).monospacedDigit())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Primary Glass Button Style

/// 72pt circular gradient button with spring press animation.
struct PrimaryGlassButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2.weight(.bold))
            .frame(width: 72, height: 72)
            .background(color.gradient, in: Circle())
            .foregroundStyle(.white)
            .shadow(color: color.opacity(0.4), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Milestone Toast

/// Achievement toast for distance milestones (25%, 50%, 75%, 100%).
struct MilestoneToast: View {
    let milestone: String
    let icon: String
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(.yellow)
            Text(milestone)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .stroke(
                            LinearGradient(colors: [.yellow.opacity(0.6), .orange.opacity(0.3)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                }
        }
        .shadow(color: .yellow.opacity(0.3), radius: 20, y: 8)
        .scaleEffect(isVisible ? 1.0 : 0.5)
        .opacity(isVisible ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isVisible = true
            }
        }
    }
}

