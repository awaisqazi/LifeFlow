//
//  WaterShape.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI

/// A premium animated water shape that fills the vessel.
/// Features a dynamic wavy surface with organic curves that respond dramatically to tilt.
struct WaterShape: Shape {
    /// Fill level from 0.0 (empty) to 1.0 (full)
    var fillLevel: Double
    
    /// Tilt angle for the water surface
    var tiltAngle: Double
    
    /// Phase for wave animation (0 to 2π)
    var wavePhase: Double
    
    /// Height of the surface wave
    var waveHeight: CGFloat = 12
    
    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(fillLevel, AnimatablePair(tiltAngle, wavePhase)) }
        set {
            fillLevel = newValue.first
            tiltAngle = newValue.second.first
            wavePhase = newValue.second.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard fillLevel > 0 else { return path }
        
        let width = rect.width
        let height = rect.height
        
        // Calculate water surface height
        let waterHeight = height * min(fillLevel, 0.92)
        let waterTop = height - waterHeight
        
        // Vessel shape parameters
        let topWidth = width * 0.98
        let bottomWidth = width * 0.7
        let topInset = (width - topWidth) / 2
        let bottomInset = (width - bottomWidth) / 2
        
        // Calculate vessel width at water level
        let progress = waterTop / height
        let vesselWidthAtLevel = bottomWidth + (topWidth - bottomWidth) * (1 - progress)
        let leftEdge = (width - vesselWidthAtLevel) / 2 + 3
        let rightEdge = width - leftEdge
        
        // DRAMATIC tilt offset - INVERTED so water rises on the side you tilt toward
        // Negative because when tilting left (negative roll), water should rise on LEFT
        let tiltOffset = vesselWidthAtLevel * tiltAngle * -1.5
        
        // Start at bottom center of vessel
        path.move(to: CGPoint(x: width * 0.5, y: height))
        
        // Bottom left curve
        path.addCurve(
            to: CGPoint(x: bottomInset, y: height * 0.85),
            control1: CGPoint(x: width * 0.35, y: height),
            control2: CGPoint(x: bottomInset, y: height * 0.95)
        )
        
        // Left side up to water level
        if waterTop < height * 0.85 {
            let leftProgress = waterTop / (height * 0.85)
            let leftX = bottomInset - 10 * (1 - leftProgress) + topInset * leftProgress
            // Left side rises when tilting left (with inverted tiltOffset)
            let leftTiltAdjust = tiltOffset * 0.5
            path.addLine(to: CGPoint(x: leftX + 3, y: waterTop - leftTiltAdjust))
        } else {
            path.addLine(to: CGPoint(x: bottomInset, y: waterTop))
        }
        
        // Draw ORGANIC wavy water surface with dramatic curl
        let steps = 50
        let stepWidth = (rightEdge - leftEdge) / CGFloat(steps)
        
        for i in 0...steps {
            let x = leftEdge + stepWidth * CGFloat(i)
            let normalizedX = CGFloat(i) / CGFloat(steps)
            
            // Multi-frequency waves for organic look
            let wave1 = sin(normalizedX * .pi * 2 + wavePhase) * waveHeight
            let wave2 = sin(normalizedX * .pi * 3.5 + wavePhase * 1.5) * (waveHeight * 0.5)
            let wave3 = sin(normalizedX * .pi * 5 + wavePhase * 0.7) * (waveHeight * 0.25)
            
            // Create a "curl" effect - wave rises higher in the middle based on tilt
            let curlFactor = sin(normalizedX * .pi) * abs(tiltAngle) * 25
            
            let wave = wave1 + wave2 + wave3 + curlFactor
            
            // Apply dramatic tilt (water rises on the side you tilt toward)
            // normalizedX 0=left, 1=right. Positive tiltOffset = left side higher
            let tilt = (0.5 - normalizedX) * tiltOffset * 3.0
            
            let y = waterTop + wave + tilt
            
            if i == 0 {
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Right side down to bottom
        if waterTop < height * 0.85 {
            let rightProgress = waterTop / (height * 0.85)
            let rightX = (width - bottomInset) + 10 * (1 - rightProgress) - topInset * rightProgress
            // Right side drops when tilting left
            let rightTiltAdjust = -tiltOffset * 0.5
            path.addLine(to: CGPoint(x: rightX - 3, y: waterTop - rightTiltAdjust))
        }
        
        path.addLine(to: CGPoint(x: width - bottomInset, y: height * 0.85))
        
        // Bottom right curve back to center
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height),
            control1: CGPoint(x: width - bottomInset, y: height * 0.95),
            control2: CGPoint(x: width * 0.65, y: height)
        )
        
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Animated Water View with Premium Effects

/// A view that renders beautifully animated water matching the logo aesthetic
/// Features cyan-to-purple gradient, floating bubbles, and luminescent glow
struct AnimatedWaterView: View {
    let fillLevel: Double
    let tiltAngle: Double
    @State private var wavePhase: Double = 0
    @State private var shimmerPhase: Double = 0
    @State private var bubbleOffset: Double = 0
    
    // Natural water gradient with logo-inspired accent
    private var waterGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.0, green: 0.2, blue: 0.5),    // Deep ocean blue
                Color(red: 0.0, green: 0.35, blue: 0.7),   // Ocean blue
                Color(red: 0.1, green: 0.5, blue: 0.85),   // Clear blue
                Color(red: 0.2, green: 0.65, blue: 0.95),  // Bright cyan-blue
                Color(red: 0.4, green: 0.8, blue: 1.0),    // Surface highlight
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }
    
    // Inner glow gradient
    private var innerGlowGradient: RadialGradient {
        RadialGradient(
            colors: [
                .cyan.opacity(0.4),
                .purple.opacity(0.2),
                .clear
            ],
            center: .center,
            startRadius: 10,
            endRadius: 80
        )
    }
    
    /// Safely computed shimmer gradient stops
    private var shimmerStops: [Gradient.Stop] {
        let center = max(0.1, min(0.9, shimmerPhase))
        let leading = max(0.0, center - 0.15)
        let trailing = min(1.0, center + 0.15)
        
        return [
            .init(color: .clear, location: 0),
            .init(color: .white.opacity(0.2), location: leading),
            .init(color: .white.opacity(0.4), location: center),
            .init(color: .white.opacity(0.2), location: trailing),
            .init(color: .clear, location: 1),
        ]
    }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            ZStack {
                // Background glow inside water
                WaterShape(
                    fillLevel: fillLevel,
                    tiltAngle: tiltAngle,
                    wavePhase: wavePhase
                )
                .fill(innerGlowGradient)
                .blur(radius: 8)
                
                // Main water body with logo-inspired gradient
                WaterShape(
                    fillLevel: fillLevel,
                    tiltAngle: tiltAngle,
                    wavePhase: wavePhase
                )
                .fill(waterGradient)
                
                // Shimmer/highlight overlay - moving across surface
                WaterShape(
                    fillLevel: fillLevel,
                    tiltAngle: tiltAngle,
                    wavePhase: wavePhase
                )
                .fill(
                    LinearGradient(
                        stops: shimmerStops,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                
                // Floating bubbles
                BubblesView(fillLevel: fillLevel, phase: bubbleOffset)
                    .clipShape(
                        WaterShape(
                            fillLevel: fillLevel,
                            tiltAngle: tiltAngle,
                            wavePhase: wavePhase
                        )
                    )
                
                // Surface highlight with glow
                WaterShape(
                    fillLevel: fillLevel,
                    tiltAngle: tiltAngle,
                    wavePhase: wavePhase
                )
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.6),
                            .cyan.opacity(0.4),
                            .purple.opacity(0.2),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2.5
                )
                .blur(radius: 0.5)
            }
            .onChange(of: timeline.date) { _, _ in
                // Faster wave animation
                wavePhase += 0.08
                if wavePhase > .pi * 2 {
                    wavePhase = 0
                }
                
                shimmerPhase += 0.015
                if shimmerPhase > 1.0 {
                    shimmerPhase = 0
                }
                
                bubbleOffset += 0.02
            }
        }
    }
}

// MARK: - Floating Bubbles

/// Animated bubbles that float upward inside the water
struct BubblesView: View {
    let fillLevel: Double
    let phase: Double
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Multiple bubbles at different positions
                ForEach(0..<8, id: \.self) { i in
                    BubbleView(
                        size: CGFloat.random(in: 4...10),
                        baseX: geo.size.width * CGFloat([0.2, 0.35, 0.5, 0.65, 0.8, 0.25, 0.55, 0.75][i]),
                        phase: phase + Double(i) * 0.5,
                        height: geo.size.height,
                        fillLevel: fillLevel
                    )
                }
            }
        }
    }
}

/// Individual floating bubble
struct BubbleView: View {
    let size: CGFloat
    let baseX: CGFloat
    let phase: Double
    let height: CGFloat
    let fillLevel: Double
    
    private var yPosition: CGFloat {
        let waterTop = height * (1 - fillLevel * 0.92)
        let waterBottom = height
        let range = waterBottom - waterTop
        // Bubble rises from bottom to top, then resets
        let normalizedPhase = phase.truncatingRemainder(dividingBy: 3.0) / 3.0
        return waterBottom - range * normalizedPhase
    }
    
    private var xOffset: CGFloat {
        sin(phase * 2) * 5
    }
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        .white.opacity(0.6),
                        .cyan.opacity(0.3),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: size
                )
            )
            .frame(width: size, height: size)
            .position(x: baseX + xOffset, y: yPosition)
            .opacity(fillLevel > 0.1 ? 0.7 : 0)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        AnimatedWaterView(fillLevel: 0.5, tiltAngle: 0.2)
            .frame(width: 180, height: 280)
    }
}
