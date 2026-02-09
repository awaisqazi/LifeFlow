//
//  HydrationVesselCard.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import WidgetKit
import SwiftData

/// A premium hydration card featuring an elegant glass vessel and motion-reactive water.
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
        guard dailyGoal > 0 else { return 0 }
        return min(currentIntake / dailyGoal, 1.0)
    }
    
    private var progressPercent: Int {
        Int((fillLevel * 100).rounded())
    }
    
    private var remainingOunces: Int {
        max(0, Int((dailyGoal - currentIntake).rounded()))
    }
    
    private var hasReachedGoal: Bool {
        currentIntake >= dailyGoal
    }
    
    var body: some View {
        GlassCard(cornerRadius: 26) {
            VStack(spacing: 18) {
                headerRow
                mainShowcaseRow
                cupProgressRow
                controlsRow
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [
                        .cyan.opacity(0.16),
                        .blue.opacity(0.09),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24)
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.85)) {
                animatedWaterLevel = fillLevel
            }
            waterManager.startMotionUpdates()
        }
        .onDisappear {
            waterManager.stopMotionUpdates()
        }
        .onChange(of: fillLevel) { oldLevel, newLevel in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                animatedWaterLevel = newLevel
            }
            
            if newLevel >= 1.0 && oldLevel < 1.0 && !hasTriggeredMilestone {
                hasTriggeredMilestone = true
                triggerSuccessPulse()
                SoundManager.shared.play(.successChime, volume: 0.5)
                SoundManager.shared.haptic(.success)
            }
        }
    }
    
    private var headerRow: some View {
        HStack {
            Label {
                Text("Hydration")
                    .font(.headline.weight(.semibold))
            } icon: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.cyan)
            }
            
            Spacer()
            
            Text("\(progressPercent)%")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
    
    private var mainShowcaseRow: some View {
        HStack(spacing: 18) {
            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                .cyan.opacity(0.35),
                                .blue.opacity(0.14),
                                .clear
                            ],
                            center: .center,
                            startRadius: 12,
                            endRadius: 82
                        )
                    )
                    .frame(width: 150, height: 108)
                    .offset(y: 42)
                    .blur(radius: 16)
                
                PremiumLiquidVesselView(
                    fillLevel: animatedWaterLevel,
                    tiltAngle: waterManager.smoothedTilt
                )
                .clipShape(VesselShape())
                .overlay(
                    VesselShape()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.56),
                                    .white.opacity(0.24),
                                    .white.opacity(0.10),
                                    .white.opacity(0.24)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.35
                        )
                )
                .overlay(
                    VesselHighlightShape()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.26), .white.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .frame(width: 116, height: 188)
            }
            .frame(width: 124, height: 200)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("\(Int(currentIntake))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.22), radius: 6, y: 2)
                
                Text("oz today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)
                
                metricPill(
                    title: "Goal",
                    value: "\(Int(dailyGoal)) oz",
                    tint: .blue
                )
                metricPill(
                    title: "Remaining",
                    value: "\(remainingOunces) oz",
                    tint: .cyan
                )
                
                Label(
                    hasReachedGoal ? "Goal reached" : "Keep it flowing",
                    systemImage: hasReachedGoal ? "checkmark.seal.fill" : "sparkles"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(hasReachedGoal ? .green : .cyan)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func metricPill(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.18), in: Capsule())
    }
    
    private var cupProgressRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<cupsGoal, id: \.self) { index in
                let filled = Double(index) < (currentIntake / 8.0)
                Image(systemName: "drop.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(filled ? .cyan : .white.opacity(0.18))
                    .shadow(color: filled ? .cyan.opacity(0.4) : .clear, radius: 4)
                    .scaleEffect(filled ? 1.12 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: filled)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }
    
    private var controlsRow: some View {
        HStack(spacing: 10) {
            HydrationAdjustButton(
                icon: "minus",
                tint: .white.opacity(0.12),
                foreground: .white.opacity(0.9),
                isDisabled: dayLog.waterIntake < 1
            ) {
                adjustWater(by: -8)
            }
            
            HStack(spacing: 8) {
                HydrationQuickAddChip(amount: 8, tint: .cyan) {
                    adjustWater(by: 8)
                }
                HydrationQuickAddChip(amount: 12, tint: .mint) {
                    adjustWater(by: 12)
                }
                HydrationQuickAddChip(amount: 16, tint: .blue) {
                    adjustWater(by: 16)
                }
            }
            .frame(maxWidth: .infinity)
            
            HydrationAdjustButton(
                icon: "plus",
                tint: .cyan.opacity(0.36),
                foreground: .cyan,
                isDisabled: false
            ) {
                adjustWater(by: 8)
            }
        }
    }
    
    private func adjustWater(by ounces: Double) {
        let newValue = max(0, dayLog.waterIntake + ounces)
        guard newValue != dayLog.waterIntake else { return }
        
        dayLog.waterIntake = newValue
        waterManager.triggerSplash(direction: ounces >= 0 ? .up : .down)
        SoundManager.shared.play(ounces > 0 ? .waterSplash : .glassTap, volume: ounces >= 16 ? 0.65 : 0.5)
        triggerHaptic(style: ounces >= 16 ? .medium : .soft)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impact = UIImpactFeedbackGenerator(style: style)
        impact.impactOccurred()
    }
}

private struct HydrationAdjustButton: View {
    let icon: String
    let tint: Color
    let foreground: Color
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(foreground)
                .frame(width: 44, height: 44)
                .background(tint, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }
}

private struct HydrationQuickAddChip: View {
    let amount: Int
    let tint: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("+\(amount)")
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(tint.opacity(0.16), in: Capsule())
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
