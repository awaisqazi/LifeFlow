//
//  MetalWaterView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//  Enhanced with SDF-based liquid physics and optional glass refraction.
//

import SwiftUI

/// A GPU-accelerated water view using Metal shaders with SDF-based physics.
/// Features realistic fluid dynamics, Fresnel effects, caustic lighting, and tilt response.
struct MetalWaterView: View {
    let fillLevel: Double
    let tiltAngle: Double
    
    /// Optional pitch for future 3D effects
    var pitchAngle: Double = 0

    @Environment(\.scenePhase) private var scenePhase
    #if os(watchOS)
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    #endif

    @State private var startTime = Date()
    @State private var frozenElapsedTime: TimeInterval = 0

    private var isRenderingActive: Bool {
        #if os(watchOS)
        return scenePhase == .active && !isLuminanceReduced
        #else
        return scenePhase == .active
        #endif
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isRenderingActive)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startTime)
            let renderElapsed = isRenderingActive ? elapsed : frozenElapsedTime
            let time = Float(renderElapsed)

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
            .onChange(of: isRenderingActive) { _, isActive in
                if isActive {
                    startTime = timeline.date.addingTimeInterval(-frozenElapsedTime)
                } else {
                    frozenElapsedTime = elapsed
                }
            }
        }
    }
}

/// A glass vessel overlay that applies refraction and chromatic aberration.
/// Use this as a layer over background content to create premium glass distortion.
struct GlassRefractionView: View {
    /// Refractive index (glass ≈ 1.5, water ≈ 1.33)
    var refractiveIndex: Double = 1.5
    
    /// Effective thickness for refraction intensity (0.0 to 1.0)
    var thickness: Double = 0.5
    
    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(.clear)
                .layerEffect(
                    ShaderLibrary.glassRefraction(
                        .float2(geo.size.width, geo.size.height),
                        .float(Float(refractiveIndex)),
                        .float(Float(thickness))
                    ),
                    maxSampleOffset: CGSize(width: 25, height: 25)
                )
        }
    }
}

/// Combined vessel view with water physics AND glass refraction.
/// This creates the full premium liquid glass effect.
struct PremiumLiquidVesselView: View {
    let fillLevel: Double
    let tiltAngle: Double
    var pitchAngle: Double = 0
    
    var body: some View {
        ZStack {
            // SDF-based water with physics
            MetalWaterView(
                fillLevel: fillLevel,
                tiltAngle: tiltAngle,
                pitchAngle: pitchAngle
            )
            
            // Glass refraction overlay (chromatic aberration + Fresnel)
            GlassRefractionView(
                refractiveIndex: 1.45,
                thickness: 0.35
            )
            .blendMode(.overlay)
            .opacity(0.6)
        }
    }
}

#Preview {
    ZStack {
        // Background content that will be refracted
        LinearGradient(
            colors: [.purple, .blue, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack {
            Text("Background Text")
                .font(.title)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.top, 50)
        
        // Premium liquid vessel
        PremiumLiquidVesselView(fillLevel: 0.6, tiltAngle: -0.2)
            .clipShape(VesselShape())
            .frame(width: 180, height: 280)
    }
}
