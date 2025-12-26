//
//  HydrationView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData

/// The showpiece hydration tracker with Liquid Glass vessel and motion-reactive water.
/// Features:
/// - Glass vessel using native `.glassEffect()` with custom shape
/// - Animated water that responds to device tilt via CoreMotion
/// - SwiftData integration for persistence
/// - Fluid "splash" animation when adding water
struct HydrationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyMetrics.date, order: .reverse) private var allMetrics: [DailyMetrics]
    
    @State private var waterManager = WaterManager()
    @State private var animatedWaterLevel: Double = 0
    
    /// Daily water goal in ounces
    private let dailyGoal: Double = 64
    
    /// Amount to add per tap
    private let addAmount: Double = 8
    
    /// Get today's metrics by filtering in Swift
    private var todayMetrics: DailyMetrics? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allMetrics.first { $0.date >= startOfDay }
    }
    
    /// Current water intake from SwiftData
    private var currentIntake: Double {
        todayMetrics?.waterIntake ?? 0
    }
    
    /// Fill level as percentage (0.0 to 1.0)
    private var fillLevel: Double {
        min(currentIntake / dailyGoal, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Title
            VStack(spacing: 4) {
                Text("Hydration")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("\(Int(currentIntake)) of \(Int(dailyGoal)) oz")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Glass Vessel with Water
            ZStack {
                // Background glow
                VesselShape()
                    .fill(
                        RadialGradient(
                            colors: [
                                .cyan.opacity(0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 200
                        )
                    )
                    .blur(radius: 30)
                    .scaleEffect(1.2)
                
                // Animated Water
                AnimatedWaterView(
                    fillLevel: animatedWaterLevel,
                    tiltAngle: waterManager.tiltAngle
                )
                .clipShape(VesselShape())
                
                // Glass Vessel overlay with Liquid Glass effect
                VesselShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.4),
                                .white.opacity(0.1),
                                .white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .glassEffect(.regular.tint(.cyan.opacity(0.1)), in: VesselShape())
                
                // Floating intake display
                VStack(spacing: 4) {
                    Text("\(Int(currentIntake))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    
                    Text("ounces")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .textCase(.uppercase)
                        .tracking(1.5)
                }
                .offset(y: -20)
            }
            .frame(width: 200, height: 280)
            
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(Double(index) < (currentIntake / 8) ? .cyan : .white.opacity(0.2))
                        .frame(width: 10, height: 10)
                }
            }
            
            // Add Water Button
            Button {
                addWater()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                    
                    Text("Add 8oz")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            .buttonStyle(.glass)
            .disabled(currentIntake >= dailyGoal)
            .opacity(currentIntake >= dailyGoal ? 0.5 : 1.0)
        }
        .onAppear {
            // Animate water level on appear
            withAnimation(.easeOut(duration: 1.0)) {
                animatedWaterLevel = fillLevel
            }
            
            // Start motion tracking
            waterManager.startMotionUpdates()
        }
        .onDisappear {
            waterManager.stopMotionUpdates()
        }
        .onChange(of: fillLevel) { _, newLevel in
            // Animate water level changes
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedWaterLevel = newLevel
            }
        }
    }
    
    // MARK: - Actions
    
    private func addWater() {
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Trigger splash animation
        waterManager.triggerSplash()
        
        // Update or create today's metrics
        if let today = todayMetrics {
            today.waterIntake += addAmount
        } else {
            let newMetrics = DailyMetrics(
                date: Date(),
                waterIntake: addAmount,
                gymAttendance: false
            )
            modelContext.insert(newMetrics)
        }
        
        // Save context
        try? modelContext.save()
    }
}

#Preview {
    ZStack {
        LiquidBackgroundView()
        
        HydrationView()
    }
    .modelContainer(for: DailyMetrics.self, inMemory: true)
    .preferredColorScheme(.dark)
}
