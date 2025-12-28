//
//  GymModeView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI
import SwiftData

/// Full-screen immersive workout experience.
/// High contrast design with minimal liquid effects for gym visibility.
struct GymModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var manager = GymModeManager()
    @State private var showSetupSheet: Bool = true
    @State private var showSummary: Bool = false
    @State private var showEndConfirmation: Bool = false
    
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
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSetupSheet) {
            WorkoutSetupSheet { session in
                manager.startWorkout(session: session)
                loadCurrentSetDefaults()
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showSummary) {
            if let session = manager.activeSession {
                GymWorkoutSummaryView(session: session) {
                    // Save and dismiss
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
        .confirmationDialog("End Workout?", isPresented: $showEndConfirmation) {
            Button("End & Save", role: .destructive) {
                endWorkout()
            }
            Button("Discard", role: .destructive) {
                discardWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to save this workout?")
        }
    }
    
    // MARK: - Active Workout View
    
    private var activeWorkoutView: some View {
        VStack(spacing: 0) {
            // Header
            workoutHeader
            
            // Exercise list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(manager.getExerciseGroups(), id: \.first?.id) { group in
                        if group.count > 1 {
                            // Superset
                            SupersetCardStack(
                                exercises: group,
                                currentExerciseID: manager.currentExercise?.id,
                                currentSetIndex: manager.currentSetIndex,
                                onExerciseTap: { _ in }
                            )
                        } else if let exercise = group.first {
                            // Single exercise
                            SingleExerciseCard(
                                exercise: exercise,
                                currentSetIndex: manager.currentSetIndex,
                                isActive: exercise.id == manager.currentExercise?.id,
                                onTap: {}
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 200) // Space for input card
            }
            
            Spacer()
            
            // Current exercise input panel
            if let exercise = manager.currentExercise {
                exerciseInputPanel(exercise: exercise)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Header
    
    private var workoutHeader: some View {
        HStack {
            // End button
            Button {
                showEndConfirmation = true
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
                    .foregroundStyle(.green)
            }
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear
                .frame(width: 44, height: 44)
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
                .onTapGesture {
                    // Don't dismiss on tap
                }
            
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
                onComplete: {
                    // Timer completed naturally
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
            showSummary = true
        } else {
            // Load defaults for next set
            loadCurrentSetDefaults()
        }
    }
    
    private func loadCurrentSetDefaults() {
        guard let exercise = manager.currentExercise else { return }
        
        // Try to get previous data
        if let previousData = manager.getPreviousSetData(
            for: exercise.name,
            setIndex: manager.currentSetIndex,
            using: modelContext
        ) {
            currentWeight = previousData.weight ?? 0
            currentReps = Double(previousData.reps ?? 0)
        } else {
            // Default values
            currentWeight = 0
            currentReps = 0
        }
        
        currentDuration = 0
        currentSpeed = 0
        currentIncline = 0
    }
    
    private func endWorkout() {
        let _ = manager.endWorkout()
        showSummary = true
    }
    
    private func discardWorkout() {
        let _ = manager.endWorkout()
        dismiss()
    }
}

#Preview {
    GymModeView()
        .modelContainer(for: WorkoutSession.self, inMemory: true)
}
