//
//  FloatingTabBar.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI

/// Represents the three main tabs in LifeFlow
enum LifeFlowTab: String, CaseIterable {
    case flow = "Flow"
    case temple = "Temple"
    case horizon = "Horizon"
    
    /// SF Symbol icon for each tab
    var icon: String {
        switch self {
        case .flow: return "drop.fill"
        case .temple: return "figure.strengthtraining.traditional"
        case .horizon: return "mountain.2.fill"
        }
    }
    
    /// Descriptive subtitle for each tab
    var subtitle: String {
        switch self {
        case .flow: return "Dashboard"
        case .temple: return "Fitness"
        case .horizon: return "Goals"
        }
    }
}

/// A floating glass capsule tab bar using Apple's native Liquid Glass effect.
/// Features organic blending, haptic feedback, and smooth morphing transitions.
struct FloatingTabBar: View {
    @Binding var selectedTab: LifeFlowTab
    @Namespace private var tabNamespace
    
    var body: some View {
        // GlassEffectContainer enables blending between sibling glass views
        GlassEffectContainer(spacing: 20) {
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
                        // Haptic feedback
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .glassEffect(in: .capsule)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 20)
    }
}

/// Individual tab button within the floating tab bar
struct TabButton: View {
    let tab: LifeFlowTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: .medium))
                    .frame(height: 24)
                
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
                    Capsule()
                        .fill(.tint.opacity(0.3))
                        .glassEffect()
                        .matchedGeometryEffect(id: "TAB_INDICATOR", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}

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
