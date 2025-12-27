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
    @Query(sort: \Goal.deadline, order: .forward) private var goals: [Goal]
    
    /// Get or create today's DayLog
    private var todayLog: DayLog {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        if let existing = dayLogs.first(where: { $0.date >= startOfDay }) {
            return existing
        }
        // Ideally we don't insert in computed prop view body, but for simplicity in this prototype.
        // A better pattern is .onAppear check.
        // For now, let's just return the first one or a dummy if empty to avoid write-in-view issues,
        // but we need a bindable.
        // Let's use a safe unwrapper.
        return dayLogs.first ?? DayLog() // Should handle creation in onAppear
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HeaderView(
                        title: "Flow",
                        subtitle: "Daily Input Stream"
                    )
                    .id("top")
                    
                    VStack(spacing: 16) {
                        // 1. System Cards
                        HydrationVesselCard(dayLog: todayLog)
                        GymCard(dayLog: todayLog)
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // 2. Goal Cards
                        if goals.isEmpty {
                            ContentUnavailableView(
                                "No Goals Active",
                                systemImage: "mountain.2",
                                description: Text("Add goals in Horizon to see them here.")
                            )
                        } else {
                            ForEach(goals) { goal in
                                GoalActionCard(goal: goal, dayLog: todayLog) {
                                    withAnimation(.smooth) {
                                        proxy.scrollTo(goal.id, anchor: .center)
                                    }
                                }
                                .id(goal.id)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 400)
                }
                .padding(.top, 60)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .onAppear {
            ensureTodayLogExists()
        }
    }
    
    private func ensureTodayLogExists() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        if dayLogs.first(where: { $0.date >= startOfDay }) == nil {
            let newLog = DayLog(date: Date())
            modelContext.insert(newLog)
            try? modelContext.save()
        }
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
