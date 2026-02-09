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
    @State private var showProfileSheet: Bool = false
    
    var body: some View {
        ZStack {
            // Animated Mesh Gradient Background with psychological color themes
            LiquidBackgroundView(
                currentTab: selectedTab,
                showSuccessPulse: $showSuccessPulse
            )
            
            // Tab Content
            TabContentView(selectedTab: selectedTab)
            
            if !isGymModeActive {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showProfileSheet = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open Profile")
                        .accessibilityHint("Opens profile and TestFlight feedback tools.")
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 54)
                    Spacer()
                }
            }
            
            // Floating Tab Bar (hidden during Gym Mode)
            if !isGymModeActive {
                VStack {
                    Spacer()
                    ZStack(alignment: .bottom) {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .frame(height: 120)
                            .overlay(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.06), Color.black.opacity(0.28)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .mask(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.8), .white],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .allowsHitTesting(false)
                        
                        FloatingTabBar(selectedTab: $selectedTab)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
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
        .sheet(isPresented: $showProfileSheet) {
            ProfileCenterSheet()
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
