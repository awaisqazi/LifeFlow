//
//  LiquidBackgroundView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI

/// A mesmerizing animated mesh gradient background that creates the "Liquid Glass" aesthetic.
/// Uses SwiftUI's MeshGradient with animated control points for organic, fluid motion.
struct LiquidBackgroundView: View {
    /// Animation phase driver
    @State private var phase: CGFloat = 0
    
    /// Calm, premium color palette
    private let colors: [Color] = [
        Color(red: 0.05, green: 0.10, blue: 0.20),  // Deep navy
        Color(red: 0.10, green: 0.15, blue: 0.30),  // Midnight blue
        Color(red: 0.08, green: 0.20, blue: 0.35),  // Ocean depth
        Color(red: 0.15, green: 0.12, blue: 0.30),  // Deep purple
        Color(red: 0.05, green: 0.18, blue: 0.28),  // Teal shadow
        Color(red: 0.12, green: 0.08, blue: 0.25),  // Violet night
        Color(red: 0.06, green: 0.12, blue: 0.22),  // Slate blue
        Color(red: 0.10, green: 0.20, blue: 0.35),  // Steel blue
        Color(red: 0.08, green: 0.15, blue: 0.28),  // Deep teal
    ]
    
    var body: some View {
        GeometryReader { geometry in
            MeshGradient(
                width: 3,
                height: 3,
                points: animatedPoints,
                colors: colors
            )
            .ignoresSafeArea()
            .onAppear {
                // Start the continuous animation
                withAnimation(
                    .easeInOut(duration: 8)
                    .repeatForever(autoreverses: true)
                ) {
                    phase = 1
                }
            }
        }
    }
    
    /// Calculates animated mesh control points with organic drift
    private var animatedPoints: [SIMD2<Float>] {
        let drift: Float = 0.05  // Subtle movement range
        let p = Float(phase)
        
        // 3x3 grid of control points with gentle organic motion
        return [
            // Row 0
            SIMD2(0.0, 0.0),
            SIMD2(0.5 + drift * sin(p * .pi), 0.0),
            SIMD2(1.0, 0.0),
            
            // Row 1 - more movement in the middle
            SIMD2(0.0, 0.5 + drift * cos(p * .pi * 0.7)),
            SIMD2(0.5 + drift * sin(p * .pi * 1.3), 0.5 + drift * cos(p * .pi * 0.9)),
            SIMD2(1.0, 0.5 + drift * sin(p * .pi * 0.6)),
            
            // Row 2
            SIMD2(0.0, 1.0),
            SIMD2(0.5 + drift * cos(p * .pi * 0.8), 1.0),
            SIMD2(1.0, 1.0),
        ]
    }
}

#Preview {
    LiquidBackgroundView()
}
