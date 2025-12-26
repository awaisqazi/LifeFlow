//
//  MetalWaterView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI

/// A GPU-accelerated water view using Metal shaders.
/// Features realistic fluid dynamics, caustic lighting, and tilt response.
struct MetalWaterView: View {
    let fillLevel: Double
    let tiltAngle: Double
    
    @State private var startTime = Date()
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = Float(timeline.date.timeIntervalSince(startTime))
            
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.blue) // Base color (shader will override)
                    .colorEffect(
                        ShaderLibrary.waterEffect(
                            .float2(geo.size.width, geo.size.height),
                            .float(time),
                            .float(Float(min(fillLevel, 0.92))),
                            .float(Float(tiltAngle))
                        )
                    )
            }
            .drawingGroup() // GPU acceleration
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        MetalWaterView(fillLevel: 0.5, tiltAngle: -0.3)
            .clipShape(VesselShape())
            .frame(width: 180, height: 280)
    }
}
