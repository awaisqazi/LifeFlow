//
//  MainTabView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData

/// The root view of LifeFlow containing the liquid background,
/// tab content, and floating tab bar navigation.
struct MainTabView: View {
    @State private var selectedTab: LifeFlowTab = .flow
    @State private var showSuccessPulse: Bool = false
    @State private var isGymModeActive: Bool = false
    
    var body: some View {
        ZStack {
            // Animated Mesh Gradient Background with psychological color themes
            LiquidBackgroundView(
                currentTab: selectedTab,
                showSuccessPulse: $showSuccessPulse
            )
            
            // Tab Content
            TabContentView(selectedTab: selectedTab)
            
            // Floating Tab Bar (hidden during Gym Mode)
            if !isGymModeActive {
                VStack {
                    Spacer()
                    FloatingTabBar(selectedTab: $selectedTab)
                }
            }
        }
        .preferredColorScheme(.dark)
        // Provide success pulse trigger to child views
        .environment(\.triggerSuccessPulse) {
            showSuccessPulse = true
        }
        // Provide Gym Mode enter/exit actions to child views
        .environment(\.enterGymMode) {
            isGymModeActive = true
        }
        .environment(\.exitGymMode) {
            isGymModeActive = false
        }
        .environment(\.openTab) { tab in
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                selectedTab = tab
            }
        }
        // Inject shared GymModeManager for workout state persistence
        .environment(\.gymModeManager, AppDependencyManager.shared.gymModeManager)
        // Full-screen Gym Mode modal
        .fullScreenCover(isPresented: $isGymModeActive) {
            GymModeView()
                .environment(AppDependencyManager.shared.gymModeManager)
                .environment(AppDependencyManager.shared.marathonCoachManager)
                .environment(AppDependencyManager.shared.healthKitManager)
        }
    }
}

/// Switches between tab content views based on selection
struct TabContentView: View {
    let selectedTab: LifeFlowTab
    
    var body: some View {
        Group {
            switch selectedTab {
            case .flow:
                FlowDashboardView()
            case .temple:
                TempleView()
            case .horizon:
                HorizonView()
            }
        }
        .id(selectedTab) // Force view identity change for animation
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: DayLog.self, inMemory: true)
}
