//
//  WaterShape.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI

/// A custom shape for the animated water inside the vessel.
/// Features a wavy surface that responds to tilt and animates continuously.
struct WaterShape: Shape {
    /// Fill level from 0.0 (empty) to 1.0 (full)
    var fillLevel: Double
    
    /// Tilt angle for the water surface (-0.5 to 0.5)
    var tiltAngle: Double
    
    /// Phase for wave animation (0 to 2π)
    var wavePhase: Double
    
    /// Amplitude of the surface wave
    var waveAmplitude: CGFloat = 8
    
    /// Vessel taper amount (must match VesselShape)
    var vesselTaper: CGFloat = 0.15
    
    /// Vessel bottom corner radius (must match VesselShape)
    var vesselCornerRadius: CGFloat = 40
    
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
        
        let width = rect.width
        let height = rect.height
        
        // Calculate water height based on fill level
        let waterHeight = height * fillLevel
        let waterTop = height - waterHeight
        
        // Calculate tilt offset for water surface
        let tiltOffset = width * tiltAngle * 0.3
        
        // Calculate vessel taper at water level
        let taperAtWaterLevel = vesselTaper * (waterTop / height)
        let leftEdge = width * taperAtWaterLevel
        let rightEdge = width - (width * taperAtWaterLevel)
        
        // Bottom of vessel (matches VesselShape)
        let bottomTaper = width * vesselTaper
        
        // Start from bottom-left of vessel
        path.move(to: CGPoint(x: bottomTaper + vesselCornerRadius * 0.5, y: height))
        
        // Bottom edge
        path.addLine(to: CGPoint(x: width - bottomTaper - vesselCornerRadius * 0.5, y: height))
        
        // Right side up to water level
        let rightSideX = rightEdge + (width - rightEdge) * (1 - fillLevel)
        path.addLine(to: CGPoint(x: rightSideX, y: waterTop))
        
        // Wavy water surface with tilt
        let steps = 50
        let stepWidth = (rightEdge - leftEdge) / CGFloat(steps)
        
        for i in (0...steps).reversed() {
            let x = leftEdge + stepWidth * CGFloat(i)
            let normalizedX = CGFloat(i) / CGFloat(steps)
            
            // Calculate wave height
            let wave = sin(normalizedX * .pi * 3 + wavePhase) * waveAmplitude
            
            // Apply tilt (higher on one side based on tiltAngle)
            let tilt = (normalizedX - 0.5) * tiltOffset * 2
            
            let y = waterTop + wave + tilt
            
            if i == steps {
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Left side back down to bottom
        let leftSideX = leftEdge - leftEdge * (1 - fillLevel)
        path.addLine(to: CGPoint(x: leftSideX, y: waterTop))
        path.addLine(to: CGPoint(x: bottomTaper + vesselCornerRadius * 0.5, y: height))
        
        path.closeSubpath()
        
        return path
    }
}

/// A view that renders animated water with gradient fill
struct AnimatedWaterView: View {
    let fillLevel: Double
    let tiltAngle: Double
    @State private var wavePhase: Double = 0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            WaterShape(
                fillLevel: fillLevel,
                tiltAngle: tiltAngle,
                wavePhase: wavePhase
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.5, blue: 0.9),
                        Color(red: 0.2, green: 0.7, blue: 1.0),
                        Color(red: 0.4, green: 0.8, blue: 1.0)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .opacity(0.85)
            .onChange(of: timeline.date) { _, _ in
                wavePhase += 0.08
                if wavePhase > .pi * 2 {
                    wavePhase = 0
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        AnimatedWaterView(fillLevel: 0.6, tiltAngle: 0.1)
            .frame(width: 200, height: 300)
    }
}
