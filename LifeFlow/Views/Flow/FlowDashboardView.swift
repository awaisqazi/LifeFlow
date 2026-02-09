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
/// Styled as a time-aware stream while preserving existing behavior.
struct FlowDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.marathonCoachManager) private var coachManager
    @Environment(\.enterGymMode) private var enterGymMode
    @Environment(\.gymModeManager) private var gymModeManager
    @Environment(\.openTab) private var openTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        return dayLogs.first ?? DayLog()
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

    private var briefingDateLine: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var briefingSubtitle: String {
        SanctuaryStyle.greeting(for: .now)
    }

    private var latestCompletedWorkoutToday: WorkoutSession? {
        todayLog.workouts
            .filter { $0.endTime != nil }
            .sorted {
                let lhs = $0.endTime ?? $0.startTime
                let rhs = $1.endTime ?? $1.startTime
                return lhs > rhs
            }
            .first
    }

    var body: some View {
        ZStack {
            SanctuaryTimeBackdrop(includeMeshOverlay: true)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        SanctuaryHeaderView(
                            title: "Flow",
                            subtitle: briefingSubtitle,
                            kicker: briefingDateLine
                        )
                        .id("top")
                        .padding(.horizontal)

                        if let latestCompletedWorkoutToday {
                            sessionCapturedBanner(for: latestCompletedWorkoutToday)
                                .padding(.horizontal)
                                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        }

                        VStack(spacing: 16) {
                            streamDepthCard(index: 0) {
                                HydrationVesselCard(dayLog: todayLog)
                            }

                            streamDepthCard(index: 1) {
                                GymCard(dayLog: todayLog)
                            }

                            if hasRaceTrainingGoal,
                               let plan = coachManager.activePlan,
                               let session = plan.todaysSession {
                                streamDepthCard(index: 2) {
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
                            }

                            SanctuarySectionHeader(title: "Goals In Motion")
                                .padding(.top, 6)

                            if goals.isEmpty {
                                ContentUnavailableView(
                                    "No Goals Active",
                                    systemImage: "mountain.2",
                                    description: Text("Add goals in Horizon to see them here.")
                                )
                                .padding(.vertical, 24)
                            } else {
                                ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                                    streamDepthCard(index: min(index + 3, 5)) {
                                        GoalActionCard(goal: goal, dayLog: todayLog) {
                                            withAnimation(.smooth) {
                                                proxy.scrollTo(goal.id, anchor: .center)
                                            }
                                        }
                                        .id(goal.id)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 260)
                    }
                    .padding(.top, 56)
                    .padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
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

    @ViewBuilder
    private func streamDepthCard<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .sanctuaryStreamDepth(index: index, reduceMotion: reduceMotion)
            .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.84), value: index)
    }

    @ViewBuilder
    private func sessionCapturedBanner(for workout: WorkoutSession) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.cyan)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Session captured")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(workout.title.isEmpty ? "Your workout was added to Temple." : "\(workout.title) was added to Temple.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
            }

            Spacer(minLength: 8)

            Button {
                openTab(.temple)
            } label: {
                Text("Open")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.16), in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Temple")
            .accessibilityHint("Shows this workout in your training history.")
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cyan.opacity(0.32), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
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
                        duration: TimeInterval(entry.durationMinutes * 60),
                        distanceMiles: nil
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

/// Reusable glass card component using native Liquid Glass.
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
        SanctuaryTimeBackdrop()
        FlowDashboardView()
    }
    .modelContainer(for: DayLog.self, inMemory: true)
    .preferredColorScheme(.dark)
}
