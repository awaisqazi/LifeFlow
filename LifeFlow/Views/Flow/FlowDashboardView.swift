//
//  FlowDashboardView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData
import HealthKit

/// The Flow tab - displays the daily summary dashboard.
/// Shows a snapshot of water intake, gym status, and momentum metrics.
struct FlowDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.marathonCoachManager) private var coachManager
    @Environment(\.enterGymMode) private var enterGymMode
    @Environment(\.gymModeManager) private var gymModeManager
    @Query(sort: \DayLog.date, order: .reverse) private var dayLogs: [DayLog]
    @Query(sort: \Goal.deadline, order: .forward) private var goals: [Goal]
    @State private var showPostRunCheckIn: Bool = false
    @State private var checkInSession: TrainingSession?
    @State private var showCrossTrainingSheet: Bool = false
    @State private var crossTrainingSession: TrainingSession?
    @State private var crossTrainingSaveError: String?
    
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
    
    private var hasRaceTrainingGoal: Bool {
        goals.contains { $0.type == .raceTraining }
    }
    
    private var raceTrainingGoalIDs: [UUID] {
        goals
            .filter { $0.type == .raceTraining }
            .map(\.id)
            .sorted { $0.uuidString < $1.uuidString }
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

                        // 2. Training Day Card (if active plan)
                        if hasRaceTrainingGoal,
                           let plan = coachManager.activePlan,
                           let session = plan.todaysSession {
                            TrainingDayCard(
                                plan: plan,
                                session: session,
                                statusColor: coachManager.statusColor,
                                onStartGuidedRun: { startTrainingSession(session) },
                                onLifeHappens: {
                                    _ = coachManager.lifeHappens(modelContext: modelContext)
                                },
                                onCheckIn: {
                                    checkInSession = session
                                    showPostRunCheckIn = true
                                }
                            )
                        }

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
            coachManager.loadActivePlan(modelContext: modelContext)
            if !hasRaceTrainingGoal, coachManager.activePlan != nil {
                coachManager.cancelPlan(modelContext: modelContext)
            }
        }
        .sheet(isPresented: $showPostRunCheckIn) {
            if let session = checkInSession {
                PostRunCheckInSheet(session: session) { distance, effort in
                    coachManager.completeSession(
                        session,
                        actualDistance: distance,
                        effort: effort,
                        modelContext: modelContext
                    )
                }
            }
        }
        .sheet(isPresented: $showCrossTrainingSheet) {
            if let session = crossTrainingSession {
                LogCrossTrainingSheet(session: session) { entry in
                    handleCrossTrainingLog(entry, for: session)
                }
            }
        }
        .alert("Saved In LifeFlow", isPresented: Binding(
            get: { crossTrainingSaveError != nil },
            set: { if !$0 { crossTrainingSaveError = nil } }
        )) {
            Button("OK", role: .cancel) { crossTrainingSaveError = nil }
        } message: {
            Text(crossTrainingSaveError ?? "")
        }
        .onChange(of: raceTrainingGoalIDs) { _, newIDs in
            if newIDs.isEmpty {
                coachManager.cancelPlan(modelContext: modelContext)
            } else if coachManager.activePlan == nil {
                coachManager.loadActivePlan(modelContext: modelContext)
            }
        }
    }
    
    private func startTrainingSession(_ trainingSession: TrainingSession) {
        if trainingSession.runType == .crossTraining {
            crossTrainingSession = trainingSession
            showCrossTrainingSheet = true
            return
        }
        startGuidedRun(trainingSession)
    }
    
    private func startGuidedRun(_ trainingSession: TrainingSession) {
        // Use the new context-aware session launch
        let workout = gymModeManager.startSmartSession(for: trainingSession, using: coachManager)
        modelContext.insert(workout)
        gymModeManager.startWorkout(session: workout)
        enterGymMode()
    }

    private func ensureTodayLogExists() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        if dayLogs.first(where: { $0.date >= startOfDay }) == nil {
            let newLog = DayLog(date: Date())
            modelContext.insert(newLog)
            try? modelContext.save()
        }
    }
    
    private func handleCrossTrainingLog(_ entry: CrossTrainingLogEntry, for session: TrainingSession) {
        coachManager.markCrossTrainingComplete(
            session: session,
            activityName: entry.displayName,
            durationMinutes: entry.durationMinutes,
            modelContext: modelContext
        )
        
        let workout = WorkoutSession(
            title: "\(entry.displayName) Cross Training",
            type: "Cross Training",
            duration: TimeInterval(entry.durationMinutes * 60),
            calories: Double(entry.durationMinutes * 6),
            source: "Flow",
            timestamp: Date()
        )
        workout.endTime = Date()
        modelContext.insert(workout)
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        if let today = dayLogs.first(where: { $0.date >= startOfDay }) {
            if !today.workouts.contains(where: { $0.id == workout.id }) {
                today.workouts.append(workout)
            }
        } else {
            let newLog = DayLog(date: Date(), workouts: [workout])
            modelContext.insert(newLog)
        }
        
        try? modelContext.save()
        
        if entry.saveToHealth {
            Task {
                do {
                    let healthKitManager = AppDependencyManager.shared.healthKitManager
                    try await healthKitManager.requestAuthorization()
                    let endDate = Date()
                    let startDate = endDate.addingTimeInterval(-TimeInterval(entry.durationMinutes * 60))
                    _ = try await healthKitManager.saveManualWorkout(
                        activityType: entry.activityType,
                        startDate: startDate,
                        endDate: endDate,
                        duration: TimeInterval(entry.durationMinutes * 60)
                    )
                } catch {
                    await MainActor.run {
                        crossTrainingSaveError = "Cross-training was logged, but Apple Health save failed."
                    }
                }
            }
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
