//
//  GymWorkoutLiveActivityManager.swift
//  LifeFlow
//
//  Manages the Gym Workout Live Activity for showing workout progress
//  in Dynamic Island and on the Lock Screen.
//

import Foundation
import ActivityKit
import SwiftUI

/// Manages Live Activities for gym workouts.
/// Call from GymModeManager to start/update/end workout activities.
@Observable
final class GymWorkoutLiveActivityManager {
    
    /// Current workout activity
    private(set) var currentActivity: Activity<GymWorkoutAttributes>?
    
    // MARK: - Start Activity
    
    /// Start a new workout Live Activity
    /// - Parameters:
    ///   - workoutTitle: Name of the workout (e.g., "Push Day")
    ///   - totalExercises: Total number of exercises
    ///   - exerciseName: First exercise name
    ///   - workoutStartDate: Start date of the session
    func startWorkout(
        workoutTitle: String,
        totalExercises: Int,
        exerciseName: String,
        workoutStartDate: Date,
        currentSet: Int,
        totalSets: Int,
        elapsedTime: Int,
        currentExerciseIndex: Int,
        isPaused: Bool = false,
        isCardio: Bool = false,
        cardioModeIndex: Int = 0,
        cardioSpeed: Double = 0,
        cardioIncline: Double = 0,
        cardioEndTime: Date? = nil,
        cardioDuration: TimeInterval = 0
    ) {
        // Check authorization status first
        let authInfo = ActivityAuthorizationInfo()
        print("🏋️ Live Activity - areActivitiesEnabled: \(authInfo.areActivitiesEnabled)")
        print("🏋️ Live Activity - frequentPushesEnabled: \(authInfo.frequentPushesEnabled)")
        
        guard authInfo.areActivitiesEnabled else {
            print("❌ Live Activities are not enabled on this device")
            return
        }
        
        // End any existing activity synchronously
        Task {
            await endAllActivities()
            await MainActor.run {
                startActivityAfterCleanup(
                    workoutTitle: workoutTitle,
                    totalExercises: totalExercises,
                    exerciseName: exerciseName,
                    workoutStartDate: workoutStartDate,
                    currentSet: currentSet,
                    totalSets: totalSets,
                    elapsedTime: elapsedTime,
                    currentExerciseIndex: currentExerciseIndex,
                    isPaused: isPaused,
                    isCardio: isCardio,
                    cardioModeIndex: cardioModeIndex,
                    cardioSpeed: cardioSpeed,
                    cardioIncline: cardioIncline,
                    cardioEndTime: cardioEndTime,
                    cardioDuration: cardioDuration
                )
            }
        }
    }
    
    private func startActivityAfterCleanup(
        workoutTitle: String,
        totalExercises: Int,
        exerciseName: String,
        workoutStartDate: Date,
        currentSet: Int,
        totalSets: Int,
        elapsedTime: Int,
        currentExerciseIndex: Int,
        isPaused: Bool,
        isCardio: Bool,
        cardioModeIndex: Int,
        cardioSpeed: Double,
        cardioIncline: Double,
        cardioEndTime: Date?,
        cardioDuration: TimeInterval
    ) {
        // Create attributes and initial state
        let attributes = GymWorkoutAttributes(
            workoutTitle: workoutTitle,
            totalExercises: totalExercises
        )
        
        let initialState = GymWorkoutAttributes.ContentState(
            exerciseName: exerciseName,
            currentSet: currentSet,
            totalSets: totalSets,
            currentExerciseIndex: currentExerciseIndex,
            elapsedTime: elapsedTime,
            workoutStartDate: workoutStartDate,
            isResting: false,
            isPaused: isPaused,
            isCardio: isCardio,
            cardioModeIndex: cardioModeIndex,
            cardioSpeed: cardioSpeed,
            cardioIncline: cardioIncline,
            cardioEndTime: cardioEndTime,
            cardioDuration: cardioDuration
        )
        
        print("🏋️ Starting Live Activity with title: \(workoutTitle), exercise: \(exerciseName)")
        
        let content = ActivityContent(state: initialState, staleDate: nil)
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivity = activity
            print("✅ Started Workout Live Activity: \(activity.id)")
            print("✅ Activity state: \(activity.activityState)")
        } catch {
            print("❌ Failed to start Workout Live Activity: \(error)")
            print("❌ Error description: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update Activity
    
    func updateWorkout(
        exerciseName: String,
        currentSet: Int,
        totalSets: Int,
        currentExerciseIndex: Int,
        elapsedTime: Int,
        workoutStartDate: Date,
        isPaused: Bool = false,
        isCardio: Bool = false,
        cardioModeIndex: Int = 0,
        cardioSpeed: Double = 0,
        cardioIncline: Double = 0,
        cardioEndTime: Date? = nil,
        cardioDuration: TimeInterval = 0
    ) {
        guard let activity = currentActivity else { return }
        
        let updatedState = GymWorkoutAttributes.ContentState(
            exerciseName: exerciseName,
            currentSet: currentSet,
            totalSets: totalSets,
            currentExerciseIndex: currentExerciseIndex,
            elapsedTime: elapsedTime,
            workoutStartDate: workoutStartDate,
            isResting: false,
            isPaused: isPaused,
            isCardio: isCardio,
            cardioModeIndex: cardioModeIndex,
            cardioSpeed: cardioSpeed,
            cardioIncline: cardioIncline,
            cardioEndTime: cardioEndTime,
            cardioDuration: cardioDuration
        )
        
        let content = ActivityContent(state: updatedState, staleDate: nil)
        
        Task {
            await activity.update(content)
        }
    }
    
    /// Start rest timer in the activity
    /// - Parameters:
    ///   - exerciseName: Current exercise
    ///   - nextSet: Next set number
    ///   - totalSets: Total sets
    ///   - elapsedTime: Elapsed workout time
    ///   - restEndTime: When the rest timer ends
    ///   - workoutStartDate: Current session start date
    func startRest(
        exerciseName: String,
        nextSet: Int,
        totalSets: Int,
        currentExerciseIndex: Int,
        elapsedTime: Int,
        restEndTime: Date,
        workoutStartDate: Date,
        isPaused: Bool = false
    ) {
        guard let activity = currentActivity else { return }
        
        let restState = GymWorkoutAttributes.ContentState(
            exerciseName: exerciseName,
            currentSet: nextSet,
            totalSets: totalSets,
            currentExerciseIndex: currentExerciseIndex,
            elapsedTime: elapsedTime,
            workoutStartDate: workoutStartDate,
            isResting: true,
            restTimeRemaining: Int(restEndTime.timeIntervalSinceNow),
            restEndTime: restEndTime,
            isPaused: isPaused,
            isCardio: false // Rest is not a cardio activity state per se
        )
        
        let content = ActivityContent(state: restState, staleDate: nil)
        
        Task {
            await activity.update(content)
        }
    }
    
    /// End rest and resume workout
    func endRest(
        exerciseName: String,
        currentSet: Int,
        totalSets: Int,
        currentExerciseIndex: Int,
        elapsedTime: Int,
        workoutStartDate: Date,
        isPaused: Bool = false
    ) {
        updateWorkout(
            exerciseName: exerciseName,
            currentSet: currentSet,
            totalSets: totalSets,
            currentExerciseIndex: currentExerciseIndex,
            elapsedTime: elapsedTime,
            workoutStartDate: workoutStartDate,
            isPaused: isPaused
        )
    }
    
    // MARK: - End Activity
    
    /// End the workout activity
    func endWorkout() async {
        guard let activity = currentActivity else { return }
        
        // Final state before dismissal
        let finalState = GymWorkoutAttributes.ContentState(
            exerciseName: "Complete!",
            currentSet: 0,
            totalSets: 0,
            elapsedTime: 0,
            isResting: false
        )
        
        let content = ActivityContent(state: finalState, staleDate: nil)
        await activity.end(content, dismissalPolicy: .default)
        currentActivity = nil
    }
    
    /// End all gym workout activities
    func endAllActivities() async {
        for activity in Activity<GymWorkoutAttributes>.activities {
            let finalState = GymWorkoutAttributes.ContentState(
                exerciseName: "Complete!",
                currentSet: 0,
                totalSets: 0,
                elapsedTime: 0,
                isResting: false
            )
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
