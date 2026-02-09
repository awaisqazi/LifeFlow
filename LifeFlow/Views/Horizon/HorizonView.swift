//
//  HorizonView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData

/// The Horizon tab - your long-term goals await.
/// Uses a panorama card rail so each goal feels like an aspiration window.
struct HorizonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.marathonCoachManager) private var coachManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \Goal.deadline, order: .forward) private var goals: [Goal]

    @State private var showingAddGoal = false
    @State private var isEditing = false
    @State private var goalToDelete: Goal?

    private var completionPercentage: Double {
        guard !goals.isEmpty else { return 0 }
        let aggregate = goals.reduce(0) { $0 + $1.progressPercentage }
        return aggregate / Double(goals.count)
    }

    private var motionAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)
    }

    var body: some View {
        ZStack {
            SanctuaryTimeBackdrop(includeMeshOverlay: true)

            ScrollView {
                VStack(spacing: 22) {
                    SanctuaryHeaderView(
                        title: "Horizon",
                        subtitle: "Build your future one deliberate step at a time.",
                        kicker: "Aspirations"
                    )

                    horizonMetaStrip

                    panoramaGoalsSection

                    HydrationGoalCard()

                    motivationPanel
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)
                .padding(.bottom, 120)
            }
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

    private var horizonMetaStrip: some View {
        HStack(spacing: 10) {
            horizonChip(title: "Goals", value: "\(goals.count)", accent: .cyan)
            horizonChip(title: "Momentum", value: "\(Int(completionPercentage * 100))%", accent: .green)

            Spacer(minLength: 8)

            Button {
                if reduceMotion {
                    isEditing.toggle()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isEditing.toggle()
                    }
                }
            } label: {
                Text(isEditing ? "Done" : "Edit")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background((isEditing ? Color.green : Color.white).opacity(isEditing ? 0.2 : 0.12), in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isEditing ? "Finish Editing Goals" : "Edit Goals")
            .accessibilityHint("Allows deleting goals from the panorama.")

            Button {
                showingAddGoal = true
            } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.15), in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add Goal")
            .accessibilityHint("Create a new long-term goal.")
        }
    }

    private func horizonChip(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accent.opacity(0.32), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var panoramaGoalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SanctuarySectionHeader(title: "Aspiration Windows")

            if goals.isEmpty {
                VStack(spacing: 24) {
                    Image("sculpture_mountain")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 220)
                        .shadow(color: .indigo.opacity(0.4), radius: 30)
                        .accessibilityHidden(true)
                    
                    VStack(spacing: 8) {
                        Text("The Horizon Awaits")
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(.white)
                        
                        Text("Set an aspiration to begin your journey.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Button {
                        showingAddGoal = true
                    } label: {
                        Label("Create Aspiration", systemImage: "plus")
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    .opacity(0.8),
                                in: Capsule()
                            )
                            .foregroundStyle(.white)
                            .shadow(color: .purple.opacity(0.4), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens goal creation.")
                }
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity)
            } else {
                GeometryReader { geometry in
                    let viewportWidth = max(geometry.size.width, 320)
                    let cardWidth = min(320, max(262, viewportWidth * 0.76))
                    let cardHeight = max(376, min(410, cardWidth * 1.31))
                    let spacing: CGFloat = viewportWidth < 390 ? 14 : 18
                    let leadingInset = max(8, (viewportWidth - cardWidth) / 2)
                    let trailingCardWidth = max(112, min(136, cardWidth * 0.42))
                    let trailingInset = max(14, (viewportWidth - trailingCardWidth) / 2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing) {
                            Spacer(minLength: 0)
                                .frame(width: leadingInset)

                            ForEach(goals) { goal in
                                PanoramaGoalCard(
                                    goal: goal,
                                    accent: colorForGoal(goal),
                                    isEditing: isEditing,
                                    reduceMotion: reduceMotion,
                                    cardWidth: cardWidth,
                                    cardHeight: cardHeight,
                                    viewportWidth: viewportWidth,
                                    onDelete: { goalToDelete = goal }
                                )
                            }

                            AddGoalPanoramaCard(
                                width: trailingCardWidth,
                                height: cardHeight
                            ) {
                                showingAddGoal = true
                            }

                            Spacer(minLength: 0)
                                .frame(width: trailingInset)
                        }
                        .padding(.vertical, 8)
                    }
                    .coordinateSpace(name: "HorizonPanorama")
                }
                .frame(height: 442)
                .animation(motionAnimation, value: goals.count)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var motivationPanel: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)

            Text("Every step counts")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Small progress is still progress. Keep going!")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
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
            if goal.type == .raceTraining {
                let hasOtherRaceGoals = goals.contains { $0.id != goal.id && $0.type == .raceTraining }
                if !hasOtherRaceGoals {
                    coachManager.cancelPlan(modelContext: modelContext)
                }
            }

            modelContext.delete(goal)
            try? modelContext.save()
        }
    }
}

private struct GhostExampleGoalCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.white.opacity(0.58))
                    .accessibilityHidden(true)
                Text("Example Aspiration")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Text("Run a Marathon")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))
            
            Text("Build this into your own horizon and track progress daily.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.45), .mint.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(maxWidth: 120)
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [6]))
                .foregroundStyle(Color.white.opacity(0.2))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example goal card. Run a Marathon.")
    }
}

private struct PanoramaGoalCard: View {
    let goal: Goal
    let accent: Color
    let isEditing: Bool
    let reduceMotion: Bool
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let viewportWidth: CGFloat
    let onDelete: () -> Void

    private var progress: Double {
        max(0, min(goal.progressPercentage, 1))
    }

    private var dailyNeedText: String {
        let plan = goal.dailyPlan
        guard plan.amountNeededToday.isFinite else { return "--" }
        return String(format: "%.1f %@", plan.amountNeededToday, goal.unit.symbol)
    }

    private var deadlineText: String {
        guard let deadline = goal.deadline else { return "No deadline" }
        let dayCount = Calendar.current.dateComponents([.day], from: .now, to: deadline).day ?? 0
        if dayCount <= 0 { return "Due now" }
        return "\(dayCount) days left"
    }

    private var accessibilitySummary: String {
        "\(goal.title), \(goal.type.title). Progress \(Int(progress * 100)) percent. Current \(String(format: "%.1f", goal.currentAmount)) \(goal.unit.symbol), target \(String(format: "%.1f", goal.targetAmount)) \(goal.unit.symbol). \(deadlineText)."
    }

    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .named("HorizonPanorama"))
            let viewportMidX = viewportWidth * 0.5
            let raw = (frame.midX - viewportMidX) / viewportWidth
            let clamped = max(-1, min(1, raw))
            let rotation = reduceMotion ? 0 : -Double(clamped) * 7
            let scale = reduceMotion ? 1 : 1 - abs(clamped) * 0.045
            let yOffset = reduceMotion ? 0 : abs(clamped) * 7

            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.42),
                                accent.opacity(0.26)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.14))
                                .frame(width: 36, height: 36)

                            Image(systemName: goal.type.icon)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(accent)
                                .accessibilityHidden(true)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(goal.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                            Text(goal.type.title)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.65))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }

                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("Momentum")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    GeometryReader { progressGeo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.16))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [accent, accent.opacity(0.5)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: progressGeo.size.width * progress)
                        }
                    }
                    .frame(height: 10)

                    VStack(alignment: .leading, spacing: 10) {
                        panoramaMetric(label: "Current", value: String(format: "%.1f %@", goal.currentAmount, goal.unit.symbol))
                        panoramaMetric(label: "Target", value: String(format: "%.1f %@", goal.targetAmount, goal.unit.symbol))
                        panoramaMetric(label: "Daily Need", value: dailyNeedText)
                        panoramaMetric(label: "Deadline", value: deadlineText)
                    }

                    Spacer(minLength: 0)
                }
                .padding(18)

                if isEditing {
                    Button(action: onDelete) {
                        Image(systemName: "trash.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.red.opacity(0.82), in: Circle())
                    }
                    .padding(12)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete \(goal.title)")
                    .accessibilityHint("Removes this goal.")
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(accent.opacity(0.36), lineWidth: 1)
            )
            .frame(width: cardWidth, height: cardHeight)
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.72
            )
            .scaleEffect(scale)
            .offset(y: yOffset)
            .shadow(color: accent.opacity(0.26), radius: 14, x: 0, y: 8)
            .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86), value: frame.midX)
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Goal", systemImage: "trash")
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityHint(isEditing ? "Delete button is available at the top right of this card." : "Swipe horizontally to browse goals.")
        }
        .frame(width: cardWidth, height: cardHeight)
    }

    private func panoramaMetric(label: String, value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.58))
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct AddGoalPanoramaCard: View {
    let width: CGFloat
    let height: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.white.opacity(0.76))
                    .accessibilityHidden(true)
                Text("New Aspiration")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(width: width, height: height)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    .foregroundStyle(.white.opacity(0.22))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add New Aspiration")
        .accessibilityHint("Creates a new goal.")
    }
}

// MARK: - Hydration Goal Settings Card

/// Settings card for configuring daily hydration goal.
struct HydrationGoalCard: View {
    @State private var cupsGoal: Int = HydrationSettings.load().dailyCupsGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "drop.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                    .accessibilityHidden(true)

                Text("Hydration Goal")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(cupsGoal * 8) oz/day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.15), in: Capsule())
            }

            Text("Set your daily water intake goal")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))

            VStack(spacing: 12) {
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
                    .accessibilityLabel("Decrease Hydration Goal")
                    .accessibilityHint("Reduces your daily water goal by one cup.")

                    Spacer()

                    VStack(spacing: 2) {
                        Text("\(cupsGoal)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText(value: Double(cupsGoal)))
                            .animation(.spring(response: 0.3), value: cupsGoal)
                            .accessibilityLabel("\(cupsGoal) cups")

                        Text("cups")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.72))
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
                    .accessibilityLabel("Increase Hydration Goal")
                    .accessibilityHint("Raises your daily water goal by one cup.")
                }
                .padding(.horizontal)

                HStack(spacing: 6) {
                    ForEach(0..<cupsGoal, id: \.self) { index in
                        WaterDroplet(isFilled: true, delay: Double(index) * 0.05)
                    }

                    ForEach(cupsGoal..<16, id: \.self) { _ in
                        WaterDroplet(isFilled: false, delay: 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.09), lineWidth: 1)
        )
    }

    private func saveGoal() {
        SoundManager.shared.play(.glassTap, volume: 0.45)
        SoundManager.shared.haptic(.success)

        let settings = HydrationSettings(dailyCupsGoal: cupsGoal)
        settings.save()
    }
}

/// Individual water droplet for the goal visualization.
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
            .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        SanctuaryTimeBackdrop()
        HorizonView()
    }
    .modelContainer(for: Goal.self, inMemory: true)
    .preferredColorScheme(.dark)
}
