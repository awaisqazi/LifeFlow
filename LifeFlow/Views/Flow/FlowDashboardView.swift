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
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \DayLog.date, order: .reverse) private var dayLogs: [DayLog]
    @Query(sort: \Goal.deadline, order: .forward) private var goals: [Goal]
    @Query(sort: \TrainingPlan.createdAt, order: .reverse) private var trainingPlans: [TrainingPlan]

    @State private var weatherService = RunWeatherService()
    @State private var showPostRunCheckIn: Bool = false
    @State private var checkInSession: TrainingSession?
    @State private var showCrossTrainingSheet: Bool = false
    @State private var crossTrainingSession: TrainingSession?
    @State private var crossTrainingSaveError: String?

    /// Get or create today's DayLog
    private var todayLog: DayLog {
        let calendar = Calendar.current
        if let existing = dayLogs.first(where: { calendar.isDateInToday($0.date) }) {
            return existing
        }
        return DayLog(date: calendar.startOfDay(for: Date()))
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

    private var briefingWeatherLine: String {
        weatherService.compactSummaryText
    }

    private var briefingSubtitle: String {
        if let plan = coachManager.activePlan,
           let session = plan.todaysSession {
            if session.isCompleted {
                if remainingHydrationOunces > 0 {
                    return "Session complete. Recover with \(remainingHydrationOunces) oz and let adaptation settle."
                }
                return "Session complete and recovery locked. Temple has your win."
            }
            
            switch session.runType {
            case .crossTraining:
                return "Cross-training day. Keep it smooth and stack consistency."
            case .rest:
                return "Rest day. Recovery is part of race preparation."
            default:
                return "Up next: \(session.runType.displayName) • \(session.targetDistance.formatted(.number.precision(.fractionLength(1)))) mi."
            }
        }
        
        if latestCompletedWorkoutToday != nil {
            if remainingHydrationOunces > 0 {
                return "Great work. Refill \(remainingHydrationOunces) oz to complete recovery."
            }
            return "Great work today. Momentum is already building."
        }
        
        if hydrationProgress < 0.35 {
            return "Start with hydration first. Early rhythm drives the whole day."
        }
        
        return SanctuaryStyle.greeting(for: .now)
    }

    private var latestCompletedWorkoutToday: WorkoutSession? {
        let calendar = Calendar.current
        return todayLog.workouts
            .filter { workout in
                guard workout.resolvedIsLifeFlowNative else { return false }
                guard workout.isMeaningfullyCompleted else { return false }
                let anchorDate = workout.endTime ?? workout.startTime
                return calendar.isDateInToday(anchorDate)
            }
            .sorted {
                let lhs = $0.endTime ?? $0.startTime
                let rhs = $1.endTime ?? $1.startTime
                return lhs > rhs
            }
            .first
    }
    
    private var hydrationGoalOunces: Double {
        max(1, HydrationSettings.load().dailyOuncesGoal)
    }
    
    private var hydrationProgress: Double {
        min(todayLog.waterIntake / hydrationGoalOunces, 1)
    }
    
    private var remainingHydrationOunces: Int {
        max(0, Int((hydrationGoalOunces - todayLog.waterIntake).rounded()))
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
                            kicker: briefingDateLine,
                            kickerAccessory: briefingWeatherLine,
                            kickerTrailingInset: 72
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

                            if let plan = coachManager.activePlan,
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
            recoverTrainingPlanIfNeeded()
            weatherService.fetchIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            ensureTodayLogExists()
            coachManager.loadActivePlan(modelContext: modelContext)
            recoverTrainingPlanIfNeeded()
            weatherService.fetchIfNeeded()
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
        .onChange(of: raceTrainingGoalIDs) { oldIDs, newIDs in
            if !oldIDs.isEmpty, newIDs.isEmpty {
                coachManager.cancelPlan(modelContext: modelContext)
            } else if coachManager.activePlan == nil {
                coachManager.loadActivePlan(modelContext: modelContext)
                recoverTrainingPlanIfNeeded()
            }
        }
    }

    private func recoverTrainingPlanIfNeeded() {
        // If there are no race training goals, clean up any orphaned plans
        if raceTrainingGoalIDs.isEmpty {
            if coachManager.activePlan != nil {
                coachManager.cancelPlan(modelContext: modelContext)
            }
            // Delete any stale TrainingPlans left over from deleted goals
            // Cascade delete rule on TrainingPlan.sessions handles child sessions.
            // Do NOT iterate plan.sessions here — backing data may be partially
            // detached after cancelPlan, causing a fatal fault-resolution crash.
            for plan in trainingPlans {
                modelContext.delete(plan)
            }
            if !trainingPlans.isEmpty {
                try? modelContext.save()
            }
            return
        }

        guard coachManager.activePlan == nil else { return }
        guard let recoverablePlan = trainingPlans.first(where: { !$0.isCompleted }) else { return }

        if !recoverablePlan.isActive {
            recoverablePlan.isActive = true
            try? modelContext.save()
        }

        coachManager.loadActivePlan(modelContext: modelContext)
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
        .liquidGlassChip(cornerRadius: 14)
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
        let calendar = Calendar.current
        if let existingLog = dayLogs.first(where: { calendar.isDateInToday($0.date) }) {
            // Sync widget-logged water into the main app's DayLog
            syncWidgetHydration(into: existingLog)
        } else {
            let newLog = DayLog(date: calendar.startOfDay(for: Date()))
            // Pull any water logged via the widget before the app opened
            syncWidgetHydration(into: newLog)
            modelContext.insert(newLog)
            try? modelContext.save()
        }
    }

    /// Sync the app's DayLog with the widget's UserDefaults value (source of truth).
    private func syncWidgetHydration(into log: DayLog) {
        guard let cachedIntake = HydrationSettings.loadCurrentIntake(),
              cachedIntake != log.waterIntake else { return }
        log.waterIntake = cachedIntake
        try? modelContext.save()
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

        let calendar = Calendar.current
        if let today = dayLogs.first(where: { calendar.isDateInToday($0.date) }) {
            if !today.workouts.contains(where: { $0.id == workout.id }) {
                today.workouts.append(workout)
            }
        } else {
            let newLog = DayLog(date: calendar.startOfDay(for: Date()), workouts: [workout])
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


#Preview {
    ZStack {
        SanctuaryTimeBackdrop()
        FlowDashboardView()
    }
    .modelContainer(for: DayLog.self, inMemory: true)
    .preferredColorScheme(.dark)
}
