//
//  GymModeView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Full-screen immersive workout experience.
/// Flexible navigation - tap any exercise to work on it in any order.
struct GymModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    /// Query for incomplete workouts to resume
    @Query(filter: #Predicate<WorkoutSession> { session in
        session.endTime == nil
    }, sort: \WorkoutSession.startTime, order: .reverse) private var incompleteWorkouts: [WorkoutSession]
    
    /// Query for DayLogs to link completed workouts
    @Query(sort: \DayLog.date, order: .reverse) private var dayLogs: [DayLog]
    
    /// Filter for only today's incomplete workouts (ignore stale sessions from previous days)
    private var todaysIncompleteWorkouts: [WorkoutSession] {
        let calendar = Calendar.current
        return incompleteWorkouts.filter { calendar.isDateInToday($0.startTime) }
    }
    
    @Environment(GymModeManager.self) private var manager
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(\.marathonCoachManager) private var coachManager
    @State private var showSetupSheet: Bool = false // Start false, will be set on appear
    @State private var showSummary: Bool = false
    @State private var showEndConfirmation: Bool = false
    @State private var isEditMode: Bool = false
    @State private var completedSession: WorkoutSession? = nil
    @State private var showAddExerciseSheet: Bool = false
    @State private var showWorkoutCompleteConfirmation: Bool = false
    @State private var showPostRunCheckIn: Bool = false
    @State private var completedTrainingSession: TrainingSession? = nil
    
    // Drag and drop state for live reordering
    @State private var draggedItem: WorkoutExercise? = nil
    @State private var localExercises: [WorkoutExercise] = []
    
    // Cardio safeguard state
    @State private var showCardioExitAlert: Bool = false
    @State private var pendingExerciseSwitch: WorkoutExercise? = nil
    
    // Namespace for morphing glass effects
    @Namespace private var animationNamespace
    
    // Current set input values
    @State private var currentWeight: Double = 0
    @State private var currentReps: Double = 0
    @State private var currentDuration: TimeInterval = 0
    @State private var currentSpeed: Double = 0
    @State private var currentIncline: Double = 0
    
    var body: some View {
        ZStack {
            // Living mesh gradient background
            AnimatedMeshGradientView(theme: .flow)
                .ignoresSafeArea()
            
            if manager.isWorkoutActive {
                activeWorkoutView
            }
            
            // Rest timer overlay
            if manager.isRestTimerActive {
                restTimerOverlay
            }
            
            // Custom Action Menu Overlay
            if showEndConfirmation {
                ZStack {
                    // Blur background
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showEndConfirmation = false
                            }
                        }
                    
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .opacity(0.8)
                    
                    WorkoutActionMenu(
                        onPause: {
                            showEndConfirmation = false
                            pauseWorkout()
                        },
                        onEnd: {
                            showEndConfirmation = false
                            endAndCompleteWorkout()
                        },
                        onDiscard: {
                            showEndConfirmation = false
                            discardWorkout()
                        },
                        onCancel: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showEndConfirmation = false
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .scale(scale: 0.9)).combined(with: .opacity))
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showEndConfirmation)
        .onAppear {
            // Check for potential resume even if active, or show setup sheet
            checkForPausedWorkout()
        }
        .sheet(isPresented: $showSetupSheet, onDismiss: {
            // If setup was dismissed without starting, dismiss the full-screen cover
            if !manager.isWorkoutActive {
                dismiss()
            }
        }) {
            WorkoutSetupSheet { session in
                manager.startWorkout(session: session)
                loadCurrentSetDefaults()
            }
            .interactiveDismissDisabled(false) // Allow dismiss with cancel
        }
        .sheet(isPresented: $showPostRunCheckIn, onDismiss: {
            // After check-in, show workout summary
            showSummary = true
        }) {
            if let session = completedTrainingSession {
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
        .sheet(isPresented: $showSummary, onDismiss: {
            // After summary is dismissed, exit gym mode
            dismiss()
        }) {
            if let session = completedSession {
                GymWorkoutSummaryView(session: session) {
                    try? modelContext.save()
                    showSummary = false
                }
            }
        }
        .sheet(isPresented: $showAddExerciseSheet) {
            AddExerciseSheet { exerciseData in
                addExerciseToWorkout(exerciseData)
                showAddExerciseSheet = false
            }
        }
        .confirmationDialog(
            "All exercises complete!",
            isPresented: $showWorkoutCompleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Finish Workout") {
                endAndCompleteWorkout()
            }
            
            Button("Add More Exercises") {
                showAddExerciseSheet = true
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You've completed all your exercises. Would you like to finish your workout or add more exercises?")
        }
        .alert("End Cardio Session?", isPresented: $showCardioExitAlert) {
            Button("Cancel", role: .cancel) {
                pendingExerciseSwitch = nil
            }
            Button("Switch & End", role: .destructive) {
                if let newExercise = pendingExerciseSwitch {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        // Manually end the cardio state in manager before switching
                        // Note: The view reconstruction will also kill the timer,
                        // but explicit state update is safer.
                        manager.isCardioInProgress = false
                        manager.selectExercise(newExercise)
                        loadCurrentSetDefaults()
                    }
                }
                pendingExerciseSwitch = nil
            }
        } message: {
            Text("Switching exercises will end your current cardio session. Are you sure you want to switch?")
        }
    }
    
    // MARK: - Active Workout View (Liquid Dashboard)
    
    private var activeWorkoutView: some View {
        VStack(spacing: 0) {
            // Header
            workoutHeader
            
            // Dashboard - Use different layouts for edit mode vs normal mode
            if isEditMode {
                // EDIT MODE: Use native List with .onMove for reliable reordering
                editModeList
            } else {
                // NORMAL MODE: Use the beautiful GlassEffectContainer
                normalModeView
            }
        }
        .onAppear {
            syncLocalExercises()
        }
        .onChange(of: manager.activeSession?.exercises.count) { _, _ in
            syncLocalExercises()
        }
        .onChange(of: isEditMode) { _, newValue in
            if !newValue {
                // Exiting edit mode - persist the new order to the manager
                persistExerciseOrder()
            } else {
                // Entering edit mode - sync to ensure we have latest data
                syncLocalExercises()
            }
        }
    }
    
    // MARK: - Edit Mode List (Liquid Glass Design with Native Reordering)
    
    private var editModeList: some View {
        List {
            ForEach(localExercises, id: \.id) { exercise in
                EditModeExerciseRow(
                    exercise: exercise,
                    completedSets: manager.completedSetsCount(for: exercise),
                    totalSets: exercise.sets.count,
                    onDelete: {
                        deleteExercise(exercise)
                    }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onMove { source, destination in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    localExercises.move(fromOffsets: source, toOffset: destination)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    deleteExercise(localExercises[index])
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }
    
    // MARK: - Normal Mode View (Glass design)
    
    private var normalModeView: some View {
        ScrollView {
            ScrollViewReader { scrollProxy in
                GlassEffectContainer(spacing: 16) {
                    ForEach(localExercises, id: \.id) { exercise in
                        if manager.currentExercise?.id == exercise.id {
                            // === STATE A: ACTIVE (Input Card) ===
                            ExerciseInputCard(
                                exercise: exercise,
                                setNumber: manager.currentSetIndex + 1,
                                previousData: manager.getPreviousSetData(
                                    for: exercise.name,
                                    setIndex: manager.currentSetIndex,
                                    using: modelContext
                                ),
                                weight: $currentWeight,
                                reps: $currentReps,
                                duration: $currentDuration,
                                speed: $currentSpeed,
                                incline: $currentIncline,
                                onComplete: { completeCurrentSet() }
                            )
                            .glassEffectID(exercise.id.uuidString, in: animationNamespace)
                            .transition(.blurReplace)
                            .id(exercise.id)
                            
                        } else {
                            // === STATE B: INACTIVE (Sliver) ===
                            InactiveGlassSliver(
                                exercise: exercise,
                                completedSets: manager.completedSetsCount(for: exercise),
                                totalSets: exercise.sets.count,
                                isEditMode: false,
                                namespace: animationNamespace,
                                onTap: {
                                    if manager.isCardioInProgress {
                                        // Show alert if cardio is running
                                        pendingExerciseSwitch = exercise
                                        showCardioExitAlert = true
                                    } else {
                                        // Normal switch
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                                            manager.selectExercise(exercise)
                                            loadCurrentSetDefaults()
                                            scrollProxy.scrollTo(exercise.id, anchor: .center)
                                        }
                                    }
                                }
                            )
                            .id(exercise.id)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 100)
            }
        }
    }
    
    /// Sync local exercises from the manager's active session
    private func syncLocalExercises() {
        localExercises = manager.activeSession?.sortedExercises ?? []
    }
    
    /// Persist the local exercise order back to the manager
    private func persistExerciseOrder() {
        for (index, exercise) in localExercises.enumerated() {
            exercise.orderIndex = index
        }
        manager.syncWidgetStateAfterExerciseChange()
        try? modelContext.save()
    }
    
    // MARK: - Header
    
    private var workoutHeader: some View {
        HStack {
            // End button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showEndConfirmation = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            
            Spacer()
            
            // Title and timer
            VStack(spacing: 2) {
                Text(manager.activeSession?.title ?? "Workout")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(manager.formattedElapsedTime)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(manager.isPaused ? .orange : .green)
            }
            
            Spacer()
            
            // Pause/Resume button
            Button {
                togglePauseResume()
            } label: {
                Image(systemName: manager.isPaused ? "play.fill" : "pause.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(manager.isPaused ? .green : .orange)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            
            // Add button (only in edit mode)
            if isEditMode {
                Button {
                    showAddExerciseSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.green)
                        .frame(width: 44, height: 44)
                        .background(Color.green.opacity(0.15), in: Circle())
                }
            }
            
            // Edit/Done button
            Button {
                isEditMode.toggle()
            } label: {
                Text(isEditMode ? "Done" : "Edit")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isEditMode ? .green : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1), in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Exercise Input Panel
    
    private func exerciseInputPanel(exercise: WorkoutExercise) -> some View {
        let previousData = manager.getPreviousSetData(
            for: exercise.name,
            setIndex: manager.currentSetIndex,
            using: modelContext
        )
        
        return ExerciseInputCard(
            exercise: exercise,
            setNumber: manager.currentSetIndex + 1,
            previousData: previousData,
            weight: $currentWeight,
            reps: $currentReps,
            duration: $currentDuration,
            speed: $currentSpeed,
            incline: $currentIncline,
            onComplete: {
                completeCurrentSet()
            }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Rest Timer Overlay
    
    private var restTimerOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {}
            
            RestTimerView(
                isActive: .constant(manager.isRestTimerActive),
                timeRemaining: Binding(
                    get: { manager.restTimeRemaining },
                    set: { _ in }
                ),
                totalTime: manager.defaultRestDuration,
                onSkip: {
                    manager.skipRest()
                },
                onComplete: {},
                onAddTime: { seconds in
                    manager.addRestTime(seconds)
                }
            )
        }
        .transition(.opacity)
    }
    
    // MARK: - Actions
    
    private func completeCurrentSet() {
        manager.completeCurrentSet(
            weight: currentWeight,
            reps: Int(currentReps),
            duration: currentDuration,
            speed: currentSpeed,
            incline: currentIncline
        )
        
        // Check if workout is complete - prompt user instead of auto-completing
        if manager.isWorkoutComplete {
            showWorkoutCompleteConfirmation = true
        } else {
            loadCurrentSetDefaults()
        }
    }
    
    /// Tracks the last exercise we loaded defaults for, to detect exercise changes
    @State private var lastLoadedExerciseId: UUID?
    
    private func loadCurrentSetDefaults() {
        guard let exercise = manager.currentExercise else { return }
        
        // Check if we're on the same exercise or switching to a new one
        let isSameExercise = lastLoadedExerciseId == exercise.id
        lastLoadedExerciseId = exercise.id
        
        // If same exercise and we already have a weight, keep it
        // This allows the weight to carry over between sets
        if isSameExercise && currentWeight > 0 {
            // Keep current weight, just reset reps for the new set
            currentReps = 0
        } else {
            // New exercise - try to load from previous session or reset
            if let previousData = manager.getPreviousSetData(
                for: exercise.name,
                setIndex: manager.currentSetIndex,
                using: modelContext
            ) {
                currentWeight = previousData.weight ?? 0
                currentReps = Double(previousData.reps ?? 0)
            } else {
                currentWeight = 0
                currentReps = 0
            }
        }
        
        currentDuration = 0
        currentSpeed = 0
        currentIncline = 0
    }
    
    /// Pause workout and return to flow - can continue later
    private func pauseWorkout() {
        // Pause the workout (keeps session incomplete for resume)
        manager.pauseWorkout()
        // Save to SwiftData
        try? modelContext.save()
        // Dismiss the full-screen cover to go back to Flow
        dismiss()
    }
    
    /// Toggle pause/resume without leaving Gym Mode
    private func togglePauseResume() {
        if manager.isPaused {
            manager.continueWorkout()
        } else {
            manager.pauseWorkout()
        }
    }
    
    /// End workout completely and show summary
    private func endAndCompleteWorkout() {
        // Capture training session before endWorkout() clears it via resetState()
        let trainingSession = manager.activeTrainingSession
        let liveDistance = healthKitManager.currentSessionDistance

        completedSession = manager.endWorkout()

        // Add completed session to today's DayLog so hasWorkedOut returns true
        if let session = completedSession {
            let startOfDay = Calendar.current.startOfDay(for: Date())
            if let todayLog = dayLogs.first(where: { $0.date >= startOfDay }) {
                // Add to existing DayLog
                if !todayLog.workouts.contains(where: { $0.id == session.id }) {
                    todayLog.workouts.append(session)
                }
            } else {
                // Create new DayLog for today
                let newLog = DayLog(date: Date(), workouts: [session])
                modelContext.insert(newLog)
            }
        }

        try? modelContext.save()

        // If this was a Marathon Coach session, show post-run check-in first
        if let trainingSession = trainingSession, !trainingSession.isCompleted {
            // Pre-fill HealthKit distance if available
            if liveDistance > 0 {
                trainingSession.actualDistance = liveDistance
            }
            completedTrainingSession = trainingSession
            showPostRunCheckIn = true
        } else {
            showSummary = true
        }
    }
    
    /// Discard workout without saving
    private func discardWorkout() {
        // Clear local references first to prevent UI updates on deleted objects
        localExercises = []
        
        // Capture the session to delete BEFORE resetting state (which sets activeSession to nil)
        let sessionToDelete = manager.activeSession
        
        // Use resetState() to clear manager state safely
        manager.resetState()
        
        // Delete the captured session
        if let session = sessionToDelete {
            modelContext.delete(session)
            // Explicitly save context to ensure deletion persists immediately
            try? modelContext.save()
        }
        
        dismiss()
    }
    
    /// Complete a cardio exercise with timed/freestyle data
    private func completeCardioExercise(
        exercise: WorkoutExercise,
        duration: TimeInterval,
        speed: Double,
        incline: Double,
        intervals: [CardioInterval]?
    ) {
        // Get the current set for this exercise
        guard let currentSet = exercise.sortedSets.first(where: { !$0.isCompleted }) else { return }
        
        // Update the set with the cardio data
        currentSet.duration = duration
        currentSet.speed = speed
        currentSet.incline = incline
        currentSet.isCompleted = true
        
        // Save interval data if freestyle
        if let intervals = intervals {
            let encoder = JSONEncoder()
            currentSet.cardioIntervals = try? encoder.encode(intervals)
            currentSet.cardioMode = CardioWorkoutMode.freestyle.rawValue
        } else {
            currentSet.cardioMode = CardioWorkoutMode.timed.rawValue
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Move to next exercise or check completion
        manager.advanceToNextExercise()
        
        // Check if workout is complete - prompt user instead of auto-completing
        if manager.isWorkoutComplete {
            showWorkoutCompleteConfirmation = true
        }
        
        try? modelContext.save()
    }
    
    /// Add a new exercise to the active workout mid-session
    private func addExerciseToWorkout(_ exerciseData: (name: String, type: ExerciseType, setCount: Int)) {
        guard let session = manager.activeSession else { return }
        
        // Create the new exercise
        let newExercise = WorkoutExercise(
            name: exerciseData.name,
            type: exerciseData.type,
            orderIndex: session.exercises.count
        )
        
        // Add sets based on user selection
        for i in 0..<exerciseData.setCount {
            let set = ExerciseSet(orderIndex: i)
            newExercise.sets.append(set)
        }
        
        // Set session relationship
        newExercise.session = session
        
        // Insert into context
        modelContext.insert(newExercise)
        
        // Add to session
        session.exercises.append(newExercise)
        
        // Tell manager to update widget state
        manager.syncWidgetStateAfterExerciseChange()
        
        // Save changes
        try? modelContext.save()
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    /// Delete an exercise from the active workout
    private func deleteExercise(_ exercise: WorkoutExercise) {
        guard let session = manager.activeSession else { return }
        
        // Remove from session
        session.exercises.removeAll { $0.id == exercise.id }
        
        // Delete from context
        modelContext.delete(exercise)
        
        // Re-index remaining exercises
        for (index, ex) in session.sortedExercises.enumerated() {
            ex.orderIndex = index
        }
        
        // Update widget/live activity
        manager.syncWidgetStateAfterExerciseChange()
        
        // Save changes
        try? modelContext.save()
        
        // Haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.warning)
    }
    
    private func checkForPausedWorkout() {
        // If the manager already has an active workout, ensure it's running
        if manager.isWorkoutActive {
            // We are entering the active workout view, so we must ensure the timer is running.
            // Explicitly continue even if we think we are already running (it's idempotent)
            // to catch cases where the timer might have stopped.
            if let session = manager.activeSession {
                manager.resumeWorkout(session: session)
            }
            loadCurrentSetDefaults()
            return
        }
        
        if let pausedSession = todaysIncompleteWorkouts.first {
            // Resume the paused workout
            manager.resumeWorkout(session: pausedSession)
            loadCurrentSetDefaults()
        } else {
            // No paused workout, show setup sheet
            showSetupSheet = true
        }
    }
}

// MARK: - Edit Mode Exercise Row

/// A modern Liquid Glass row for edit mode with native List reordering
private struct EditModeExerciseRow: View {
    let exercise: WorkoutExercise
    let completedSets: Int
    let totalSets: Int
    let onDelete: () -> Void
    
    private var isComplete: Bool {
        completedSets >= totalSets
    }
    
    private var progress: Double {
        guard totalSets > 0 else { return 0 }
        return Double(completedSets) / Double(totalSets)
    }
    
    private var exerciseIcon: String {
        switch exercise.type {
        case .weight: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .calisthenics: return "figure.gymnastics"
        case .flexibility: return "figure.cooldown"
        case .machine: return "gearshape.fill"
        case .functional: return "figure.cross.training"
        }
    }
    
    private var accentColor: Color {
        isComplete ? .green : .white.opacity(0.7)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Exercise type icon with progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 3)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isComplete ? Color.green : Color.white.opacity(0.5),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                // Icon
                Image(systemName: isComplete ? "checkmark" : exerciseIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
            .frame(width: 36, height: 36)
            
            // Exercise info
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(exercise.type.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Progress text
            Text("\(completedSets)/\(totalSets)")
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(isComplete ? .green : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background {
                    Capsule()
                        .fill(isComplete ? Color.green.opacity(0.15) : Color.white.opacity(0.08))
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            // Liquid Glass background
            RoundedRectangle(cornerRadius: 20)
                .fill(.clear)
                .glassEffect(.regular.interactive())
        }
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 20))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Flexible Exercise Card

private struct FlexibleExerciseCard: View {
    let exercise: WorkoutExercise
    let isActive: Bool
    let completedSets: Int
    let totalSets: Int
    let isEditMode: Bool
    let onTap: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    
    private var isComplete: Bool {
        completedSets >= totalSets
    }
    
    private var progress: Double {
        guard totalSets > 0 else { return 0 }
        return Double(completedSets) / Double(totalSets)
    }
    
    var body: some View {
        HStack(spacing: 16) {
                // Progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 3)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            isComplete ? Color.green : (isActive ? Color.orange : Color.white.opacity(0.5)),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                    } else {
                        Text("\(completedSets)/\(totalSets)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isActive ? .orange : .secondary)
                    }
                }
                .frame(width: 40, height: 40)
                
                // Exercise info
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(isComplete ? .secondary : .primary)
                        .strikethrough(isComplete)
                    
                    Text(exercise.type.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Edit mode controls or active indicator
                if isEditMode {
                    HStack(spacing: 8) {
                        Button(action: onMoveUp) {
                            Image(systemName: "chevron.up")
                                .font(.caption.weight(.bold))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1), in: Circle())
                        }
                        
                        Button(action: onMoveDown) {
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1), in: Circle())
                        }
                    }
                } else if isActive && !isComplete {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isActive && !isEditMode ? Color.orange.opacity(0.1) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isActive && !isEditMode ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditMode {
                    onTap()
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if isEditMode {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
    }
}

// MARK: - Add Exercise Sheet

private struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: ((name: String, type: ExerciseType, setCount: Int)) -> Void
    
    @State private var searchText: String = ""
    @State private var selectedType: ExerciseType? = nil
    @State private var selectedExercise: (name: String, type: ExerciseType)? = nil
    @State private var setCount: Int = 3
    
    private var allExercises: [(name: String, type: ExerciseType)] {
        var exercises: [(name: String, type: ExerciseType)] = []
        
        for name in WorkoutExercise.weightExercises {
            exercises.append((name, .weight))
        }
        for name in WorkoutExercise.machineExercises {
            exercises.append((name, .machine))
        }
        for name in WorkoutExercise.cardioExercises {
            exercises.append((name, .cardio))
        }
        for name in WorkoutExercise.calisthenicsExercises {
            exercises.append((name, .calisthenics))
        }
        for name in WorkoutExercise.functionalExercises {
            exercises.append((name, .functional))
        }
        for name in WorkoutExercise.flexibilityExercises {
            exercises.append((name, .flexibility))
        }
        
        return exercises.sorted { $0.name < $1.name }
    }
    
    private var filteredExercises: [(name: String, type: ExerciseType)] {
        var result = allExercises
        
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }
        
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Animated mesh gradient background
                AnimatedMeshGradientView(theme: .flow)
                    .ignoresSafeArea()
                
                if let exercise = selectedExercise {
                    // Phase 2: Set count selection
                    setCountSelectionView(for: exercise)
                } else {
                    // Phase 1: Exercise selection
                    exerciseSelectionView
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Exercise Selection View
    
    private var exerciseSelectionView: some View {
        VStack(spacing: 0) {
            // Header with glass effect
            VStack(spacing: 16) {
                // Title bar
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text("Add Exercise")
                        .font(.headline.weight(.semibold))
                    
                    Spacer()
                    
                    // Invisible spacer for alignment
                    Text("Cancel")
                        .font(.body.weight(.medium))
                        .opacity(0)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Type filter chips with glass effect
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        GlassFilterChip(title: "All", isSelected: selectedType == nil) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedType = nil
                            }
                        }
                        
                        ForEach(ExerciseType.allCases, id: \.self) { type in
                            GlassFilterChip(
                                title: type.title,
                                icon: type.icon,
                                color: colorForType(type),
                                isSelected: selectedType == type
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedType = type
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 12)
            .background(.ultraThinMaterial)
            
            // Exercise list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredExercises, id: \.name) { exercise in
                        ExerciseSelectionRow(
                            name: exercise.name,
                            type: exercise.type,
                            color: colorForType(exercise.type)
                        ) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedExercise = exercise
                                setCount = (exercise.type == .cardio || exercise.type == .flexibility) ? 1 : 3
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            
            // Search bar at bottom with glass effect
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search exercises", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Set Count Selection View
    
    private func setCountSelectionView(for exercise: (name: String, type: ExerciseType)) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedExercise = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                        Text("Back")
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
                
                Spacer()
                
                Text("Set Count")
                    .font(.headline.weight(.semibold))
                
                Spacer()
                
                // Invisible spacer
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .opacity(0)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            
            Spacer()
            
            // Exercise info card with glass effect
            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(colorForType(exercise.type).opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: exercise.type.icon)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(colorForType(exercise.type))
                }
                
                Text(exercise.name)
                    .font(.title2.weight(.bold))
                
                Text(exercise.type.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 40)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.clear)
                    .glassEffect(.regular)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Set count stepper with glass effect
            VStack(spacing: 16) {
                Text("How many sets?")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 32) {
                    Button {
                        if setCount > 1 {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                setCount -= 1
                            }
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(setCount <= 1 ? Color.secondary : Color.white)
                            .frame(width: 56, height: 56)
                            .background {
                                Circle()
                                    .fill(.clear)
                                    .glassEffect(.regular.interactive())
                            }
                    }
                    .disabled(setCount <= 1)
                    
                    Text("\(setCount)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 100)
                        .contentTransition(.numericText())
                    
                    Button {
                        if setCount < 10 {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                setCount += 1
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(setCount >= 10 ? Color.secondary : Color.white)
                            .frame(width: 56, height: 56)
                            .background {
                                Circle()
                                    .fill(.clear)
                                    .glassEffect(.regular.interactive())
                            }
                    }
                    .disabled(setCount >= 10)
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 32)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.clear)
                    .glassEffect(.regular)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Add button
            Button {
                onAdd((name: exercise.name, type: exercise.type, setCount: setCount))
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Add \(exercise.name)")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.green.gradient, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .green.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    private func colorForType(_ type: ExerciseType) -> Color {
        switch type {
        case .weight: return .blue
        case .cardio: return .green
        case .calisthenics: return .orange
        case .flexibility: return .purple
        case .machine: return .red
        case .functional: return .cyan
        }
    }
}

// MARK: - Glass Filter Chip

private struct GlassFilterChip: View {
    let title: String
    var icon: String? = nil
    var color: Color = .white
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : color)
                }
                
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.green.gradient)
                } else {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(.regular.interactive())
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise Selection Row

private struct ExerciseSelectionRow: View {
    let name: String
    let type: ExerciseType
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon with colored background
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                }
                
                // Exercise name
                Text(name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                    .glassEffect(.regular.interactive())
            }
        }
        .buttonStyle(.plain)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .black : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.green : Color.white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Drag Preview Card

/// A visually polished drag preview card for exercise reordering
private struct DragPreviewCard: View {
    let exerciseName: String
    let completedSets: Int
    let totalSets: Int
    let isEditMode: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Drag indicator icon
            Image(systemName: "line.3.horizontal")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            
            Text(exerciseName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Spacer()
            
            // Progress indicator
            if completedSets >= totalSets {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Text("\(completedSets)/\(totalSets)")
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(minWidth: 300, maxWidth: 360)
        .background {
            // Dark gradient background with depth
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.18, blue: 0.22),
                            Color(red: 0.1, green: 0.12, blue: 0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Subtle inner glow
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
        .shadow(color: .green.opacity(0.15), radius: 20, x: 0, y: 0) // Subtle green glow
    }
}

#Preview {
    GymModeView()
        .modelContainer(for: WorkoutSession.self, inMemory: true)
}
