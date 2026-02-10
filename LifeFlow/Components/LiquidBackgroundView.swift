//
//  LiquidBackgroundView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI

/// A mesmerizing animated mesh gradient background that creates the "Liquid Glass" aesthetic.
/// Uses iOS 18's MeshGradient with TimelineView-driven complex sine wave animations
/// for organic, fluid motion that never repeats exactly.
///
/// Color palettes are based on psychological color theory:
/// - Flow: Cool blues and teals for focus
/// - Temple: Warm oranges and deep purples for reflection
/// - Horizon: Cosmic violets for aspiration
/// - Success: Gold and green pulse for achievement
struct LiquidBackgroundView: View {
    /// The current tab determining the color theme
    var currentTab: LifeFlowTab = .flow
    
    /// Whether a success pulse animation is active
    @Binding var showSuccessPulse: Bool
    
    /// Multiplier for pulse intensity, used by micro-delight accessibility settings.
    var successPulseScale: Double = 1.0

    /// Controls whether photographic light leaks are composited over the mesh.
    /// Some dense sheet layouts look cleaner with pure gradient + mesh only.
    var showsAtmosphereLeaks: Bool = true
    
    /// Internal state for animating the success pulse intensity
    @State private var successPulseIntensity: Double = 0.0
    
    /// State for tracking the previous theme for smooth transitions
    @State private var previousTheme: MeshGradientTheme?
    @State private var transitionProgress: Double = 1.0
    
    init(
        currentTab: LifeFlowTab = .flow,
        showSuccessPulse: Binding<Bool> = .constant(false),
        successPulseScale: Double = 1.0,
        showsAtmosphereLeaks: Bool = true
    ) {
        self.currentTab = currentTab
        self._showSuccessPulse = showSuccessPulse
        self.successPulseScale = successPulseScale
        self.showsAtmosphereLeaks = showsAtmosphereLeaks
    }
    
    /// The current theme based on tab selection
    private var currentTheme: MeshGradientTheme {
        MeshGradientTheme.forTab(currentTab)
    }
    
    var body: some View {
        ZStack {
            AnimatedMeshGradientView(
                theme: currentTheme,
                successPulseIntensity: successPulseIntensity
            )

            if showsAtmosphereLeaks {
                // Atmosphere Layer
                Image("light_leak_dawn")
                    .resizable()
                    .blendMode(.screen)
                    .opacity(0.4)
                    .ignoresSafeArea()

                // Subtle dusk leak for contrast
                Image("light_leak_dusk")
                    .resizable()
                    .blendMode(.screen)
                    .opacity(0.2)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: currentTab) { oldValue, newValue in
            // Trigger smooth theme transition
            withAnimation(.easeInOut(duration: 0.8)) {
                // The color transition happens automatically via the theme change
            }
        }
        .onChange(of: showSuccessPulse) { _, isActive in
            if isActive {
                triggerSuccessPulse()
            }
        }
    }
    
    /// Triggers the success pulse animation sequence
    private func triggerSuccessPulse() {
        let clampedScale = max(0, min(successPulseScale, 1))
        guard clampedScale > 0.001 else {
            showSuccessPulse = false
            return
        }
        
        // Phase 1: Ramp up (0.3s)
        withAnimation(.easeOut(duration: 0.3)) {
            successPulseIntensity = 0.7 * clampedScale
        }
        
        // Phase 2: Hold at peak (0.5s), then fade (1.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 1.0)) {
                successPulseIntensity = 0.0
            }
            
            // Reset the trigger after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showSuccessPulse = false
            }
        }
    }
}

// MARK: - Environment Key for Success Pulse

/// Environment key for triggering success pulses from anywhere in the app
struct SuccessPulseTriggerKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var triggerSuccessPulse: () -> Void {
        get { self[SuccessPulseTriggerKey.self] }
        set { self[SuccessPulseTriggerKey.self] = newValue }
    }
}

// MARK: - Previews

#Preview("Flow Theme") {
    LiquidBackgroundView(currentTab: .flow)
        .preferredColorScheme(.dark)
}

#Preview("Temple Theme") {
    LiquidBackgroundView(currentTab: .temple)
        .preferredColorScheme(.dark)
}

#Preview("Horizon Theme") {
    LiquidBackgroundView(currentTab: .horizon)
        .preferredColorScheme(.dark)
}

#Preview("Success Pulse") {
    struct SuccessPreview: View {
        @State private var showPulse = false
        
        var body: some View {
            ZStack {
                LiquidBackgroundView(currentTab: .flow, showSuccessPulse: $showPulse)
                
                Button("Trigger Success") {
                    showPulse = true
                }
                .buttonStyle(.borderedProminent)
            }
            .preferredColorScheme(.dark)
        }
    }
    
    return SuccessPreview()
}
