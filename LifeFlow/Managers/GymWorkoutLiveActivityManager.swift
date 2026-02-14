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
import CoreLocation

// MARK: - Douglas-Peucker Polyline Downsampler

/// Reduces the number of points in a CLLocationCoordinate2D polyline using
/// the Douglas-Peucker algorithm. This prevents memory bloat and excessive
/// SwiftUI diffing when appending 1Hz location updates to a MapPolyline.
///
/// Usage: Feed the full coordinate history through `simplify(coordinates:epsilon:)`
/// to get a visually equivalent polyline with far fewer points for MapKit.
nonisolated struct PolylineDownsampler: Sendable {
    /// Simplifies a coordinate array using the Douglas-Peucker algorithm.
    /// - Parameters:
    ///   - coordinates: The full array of CLLocationCoordinate2D points.
    ///   - epsilon: The perpendicular distance threshold (in degrees). Larger values = more aggressive simplification.
    ///     A good default for running routes is ~0.00005 (~5 meters).
    /// - Returns: A simplified array preserving endpoints and significant turns.
    @concurrent
    func simplify(coordinates: [CLLocationCoordinate2D], epsilon: Double = 0.00005) async -> [CLLocationCoordinate2D] {
        guard coordinates.count > 2 else { return coordinates }
        return douglasPeucker(coordinates, epsilon: epsilon)
    }

    private func douglasPeucker(_ points: [CLLocationCoordinate2D], epsilon: Double) -> [CLLocationCoordinate2D] {
        guard points.count > 2 else { return points }

        // Find the point with the maximum perpendicular distance from the line
        // connecting the first and last points.
        var maxDistance: Double = 0
        var maxIndex = 0

        let start = points[0]
        let end = points[points.count - 1]

        for i in 1..<(points.count - 1) {
            let distance = perpendicularDistance(point: points[i], lineStart: start, lineEnd: end)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        // If the max distance exceeds epsilon, recursively simplify both halves.
        if maxDistance > epsilon {
            let left = douglasPeucker(Array(points[0...maxIndex]), epsilon: epsilon)
            let right = douglasPeucker(Array(points[maxIndex...]), epsilon: epsilon)
            // Combine, removing duplicate midpoint
            return Array(left.dropLast()) + right
        } else {
            // All intermediate points are within epsilon; keep only endpoints.
            return [start, end]
        }
    }

    /// Calculates perpendicular distance from a point to a line segment (in degrees).
    private func perpendicularDistance(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude

        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            // Start and end are the same point
            let pdx = point.longitude - lineStart.longitude
            let pdy = point.latitude - lineStart.latitude
            return sqrt(pdx * pdx + pdy * pdy)
        }

        // Project point onto line, clamping to segment
        let t = max(0, min(1, ((point.longitude - lineStart.longitude) * dx + (point.latitude - lineStart.latitude) * dy) / lengthSquared))
        let projLon = lineStart.longitude + t * dx
        let projLat = lineStart.latitude + t * dy

        let diffLon = point.longitude - projLon
        let diffLat = point.latitude - projLat
        return sqrt(diffLon * diffLon + diffLat * diffLat)
    }
}

// MARK: - GymWorkoutLiveActivityManager

/// Manages Live Activities for gym workouts.
/// Call from GymModeManager to start/update/end workout activities.
///
/// Live Activity updates are throttled to fire only on significant milestones
/// (every 0.25 miles or heart-rate zone change) instead of every tick,
/// preventing Apple from silently throttling the widget's daily update budget.
@Observable
final class GymWorkoutLiveActivityManager {
    
    /// Current workout activity
    private(set) var currentActivity: Activity<GymWorkoutAttributes>?

    // MARK: - Live Activity Throttle State
    // Only push ActivityKit updates when the runner crosses a meaningful
    // milestone, preserving the system's daily update budget.

    /// Distance (in miles) at the time of the last ActivityKit update.
    private var lastUpdateDistanceMiles: Double = 0

    /// Heart rate zone at the time of the last ActivityKit update.
    private var lastUpdateHeartRateZone: Int = 0

    /// The distance increment (in miles) required before pushing a new update.
    private static let milestoneDistanceMiles: Double = 0.25

    /// Determines whether a Live Activity update should be pushed based on
    /// distance milestones and heart-rate zone changes.
    /// - Parameters:
    ///   - currentDistance: The runner's current cumulative distance in miles.
    ///   - currentHRZone: The runner's current heart-rate zone (1–5).
    /// - Returns: `true` if a significant milestone has been reached.
    func shouldPushUpdate(currentDistance: Double, currentHRZone: Int) -> Bool {
        let distanceDelta = currentDistance - lastUpdateDistanceMiles
        let zoneChanged = currentHRZone != lastUpdateHeartRateZone && currentHRZone > 0

        if distanceDelta >= Self.milestoneDistanceMiles || zoneChanged {
            lastUpdateDistanceMiles = currentDistance
            if currentHRZone > 0 {
                lastUpdateHeartRateZone = currentHRZone
            }
            return true
        }
        return false
    }

    /// Resets throttle state when starting a new workout session.
    func resetThrottle() {
        lastUpdateDistanceMiles = 0
        lastUpdateHeartRateZone = 0
    }
    
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
        cardioDuration: TimeInterval = 0,
        intervalProgress: Double? = nil,
        currentIntervalName: String? = nil,
        targetDistanceRemaining: Double? = nil,
        targetDistanceTotal: Double? = nil,
        currentDistanceMiles: Double? = nil,
        targetPaceMinutesPerMile: Double? = nil,
        ghostExpectedDistanceMiles: Double? = nil,
        ghostDeltaMiles: Double? = nil
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
                    cardioDuration: cardioDuration,
                    intervalProgress: intervalProgress,
                    currentIntervalName: currentIntervalName,
                    targetDistanceRemaining: targetDistanceRemaining,
                    targetDistanceTotal: targetDistanceTotal,
                    currentDistanceMiles: currentDistanceMiles,
                    targetPaceMinutesPerMile: targetPaceMinutesPerMile,
                    ghostExpectedDistanceMiles: ghostExpectedDistanceMiles,
                    ghostDeltaMiles: ghostDeltaMiles
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
        cardioDuration: TimeInterval,
        intervalProgress: Double?,
        currentIntervalName: String?,
        targetDistanceRemaining: Double?,
        targetDistanceTotal: Double?,
        currentDistanceMiles: Double?,
        targetPaceMinutesPerMile: Double?,
        ghostExpectedDistanceMiles: Double?,
        ghostDeltaMiles: Double?
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
            cardioDuration: cardioDuration,
            intervalProgress: intervalProgress,
            currentIntervalName: currentIntervalName,
            targetDistanceRemaining: targetDistanceRemaining,
            targetDistanceTotal: targetDistanceTotal,
            currentDistanceMiles: currentDistanceMiles,
            targetPaceMinutesPerMile: targetPaceMinutesPerMile,
            ghostExpectedDistanceMiles: ghostExpectedDistanceMiles,
            ghostDeltaMiles: ghostDeltaMiles
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
        cardioDuration: TimeInterval = 0,
        intervalProgress: Double? = nil,
        currentIntervalName: String? = nil,
        targetDistanceRemaining: Double? = nil,
        targetDistanceTotal: Double? = nil,
        currentDistanceMiles: Double? = nil,
        targetPaceMinutesPerMile: Double? = nil,
        ghostExpectedDistanceMiles: Double? = nil,
        ghostDeltaMiles: Double? = nil
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
            cardioDuration: cardioDuration,
            intervalProgress: intervalProgress,
            currentIntervalName: currentIntervalName,
            targetDistanceRemaining: targetDistanceRemaining,
            targetDistanceTotal: targetDistanceTotal,
            currentDistanceMiles: currentDistanceMiles,
            targetPaceMinutesPerMile: targetPaceMinutesPerMile,
            ghostExpectedDistanceMiles: ghostExpectedDistanceMiles,
            ghostDeltaMiles: ghostDeltaMiles
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
        isPaused: Bool = false,
        intervalProgress: Double? = nil,
        currentIntervalName: String? = nil,
        targetDistanceRemaining: Double? = nil,
        targetDistanceTotal: Double? = nil,
        currentDistanceMiles: Double? = nil,
        targetPaceMinutesPerMile: Double? = nil,
        ghostExpectedDistanceMiles: Double? = nil,
        ghostDeltaMiles: Double? = nil
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
            isCardio: false, // Rest is not a cardio activity state per se
            intervalProgress: intervalProgress,
            currentIntervalName: currentIntervalName,
            targetDistanceRemaining: targetDistanceRemaining,
            targetDistanceTotal: targetDistanceTotal,
            currentDistanceMiles: currentDistanceMiles,
            targetPaceMinutesPerMile: targetPaceMinutesPerMile,
            ghostExpectedDistanceMiles: ghostExpectedDistanceMiles,
            ghostDeltaMiles: ghostDeltaMiles
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
        isPaused: Bool = false,
        intervalProgress: Double? = nil,
        currentIntervalName: String? = nil,
        targetDistanceRemaining: Double? = nil,
        targetDistanceTotal: Double? = nil,
        currentDistanceMiles: Double? = nil,
        targetPaceMinutesPerMile: Double? = nil,
        ghostExpectedDistanceMiles: Double? = nil,
        ghostDeltaMiles: Double? = nil
    ) {
        updateWorkout(
            exerciseName: exerciseName,
            currentSet: currentSet,
            totalSets: totalSets,
            currentExerciseIndex: currentExerciseIndex,
            elapsedTime: elapsedTime,
            workoutStartDate: workoutStartDate,
            isPaused: isPaused,
            intervalProgress: intervalProgress,
            currentIntervalName: currentIntervalName,
            targetDistanceRemaining: targetDistanceRemaining,
            targetDistanceTotal: targetDistanceTotal,
            currentDistanceMiles: currentDistanceMiles,
            targetPaceMinutesPerMile: targetPaceMinutesPerMile,
            ghostExpectedDistanceMiles: ghostExpectedDistanceMiles,
            ghostDeltaMiles: ghostDeltaMiles
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
