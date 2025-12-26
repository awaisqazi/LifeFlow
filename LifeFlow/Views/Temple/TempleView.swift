//
//  TempleView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData

/// The Temple tab - your body is a temple.
/// Features the showpiece HydrationView and gym tracking.
struct TempleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyMetrics.date, order: .reverse) private var allMetrics: [DailyMetrics]
    
    @State private var gymCheckedIn: Bool = false
    
    /// Get today's metrics by filtering in Swift
    private var todayMetrics: DailyMetrics? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allMetrics.first { $0.date >= startOfDay }
    }
    
    /// Current gym status from SwiftData
    private var isGymDone: Bool {
        todayMetrics?.gymAttendance ?? false
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                HeaderView(
                    title: "Temple",
                    subtitle: "Honor Your Body"
                )
                
                // Main Hydration Vessel - the showpiece
                GlassEffectContainer(spacing: 20) {
                    HydrationView()
                }
                
                // Gym Tracking Card
                GlassEffectContainer(spacing: 16) {
                    GymTrackingCard(isCheckedIn: $gymCheckedIn)
                        .onChange(of: gymCheckedIn) { _, newValue in
                            updateGymStatus(newValue)
                        }
                        .onAppear {
                            gymCheckedIn = isGymDone
                        }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100) // Space for tab bar
            }
            .padding(.top, 60)
        }
    }
    
    // MARK: - Actions
    
    private func updateGymStatus(_ attended: Bool) {
        if let today = todayMetrics {
            today.gymAttendance = attended
        } else {
            let newMetrics = DailyMetrics(
                date: Date(),
                waterIntake: 0,
                gymAttendance: attended
            )
            modelContext.insert(newMetrics)
        }
        
        try? modelContext.save()
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
                }
                .buttonStyle(.glass)
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
