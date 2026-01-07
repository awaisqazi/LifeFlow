//
//  GymModeManager.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation
import SwiftUI
import SwiftData
import Observation
import Combine
import WidgetKit

/// Manages the active workout state during Gym Mode.
/// Handles exercise navigation, rest timer, screen wake lock, and superset flow.
@Observable
final class GymModeManager {
    
    // MARK: - Workout State
    
    /// The active workout session being tracked
    private(set) var activeSession: WorkoutSession?
    
    /// Index of the currently active exercise
    private(set) var currentExerciseIndex: Int = 0
    
    /// Index of the current set within the active exercise
    private(set) var currentSetIndex: Int = 0
    
    /// Whether a workout is currently in progress
    var isWorkoutActive: Bool { activeSession != nil }
    
    /// Elapsed time since workout started
    private(set) var elapsedTime: TimeInterval = 0
    
    // MARK: - Rest Timer
    
    /// Whether the rest timer is currently running
    private(set) var isRestTimerActive: Bool = false
    
    /// Remaining seconds on the rest timer
    private(set) var restTimeRemaining: TimeInterval = 0
    
    /// Default rest duration in seconds
    var defaultRestDuration: TimeInterval = 60
    
    // MARK: - Private Properties
    
    private var elapsedTimerCancellable: AnyCancellable?
    private var restTimerCancellable: AnyCancellable?
    private var workoutStartTime: Date?
    
    /// Manager for workout Live Activity (handles progress and rest)
    private var workoutLiveActivityManager = GymWorkoutLiveActivityManager()
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Widget Sync
    
    /// Sync current workout state to widget via App Group UserDefaults
    private func syncWidgetState() {
        let state = WorkoutWidgetState(
            isActive: isWorkoutActive,
            workoutTitle: activeSession?.title ?? "Workout",
            exerciseName: currentExercise?.name ?? "Ready",
            currentSet: currentSetIndex + 1,
            totalSets: currentExercise?.sets.count ?? 0,
            workoutStartDate: workoutStartTime ?? Date(),
            restEndTime: isRestTimerActive ? Date().addingTimeInterval(restTimeRemaining) : nil
        )
        state.save()
    }
    
    // MARK: - Workout Lifecycle
    
    /// Start a new workout session
    /// - Parameter session: The workout session to start
    func startWorkout(session: WorkoutSession) {
        print("🔥 GymModeManager.startWorkout called with session: \(session.title)")
        
        activeSession = session
        currentExerciseIndex = 0
        currentSetIndex = 0
        workoutStartTime = Date()
        elapsedTime = 0
        
        // Enable screen wake lock
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Start elapsed time timer
        startElapsedTimer()
        
        // Start Live Activity
        let firstExercise = session.sortedExercises.first?.name ?? "Workout"
        print("🔥 Calling workoutLiveActivityManager.startWorkout...")
        workoutLiveActivityManager.startWorkout(
            workoutTitle: session.title,
            totalExercises: session.exercises.count,
            exerciseName: firstExercise,
            workoutStartDate: workoutStartTime ?? Date()
        )
        
        // Sync to widget
        syncWidgetState()
    }
    
    /// Resume a paused workout session
    /// - Parameter session: The workout session to resume
    func resumeWorkout(session: WorkoutSession) {
        activeSession = session
        
        // Use the already accumulated duration from the session
        elapsedTime = session.duration
        
        // Find the first exercise with incomplete sets
        let exercises = session.sortedExercises
        for (index, exercise) in exercises.enumerated() {
            let incompleteSets = exercise.sortedSets.filter { !$0.isCompleted }
            if !incompleteSets.isEmpty {
                currentExerciseIndex = index
                // Find the first incomplete set in this exercise
                currentSetIndex = getNextIncompleteSetIndex(for: exercise)
                break
            }
        }
        
        // Enable screen wake lock
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Resume elapsed time timer
        // Adjust start time to account for already elapsed time
        workoutStartTime = Date().addingTimeInterval(-elapsedTime)
        startElapsedTimer()
        
        // Resume Live Activity
        if let currentEx = currentExercise {
            workoutLiveActivityManager.startWorkout(
                workoutTitle: session.title,
                totalExercises: session.exercises.count,
                exerciseName: currentEx.name,
                workoutStartDate: workoutStartTime ?? Date()
            )
        }
        
        // Sync to widget
        syncWidgetState()
    }
    
    /// End the current workout and return the completed session
    /// - Returns: The completed workout session
    func endWorkout() -> WorkoutSession? {
        let completedSession = activeSession
        
        // Update session end time
        activeSession?.endTime = Date()
        activeSession?.duration = elapsedTime
        
        // Stop timers
        stopElapsedTimer()
        stopRestTimer()
        
        // Clean up all Live Activities
        Task {
            await workoutLiveActivityManager.endAllActivities()
        }
        
        // Disable screen wake lock
        UIApplication.shared.isIdleTimerDisabled = false
        
        // Reset state
        activeSession = nil
        currentExerciseIndex = 0
        currentSetIndex = 0
        elapsedTime = 0
        
        // Clear widget state
        WorkoutWidgetState.clear()
        
        return completedSession
    }
    
    /// Pause the workout (stops timers but keeps session in incomplete state for resume)
    func pauseWorkout() {
        guard let session = activeSession else { return }
        
        // Save the current elapsed time to the session (but don't set endTime)
        session.duration = elapsedTime
        
        // Stop timers
        stopElapsedTimer()
        stopRestTimer()
        
        // Clean up Live Activities
        Task {
            await workoutLiveActivityManager.endAllActivities()
        }
        
        // Disable screen wake lock
        UIApplication.shared.isIdleTimerDisabled = false
        
        // Reset manager state (but session remains in SwiftData without endTime)
        activeSession = nil
        currentExerciseIndex = 0
        currentSetIndex = 0
        elapsedTime = 0
        
        // Clear widget state (paused workout shows as idle)
        WorkoutWidgetState.clear()
    }
    
    // MARK: - Exercise Navigation
    
    /// Get the currently active exercise
    var currentExercise: WorkoutExercise? {
        guard let session = activeSession else { return nil }
        let exercises = session.sortedExercises
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }
    
    /// Get the current set for the active exercise
    var currentSet: ExerciseSet? {
        guard let exercise = currentExercise else { return nil }
        let sets = exercise.sortedSets
        guard currentSetIndex < sets.count else { return nil }
        return sets[currentSetIndex]
    }
    
    // MARK: - Flexible Exercise Selection
    
    /// Select a specific exercise to work on (allows any order)
    /// - Parameter exercise: The exercise to select
    func selectExercise(_ exercise: WorkoutExercise) {
        guard let session = activeSession else { return }
        let exercises = session.sortedExercises
        
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            currentExerciseIndex = index
            // Find the next incomplete set for this exercise
            currentSetIndex = getNextIncompleteSetIndex(for: exercise)
            
            // Synchronize Live Activity
            workoutLiveActivityManager.updateWorkout(
                exerciseName: exercise.name,
                currentSet: currentSetIndex + 1,
                totalSets: exercise.sets.count,
                elapsedTime: Int(elapsedTime),
                workoutStartDate: self.workoutStartTime ?? Date()
            )
            
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }
    
    /// Get the index of the next incomplete set for an exercise
    func getNextIncompleteSetIndex(for exercise: WorkoutExercise) -> Int {
        let sets = exercise.sortedSets
        for (index, set) in sets.enumerated() {
            if !set.isCompleted {
                return index
            }
        }
        // All sets complete, return the last set index
        return max(0, sets.count - 1)
    }
    
    /// Move an exercise to a new position
    /// - Parameters:
    ///   - fromIndex: Original index
    ///   - toIndex: Target index
    func moveExercise(from fromIndex: Int, to toIndex: Int) {
        guard let session = activeSession else { return }
        var exercises = session.sortedExercises
        guard fromIndex < exercises.count, toIndex < exercises.count else { return }
        
        let exercise = exercises.remove(at: fromIndex)
        exercises.insert(exercise, at: toIndex)
        
        // Update order indices
        for (index, ex) in exercises.enumerated() {
            ex.orderIndex = index
        }
        
        // Update current index if needed
        if currentExerciseIndex == fromIndex {
            currentExerciseIndex = toIndex
        } else if currentExerciseIndex > fromIndex && currentExerciseIndex <= toIndex {
            currentExerciseIndex -= 1
        } else if currentExerciseIndex < fromIndex && currentExerciseIndex >= toIndex {
            currentExerciseIndex += 1
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    /// Check if an exercise has any incomplete sets
    func hasIncompleteSets(_ exercise: WorkoutExercise) -> Bool {
        exercise.sets.contains { !$0.isCompleted }
    }
    
    /// Get completed sets count for an exercise
    func completedSetsCount(for exercise: WorkoutExercise) -> Int {
        exercise.sets.filter { $0.isCompleted }.count
    }
    
    /// Complete the current set and advance to the next
    /// - Parameters:
    ///   - weight: Weight used (for weight training)
    ///   - reps: Reps completed (for weight/calisthenics)
    ///   - duration: Duration (for cardio)
    func completeCurrentSet(
        weight: Double? = nil,
        reps: Int? = nil,
        duration: TimeInterval? = nil,
        speed: Double? = nil,
        incline: Double? = nil
    ) {
        guard let set = currentSet else { return }
        
        // Update set data
        set.weight = weight
        set.reps = reps
        set.duration = duration
        set.speed = speed
        set.incline = incline
        set.isCompleted = true
        
        // Haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        
        // Advance to next set/exercise
        advanceToNext()
        
        // Start rest timer (unless workout is complete)
        if isWorkoutActive && !isWorkoutComplete {
            startRestTimer(duration: defaultRestDuration)
        }
    }
    
    /// Whether all exercises and sets are complete
    var isWorkoutComplete: Bool {
        guard let session = activeSession else { return false }
        let exercises = session.sortedExercises
        
        // Check if we've gone past all exercises
        if currentExerciseIndex >= exercises.count {
            return true
        }
        
        return false
    }
    
    /// Advance to the next set or exercise, handling supersets
    private func advanceToNext() {
        guard let session = activeSession else { return }
        let exercises = session.sortedExercises
        guard currentExerciseIndex < exercises.count else { return }
        
        let exerciseToAdvance = exercises[currentExerciseIndex]
        
        // Check if current exercise is part of a superset
        if exerciseToAdvance.isSuperset, let groupID = exerciseToAdvance.supersetGroupID {
            // Find all exercises in this superset group
            let supersetExercises = exercises.filter { $0.supersetGroupID == groupID }
            
            // Find next exercise in superset
            if let currentIndexInSuperset = supersetExercises.firstIndex(where: { $0.id == exerciseToAdvance.id }) {
                let nextIndexInSuperset = currentIndexInSuperset + 1
                
                if nextIndexInSuperset < supersetExercises.count {
                    // Move to next exercise in superset (same set number)
                    if let globalIndex = exercises.firstIndex(where: { $0.id == supersetExercises[nextIndexInSuperset].id }) {
                        currentExerciseIndex = globalIndex
                    }
                } else {
                    // Completed all exercises in superset for this set
                    // Move to next set of first exercise in superset
                    currentSetIndex += 1
                    
                    // Check if we've completed all sets
                    let firstExercise = supersetExercises[0]
                    if currentSetIndex >= firstExercise.sets.count {
                        // Move to next exercise group after superset
                        moveToNextExerciseGroup(after: groupID, exercises: exercises)
                    } else {
                        // Go back to first exercise in superset
                        if let globalIndex = exercises.firstIndex(where: { $0.id == firstExercise.id }) {
                            currentExerciseIndex = globalIndex
                        }
                    }
                }
            }
        } else {
            // Regular exercise (not a superset)
            let currentSets = exerciseToAdvance.sortedSets
            
            if currentSetIndex + 1 < currentSets.count {
                // More sets remaining
                currentSetIndex += 1
            } else {
                // Move to next exercise
                currentExerciseIndex += 1
                currentSetIndex = 0
            }
        }
        
        // Update Live Activity immediately after advancing
        if let newExercise = self.currentExercise {
            workoutLiveActivityManager.updateWorkout(
                exerciseName: newExercise.name,
                currentSet: currentSetIndex + 1,
                totalSets: newExercise.sets.count,
                elapsedTime: Int(elapsedTime),
                workoutStartDate: self.workoutStartTime ?? Date()
            )
        }
    }
    
    /// Move to the next exercise group after completing a superset
    private func moveToNextExerciseGroup(after groupID: UUID, exercises: [WorkoutExercise]) {
        if let lastSupersetIndex = exercises.lastIndex(where: { $0.supersetGroupID == groupID }) {
            currentExerciseIndex = lastSupersetIndex + 1
            currentSetIndex = 0
            
            // Update Live Activity
            if let nextExercise = self.currentExercise {
                workoutLiveActivityManager.updateWorkout(
                    exerciseName: nextExercise.name,
                    currentSet: currentSetIndex + 1,
                    totalSets: nextExercise.sets.count,
                    elapsedTime: Int(elapsedTime),
                    workoutStartDate: self.workoutStartTime ?? Date()
                )
            }
        }
    }
    
    // MARK: - Rest Timer
    
    /// Start the rest timer
    /// - Parameter duration: Duration in seconds
    func startRestTimer(duration: TimeInterval) {
        restTimeRemaining = duration
        isRestTimerActive = true
        
        // Update workout Live Activity to show rest state
        let exerciseName = currentExercise?.name ?? "Rest"
        let nextSet = currentSetIndex + 1
        let totalSets = currentExercise?.sets.count ?? 3
        
        workoutLiveActivityManager.startRest(
            exerciseName: exerciseName,
            nextSet: nextSet,
            totalSets: totalSets,
            elapsedTime: Int(elapsedTime),
            restEndTime: Date().addingTimeInterval(duration),
            workoutStartDate: self.workoutStartTime ?? Date()
        )
        
        // Sync rest state to widget
        syncWidgetState()
        
        restTimerCancellable?.cancel()
        restTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                if self.restTimeRemaining > 0 {
                    self.restTimeRemaining -= 1
                    
                    // No longer updating Live Activity every second for rest.
                    // The native timer handles the countdown on-device.
                } else {
                    self.stopRestTimer()
                    // Haptic feedback when timer completes
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.warning)
                }
            }
    }
    
    /// Add time to the current rest timer
    /// - Parameter seconds: Seconds to add
    func addRestTime(_ seconds: TimeInterval) {
        restTimeRemaining += seconds
        
        // Update Live Activity if active
        if isRestTimerActive {
            let exerciseName = currentExercise?.name ?? "Rest"
            let nextSet = currentSetIndex + 1
            let totalSets = currentExercise?.sets.count ?? 3
            
            workoutLiveActivityManager.startRest(
                exerciseName: exerciseName,
                nextSet: nextSet,
                totalSets: totalSets,
                elapsedTime: Int(elapsedTime),
                restEndTime: Date().addingTimeInterval(restTimeRemaining),
                workoutStartDate: self.workoutStartTime ?? Date()
            )
            
            // Sync updated rest time to widget
            syncWidgetState()
        }
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    /// Stop/skip the rest timer
    func stopRestTimer() {
        restTimerCancellable?.cancel()
        restTimerCancellable = nil
        isRestTimerActive = false
        restTimeRemaining = 0
        
        // Resume normal workout state in Live Activity
        if let currentActiveExercise = self.currentExercise {
            workoutLiveActivityManager.endRest(
                exerciseName: currentActiveExercise.name,
                currentSet: currentSetIndex + 1,
                totalSets: currentActiveExercise.sets.count,
                elapsedTime: Int(elapsedTime),
                workoutStartDate: self.workoutStartTime ?? Date()
            )
        }
        
        // Sync to widget (rest ended)
        syncWidgetState()
    }
    
    /// Skip the rest timer
    func skipRest() {
        stopRestTimer()
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    // MARK: - Elapsed Time Timer
    
    private func startElapsedTimer() {
        elapsedTimerCancellable?.cancel()
        elapsedTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let startTime = self.workoutStartTime else { return }
                self.elapsedTime = Date().timeIntervalSince(startTime)
                
                // No longer updating Live Activity every second.
                // The native timer handles the count-up on-device.
            }
    }
    
    private func stopElapsedTimer() {
        elapsedTimerCancellable?.cancel()
        elapsedTimerCancellable = nil
    }
    
    // MARK: - Progressive Overload
    
    /// Fetch the previous session's data for a specific exercise
    /// - Parameters:
    ///   - exerciseName: Name of the exercise
    ///   - modelContext: SwiftData model context
    /// - Returns: The most recent set data for this exercise, if available
    func getPreviousSetData(
        for exerciseName: String,
        setIndex: Int,
        using modelContext: ModelContext
    ) -> (weight: Double?, reps: Int?)? {
        // Query for recent workout sessions containing this exercise
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.exercises.contains { exercise in
                    exercise.name == exerciseName
                }
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        do {
            let sessions = try modelContext.fetch(descriptor)
            
            // Find the most recent session (excluding current)
            for session in sessions {
                if session.id == activeSession?.id { continue }
                
                if let exercise = session.exercises.first(where: { $0.name == exerciseName }) {
                    let sets = exercise.sortedSets
                    if setIndex < sets.count {
                        let previousSet = sets[setIndex]
                        return (previousSet.weight, previousSet.reps)
                    }
                }
            }
        } catch {
            print("Error fetching previous set data: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Superset Helpers
    
    /// Get exercises grouped by superset
    /// - Returns: Array of exercise groups (single exercises or superset arrays)
    func getExerciseGroups() -> [[WorkoutExercise]] {
        guard let session = activeSession else { return [] }
        let exercises = session.sortedExercises
        
        var groups: [[WorkoutExercise]] = []
        var processedIDs: Set<UUID> = []
        
        for exercise in exercises {
            if processedIDs.contains(exercise.id) { continue }
            
            if exercise.isSuperset, let groupID = exercise.supersetGroupID {
                // Find all exercises in this superset
                let supersetGroup = exercises.filter { $0.supersetGroupID == groupID }
                groups.append(supersetGroup)
                supersetGroup.forEach { processedIDs.insert($0.id) }
            } else {
                // Single exercise
                groups.append([exercise])
                processedIDs.insert(exercise.id)
            }
        }
        
        return groups
    }
    
    // MARK: - Formatted Display
    
    /// Format elapsed time as MM:SS or HH:MM:SS
    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// Format rest time remaining as MM:SS
    var formattedRestTime: String {
        let minutes = Int(restTimeRemaining) / 60
        let seconds = Int(restTimeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
