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
