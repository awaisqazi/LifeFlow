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
    func startWorkout(workoutTitle: String, totalExercises: Int, exerciseName: String, workoutStartDate: Date) {
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
                    workoutStartDate: workoutStartDate
                )
            }
        }
    }
    
    private func startActivityAfterCleanup(workoutTitle: String, totalExercises: Int, exerciseName: String, workoutStartDate: Date) {
        // Create attributes and initial state
        let attributes = GymWorkoutAttributes(
            workoutTitle: workoutTitle,
            totalExercises: totalExercises
        )
        
        let initialState = GymWorkoutAttributes.ContentState(
            exerciseName: exerciseName,
            currentSet: 1,
            totalSets: 3,
            elapsedTime: 0,
            workoutStartDate: workoutStartDate,
            isResting: false
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
    
    /// Update the workout activity with current state
    /// - Parameters:
    ///   - exerciseName: Current exercise
    ///   - currentSet: Current set number
    ///   - totalSets: Total sets for exercise
    ///   - elapsedTime: Total elapsed workout time in seconds
    ///   - workoutStartDate: Current session start date
    func updateWorkout(exerciseName: String, currentSet: Int, totalSets: Int, elapsedTime: Int, workoutStartDate: Date) {
        guard let activity = currentActivity else { return }
        
        let updatedState = GymWorkoutAttributes.ContentState(
            exerciseName: exerciseName,
            currentSet: currentSet,
            totalSets: totalSets,
            elapsedTime: elapsedTime,
            workoutStartDate: workoutStartDate,
            isResting: false
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
    func startRest(exerciseName: String, nextSet: Int, totalSets: Int, elapsedTime: Int, restEndTime: Date, workoutStartDate: Date) {
        guard let activity = currentActivity else { return }
        
        let restState = GymWorkoutAttributes.ContentState(
            exerciseName: exerciseName,
            currentSet: nextSet,
            totalSets: totalSets,
            elapsedTime: elapsedTime,
            workoutStartDate: workoutStartDate,
            isResting: true,
            restTimeRemaining: Int(restEndTime.timeIntervalSinceNow),
            restEndTime: restEndTime
        )
        
        let content = ActivityContent(state: restState, staleDate: nil)
        
        Task {
            await activity.update(content)
        }
    }
    
    /// End rest and resume workout
    func endRest(exerciseName: String, currentSet: Int, totalSets: Int, elapsedTime: Int, workoutStartDate: Date) {
        updateWorkout(
            exerciseName: exerciseName,
            currentSet: currentSet,
            totalSets: totalSets,
            elapsedTime: elapsedTime,
            workoutStartDate: workoutStartDate
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
