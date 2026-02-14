//
//  HydrationShapes.swift
//  HydrationWidget
//
//  Created by Codex on 2/9/26.
//

import SwiftUI

struct WidgetWave: Shape {
    var progress: Double
    var waveHeight: Double = 0.05
    var phase: Double = 0
    
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(progress, phase) }
        set {
            progress = newValue.first
            phase = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let clampedProgress = max(0, min(progress, 1))
        let waterline = rect.height * CGFloat(1 - clampedProgress)
        let waveAmp = rect.height * CGFloat(max(0.01, waveHeight))
        
        path.move(to: CGPoint(x: 0, y: waterline))
        
        let step: CGFloat = 1.5
        var x: CGFloat = 0
        while x <= rect.width {
            let relativeX = x / max(rect.width, 1)
            let sine = sin((relativeX * .pi * 2) + CGFloat(phase))
            let y = waterline + (waveAmp * sine)
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}
