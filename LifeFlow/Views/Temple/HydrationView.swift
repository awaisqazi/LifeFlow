//
//  HydrationView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData

/// The showpiece hydration tracker with premium Liquid Glass vessel.
/// Features elegant curves, animated water with shimmer, and motion physics.
struct HydrationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DayLog.date, order: .reverse) private var allLogs: [DayLog]
    
    @State private var waterManager = WaterManager()
    @State private var animatedWaterLevel: Double = 0
    
    /// Hydration settings from user preferences
    private var settings: HydrationSettings {
        HydrationSettings.load()
    }
    
    /// Daily water goal in ounces (from settings)
    private var dailyGoal: Double {
        settings.dailyOuncesGoal
    }
    
    /// Number of cups for progress indicator
    private var cupsGoal: Int {
        settings.dailyCupsGoal
    }

    
    /// Get today's metrics by filtering in Swift
    private var todayLog: DayLog? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allLogs.first { $0.date >= startOfDay }
    }
    
    /// Current water intake from SwiftData
    private var currentIntake: Double {
        todayLog?.waterIntake ?? 0
    }
    
    /// Fill level as percentage (0.0 to 1.0)
    private var fillLevel: Double {
        min(currentIntake / dailyGoal, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Glass Vessel with Water
            ZStack {
                // Ambient glow behind vessel
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                .cyan.opacity(0.25),
                                .blue.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 150
                        )
                    )
                    .frame(width: 250, height: 180)
                    .offset(y: 60)
                    .blur(radius: 25)
                
                // Main vessel container
                ZStack {
                    // Animated Water
                    AnimatedWaterView(
                        fillLevel: animatedWaterLevel,
                        tiltAngle: waterManager.tiltAngle
                    )
                    .clipShape(VesselShape())
                    
                    // Glass vessel with Liquid Glass effect
                    VesselShape()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.5),
                                    .white.opacity(0.2),
                                    .white.opacity(0.1),
                                    .white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                    
                    // Inner glass highlight (left side reflection)
                    VesselHighlightShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.25),
                                    .white.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Glass effect overlay
                    VesselShape()
                        .fill(.clear)
                        .glassEffect(.regular.tint(.cyan.opacity(0.08)), in: VesselShape())
                    
                    // Floating intake display
                    VStack(spacing: 2) {
                        Text("\(Int(currentIntake))")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                        
                        Text("oz")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .textCase(.uppercase)
                            .tracking(2)
                    }
                    .offset(y: -20)
                }
                .frame(width: 180, height: 280)
            }
            
            // Progress indicator with glow (one drop per cup)
            HStack(spacing: 8) {
                ForEach(0..<cupsGoal, id: \.self) { index in
                    let isFilled = Double(index) < (currentIntake / 8)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(
                            isFilled
                                ? LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .top,
                                    endPoint: .bottom
                                  )
                                : LinearGradient(
                                    colors: [.white.opacity(0.2), .white.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                  )
                        )
                        .shadow(color: isFilled ? .cyan.opacity(0.6) : .clear, radius: 4)
                        .scaleEffect(isFilled ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3), value: isFilled)
                }
            }
            
            // Goal text
            Text("\(Int(currentIntake)) of \(Int(dailyGoal)) oz")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            

        }
        .onAppear {
            // Animate water level on appear
            withAnimation(.easeOut(duration: 1.2)) {
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
    

}

#Preview {
    ZStack {
        LiquidBackgroundView()
        
        HydrationView()
    }
    .modelContainer(for: DayLog.self, inMemory: true)
    .preferredColorScheme(.dark)
}
