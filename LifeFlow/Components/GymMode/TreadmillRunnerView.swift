//
//  TreadmillRunnerView.swift
//  LifeFlow
//
//  Created by Antigravity on 2/13/26.
//

import SwiftUI
import Combine

/// Gamified full-screen treadmill experience for indoor runs.
/// Features parallax scrolling cityscape, animated runner, speed-responsive
/// road, mile markers, and achievement toasts.
struct TreadmillRunnerView: View {
    let currentDistance: Double
    let targetDistance: Double
    let speed: Double
    let elapsedTime: TimeInterval
    let formattedPace: String
    let formattedTime: String
    let ghostProgress: Double
    let ghostDeltaLabel: String
    let ghostDelta: Double
    let showGhostRunner: Bool
    
    @State private var scrollOffset: CGFloat = 0
    @State private var displayedMilestone: MilestoneData? = nil
    @State private var passedMilestones: Set<Int> = []
    @State private var runnerBounce: Bool = false
    @State private var pulseGlow: Bool = false
    
    private var progress: Double {
        guard targetDistance > 0 else { return 0 }
        return min(1.0, currentDistance / targetDistance)
    }
    
    private var speedFactor: CGFloat {
        max(0.1, CGFloat(speed) / 6.0)
    }
    
    struct MilestoneData: Equatable {
        let percent: Int
        let label: String
        let icon: String
    }
    
    // Colors that shift based on progress
    private var skyTopColor: Color {
        let hue = 0.62 + progress * 0.08
        return Color(hue: hue, saturation: 0.85, brightness: 0.08 + progress * 0.06)
    }
    
    private var skyMidColor: Color {
        Color(hue: 0.58, saturation: 0.65, brightness: 0.15 + progress * 0.1)
    }
    
    private var horizonColor: Color {
        let hue = progress > 0.75 ? 0.08 : 0.55 // shift to warm sunrise near end
        return Color(hue: hue, saturation: 0.5 + progress * 0.2, brightness: 0.2 + progress * 0.2)
    }
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // === SKY ===
                LinearGradient(
                    colors: [skyTopColor, skyMidColor, horizonColor],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // === STARS ===
                StarsField(size: geo.size)
                    .opacity(max(0, 0.8 - progress * 0.6))
                
                // === MOON/SUN ===
                Circle()
                    .fill(
                        RadialGradient(
                            colors: progress > 0.75
                                ? [.orange.opacity(0.8), .orange.opacity(0.2), .clear]
                                : [.white.opacity(0.6), .white.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 15,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .offset(x: w * 0.28, y: -h * 0.28 + CGFloat(progress) * h * 0.15)
                
                // === FAR SKYLINE (slow) ===
                SkylineLayer(
                    buildingCount: 18,
                    maxBuildingHeight: h * 0.18,
                    minBuildingHeight: h * 0.04,
                    baseColor: Color(white: 0.06),
                    windowColor: .cyan.opacity(0.3),
                    scrollOffset: scrollOffset * 0.15,
                    totalWidth: w * 3
                )
                .frame(maxHeight: .infinity, alignment: .bottom)
                .offset(y: -h * 0.24)
                
                // === MID SKYLINE (medium) ===
                SkylineLayer(
                    buildingCount: 12,
                    maxBuildingHeight: h * 0.28,
                    minBuildingHeight: h * 0.1,
                    baseColor: Color(white: 0.04),
                    windowColor: .yellow.opacity(0.5),
                    scrollOffset: scrollOffset * 0.35,
                    totalWidth: w * 2.5
                )
                .frame(maxHeight: .infinity, alignment: .bottom)
                .offset(y: -h * 0.18)
                
                // === NEAR BUILDINGS (fast) ===
                SkylineLayer(
                    buildingCount: 8,
                    maxBuildingHeight: h * 0.38,
                    minBuildingHeight: h * 0.18,
                    baseColor: Color(white: 0.02),
                    windowColor: .orange.opacity(0.4),
                    scrollOffset: scrollOffset * 0.6,
                    totalWidth: w * 2
                )
                .frame(maxHeight: .infinity, alignment: .bottom)
                .offset(y: -h * 0.12)
                
                // === GROUND PLANE ===
                VStack(spacing: 0) {
                    Spacer()
                    
                    ZStack {
                        // Sidewalk / ground
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.08), Color(white: 0.03)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // Road lane stripe
                        ScrollingRoadStripes(scrollOffset: scrollOffset, width: w)
                        
                        // Lamp posts
                        ScrollingLampPosts(scrollOffset: scrollOffset, width: w, height: h * 0.12)
                    }
                    .frame(height: h * 0.12)
                }
                .ignoresSafeArea(edges: .bottom)
                
                // === RUNNER ===
                VStack {
                    Spacer()
                    
                    ZStack {
                        // Ground glow
                        Ellipse()
                            .fill(
                                RadialGradient(
                                    colors: [.cyan.opacity(pulseGlow ? 0.4 : 0.2), .clear],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 40)
                            .offset(y: 30)
                        
                        // Runner figure
                        Image(systemName: "figure.run")
                            .font(.system(size: 72, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.cyan, .white, .cyan.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .cyan.opacity(0.8), radius: 20)
                            .shadow(color: .cyan.opacity(0.3), radius: 40)
                            .offset(y: runnerBounce ? -6 : 6)
                        
                        // Speed lines (when running fast)
                        if speed > 4 {
                            ForEach(0..<3, id: \.self) { i in
                                Capsule()
                                    .fill(.cyan.opacity(0.15 + Double(i) * 0.05))
                                    .frame(width: CGFloat(30 + i * 15), height: 2)
                                    .offset(x: CGFloat(-50 - i * 12), y: CGFloat(-10 + i * 14))
                            }
                        }
                    }
                    .offset(y: -(h * 0.12) - 10)
                }
                
                // === GHOST RUNNER ===
                if showGhostRunner {
                    VStack {
                        Spacer()
                        
                        Image(systemName: "figure.run")
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.12))
                            .shadow(color: .white.opacity(0.05), radius: 12)
                            .offset(
                                x: min(max(CGFloat(ghostDelta) * 60, -120), 120),
                                y: -(h * 0.12) - 14
                            )
                    }
                }
                
                // === DISTANCE HIGHWAY (top) ===
                VStack {
                    MiniDistanceBar(
                        progress: progress,
                        currentMiles: currentDistance,
                        targetMiles: targetDistance
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    Spacer()
                }
                
                // === MILESTONE TOAST ===
                if let milestone = displayedMilestone {
                    VStack {
                        Spacer()
                            .frame(height: h * 0.25)
                        MilestoneToast(milestone: milestone.label, icon: milestone.icon)
                        Spacer()
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: currentDistance) { _, newVal in
            checkMilestones(distance: newVal)
        }
        .onReceive(Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()) { _ in
            scrollOffset += speedFactor * 3.5
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
            runnerBounce = true
        }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseGlow = true
        }
    }
    
    private func checkMilestones(distance: Double) {
        guard targetDistance > 0 else { return }
        let pct = Int((distance / targetDistance) * 100)
        
        let milestones: [(Int, String, String)] = [
            (25, "25% — 🔥 Quarter Way!", "flame.fill"),
            (50, "50% — 💪 Halfway!", "bolt.fill"),
            (75, "75% — 🏃 Almost There!", "trophy.fill"),
            (100, "100% — 🎉 FINISHED!", "star.fill")
        ]
        
        for (threshold, label, icon) in milestones {
            if pct >= threshold && !passedMilestones.contains(threshold) {
                passedMilestones.insert(threshold)
                
                let data = MilestoneData(percent: threshold, label: label, icon: icon)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    displayedMilestone = data
                }
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(threshold == 100 ? .success : .warning)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        if displayedMilestone == data {
                            displayedMilestone = nil
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Stars

private struct StarsField: View {
    let size: CGSize
    
    @State private var twinkle = false
    
    var body: some View {
        Canvas { context, canvasSize in
            // Fixed seed for consistent star layout
            var rng = SeededRandomNumberGenerator(seed: 42)
            
            for _ in 0..<120 {
                let x = CGFloat.random(in: 0...canvasSize.width, using: &rng)
                let y = CGFloat.random(in: 0...(canvasSize.height * 0.5), using: &rng)
                let r = CGFloat.random(in: 0.5...2.5, using: &rng)
                let brightness = CGFloat.random(in: 0.3...1.0, using: &rng)
                
                let rect = CGRect(x: x, y: y, width: r, height: r)
                context.opacity = twinkle ? Double(brightness) : Double(brightness * 0.6)
                context.fill(Circle().path(in: rect), with: .color(.white))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                twinkle = true
            }
        }
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    var state: UInt64
    
    init(seed: UInt64) {
        state = seed
    }
    
    mutating func next() -> UInt64 {
        state &+= 0x6a09e667f3bcc909
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

// MARK: - Skyline Layer

private struct SkylineLayer: View {
    let buildingCount: Int
    let maxBuildingHeight: CGFloat
    let minBuildingHeight: CGFloat
    let baseColor: Color
    let windowColor: Color
    let scrollOffset: CGFloat
    let totalWidth: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let spacing = totalWidth / CGFloat(buildingCount)
            let wrapOffset = scrollOffset.truncatingRemainder(dividingBy: totalWidth)
            var rng = SeededRandomNumberGenerator(seed: UInt64(buildingCount * 777))
            
            // Pre-generate building data
            var buildings: [(CGFloat, CGFloat)] = []  // width, height
            for _ in 0..<buildingCount {
                let w = CGFloat.random(in: 25...55, using: &rng)
                let h = CGFloat.random(in: minBuildingHeight...maxBuildingHeight, using: &rng)
                buildings.append((w, h))
            }
            
            for (i, building) in buildings.enumerated() {
                var x = CGFloat(i) * spacing - wrapOffset
                while x < -building.0 { x += totalWidth }
                while x > size.width + building.0 { x -= totalWidth }
                
                guard x > -building.0, x < size.width + building.0 else { continue }
                
                let rect = CGRect(
                    x: x,
                    y: size.height - building.1,
                    width: building.0,
                    height: building.1
                )
                
                // Building body
                context.fill(Rectangle().path(in: rect), with: .color(baseColor))
                
                // Roof accent line
                let roofLine = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 2)
                context.fill(Rectangle().path(in: roofLine), with: .color(windowColor.opacity(0.3)))
                
                // Windows
                var wy = rect.minY + 6
                var windowRng = SeededRandomNumberGenerator(seed: UInt64(i * 31 + buildingCount))
                while wy < rect.maxY - 5 {
                    var wx = rect.minX + 4
                    while wx < rect.maxX - 4 {
                        let windowW: CGFloat = 3
                        let windowH: CGFloat = 4
                        let windowRect = CGRect(x: wx, y: wy, width: windowW, height: windowH)
                        let lit = Bool.random(using: &windowRng)
                        if lit {
                            let brightness = CGFloat.random(in: 0.2...0.8, using: &windowRng)
                            context.fill(
                                Rectangle().path(in: windowRect),
                                with: .color(windowColor.opacity(Double(brightness)))
                            )
                        }
                        wx += 8
                    }
                    wy += 8
                }
            }
        }
    }
}

// MARK: - Road Stripes

private struct ScrollingRoadStripes: View {
    let scrollOffset: CGFloat
    let width: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let dashWidth: CGFloat = 35
            let gapWidth: CGFloat = 50
            let unit = dashWidth + gapWidth
            let y = size.height * 0.4
            let offset = scrollOffset.truncatingRemainder(dividingBy: unit)
            
            var x = -offset - unit
            while x < size.width + unit {
                let rect = CGRect(x: x, y: y, width: dashWidth, height: 3)
                context.fill(
                    RoundedRectangle(cornerRadius: 1.5).path(in: rect),
                    with: .color(.yellow.opacity(0.35))
                )
                x += unit
            }
            
            // Side line
            let topLine = CGRect(x: 0, y: 2, width: size.width, height: 1)
            context.fill(Rectangle().path(in: topLine), with: .color(.white.opacity(0.08)))
        }
    }
}

// MARK: - Lamp Posts

private struct ScrollingLampPosts: View {
    let scrollOffset: CGFloat
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 180
            let offset = scrollOffset.truncatingRemainder(dividingBy: spacing)
            
            var x = -offset
            while x < size.width + spacing {
                // Pole
                let pole = CGRect(x: x, y: -height * 0.6, width: 2, height: height * 0.6)
                context.fill(Rectangle().path(in: pole), with: .color(.white.opacity(0.08)))
                
                // Light glow
                let glowRect = CGRect(x: x - 12, y: -height * 0.6 - 4, width: 26, height: 8)
                context.fill(
                    Ellipse().path(in: glowRect),
                    with: .color(.yellow.opacity(0.12))
                )
                
                // Ground light cone
                let coneRect = CGRect(x: x - 25, y: 0, width: 52, height: size.height)
                context.fill(
                    Ellipse().path(in: coneRect),
                    with: .color(.yellow.opacity(0.03))
                )
                
                x += spacing
            }
        }
    }
}

// MARK: - Mini Distance Bar

private struct MiniDistanceBar: View {
    let progress: Double
    let currentMiles: Double
    let targetMiles: Double
    
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * CGFloat(min(1.0, progress))))
                        .shadow(color: .cyan.opacity(0.6), radius: 6)
                    
                    // Quarter dots
                    ForEach([0.25, 0.5, 0.75], id: \.self) { marker in
                        Circle()
                            .fill(progress >= marker ? .white : .white.opacity(0.15))
                            .frame(width: 5, height: 5)
                            .offset(x: geo.size.width * CGFloat(marker) - 2.5)
                    }
                }
            }
            .frame(height: 6)
            
            HStack {
                Text(String(format: "%.2f mi", currentMiles))
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.cyan)
                    .contentTransition(.numericText())
                
                Spacer()
                
                Text(String(format: "%.1f mi", targetMiles))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
    }
}
