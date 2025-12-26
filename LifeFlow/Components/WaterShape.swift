//
//  WaterShape.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI

/// A premium animated water shape that fills the vessel.
/// Features a realistic wavy surface that responds to tilt.
struct WaterShape: Shape {
    /// Fill level from 0.0 (empty) to 1.0 (full)
    var fillLevel: Double
    
    /// Tilt angle for the water surface (-0.5 to 0.5)
    var tiltAngle: Double
    
    /// Phase for wave animation (0 to 2π)
    var wavePhase: Double
    
    /// Amplitude of the surface wave
    var waveAmplitude: CGFloat = 6
    
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
        let waterHeight = height * min(fillLevel, 0.92)  // Leave room at top
        let waterTop = height - waterHeight
        
        // Vessel shape parameters (must match VesselShape)
        let topWidth = width * 0.98
        let bottomWidth = width * 0.7
        let topInset = (width - topWidth) / 2
        let bottomInset = (width - bottomWidth) / 2
        
        // Calculate vessel width at water level
        let progress = waterTop / height
        let vesselWidthAtLevel = bottomWidth + (topWidth - bottomWidth) * (1 - progress)
        let leftEdge = (width - vesselWidthAtLevel) / 2
        let rightEdge = width - leftEdge
        
        // Tilt offset for water surface
        let tiltOffset = vesselWidthAtLevel * tiltAngle * 0.2
        
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
            path.addLine(to: CGPoint(x: leftX + 3, y: waterTop))
        } else {
            path.addLine(to: CGPoint(x: bottomInset, y: waterTop))
        }
        
        // Draw wavy water surface
        let steps = 40
        let stepWidth = (rightEdge - leftEdge) / CGFloat(steps)
        
        for i in 0...steps {
            let x = leftEdge + stepWidth * CGFloat(i) + 3
            let normalizedX = CGFloat(i) / CGFloat(steps)
            
            // Calculate wave with two frequencies for more natural look
            let wave1 = sin(normalizedX * .pi * 2.5 + wavePhase) * waveAmplitude
            let wave2 = sin(normalizedX * .pi * 4 + wavePhase * 1.3) * (waveAmplitude * 0.4)
            let wave = wave1 + wave2
            
            // Apply tilt (higher on one side based on tiltAngle)
            let tilt = (normalizedX - 0.5) * tiltOffset * 2
            
            let y = waterTop + wave + tilt
            
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Right side down to bottom
        if waterTop < height * 0.85 {
            let rightProgress = waterTop / (height * 0.85)
            let rightX = (width - bottomInset) + 10 * (1 - rightProgress) - topInset * rightProgress
            path.addLine(to: CGPoint(x: rightX - 3, y: waterTop))
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

/// A view that renders beautifully animated water with shimmer effects
struct AnimatedWaterView: View {
    let fillLevel: Double
    let tiltAngle: Double
    @State private var wavePhase: Double = 0
    @State private var shimmerPhase: Double = 0
    
    // Premium water gradient colors
    private let waterColors: [Color] = [
        Color(red: 0.0, green: 0.35, blue: 0.65),   // Deep ocean
        Color(red: 0.05, green: 0.45, blue: 0.75),  // Ocean blue
        Color(red: 0.1, green: 0.55, blue: 0.85),   // Clear blue
        Color(red: 0.3, green: 0.7, blue: 0.95),    // Surface cyan
    ]
    
    /// Safely computed shimmer gradient stops (always ordered)
    private var shimmerStops: [Gradient.Stop] {
        // Clamp positions to valid range and ensure ordering
        let center = max(0.1, min(0.9, shimmerPhase))
        let leading = max(0.0, center - 0.1)
        let trailing = min(1.0, center + 0.1)
        
        return [
            .init(color: .clear, location: 0),
            .init(color: .white.opacity(0.15), location: leading),
            .init(color: .white.opacity(0.25), location: center),
            .init(color: .white.opacity(0.15), location: trailing),
            .init(color: .clear, location: 1),
        ]
    }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            ZStack {
                // Main water body
                WaterShape(
                    fillLevel: fillLevel,
                    tiltAngle: tiltAngle,
                    wavePhase: wavePhase
                )
                .fill(
                    LinearGradient(
                        colors: waterColors,
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                
                // Shimmer/highlight overlay
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
                
                // Surface highlight
                WaterShape(
                    fillLevel: fillLevel,
                    tiltAngle: tiltAngle,
                    wavePhase: wavePhase
                )
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.4),
                            .white.opacity(0.1),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
            }
            .onChange(of: timeline.date) { _, _ in
                wavePhase += 0.06
                if wavePhase > .pi * 2 {
                    wavePhase = 0
                }
                
                shimmerPhase += 0.01
                if shimmerPhase > 1.0 {
                    shimmerPhase = 0
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        AnimatedWaterView(fillLevel: 0.5, tiltAngle: 0.05)
            .frame(width: 180, height: 280)
    }
}
