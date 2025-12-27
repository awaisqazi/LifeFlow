//
//  AnimatedMeshGradientView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI

/// A sophisticated animated mesh gradient that creates an organic "breathing" effect.
/// Uses TimelineView with complex sine waves to animate control points,
/// ensuring the animation never repeats exactly for a natural, flowing appearance.
struct AnimatedMeshGradientView: View {
    /// The current theme determining the color palette
    let theme: MeshGradientTheme
    
    /// Optional success pulse intensity (0.0 to 1.0)
    var successPulseIntensity: Double = 0.0
    
    /// Animation speed multiplier (1.0 = normal)
    var animationSpeed: Double = 1.0
    
    /// The amplitude of point movement (0.0 to 0.15 recommended)
    private let driftAmplitude: Float = 0.08
    
    /// Configuration for each control point's animation
    private struct PointAnimation {
        let basePosition: SIMD2<Float>
        let xFrequency: Float
        let yFrequency: Float
        let xPhase: Float
        let yPhase: Float
        let xAmplitude: Float
        let yAmplitude: Float
    }
    
    /// Pre-computed animation parameters for each of the 9 control points
    /// Using prime-ratio frequencies ensures no obvious repeat pattern
    private let pointAnimations: [PointAnimation] = [
        // Row 0 - Top edge (minimal vertical movement)
        PointAnimation(basePosition: SIMD2(0.0, 0.0), xFrequency: 0.0, yFrequency: 0.0,
                      xPhase: 0, yPhase: 0, xAmplitude: 0, yAmplitude: 0),
        PointAnimation(basePosition: SIMD2(0.5, 0.0), xFrequency: 0.23, yFrequency: 0.17,
                      xPhase: 0.5, yPhase: 1.2, xAmplitude: 0.06, yAmplitude: 0.02),
        PointAnimation(basePosition: SIMD2(1.0, 0.0), xFrequency: 0.0, yFrequency: 0.0,
                      xPhase: 0, yPhase: 0, xAmplitude: 0, yAmplitude: 0),
        
        // Row 1 - Middle (maximum movement for visible breathing)
        PointAnimation(basePosition: SIMD2(0.0, 0.5), xFrequency: 0.19, yFrequency: 0.29,
                      xPhase: 2.1, yPhase: 0.8, xAmplitude: 0.02, yAmplitude: 0.06),
        PointAnimation(basePosition: SIMD2(0.5, 0.5), xFrequency: 0.31, yFrequency: 0.37,
                      xPhase: 1.7, yPhase: 3.2, xAmplitude: 0.08, yAmplitude: 0.08),
        PointAnimation(basePosition: SIMD2(1.0, 0.5), xFrequency: 0.21, yFrequency: 0.27,
                      xPhase: 4.1, yPhase: 1.5, xAmplitude: 0.02, yAmplitude: 0.06),
        
        // Row 2 - Bottom edge (minimal vertical movement)
        PointAnimation(basePosition: SIMD2(0.0, 1.0), xFrequency: 0.0, yFrequency: 0.0,
                      xPhase: 0, yPhase: 0, xAmplitude: 0, yAmplitude: 0),
        PointAnimation(basePosition: SIMD2(0.5, 1.0), xFrequency: 0.25, yFrequency: 0.19,
                      xPhase: 3.5, yPhase: 2.3, xAmplitude: 0.06, yAmplitude: 0.02),
        PointAnimation(basePosition: SIMD2(1.0, 1.0), xFrequency: 0.0, yFrequency: 0.0,
                      xPhase: 0, yPhase: 0, xAmplitude: 0, yAmplitude: 0),
    ]
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate * animationSpeed
            
            MeshGradient(
                width: 3,
                height: 3,
                points: animatedPoints(at: time),
                colors: currentColors
            )
            .ignoresSafeArea()
        }
    }
    
    /// Calculates animated positions for all 9 control points at a given time
    private func animatedPoints(at time: TimeInterval) -> [SIMD2<Float>] {
        let t = Float(time)
        
        return pointAnimations.map { anim in
            // Calculate displacement using sine waves with unique frequencies and phases
            let xOffset = anim.xAmplitude * sin(t * anim.xFrequency * .pi * 2 + anim.xPhase)
            let yOffset = anim.yAmplitude * sin(t * anim.yFrequency * .pi * 2 + anim.yPhase)
            
            // Add secondary harmonics for more organic movement
            let xHarmonic = anim.xAmplitude * 0.3 * sin(t * anim.xFrequency * .pi * 3 + anim.xPhase * 1.5)
            let yHarmonic = anim.yAmplitude * 0.3 * sin(t * anim.yFrequency * .pi * 3 + anim.yPhase * 1.5)
            
            return SIMD2(
                anim.basePosition.x + xOffset + xHarmonic,
                anim.basePosition.y + yOffset + yHarmonic
            )
        }
    }
    
    /// Returns the current color palette, blending with success pulse if active
    private var currentColors: [Color] {
        if successPulseIntensity > 0 {
            return MeshGradientTheme.withSuccessPulse(base: theme, intensity: successPulseIntensity)
        }
        return theme.colors
    }
}

// MARK: - Preview

#Preview("Flow Theme") {
    AnimatedMeshGradientView(theme: .flow)
}

#Preview("Temple Theme") {
    AnimatedMeshGradientView(theme: .temple)
}

#Preview("Horizon Theme") {
    AnimatedMeshGradientView(theme: .horizon)
}

#Preview("Success Pulse") {
    AnimatedMeshGradientView(theme: .flow, successPulseIntensity: 0.6)
}
