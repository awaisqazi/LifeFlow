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
    
    var body: some View {
        ZStack {
            // Liquid Glass Background
            LiquidBackgroundView()
            
            // Tab Content
            TabContentView(selectedTab: selectedTab)
            
            // Floating Tab Bar
            VStack {
                Spacer()
                FloatingTabBar(selectedTab: $selectedTab)
            }
        }
        .preferredColorScheme(.dark)
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
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: DayLog.self, inMemory: true)
}
