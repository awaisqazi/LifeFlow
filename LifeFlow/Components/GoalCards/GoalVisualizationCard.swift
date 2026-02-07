//
//  GoalVisualizationCard.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI

/// Polymorphic wrapper that renders the appropriate visualization card
/// based on the goal type.
struct GoalVisualizationCard: View {
    let goal: Goal
    
    var body: some View {
        switch goal.type {
        case .savings:
            SavingsJarCard(goal: goal)
        case .weightLoss:
            WeightLossChartCard(goal: goal)
        case .habit:
            HabitHeatmapCard(goal: goal)
        case .study:
            StudyProgressCard(goal: goal)
        case .custom:
            DefaultProgressCard(goal: goal)
        case .raceTraining:
            RaceTrainingVisualizationCard(goal: goal)
        }
    }
}

// MARK: - Race Training Visualization Card

/// Thin wrapper that connects a Goal (anchor) to the RaceTrackCard
/// by fetching the active TrainingPlan from the MarathonCoachManager.
struct RaceTrainingVisualizationCard: View {
    let goal: Goal
    @Environment(\.marathonCoachManager) private var coachManager

    var body: some View {
        if let plan = coachManager.activePlan {
            RaceTrackCard(plan: plan, status: coachManager.trainingStatus)
        } else {
            // Fallback if plan isn't loaded yet
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "figure.run")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text(goal.title)
                        .font(.headline)
                    Spacer()
                }
                Text("Open the app to load your training plan.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .glassEffect(in: .rect(cornerRadius: 20))
        }
    }
}

// MARK: - Study Progress Card

/// A progress bar visualization for study/time accumulation goals
struct StudyProgressCard: View {
    let goal: Goal
    
    private var plan: DailyPlan {
        goal.dailyPlan
    }
    
    private var fillLevel: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return min(goal.currentAmount / goal.targetAmount, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "book.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
                
                Text(goal.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                StatusBadge(status: plan.status)
            }
            
            // Large progress ring
            HStack(spacing: 20) {
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(.gray.opacity(0.2), lineWidth: 12)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: fillLevel)
                        .stroke(
                            AngularGradient(
                                colors: [.purple, .pink, .purple],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    // Center text
                    VStack(spacing: 2) {
                        Text("\(Int(goal.currentAmount))")
                            .font(.title.bold())
                        Text("/ \(Int(goal.targetAmount)) hrs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 100, height: 100)
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Goal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(plan.amountNeededToday, specifier: "%.1f") hours")
                            .font(.headline)
                            .foregroundStyle(plan.isUnrealistic ? .red : .purple)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Days Left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(plan.daysRemaining)")
                            .font(.headline)
                    }
                    
                    if let warning = plan.warningMessage {
                        Text(warning)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.gray.opacity(0.2))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * fillLevel)
                }
            }
            .frame(height: 8)
            
            // Percentage
            Text("\(Int(fillLevel * 100))% Complete")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }
}

// MARK: - Default Progress Card

/// A simple progress card for custom/generic goals
struct DefaultProgressCard: View {
    let goal: Goal
    
    private var plan: DailyPlan {
        goal.dailyPlan
    }
    
    private var fillLevel: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return min(goal.currentAmount / goal.targetAmount, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: goal.iconName ?? "target")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text(goal.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                StatusBadge(status: plan.status)
            }
            
            // Progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(goal.currentAmount, specifier: "%.1f")")
                        .font(.title2.bold())
                    Text("/ \(goal.targetAmount, specifier: "%.0f") \(goal.unit.symbol)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(fillLevel * 100))%")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.gray.opacity(0.2))
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * fillLevel)
                    }
                }
                .frame(height: 10)
            }
            
            Divider()
            
            // Stats row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Need")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(plan.amountNeededToday, specifier: "%.1f")")
                        .font(.subheadline.bold())
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 2) {
                    Text("Days Left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(plan.daysRemaining)")
                        .font(.subheadline.bold())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(max(0, goal.targetAmount - goal.currentAmount), specifier: "%.0f")")
                        .font(.subheadline.bold())
                }
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            GoalVisualizationCard(goal: Goal(
                title: "Vacation Fund",
                targetAmount: 2000,
                currentAmount: 1200,
                type: .savings
            ))
            
            GoalVisualizationCard(goal: Goal(
                title: "Swift Mastery",
                targetAmount: 100,
                currentAmount: 45,
                type: .study
            ))
            
            GoalVisualizationCard(goal: Goal(
                title: "Read Books",
                targetAmount: 24,
                currentAmount: 8,
                type: .custom
            ))
        }
        .padding()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}
