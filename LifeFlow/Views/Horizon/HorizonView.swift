//
//  HorizonView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData

/// The Horizon tab - your long-term goals await.
/// Tracks debt payoff, skill building, and major life challenges.
struct HorizonView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.deadline, order: .forward) private var goals: [Goal]
    @State private var showingAddGoal = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HeaderView(
                    title: "Horizon",
                    subtitle: "Chase Your Dreams"
                )
                
                // Glass effect container for blending goal cards
                GlassEffectContainer(spacing: 16) {
                    VStack(spacing: 16) {
                        // Long-term Goals Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "mountain.2.fill")
                                    .font(.title2)
                                    .foregroundStyle(.purple)
                                
                                Text("Life Goals")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Button {
                                    showingAddGoal = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.purple)
                                }
                            }
                            
                            Text("Your long-term challenges")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            // Goals list
                            VStack(spacing: 12) {
                                if goals.isEmpty {
                                    ContentUnavailableView(
                                        "No Goals Yet",
                                        systemImage: "mountain.2",
                                        description: Text("Set your sights on the horizon.")
                                    )
                                    .padding(.vertical)
                                } else {
                                    ForEach(goals) { goal in
                                        GoalRow(
                                            icon: iconForGoal(goal),
                                            title: goal.title,
                                            progress: goal.currentAmount / max(goal.targetAmount, 1),
                                            color: colorForGoal(goal)
                                        )
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .glassEffect(in: .rect(cornerRadius: 20))
                        
                        // Motivation Card
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.largeTitle)
                                .foregroundStyle(.yellow)
                            
                            Text("Every step counts")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text("Small progress is still progress. Keep going!")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .glassEffect(in: .rect(cornerRadius: 20))
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100) // Space for tab bar
            }
            .padding(.top, 60)
        }
        .sheet(isPresented: $showingAddGoal) {
            AddGoalSheet()
        }
    }
    
    private func iconForGoal(_ goal: Goal) -> String {
        switch goal.type {
        case .targetValue: return "flag.fill"
        case .frequency: return "repeat"
        case .dailyHabit: return "checkmark.seal.fill"
        }
    }
    
    private func colorForGoal(_ goal: Goal) -> Color {
        switch goal.type {
        case .targetValue: return .green
        case .frequency: return .blue
        case .dailyHabit: return .orange
        }
    }
}

/// A single goal row with animated progress bar
struct GoalRow: View {
    let icon: String
    let title: String
    let progress: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.primary.opacity(0.1))
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 6)
            }
            
            Text("\(Int(progress * 100))%")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
        }
    }
}

#Preview {
    ZStack {
        LiquidBackgroundView()
        HorizonView()
    }
    .modelContainer(for: Goal.self, inMemory: true)
    .preferredColorScheme(.dark)
}
