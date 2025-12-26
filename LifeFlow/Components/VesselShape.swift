//
//  VesselShape.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI

/// A premium glass vessel shape with elegant curves.
/// Designed to work with `.glassEffect(in:)` for the Liquid Glass aesthetic.
struct VesselShape: Shape {
    /// How rounded the vessel is (0 = angular, 1 = very rounded)
    var roundness: CGFloat = 0.4
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Control points for elegant curves
        let topWidth = width * 0.98
        let bottomWidth = width * 0.7
        let topInset = (width - topWidth) / 2
        let bottomInset = (width - bottomWidth) / 2
        
        // Neck taper (top of glass is slightly narrower)
        let neckHeight = height * 0.08
        let neckWidth = width * 0.94
        let neckInset = (width - neckWidth) / 2
        
        // Start from top-left
        path.move(to: CGPoint(x: neckInset, y: 0))
        
        // Top edge
        path.addLine(to: CGPoint(x: width - neckInset, y: 0))
        
        // Right side - elegant curve widening then tapering
        path.addCurve(
            to: CGPoint(x: width - topInset, y: neckHeight),
            control1: CGPoint(x: width - neckInset + 5, y: neckHeight * 0.3),
            control2: CGPoint(x: width - topInset, y: neckHeight * 0.7)
        )
        
        // Right side body
        path.addCurve(
            to: CGPoint(x: width - bottomInset, y: height * 0.85),
            control1: CGPoint(x: width - topInset + 5, y: height * 0.3),
            control2: CGPoint(x: width - bottomInset + 10, y: height * 0.6)
        )
        
        // Bottom right curve
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height),
            control1: CGPoint(x: width - bottomInset, y: height * 0.95),
            control2: CGPoint(x: width * 0.65, y: height)
        )
        
        // Bottom left curve
        path.addCurve(
            to: CGPoint(x: bottomInset, y: height * 0.85),
            control1: CGPoint(x: width * 0.35, y: height),
            control2: CGPoint(x: bottomInset, y: height * 0.95)
        )
        
        // Left side body
        path.addCurve(
            to: CGPoint(x: topInset, y: neckHeight),
            control1: CGPoint(x: bottomInset - 10, y: height * 0.6),
            control2: CGPoint(x: topInset - 5, y: height * 0.3)
        )
        
        // Left side neck curve back to start
        path.addCurve(
            to: CGPoint(x: neckInset, y: 0),
            control1: CGPoint(x: topInset, y: neckHeight * 0.7),
            control2: CGPoint(x: neckInset - 5, y: neckHeight * 0.3)
        )
        
        path.closeSubpath()
        
        return path
    }
}

/// Inner highlight shape for glass reflection effect
struct VesselHighlightShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Left side highlight - thin curved strip
        path.move(to: CGPoint(x: width * 0.12, y: height * 0.1))
        
        path.addCurve(
            to: CGPoint(x: width * 0.18, y: height * 0.6),
            control1: CGPoint(x: width * 0.08, y: height * 0.25),
            control2: CGPoint(x: width * 0.1, y: height * 0.45)
        )
        
        path.addCurve(
            to: CGPoint(x: width * 0.22, y: height * 0.1),
            control1: CGPoint(x: width * 0.2, y: height * 0.45),
            control2: CGPoint(x: width * 0.18, y: height * 0.25)
        )
        
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ZStack {
            VesselShape()
                .fill(.cyan.opacity(0.15))
            
            VesselShape()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
            
            VesselHighlightShape()
                .fill(.white.opacity(0.15))
        }
        .frame(width: 180, height: 280)
    }
}
