//
//  VesselShape.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI

/// A custom shape for the water vessel/glass container.
/// Designed to work with `.glassEffect(in:)` for the Liquid Glass aesthetic.
/// Features a rounded bottom and slightly tapered sides.
struct VesselShape: Shape {
    /// How much the vessel tapers (0 = straight sides, 1 = very tapered)
    var taperAmount: CGFloat = 0.15
    
    /// Corner radius for the bottom
    var bottomCornerRadius: CGFloat = 40
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let taper = width * taperAmount
        
        // Top edge (wider)
        let topLeft = CGPoint(x: 0, y: 0)
        let topRight = CGPoint(x: width, y: 0)
        
        // Bottom edge (narrower due to taper)
        let bottomLeft = CGPoint(x: taper, y: height)
        let bottomRight = CGPoint(x: width - taper, y: height)
        
        // Start from top-left
        path.move(to: topLeft)
        
        // Right side (tapered)
        path.addLine(to: topRight)
        
        // Bottom-right curve
        let bottomRightControl = CGPoint(x: width - taper, y: height - bottomCornerRadius)
        path.addLine(to: CGPoint(x: width, y: height - bottomCornerRadius * 1.5))
        path.addQuadCurve(
            to: CGPoint(x: width - taper - bottomCornerRadius * 0.5, y: height),
            control: bottomRightControl
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: taper + bottomCornerRadius * 0.5, y: height))
        
        // Bottom-left curve
        let bottomLeftControl = CGPoint(x: taper, y: height - bottomCornerRadius)
        path.addQuadCurve(
            to: CGPoint(x: 0, y: height - bottomCornerRadius * 1.5),
            control: bottomLeftControl
        )
        
        // Left side (back to top)
        path.addLine(to: topLeft)
        
        path.closeSubpath()
        
        return path
    }
}

/// A shape that represents just the vessel outline (for borders)
struct VesselOutlineShape: Shape {
    var taperAmount: CGFloat = 0.15
    var bottomCornerRadius: CGFloat = 40
    var lineWidth: CGFloat = 2
    
    func path(in rect: CGRect) -> Path {
        VesselShape(
            taperAmount: taperAmount,
            bottomCornerRadius: bottomCornerRadius
        ).path(in: rect)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VesselShape()
            .fill(.cyan.opacity(0.2))
            .frame(width: 200, height: 300)
            .overlay {
                VesselOutlineShape()
                    .stroke(.white.opacity(0.3), lineWidth: 2)
            }
    }
}
