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
            // Check if the shared manager already has an active workout
            if manager.isWorkoutActive {
                // Workout is running, show current state (no sheet needed)
                loadCurrentSetDefaults()
            } else {
                // No active workout, check for paused sessions or show setup
                checkForPausedWorkout()
            }
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
        
        // Check if workout is complete
        if manager.isWorkoutComplete {
            endAndCompleteWorkout()
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
    
    private var isComplete: Bool {
        completedSets >= totalSets
    }
    
    private var progress: Double {
        guard totalSets > 0 else { return 0 }
        return Double(completedSets) / Double(totalSets)
    }
    
    var body: some View {
        Button(action: onTap) {
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
        }
        .buttonStyle(.plain)
        .disabled(isEditMode)
    }
}

#Preview {
    GymModeView()
        .modelContainer(for: WorkoutSession.self, inMemory: true)
}
