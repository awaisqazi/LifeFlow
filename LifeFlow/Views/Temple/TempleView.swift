//
//  TempleView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData

/// The Temple tab - your body is a temple.
/// Tracks gym attendance and water intake for physical wellness.
struct TempleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyMetrics.date, order: .reverse) private var metrics: [DailyMetrics]
    
    @State private var waterGlasses: Int = 0
    @State private var gymCheckedIn: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HeaderView(
                    title: "Temple",
                    subtitle: "Honor Your Body"
                )
                
                // Glass effect container for blending cards
                GlassEffectContainer(spacing: 16) {
                    VStack(spacing: 16) {
                        // Water Tracking Card
                        WaterTrackingCard(glasses: $waterGlasses)
                        
                        // Gym Tracking Card
                        GymTrackingCard(isCheckedIn: $gymCheckedIn)
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100) // Space for tab bar
            }
            .padding(.top, 60)
        }
    }
}

/// Interactive water tracking card with Liquid Glass
struct WaterTrackingCard: View {
    @Binding var glasses: Int
    let maxGlasses = 8
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "drop.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                
                Text("Hydration")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("\(glasses * 8) oz")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            
            Text("Track your daily water intake")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Interactive water glasses
            HStack(spacing: 8) {
                ForEach(0..<maxGlasses, id: \.self) { index in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            if glasses == index + 1 {
                                glasses = index // Tap same to deselect
                            } else {
                                glasses = index + 1
                            }
                        }
                        let impact = UIImpactFeedbackGenerator(style: .soft)
                        impact.impactOccurred()
                    } label: {
                        Circle()
                            .fill(index < glasses ? .cyan : .primary.opacity(0.1))
                            .frame(width: 32, height: 32)
                            .overlay {
                                if index < glasses {
                                    Image(systemName: "drop.fill")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(index < glasses ? 1.1 : 1.0)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }
}

/// Gym check-in card with Liquid Glass toggle
struct GymTrackingCard: View {
    @Binding var isCheckedIn: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                Text("Gym")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Glass-style toggle button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isCheckedIn.toggle()
                    }
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isCheckedIn ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                        
                        Text(isCheckedIn ? "Done" : "Check In")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(isCheckedIn ? .green : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect(in: .capsule)
                }
                .buttonStyle(.plain)
            }
            
            Text(isCheckedIn ? "Great work today! 💪" : "Log your workout session")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }
}

#Preview {
    ZStack {
        LiquidBackgroundView()
        TempleView()
    }
    .modelContainer(for: DailyMetrics.self, inMemory: true)
    .preferredColorScheme(.dark)
}
