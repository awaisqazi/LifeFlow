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
    @State private var isEditing = false
    @State private var goalToDelete: Goal?
    
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
                                
                                // Edit/Done button (only show if there are goals)
                                if !goals.isEmpty {
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            isEditing.toggle()
                                        }
                                    } label: {
                                        Text(isEditing ? "Done" : "Edit")
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                isEditing 
                                                    ? Color.green.opacity(0.2) 
                                                    : Color.secondary.opacity(0.15),
                                                in: Capsule()
                                            )
                                            .foregroundStyle(isEditing ? .green : .primary)
                                    }
                                }
                                
                                if !isEditing {
                                    Button {
                                        showingAddGoal = true
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.purple)
                                    }
                                }
                            }
                            
                            Text(isEditing ? "Swipe left or tap ⊖ to delete" : "Your long-term challenges")
                                .font(.subheadline)
                                .foregroundStyle(isEditing ? .red.opacity(0.8) : .secondary)
                            
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
                                        SwipeableGoalRow(
                                            goal: goal,
                                            isEditing: isEditing,
                                            colorForGoal: colorForGoal,
                                            onDelete: { goalToDelete = goal }
                                        )
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .glassEffect(in: .rect(cornerRadius: 20))
                        
                        // Hydration Goal Settings Card
                        HydrationGoalCard()
                        
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
        .alert("Delete Goal?", isPresented: .init(
            get: { goalToDelete != nil },
            set: { if !$0 { goalToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                goalToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let goal = goalToDelete {
                    deleteGoal(goal)
                }
                goalToDelete = nil
            }
        } message: {
            Text("This will permanently delete \"\(goalToDelete?.title ?? "this goal")\" and all its progress data.")
        }
    }
    
    private func iconForGoal(_ goal: Goal) -> String {
        goal.type.icon
    }
    
    private func colorForGoal(_ goal: Goal) -> Color {
        switch goal.type {
        case .savings: return .yellow
        case .weightLoss: return .green
        case .habit: return .orange
        case .study: return .purple
        case .raceTraining: return .green
        case .custom: return .blue
        }
    }
    
    private func deleteGoal(_ goal: Goal) {
        withAnimation {
            modelContext.delete(goal)
            try? modelContext.save()
        }
    }
}

/// A goal row with swipe-to-delete and tap delete button functionality
struct SwipeableGoalRow: View {
    let goal: Goal
    let isEditing: Bool
    let colorForGoal: (Goal) -> Color
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    
    private let deleteThreshold: CGFloat = -100
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background (revealed on swipe)
            if isEditing {
                HStack {
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "trash.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 44)
                    }
                    .background(Color.red)
                    .cornerRadius(8)
                }
                .opacity(offset < -20 ? 1 : 0)
            }
            
            // Main row content
            HStack(spacing: 12) {
                // Delete button (visible in edit mode)
                if isEditing {
                    Button(action: onDelete) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                GoalRow(
                    icon: goal.type.icon,
                    title: goal.title,
                    progress: goal.progressPercentage,
                    color: colorForGoal(goal)
                )
            }
            .background(Color(uiColor: .systemBackground).opacity(0.01)) // For hit testing
            .offset(x: offset)
            .gesture(
                isEditing ? 
                DragGesture()
                    .onChanged { gesture in
                        isDragging = true
                        // Only allow left swipe
                        if gesture.translation.width < 0 {
                            offset = gesture.translation.width
                        }
                    }
                    .onEnded { gesture in
                        isDragging = false
                        withAnimation(.spring(response: 0.3)) {
                            if offset < deleteThreshold {
                                // Trigger delete
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                onDelete()
                            }
                            // Reset position
                            offset = 0
                        }
                    }
                : nil
            )
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Goal", systemImage: "trash")
                }
            }
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

// MARK: - Hydration Goal Settings Card

/// Settings card for configuring daily hydration goal
struct HydrationGoalCard: View {
    @State private var cupsGoal: Int = HydrationSettings.load().dailyCupsGoal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "drop.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                
                Text("Hydration Goal")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("\(cupsGoal * 8) oz/day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.15), in: Capsule())
            }
            
            // Description
            Text("Set your daily water intake goal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Stepper with visual
            VStack(spacing: 12) {
                // Custom stepper row
                HStack {
                    Button {
                        if cupsGoal > 4 {
                            cupsGoal -= 1
                            saveGoal()
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(cupsGoal > 4 ? .cyan : .secondary.opacity(0.3))
                    }
                    .disabled(cupsGoal <= 4)
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("\(cupsGoal)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText(value: Double(cupsGoal)))
                            .animation(.spring(response: 0.3), value: cupsGoal)
                        
                        Text("cups")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        if cupsGoal < 16 {
                            cupsGoal += 1
                            saveGoal()
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(cupsGoal < 16 ? .cyan : .secondary.opacity(0.3))
                    }
                    .disabled(cupsGoal >= 16)
                }
                .padding(.horizontal)
                
                // Water drop visualization
                HStack(spacing: 6) {
                    ForEach(0..<cupsGoal, id: \.self) { index in
                        WaterDroplet(
                            isFilled: true,
                            delay: Double(index) * 0.05
                        )
                    }
                    
                    // Empty slots to show capacity
                    ForEach(cupsGoal..<16, id: \.self) { index in
                        WaterDroplet(
                            isFilled: false,
                            delay: 0
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }
    
    private func saveGoal() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        let settings = HydrationSettings(dailyCupsGoal: cupsGoal)
        settings.save()
    }
}

/// Individual water droplet for the goal visualization
struct WaterDroplet: View {
    let isFilled: Bool
    let delay: Double
    
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "drop.fill")
            .font(.system(size: 14))
            .foregroundStyle(
                isFilled
                    ? LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .top,
                        endPoint: .bottom
                      )
                    : LinearGradient(
                        colors: [.secondary.opacity(0.2), .secondary.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                      )
            )
            .scaleEffect(isAnimating && isFilled ? 1.0 : 0.8)
            .opacity(isAnimating || !isFilled ? 1.0 : 0.5)
            .animation(
                .spring(response: 0.4, dampingFraction: 0.6).delay(delay),
                value: isAnimating
            )
            .onAppear {
                if isFilled {
                    isAnimating = true
                }
            }
            .onChange(of: isFilled) { _, newValue in
                if newValue {
                    isAnimating = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isAnimating = true
                    }
                }
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
