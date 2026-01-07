//
//  HydrationVesselCard.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import WidgetKit
import SwiftData

/// A premium hydration card featuring a glass vessel with CoreMotion water physics.
/// The water surface tilts realistically as you physically tilt your phone.
struct HydrationVesselCard: View {
    @Bindable var dayLog: DayLog
    @Environment(\.modelContext) private var modelContext
    
    /// Environment action to trigger success pulse on the mesh gradient background
    @Environment(\.triggerSuccessPulse) private var triggerSuccessPulse
    
    @State private var waterManager = WaterManager()
    @State private var animatedWaterLevel: Double = 0
    @State private var hasTriggeredMilestone: Bool = false
    
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
    
    /// Current water intake from the DayLog
    private var currentIntake: Double {
        dayLog.waterIntake
    }
    
    /// Fill level as percentage (0.0 to 1.0)
    private var fillLevel: Double {
        min(currentIntake / dailyGoal, 1.0)
    }
    
    var body: some View {
        GlassCard(cornerRadius: 24) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "drop.fill")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                    
                    Text("Hydration")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(Int(currentIntake)) / \(Int(dailyGoal)) oz")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                // Vessel with Physics
                ZStack {
                    // Ambient glow
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .cyan.opacity(0.2),
                                    .blue.opacity(0.08),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 80
                            )
                        )
                        .frame(width: 140, height: 100)
                        .offset(y: 35)
                        .blur(radius: 15)
                    
                    // Main vessel container
                    ZStack {
                        // Metal-accelerated water with realistic fluid physics
                        MetalWaterView(
                            fillLevel: animatedWaterLevel,
                            tiltAngle: waterManager.tiltAngle
                        )
                        .clipShape(VesselShape())
                        .drawingGroup() // GPU acceleration
                        
                        // Glass vessel stroke
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
                        
                        // Inner glass highlight
                        VesselHighlightShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.2),
                                        .white.opacity(0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // Glass effect overlay
                        VesselShape()
                            .fill(.clear)
                            .glassEffect(.regular.tint(.cyan.opacity(0.06)), in: VesselShape())
                        
                        // Floating intake display
                        VStack(spacing: 0) {
                            Text("\(Int(currentIntake))")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                            
                            Text("oz")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .textCase(.uppercase)
                                .tracking(1.5)
                        }
                        .offset(y: -10)
                    }
                    .frame(width: 100, height: 160)
                }
                
                // Progress drops (one per cup)
                HStack(spacing: 6) {
                    ForEach(0..<cupsGoal, id: \.self) { index in
                        let isFilled = Double(index) < (currentIntake / 8)
                        Image(systemName: "drop.fill")
                            .font(.system(size: 10))
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
                            .shadow(color: isFilled ? .cyan.opacity(0.5) : .clear, radius: 3)
                            .scaleEffect(isFilled ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3), value: isFilled)
                    }
                }
                
                // Controls
                HStack(spacing: 16) {
                    // Minus Button
                    Button {
                        if dayLog.waterIntake >= 8 {
                            dayLog.waterIntake -= 8
                            waterManager.triggerSplash(direction: .down)
                            triggerHaptic(style: .light)
                            try? modelContext.save()
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(dayLog.waterIntake < 8)
                    .opacity(dayLog.waterIntake >= 8 ? 1.0 : 0.4)
                    
                    Spacer()
                    
                    // Quick add amounts
                    HStack(spacing: 8) {
                        QuickAddButton(amount: 8, unit: "oz") {
                            dayLog.waterIntake += 8
                            waterManager.triggerSplash(direction: .up)
                            triggerHaptic(style: .soft)
                            try? modelContext.save()
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                        
                        QuickAddButton(amount: 16, unit: "oz") {
                            dayLog.waterIntake += 16
                            waterManager.triggerSplash(direction: .up)
                            triggerHaptic(style: .medium)
                            try? modelContext.save()
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    }
                    
                    Spacer()
                    
                    // Plus Button
                    Button {
                        dayLog.waterIntake += 8
                        waterManager.triggerSplash(direction: .up)
                        triggerHaptic(style: .soft)
                        try? modelContext.save()
                        WidgetCenter.shared.reloadAllTimelines()
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .background(Color.cyan.opacity(0.3), in: Circle())
                            .foregroundStyle(.cyan)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .onAppear {
            // Animate water level on appear
            withAnimation(.easeOut(duration: 0.8)) {
                animatedWaterLevel = fillLevel
            }
            // Start motion tracking
            waterManager.startMotionUpdates()
        }
        .onDisappear {
            waterManager.stopMotionUpdates()
        }
        .onChange(of: fillLevel) { oldLevel, newLevel in
            // Animate water level changes
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedWaterLevel = newLevel
            }
            
            // Trigger success pulse when reaching daily goal
            if newLevel >= 1.0 && oldLevel < 1.0 && !hasTriggeredMilestone {
                hasTriggeredMilestone = true
                triggerSuccessPulse()
                // Extra celebratory haptic
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.success)
            }
        }
    }
    
    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impact = UIImpactFeedbackGenerator(style: style)
        impact.impactOccurred()
    }
}

/// Quick-add button for common water amounts
private struct QuickAddButton: View {
    let amount: Int
    let unit: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("+\(amount)")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.cyan.opacity(0.15), in: Capsule())
                .foregroundStyle(.cyan)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        LiquidBackgroundView()
        
        VStack {
            HydrationVesselCard(dayLog: DayLog(waterIntake: 24))
                .padding()
            Spacer()
        }
    }
    .modelContainer(for: DayLog.self, inMemory: true)
    .preferredColorScheme(.dark)
}
