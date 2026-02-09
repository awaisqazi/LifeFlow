//
//  FloatingTabBar.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import UIKit

// MARK: - Tab Enum

/// Represents the three main tabs in LifeFlow
// Enum moved to Models/LifeFlowTab.swift

// MARK: - UIKit Blur Fallback

/// UIViewRepresentable wrapper for UIVisualEffectView with systemUltraThinMaterial
/// Used as fallback for older iOS versions that don't support SwiftUI glassEffect
struct UltraThinBlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemUltraThinMaterialDark
    var cornerRadius: CGFloat = 0
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: style)
        let visualEffectView = UIVisualEffectView(effect: blurEffect)
        visualEffectView.layer.cornerRadius = cornerRadius
        visualEffectView.clipsToBounds = true
        visualEffectView.layer.cornerCurve = .continuous
        return visualEffectView
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
        uiView.layer.cornerRadius = cornerRadius
    }
}

// MARK: - Enhanced Glass Capsule Background

/// Enhanced glass background with multiple visual layers for premium feel
struct EnhancedGlassCapsule: View {
    var body: some View {
        ZStack {
            // Base blur layer using UIKit for maximum compatibility
            UltraThinBlurView(
                style: .systemUltraThinMaterialDark,
                cornerRadius: 40
            )
            
            // Subtle gradient overlay for depth
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Inner highlight border for glass edge effect
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
            
            // Secondary subtle inner glow
            Capsule()
                .strokeBorder(
                    Color.white.opacity(0.08),
                    lineWidth: 1.5
                )
                .blur(radius: 1)
        }
    }
}

// MARK: - Floating Tab Bar

/// A floating glass capsule tab bar with enhanced visual effects.
/// Features:
/// - UIKit blur fallback (systemUltraThinMaterial) for older iOS
/// - glassEffect for iOS 26+
/// - Outer shadow for floating depth
/// - Inner glow and gradient for premium glass aesthetic
/// - Haptic feedback on every tab switch
struct FloatingTabBar: View {
    @Binding var selectedTab: LifeFlowTab
    @Namespace private var tabNamespace
    
    var body: some View {
        tabBarContent
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private var tabBarContent: some View {
        if #available(iOS 26.0, *) {
            // iOS 26+: Use native glassEffect with enhancements
            GlassEffectContainer(spacing: 20) {
                tabButtons
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background {
                        // Enhanced glass with gradient overlay
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.08),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .overlay {
                        // Subtle border highlight
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
            // Outer shadow for floating depth
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        } else {
            // Fallback for older iOS: UIVisualEffectView with systemUltraThinMaterial
            tabButtons
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background {
                    EnhancedGlassCapsule()
                }
                .clipShape(Capsule())
                // Outer shadow for floating depth
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private var tabButtons: some View {
        HStack(spacing: 0) {
            ForEach(LifeFlowTab.allCases, id: \.self) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: tabNamespace
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                    // Haptic feedback - grounding digital in physical sensation
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
            }
        }
    }
}

// MARK: - Tab Button

/// Individual tab button within the floating tab bar
struct TabButton: View {
    let tab: LifeFlowTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var isPressedPop: Bool = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.52)) {
                isPressedPop = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
                    isPressedPop = false
                }
            }
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: .medium))
                    .frame(height: 24)
                    .symbolEffect(.bounce, value: isSelected)
                    .scaleEffect(isPressedPop ? 1.14 : 1.0)
                
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background {
                if isSelected {
                    selectedTabBackground
                        .matchedGeometryEffect(id: "TAB_INDICATOR", in: namespace)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
    }
    
    @ViewBuilder
    private var selectedTabBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .fill(.tint.opacity(0.3))
                .glassEffect(.regular.interactive())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                }
        } else {
            // Fallback for older iOS
            ZStack {
                Capsule()
                    .fill(.tint.opacity(0.3))
                
                UltraThinBlurView(
                    style: .systemThinMaterialDark,
                    cornerRadius: 20
                )
                .clipShape(Capsule())
                .opacity(0.5)
                
                Capsule()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LiquidBackgroundView()
        
        VStack {
            Spacer()
            FloatingTabBar(selectedTab: .constant(.flow))
        }
    }
    .preferredColorScheme(.dark)
}
