//
//  TempleView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData
import Charts
import CoreLocation

/// The Temple tab - Digital Sanctuary.
/// Distinguishes LifeFlow-native work from imported workouts while keeping analytics in one place.
struct TempleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.enterGymMode) private var enterGymMode
    @Query(sort: \DayLog.date, order: .reverse) private var allLogs: [DayLog]
    @Query(sort: \Goal.deadline, order: .forward) private var goals: [Goal]

    /// Completed workouts only.
    @Query(filter: #Predicate<WorkoutSession> { session in
        session.endTime != nil
    }, sort: \WorkoutSession.startTime, order: .reverse) private var completedWorkouts: [WorkoutSession]

    @State private var selectedScope: TimeScope = .week
    @State private var showingHealthKitAlert = false
    @State private var selectedWorkoutForDetail: WorkoutSession? = nil
    @State private var healthKitManager = HealthKitManager()

    private var scopedLogs: [DayLog] {
        allLogs
            .filter { $0.date >= scopeStartDate }
            .sorted { $0.date < $1.date }
    }

    private var scopedWorkouts: [WorkoutSession] {
        completedWorkouts.filter { $0.startTime >= scopeStartDate }
    }

    private var nativeWorkouts: [WorkoutSession] {
        scopedWorkouts.filter(\.resolvedIsLifeFlowNative)
    }

    private var importedWorkouts: [WorkoutSession] {
        scopedWorkouts.filter { !$0.resolvedIsLifeFlowNative }
    }

    private var totalDistanceMiles: Double {
        scopedWorkouts.reduce(0) { $0 + $1.totalDistanceMiles }
    }

    private var totalCalories: Double {
        scopedWorkouts.reduce(0) { $0 + $1.calories }
    }

    private var totalDuration: TimeInterval {
        scopedWorkouts.reduce(0) { $0 + $1.duration }
    }

    private var scopeStartDate: Date {
        let calendar = Calendar.current
        let now = Date()

        switch selectedScope {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.10),
                    Color(red: 0.04, green: 0.10, blue: 0.16),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    headerSection
                    scopePicker
                    vitalsSection
                    analyticsSection
                    chronicleSection
                    goalsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 62)
                .padding(.bottom, 110)
            }
        }
        .task(id: selectedScope) {
            await syncHealthKit(isUserInitiated: false)
        }
        .alert("HealthKit", isPresented: $showingHealthKitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(healthKitManager.lastError?.localizedDescription ?? "Unable to sync with HealthKit")
        }
        .sheet(item: $selectedWorkoutForDetail) { workout in
            WorkoutDetailModal(workout: workout)
                .presentationDetents([.medium, .large])
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("The Temple")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.72)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
                    .accessibilityAddTraits(.isHeader)

                Text("Inner work from LifeFlow. Outer work from your ecosystem.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            Button {
                Task {
                    await syncHealthKit(isUserInitiated: true)
                }
            } label: {
                HStack(spacing: 7) {
                    if healthKitManager.isSyncing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.semibold))
                    }
                    Text(healthKitManager.isSyncing ? "Syncing" : "Sync")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.13), in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .disabled(healthKitManager.isSyncing)
            .accessibilityLabel(healthKitManager.isSyncing ? "Syncing Health Data" : "Sync Health Data")
            .accessibilityHint("Imports workouts from Apple Health.")
        }
    }

    private var scopePicker: some View {
        Picker("Range", selection: $selectedScope) {
            ForEach(TimeScope.allCases) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .padding(5)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var vitalsSection: some View {
        HStack(spacing: 12) {
            TempleInsightTile(
                title: "Chronicle",
                value: "\(scopedWorkouts.count)",
                caption: scopedWorkouts.count == 1 ? "session" : "sessions",
                accent: .cyan,
                icon: "waveform.path.ecg"
            )

            TempleInsightTile(
                title: "Distance",
                value: formatDistance(totalDistanceMiles),
                caption: "logged",
                accent: .mint,
                icon: "figure.run"
            )

            TempleInsightTile(
                title: "Focus",
                value: formatDuration(totalDuration),
                caption: "moving time",
                accent: .orange,
                icon: "clock.fill"
            )
        }
    }

    private var analyticsSection: some View {
        VStack(spacing: 18) {
            HydrationChart(logs: allLogs, scope: selectedScope)

            if let firstGoal = goals.first {
                GoalProgressChart(goal: firstGoal)
            }

            ConsistencyHeatmap(logs: allLogs)

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(Int(totalCalories.rounded())) kcal")
                }

                Text("•")
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.cyan)
                    Text("\(scopedLogs.filter { $0.waterIntake >= HydrationSettings.load().dailyOuncesGoal }.count) hydration wins")
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .padding(16)
        .liquidGlassCard()
    }

    private var chronicleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Chronicle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(scopedWorkouts.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.cyan.opacity(0.75), in: Capsule())
            }

            if scopedWorkouts.isEmpty {
                TempleChronicleEmptyState {
                    enterGymMode()
                }
            } else {
                LazyVStack(spacing: 14) {
                    if !nativeWorkouts.isEmpty {
                        TempleSectionHeader(
                            title: "Inner Work",
                            subtitle: "Captured natively in LifeFlow",
                            accent: .cyan,
                            icon: "drop.fill"
                        )

                        ForEach(nativeWorkouts) { workout in
                            Button {
                                selectedWorkoutForDetail = workout
                            } label: {
                                SanctuaryWorkoutRow(workout: workout)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens workout details.")
                            .contextMenu {
                                Button {
                                    selectedWorkoutForDetail = workout
                                } label: {
                                    Label("View Details", systemImage: "info.circle")
                                }

                                Button(role: .destructive) {
                                    deleteWorkout(workout)
                                } label: {
                                    Label("Delete Session", systemImage: "trash")
                                }
                            }
                        }
                    }

                    if !importedWorkouts.isEmpty {
                        TempleSectionHeader(
                            title: "Imported Work",
                            subtitle: "Synced from Apple Health and connected services",
                            accent: .secondary,
                            icon: "square.and.arrow.down"
                        )

                        ForEach(importedWorkouts) { workout in
                            Button {
                                selectedWorkoutForDetail = workout
                            } label: {
                                SanctuaryWorkoutRow(workout: workout)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens workout details.")
                        }
                    }
                }
            }
        }
        .padding(16)
        .liquidGlassCard()
    }

    @ViewBuilder
    private var goalsSection: some View {
        if !goals.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text("Intentions")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                ForEach(goals.prefix(3)) { goal in
                    GoalVisualizationCard(goal: goal)
                }
            }
            .padding(16)
            .liquidGlassCard()
        }
    }

    private func deleteWorkout(_ workout: WorkoutSession) {
        modelContext.delete(workout)
        try? modelContext.save()

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    private func syncHealthKit(isUserInitiated: Bool) async {
        do {
            try await healthKitManager.requestAuthorization()
            let workouts = try await healthKitManager.fetchWorkouts(for: selectedScope)
            await MainActor.run {
                mergeHealthKitWorkouts(workouts)
            }
        } catch {
            if isUserInitiated {
                await MainActor.run {
                    showingHealthKitAlert = true
                }
            } else {
                print("Temple HealthKit sync (silent) failed: \(error)")
            }
        }
    }

    /// Merge HealthKit workouts into DayLog records.
    /// Updates existing workouts by ID to keep source metadata fresh.
    private func mergeHealthKitWorkouts(_ workouts: [WorkoutSession]) {
        let calendar = Calendar.current

        for workout in workouts {
            let startOfDay = calendar.startOfDay(for: workout.timestamp)

            let dayLog: DayLog
            if let existing = allLogs.first(where: { calendar.isDate($0.date, inSameDayAs: startOfDay) }) {
                dayLog = existing
            } else {
                let newLog = DayLog(date: startOfDay, workouts: [])
                modelContext.insert(newLog)
                dayLog = newLog
            }

            if let existingWorkout = dayLog.workouts.first(where: { $0.id == workout.id }) {
                existingWorkout.title = workout.title
                existingWorkout.type = workout.type
                existingWorkout.duration = workout.duration
                existingWorkout.calories = workout.calories
                existingWorkout.source = workout.source
                existingWorkout.timestamp = workout.timestamp
                existingWorkout.startTime = workout.startTime
                existingWorkout.endTime = workout.endTime
                existingWorkout.notes = workout.notes
                existingWorkout.distanceMiles = workout.distanceMiles
                existingWorkout.averageHeartRate = workout.averageHeartRate
                existingWorkout.sourceName = workout.sourceName
                existingWorkout.sourceBundleID = workout.sourceBundleID
                existingWorkout.isLifeFlowNative = workout.isLifeFlowNative
            } else {
                dayLog.workouts.append(workout)
            }
        }

        try? modelContext.save()
    }

    private func formatDistance(_ miles: Double) -> String {
        if miles >= 10 {
            return String(format: "%.0f mi", miles)
        }
        return String(format: "%.1f mi", miles)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes >= 120 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

private struct TempleInsightTile: View {
    let title: String
    let value: String
    let caption: String
    let accent: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(accent)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .liquidGlassChip(cornerRadius: LiquidGlass.cornerRadiusSmall)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value), \(caption)")
    }
}

private struct TempleSectionHeader: View {
    let title: String
    let subtitle: String
    let accent: Color
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 22, height: 22)
                .background(accent.opacity(0.18), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct TempleChronicleEmptyState: View {
    let onRecordWorkout: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image("sculpture_zen_stone")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 180)
                .shadow(color: .white.opacity(0.1), radius: 20)
                .accessibilityHidden(true)
            
            Image("sculpture_start_line")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 56)
                .blendMode(.screen)
                .opacity(0.72)
                .accessibilityHidden(true)

            Text("Your digital sanctuary is quiet.")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))

            Text("Record your first workout to begin the chronicle.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onRecordWorkout) {
                Label("Initialize Temple", systemImage: "figure.run")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.12), in: Capsule())
                    .foregroundStyle(.white)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

// MARK: - Workout Detail Modal

struct WorkoutDetailModal: View {
    let workout: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFlowPrintFormat: FlowPrintFormat = .story
    @State private var isRenderingFlowPrint: Bool = false
    @State private var flowPrintFileURL: URL?
    @State private var flowPrintCaption: String = ""
    @State private var flowPrintError: String?
    @State private var showFlowPrintShareSheet: Bool = false
    @State private var healthKitManager = HealthKitManager()

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: workout.startTime)
    }

    private var formattedDuration: String {
        let hours = Int(workout.duration) / 3600
        let mins = (Int(workout.duration) % 3600) / 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        StatBubble(icon: "clock.fill", value: formattedDuration, label: "Duration", color: .cyan)
                        StatBubble(icon: "dumbbell.fill", value: "\(workout.exercises.count)", label: "Exercises", color: .orange)
                        StatBubble(icon: "flame.fill", value: "\(Int(workout.calories))", label: "Calories", color: .red)
                    }
                    .padding(.horizontal)

                    HStack(spacing: 8) {
                        WorkoutSourceBadge(
                            sourceName: workout.resolvedSourceName,
                            bundleID: workout.resolvedSourceBundleID,
                            isNative: workout.resolvedIsLifeFlowNative
                        )

                        if let heartRate = workout.averageHeartRate, heartRate > 0 {
                            Text("Avg HR \(Int(heartRate.rounded())) bpm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .liquidGlassChip()
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    if let weatherStamp = workout.weatherStampText {
                        Label(weatherStamp, systemImage: "cloud.sun.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    flowPrintShareSection

                    Divider()
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("EXERCISES")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(1)
                            .padding(.horizontal)

                        ForEach(workout.sortedExercises) { exercise in
                            ExerciseDetailCard(exercise: exercise)
                        }
                    }

                    if workout.sortedExercises.isEmpty {
                        Text("No granular exercise breakdown available for this session.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(workout.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showFlowPrintShareSheet) {
            if let fileURL = flowPrintFileURL {
                ActivityShareSheet(items: [flowPrintCaption, fileURL])
            }
        }
    }
    
    private var flowPrintShareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FLOW PRINT")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                
                Spacer()
                
                Picker("Format", selection: $selectedFlowPrintFormat) {
                    ForEach(FlowPrintFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
            
            HStack(spacing: 10) {
                Button {
                    Task {
                        await generateFlowPrint()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isRenderingFlowPrint {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles.rectangle.stack.fill")
                        }
                        Text(flowPrintFileURL == nil ? "Generate Poster" : "Regenerate")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.cyan.opacity(0.24), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isRenderingFlowPrint)
                
                Button {
                    showFlowPrintShareSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Share")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.green.opacity(0.24), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(flowPrintFileURL == nil)
            }
            
            if let flowPrintError, !flowPrintError.isEmpty {
                Text(flowPrintError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("Share a complete win card with exercises, sets, calories, hydration, and route glow when available.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 2)
    }
    
    private var flowPrintRunLine: String {
        if let miles = workout.runAnalysisMetadata?.completedDistanceMiles ?? (workout.totalDistanceMiles > 0 ? workout.totalDistanceMiles : nil) {
            if abs(miles - 3.10686) < 0.2 { return "5K Run" }
            if abs(miles - 6.21371) < 0.25 { return "10K Run" }
            if abs(miles - 13.1094) < 0.35 { return "Half Marathon" }
            if abs(miles - 26.2188) < 0.45 { return "Marathon" }
            return String(format: "%.1f mi Run", miles)
        }
        return workout.type == "Running" ? "Run Session" : workout.title
    }
    
    private var flowPrintDurationLine: String {
        let totalSeconds = Int(workout.duration.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var flowPrintPaceLine: String? {
        guard let targetPace = workout.runAnalysisMetadata?.targetPaceMinutesPerMile,
              targetPace.isFinite, targetPace > 0 else {
            return nil
        }
        let totalSeconds = Int((targetPace * 60).rounded())
        return String(format: "Target Pace %d:%02d/mi", totalSeconds / 60, totalSeconds % 60)
    }
    
    private var completedExercisesForShare: Int {
        let completed = workout.sortedExercises.filter { exercise in
            exercise.sortedSets.contains(where: \.isCompleted)
        }.count
        return completed > 0 ? completed : workout.sortedExercises.count
    }
    
    private var completedSetsForShare: Int {
        workout.sortedExercises.reduce(0) { partial, exercise in
            partial + exercise.sortedSets.filter(\.isCompleted).count
        }
    }
    
    private var totalRepsForShare: Int {
        workout.sortedExercises
            .flatMap(\.sortedSets)
            .filter(\.isCompleted)
            .compactMap(\.reps)
            .reduce(0, +)
    }
    
    private var totalVolumeForShare: Int {
        let volume = workout.sortedExercises
            .flatMap(\.sortedSets)
            .filter(\.isCompleted)
            .reduce(0.0) { partial, set in
                guard let weight = set.weight, let reps = set.reps else { return partial }
                return partial + (weight * Double(reps))
            }
        return Int(volume.rounded())
    }
    
    private var resolvedCaloriesForShare: Int {
        let roundedCalories = Int(workout.calories.rounded())
        if roundedCalories > 0 {
            return roundedCalories
        }
        
        let durationCalories = Int((workout.duration / 60) * 3)
        let setsCalories = completedSetsForShare * 5
        return max(0, durationCalories + setsCalories)
    }
    
    private var flowPrintHighlights: [FlowPrintHighlight] {
        var highlights: [FlowPrintHighlight] = [
            FlowPrintHighlight(icon: "clock.fill", label: "Duration", value: flowPrintDurationLine, tone: .cyan)
        ]
        
        let distance = workout.totalDistanceMiles
        if distance > 0 {
            highlights.append(
                FlowPrintHighlight(
                    icon: "figure.run",
                    label: "Distance",
                    value: String(format: "%.1f mi", distance),
                    tone: .green
                )
            )
        }
        
        if completedExercisesForShare > 0 {
            highlights.append(
                FlowPrintHighlight(
                    icon: "dumbbell.fill",
                    label: "Exercises",
                    value: "\(completedExercisesForShare)",
                    tone: .orange
                )
            )
        }
        
        if completedSetsForShare > 0 {
            highlights.append(
                FlowPrintHighlight(
                    icon: "repeat",
                    label: "Sets",
                    value: "\(completedSetsForShare)",
                    tone: .purple
                )
            )
        }
        
        if resolvedCaloriesForShare > 0 {
            highlights.append(
                FlowPrintHighlight(
                    icon: "flame.fill",
                    label: "Calories",
                    value: "\(resolvedCaloriesForShare)",
                    tone: .pink
                )
            )
        }
        
        if totalVolumeForShare > 0 {
            highlights.append(
                FlowPrintHighlight(
                    icon: "scalemass.fill",
                    label: "Volume",
                    value: "\(totalVolumeForShare) lb",
                    tone: .blue
                )
            )
        }
        
        if let hydration = workout.resolvedLiquidLossEstimate {
            highlights.append(
                FlowPrintHighlight(
                    icon: "drop.fill",
                    label: "Hydration",
                    value: "\(Int(hydration.rounded())) oz",
                    tone: .cyan
                )
            )
        }
        
        return highlights
    }
    
    private var flowPrintWinLine: String? {
        var wins: [String] = []
        
        if completedExercisesForShare > 0 {
            wins.append("\(completedExercisesForShare) exercises")
        }
        
        if completedSetsForShare > 0 {
            wins.append("\(completedSetsForShare) sets")
        }
        
        if totalRepsForShare > 0 {
            wins.append("\(totalRepsForShare) reps")
        }
        
        if let delta = workout.resolvedGhostRunnerDelta {
            let prefix = delta >= 0 ? "ahead" : "behind"
            wins.append("\(Int(abs(delta).rounded()))s \(prefix)")
        }
        
        if wins.isEmpty {
            return nil
        }
        
        return wins.prefix(3).joined(separator: " • ")
    }
    
    @MainActor
    private func generateFlowPrint() async {
        guard !isRenderingFlowPrint else { return }
        isRenderingFlowPrint = true
        defer { isRenderingFlowPrint = false }
        flowPrintError = nil
        
        var segments: [FlowPrintRouteSegment] = []
        
        if let workoutID = workout.runAnalysisMetadata?.healthKitWorkoutID {
            do {
                try? await healthKitManager.requestAuthorization()
                let routeLocations = try await healthKitManager.fetchWorkoutRouteLocations(for: workoutID)
                segments = buildFlowPrintSegments(
                    from: routeLocations,
                    targetPace: workout.runAnalysisMetadata?.targetPaceMinutesPerMile
                )
            } catch {
                // Non-blocking: Flow Print still works with stats-only composition.
            }
        }
        
        do {
            let renderInput = FlowPrintRenderInput(
                sessionTitle: workout.title,
                runLine: flowPrintRunLine,
                durationLine: flowPrintDurationLine,
                templeLine: "The Temple",
                weatherLine: workout.weatherStampText,
                paceLine: flowPrintPaceLine,
                highlights: flowPrintHighlights,
                winLine: flowPrintWinLine,
                completionDate: workout.endTime ?? workout.startTime,
                format: selectedFlowPrintFormat,
                routeSegments: segments
            )
            
            let result = try FlowPrintRenderer.shared.renderPoster(input: renderInput)
            flowPrintFileURL = result.fileURL
            flowPrintCaption = result.caption
            SoundManager.shared.play(.successChime, volume: 0.56)
        } catch {
            flowPrintError = error.localizedDescription
        }
    }
    
    private func buildFlowPrintSegments(
        from locations: [CLLocation],
        targetPace: Double?
    ) -> [FlowPrintRouteSegment] {
        let sorted = locations.sorted { $0.timestamp < $1.timestamp }
        guard sorted.count > 1 else { return [] }
        
        var segments: [FlowPrintRouteSegment] = []
        segments.reserveCapacity(sorted.count - 1)
        
        for index in 1..<sorted.count {
            let previous = sorted[index - 1]
            let current = sorted[index]
            
            let segmentDistanceMiles = max(0, current.distance(from: previous) / 1609.34)
            let segmentDuration = max(0, current.timestamp.timeIntervalSince(previous.timestamp))
            guard segmentDistanceMiles > 0.0003, segmentDuration > 0 else { continue }
            
            let segmentPace = (segmentDuration / 60) / segmentDistanceMiles
            let isAhead: Bool
            if let targetPace, targetPace > 0 {
                isAhead = segmentPace <= targetPace
            } else {
                isAhead = true
            }
            
            segments.append(
                FlowPrintRouteSegment(
                    coordinates: [previous.coordinate, current.coordinate],
                    isAhead: isAhead
                )
            )
        }
        
        return segments
    }
}

private struct StatBubble: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .liquidGlassChip(cornerRadius: LiquidGlass.cornerRadiusSmall)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct ExerciseDetailCard: View {
    let exercise: WorkoutExercise

    private var completedSets: [ExerciseSet] {
        exercise.sortedSets.filter(\.isCompleted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: exercise.type.icon)
                    .font(.callout)
                    .foregroundStyle(colorForType(exercise.type))
                    .frame(width: 28, height: 28)
                    .background(colorForType(exercise.type).opacity(0.15), in: Circle())

                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(completedSets.count)/\(exercise.sets.count) sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !completedSets.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(completedSets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("Set \(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            if let weight = set.weight, let reps = set.reps {
                                Text("\(Int(weight)) lbs × \(reps) reps")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)
                            } else if let reps = set.reps {
                                Text("\(reps) reps")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)
                            } else if let duration = set.duration {
                                Text("\(Int(duration / 60))m")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    private func colorForType(_ type: ExerciseType) -> Color {
        switch type {
        case .weight: return .orange
        case .cardio: return .green
        case .calisthenics: return .blue
        case .flexibility: return .purple
        case .machine: return .red
        case .functional: return .cyan
        }
    }
}

#Preview {
    ZStack {
        LiquidBackgroundView(currentTab: .temple)
        TempleView()
    }
    .modelContainer(for: [DayLog.self, WorkoutSession.self, Goal.self], inMemory: true)
    .preferredColorScheme(.dark)
}
