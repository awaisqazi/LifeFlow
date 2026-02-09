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
    @State private var successPulseScale: Double = LifeFlowExperienceSettings.load().microDelightIntensity.successPulseScale
    @State private var isGymModeActive: Bool = false
    @State private var showProfileSheet: Bool = false
    
    var body: some View {
        ZStack {
            // Animated Mesh Gradient Background with psychological color themes
            LiquidBackgroundView(
                currentTab: selectedTab,
                showSuccessPulse: $showSuccessPulse,
                successPulseScale: successPulseScale
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
            let intensity = LifeFlowExperienceSettings.load().microDelightIntensity
            guard intensity.isEnabled else { return }
            successPulseScale = intensity.successPulseScale
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
            selectedTab = tab
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
    @State private var loadedTabs: Set<LifeFlowTab> = [.flow]
    
    var body: some View {
        ZStack {
            page(for: .flow)
            page(for: .temple)
            page(for: .horizon)
        }
        // Keep tab content switching seamless by avoiding blended crossfades
        // between full-screen pages (which can ghost headers during transition).
        .transaction { transaction in
            transaction.animation = nil
        }
        .onAppear {
            loadedTabs.insert(selectedTab)
        }
        .onChange(of: selectedTab) { _, newValue in
            loadedTabs.insert(newValue)
        }
    }
    
    @ViewBuilder
    private func page(for tab: LifeFlowTab) -> some View {
        Group {
            if loadedTabs.contains(tab) {
                content(for: tab)
            } else {
                Color.clear
            }
        }
        .opacity(selectedTab == tab ? 1 : 0)
        .allowsHitTesting(selectedTab == tab)
        .accessibilityHidden(selectedTab != tab)
        .zIndex(selectedTab == tab ? 1 : 0)
    }
    
    @ViewBuilder
    private func content(for tab: LifeFlowTab) -> some View {
        switch tab {
        case .flow:
            FlowDashboardView()
        case .temple:
            TempleView()
        case .horizon:
            HorizonView()
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: DayLog.self, inMemory: true)
}
