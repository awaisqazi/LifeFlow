//
//  FlowDashboardView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData

/// The Flow tab - displays the daily summary dashboard.
/// Shows a snapshot of water intake, gym status, and momentum metrics.
struct FlowDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DayLog.date, order: .reverse) private var dayLogs: [DayLog]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HeaderView(
                    title: "Flow",
                    subtitle: "Your Daily Momentum"
                )
                
                // Glass cards using native Liquid Glass
                GlassEffectContainer(spacing: 16) {
                    VStack(spacing: 16) {
                        // Today's Overview Card
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Today's Overview", systemImage: "calendar")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text("Your wellness metrics will appear here")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .glassEffect(in: .rect(cornerRadius: 20))
                        
                        // Quick Stats Row
                        HStack(spacing: 12) {
                            QuickStatCard(
                                icon: "drop.fill",
                                value: "0",
                                unit: "oz",
                                color: .cyan
                            )
                            
                            QuickStatCard(
                                icon: "figure.strengthtraining.traditional",
                                value: "—",
                                unit: "gym",
                                color: .orange
                            )
                            
                            QuickStatCard(
                                icon: "flame.fill",
                                value: "0",
                                unit: "streak",
                                color: .red
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100) // Space for tab bar
            }
            .padding(.top, 60)
        }
    }
}

/// Quick stat card with Liquid Glass effect
struct QuickStatCard: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

/// Reusable header component for each tab
struct HeaderView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.5)
        }
        .padding(.bottom, 8)
    }
}

/// Reusable glass card component using native Liquid Glass
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .glassEffect(in: .rect(cornerRadius: cornerRadius))
    }
}

#Preview {
    ZStack {
        LiquidBackgroundView()
        FlowDashboardView()
    }
    .modelContainer(for: DayLog.self, inMemory: true)
    .preferredColorScheme(.dark)
}
