//
//  LiveActivityManager.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation
import ActivityKit
import SwiftUI

/// Manages Live Activities for the rest timer.
/// Handles starting, updating, and ending activities.
@Observable
final class LiveActivityManager {
    
    /// Current rest timer activity
    private(set) var currentActivity: Activity<RestTimerAttributes>?
    
    // MARK: - Start Activity
    
    /// Start a new rest timer Live Activity
    /// - Parameters:
    ///   - exerciseName: Name of the exercise
    ///   - nextSetNumber: The upcoming set number
    ///   - duration: Total rest duration in seconds
    func startRestTimer(exerciseName: String, nextSetNumber: Int, duration: Int) {
        // Check if Live Activities are supported
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }
        
        // End any existing activity
        Task {
            await endRestTimer()
        }
        
        // Create attributes and initial state
        let attributes = RestTimerAttributes(
            exerciseName: exerciseName,
            nextSetNumber: nextSetNumber,
            totalDuration: duration
        )
        
        let initialState = RestTimerAttributes.ContentState(
            timeRemaining: duration,
            isPaused: false
        )
        
        // Create activity content
        let content = ActivityContent(state: initialState, staleDate: nil)
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivity = activity
            print("Started Live Activity: \(activity.id)")
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update Activity
    
    /// Update the rest timer with new remaining time
    /// - Parameter timeRemaining: Seconds remaining
    func updateRestTimer(timeRemaining: Int) {
        guard let activity = currentActivity else { return }
        
        let updatedState = RestTimerAttributes.ContentState(
            timeRemaining: timeRemaining,
            isPaused: false
        )
        
        let content = ActivityContent(state: updatedState, staleDate: nil)
        
        Task {
            await activity.update(content)
        }
    }
    
    /// Pause the rest timer
    func pauseRestTimer(timeRemaining: Int) {
        guard let activity = currentActivity else { return }
        
        let pausedState = RestTimerAttributes.ContentState(
            timeRemaining: timeRemaining,
            isPaused: true
        )
        
        let content = ActivityContent(state: pausedState, staleDate: nil)
        
        Task {
            await activity.update(content)
        }
    }
    
    // MARK: - End Activity
    
    /// End the rest timer activity
    /// - Parameter immediately: If true, dismisses immediately. If false, shows final content briefly.
    func endRestTimer(immediately: Bool = false) async {
        guard let activity = currentActivity else { return }
        
        let finalState = RestTimerAttributes.ContentState(
            timeRemaining: 0,
            isPaused: false
        )
        
        let dismissalPolicy: ActivityUIDismissalPolicy = immediately ? .immediate : .default
        
        let content = ActivityContent(state: finalState, staleDate: nil)
        
        await activity.end(content, dismissalPolicy: dismissalPolicy)
        currentActivity = nil
    }
    
    /// End all activities (cleanup)
    func endAllActivities() async {
        for activity in Activity<RestTimerAttributes>.activities {
            let finalState = RestTimerAttributes.ContentState(
                timeRemaining: 0,
                isPaused: false
            )
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
