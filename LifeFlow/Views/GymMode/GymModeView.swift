//
//  GymModeView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI
import SwiftData

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
    
    @Environment(\.gymModeManager) private var manager
    @State private var showSetupSheet: Bool = false // Start false, will be set on appear
    @State private var showSummary: Bool = false
    @State private var showEndConfirmation: Bool = false
    @State private var isEditMode: Bool = false
    @State private var completedSession: WorkoutSession? = nil
    @State private var showAddExerciseSheet: Bool = false
    @State private var showWorkoutCompleteConfirmation: Bool = false
    
    // Current set input values
    @State private var currentWeight: Double = 0
    @State private var currentReps: Double = 0
    @State private var currentDuration: TimeInterval = 0
    @State private var currentSpeed: Double = 0
    @State private var currentIncline: Double = 0
    
    var body: some View {
        ZStack {
            // Dark background for high contrast
            Color.black.ignoresSafeArea()
            
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
    }
    
    // MARK: - Active Workout View
    
    private var activeWorkoutView: some View {
        VStack(spacing: 0) {
            // Header
            workoutHeader
            
            // Exercise list (tappable, reorderable)
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(manager.activeSession?.sortedExercises ?? [], id: \.id) { exercise in
                        FlexibleExerciseCard(
                            exercise: exercise,
                            isActive: exercise.id == manager.currentExercise?.id,
                            completedSets: manager.completedSetsCount(for: exercise),
                            totalSets: exercise.sets.count,
                            isEditMode: isEditMode,
                            onTap: {
                                if !isEditMode {
                                    manager.selectExercise(exercise)
                                    loadCurrentSetDefaults()
                                }
                            },
                            onMoveUp: {
                                if let index = manager.activeSession?.sortedExercises.firstIndex(where: { $0.id == exercise.id }),
                                   index > 0 {
                                    manager.moveExercise(from: index, to: index - 1)
                                }
                            },
                            onMoveDown: {
                                if let session = manager.activeSession,
                                   let index = session.sortedExercises.firstIndex(where: { $0.id == exercise.id }),
                                   index < session.exercises.count - 1 {
                                    manager.moveExercise(from: index, to: index + 1)
                                }
                            },
                            onDelete: {
                                deleteExercise(exercise)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 220)
            }
            
            Spacer()
            
            // Current exercise input panel (if not in edit mode)
            if !isEditMode, let exercise = manager.currentExercise {
                exerciseInputPanel(exercise: exercise)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: isEditMode)
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
    
    /// End workout completely and show summary
    private func endAndCompleteWorkout() {
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
        showSummary = true
    }
    
    /// Discard workout without saving
    private func discardWorkout() {
        if let session = manager.activeSession {
            modelContext.delete(session)
            try? modelContext.save() // Persist the deletion
        }
        let _ = manager.endWorkout()
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
            if let exercise = selectedExercise {
                // Phase 2: Set count selection
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Exercise name
                    VStack(spacing: 8) {
                        Image(systemName: exercise.type.icon)
                            .font(.system(size: 48))
                            .foregroundStyle(colorForType(exercise.type))
                        
                        Text(exercise.name)
                            .font(.title2.weight(.bold))
                    }
                    
                    // Set count stepper
                    VStack(spacing: 12) {
                        Text("How many sets?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 24) {
                            Button {
                                if setCount > 1 { setCount -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.secondary)
                            }
                            .disabled(setCount <= 1)
                            
                            Text("\(setCount)")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .frame(width: 80)
                            
                            Button {
                                if setCount < 10 { setCount += 1 }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.green)
                            }
                            .disabled(setCount >= 10)
                        }
                    }
                    
                    Spacer()
                    
                    // Add button
                    Button {
                        onAdd((name: exercise.name, type: exercise.type, setCount: setCount))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("Add \(exercise.name)")
                                .font(.headline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green.gradient, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .navigationTitle("Set Count")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") {
                            selectedExercise = nil
                        }
                    }
                }
            } else {
                // Phase 1: Exercise selection
                VStack(spacing: 0) {
                    // Type filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All", isSelected: selectedType == nil) {
                                selectedType = nil
                            }
                            
                            ForEach(ExerciseType.allCases, id: \.self) { type in
                                FilterChip(title: type.title, isSelected: selectedType == type) {
                                    selectedType = type
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                    
                    // Exercise list
                    List {
                        ForEach(filteredExercises, id: \.name) { exercise in
                            Button {
                                selectedExercise = exercise
                                // Default to 1 set for cardio/flexibility, 3 for weights
                                setCount = (exercise.type == .cardio || exercise.type == .flexibility) ? 1 : 3
                            } label: {
                                HStack {
                                    Image(systemName: exercise.type.icon)
                                        .foregroundStyle(colorForType(exercise.type))
                                        .frame(width: 30)
                                    
                                    Text(exercise.name)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                .searchable(text: $searchText, prompt: "Search exercises")
                .navigationTitle("Add Exercise")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
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

#Preview {
    GymModeView()
        .modelContainer(for: WorkoutSession.self, inMemory: true)
}
