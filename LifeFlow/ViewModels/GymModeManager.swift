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
import HealthKit

/// Manages the active workout state during Gym Mode.
/// Handles exercise navigation, rest timer, screen wake lock, and superset flow.

// MARK: - Workout Target Types

/// Defines the goal type for a workout session, enabling context-aware workout launches
/// from the Marathon Coach training plan.
enum WorkoutTarget: Equatable {
    /// No specific goal - freestyle workout
    case open
    /// Time-based goal
    case duration(TimeInterval)
    /// Distance-based goal (e.g., 5 miles)
    case distance(Double, unit: UnitLength)
    /// Interval training (e.g., 8x400m with 2 min rest)
    case interval(repeats: Int, distanceMeters: Double, restSeconds: TimeInterval)
    
    var displayName: String {
        switch self {
        case .open: return "Freestyle"
        case .duration(let time): 
            let minutes = Int(time / 60)
            return "\(minutes) min"
        case .distance(let dist, let unit):
            let formatter = MeasurementFormatter()
            formatter.unitStyle = .short
            let measurement = Measurement(value: dist, unit: unit)
            return formatter.string(from: measurement)
        case .interval(let repeats, let distance, _):
            let meters = Int(distance)
            return "\(repeats)x\(meters)m"
        }
    }
}

struct HealthKitWorkoutSnapshot: Equatable {
    let workoutID: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let distanceMiles: Double?
}

struct WorkoutFinishPayload {
    let completedSession: WorkoutSession?
    let linkedTrainingSession: TrainingSession?
    let bestDistanceMiles: Double?
    let healthKitSnapshot: HealthKitWorkoutSnapshot?
    let targetPaceMinutesPerMile: Double?
    let weatherSummary: String?
}

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
    
    /// Whether the active workout is currently paused
    private(set) var isPaused: Bool = false
    
    /// Elapsed time since workout started
    private(set) var elapsedTime: TimeInterval = 0
    
    // MARK: - Cardio State
    
    /// Current cardio mode (0: Timed, 1: Freestyle, 2: Distance)
    private(set) var cardioModeIndex: Int = 0
    
    /// When the timed cardio ends
    private(set) var cardioEndTime: Date?
    
    /// Current cardio speed
    var cardioSpeed: Double = 0
    
    /// Current cardio incline
    var cardioIncline: Double = 0
    
    /// Current cardio elapsed time
    private(set) var cardioElapsedTime: TimeInterval = 0
    
    /// Current cardio total duration (for timed mode)
    private(set) var cardioDuration: TimeInterval = 0
    
    /// Whether a cardio session is currently running (timer active)
    var isCardioInProgress: Bool = false
    
    /// Baseline HealthKit distance captured at guided-run start to avoid stale carryover.
    var guidedRunDistanceBaselineMiles: Double = 0
    
    // MARK: - Marathon Coach Integration
    
    /// The target goal for the current workout (from training plan)
    var activeTarget: WorkoutTarget = .open
    
    /// Links this workout to a training plan session for post-workout adaptation
    var associatedTrainingSessionID: UUID?
    
    /// The active training session context (if launched from a plan)
    var activeTrainingSession: TrainingSession?
    
    /// Live distance from HealthKit during running sessions
    var healthKitDistance: Double = 0
    
    /// Guided run location mode (false: outdoor GPS, true: indoor treadmill)
    var isIndoorRun: Bool = false
    
    /// Whether Voice Coach is currently muted for this run
    private(set) var isVoiceCoachMuted: Bool = false
    
    /// Whether the Voice Coach is actively speaking a prompt.
    private(set) var isCoachSpeaking: Bool = false
    
    /// Target pace used by Voice Coach and Ghost Runner (minutes per mile)
    private(set) var targetPaceMinutesPerMile: Double?
    
    /// Weather callout captured at guided-run start for post-run history context
    private(set) var activeWeatherSummary: String?
    
    /// Helper to extract target distance from activeTarget
    var targetDistance: Double {
        if case .distance(let miles, _) = activeTarget {
            return miles
        }
        return 0
    }
    
    // MARK: - Rest Timer
    
    /// Whether the rest timer is currently running
    private(set) var isRestTimerActive: Bool = false
    
    /// Total duration for the current rest period (seconds)
    private(set) var restDuration: TimeInterval = 0
    
    /// When the rest timer ends (Date-based for background sync)
    private(set) var restEndTime: Date?
    
    /// Remaining seconds on the rest timer (computed from restEndTime)
    var restTimeRemaining: TimeInterval {
        guard let endTime = restEndTime else { return 0 }
        return max(0, endTime.timeIntervalSinceNow)
    }
    
    /// Default rest duration in seconds
    var defaultRestDuration: TimeInterval = 60
    
    // MARK: - Private Properties
    
    private var elapsedTimer: Timer?
    private var restTimerCancellable: AnyCancellable?
    private var workoutStartTime: Date?
    
    /// Manager for workout Live Activity (handles progress and rest)
    private var workoutLiveActivityManager = GymWorkoutLiveActivityManager()
    
    /// Handles spoken pace/distance coaching during guided runs
    private let voiceCoach = VoiceCoach()
    
    // MARK: - Initialization
    
    init() {
        voiceCoach.onSpeakingStateChange = { [weak self] isSpeaking in
            self?.isCoachSpeaking = isSpeaking
        }
        
        // Register for Darwin notifications from widget extension
        registerForWidgetNotifications()
    }
    
    deinit {
        // Unregister Darwin notification observer
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
    
    /// Register for Darwin notifications posted by widget intents
    private func registerForWidgetNotifications() {
        let notificationName = "com.Fez.LifeFlow.workoutStateChanged" as CFString
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                // Callback runs on arbitrary thread - dispatch to main
                DispatchQueue.main.async {
                    guard let observer = observer else { return }
                    let manager = Unmanaged<GymModeManager>.fromOpaque(observer).takeUnretainedValue()
                    manager.handleWidgetStateChange()
                }
            },
            notificationName,
            nil,
            .deliverImmediately
        )
    }
    
    /// Handle widget state change notification
    private func handleWidgetStateChange() {
        guard isWorkoutActive else { return }
        
        let widgetState = WorkoutWidgetState.load()
        
        // Sync pause/resume state to Live Activity
        if let currentEx = currentExercise {
            // Update our local pause state to match widget
            if widgetState.isPaused != isPaused {
                let wasResumed = isPaused && !widgetState.isPaused
                let wasPaused = !isPaused && widgetState.isPaused
                
                isPaused = widgetState.isPaused
                
                // Sync elapsed time from widget
                elapsedTime = elapsedTimeFromWidgetState(widgetState)
                
                if wasResumed {
                    // Resuming - restart the elapsed timer
                    workoutStartTime = Date().addingTimeInterval(-elapsedTime)
                    startElapsedTimer()
                    UIApplication.shared.isIdleTimerDisabled = true
                    syncHealthKitPauseState(paused: false)
                    
                    // Restore rest timer if there was remaining time
                    if let restRemaining = widgetState.restTimeRemaining, restRemaining > 0 {
                        restEndTime = Date().addingTimeInterval(restRemaining)
                        // isRestTimerActive should already be true if we were resting
                        // The rest timer will continue from the restored end time
                    }
                    
                    // Restore cardio timer if there was remaining time
                    if widgetState.isCardio && widgetState.cardioModeIndex == 0,
                       let cardioRemaining = widgetState.cardioTimeRemaining, cardioRemaining > 0 {
                        cardioEndTime = Date().addingTimeInterval(cardioRemaining)
                    }
                } else if wasPaused {
                    // Pausing - stop the elapsed timer
                    stopElapsedTimer()
                    UIApplication.shared.isIdleTimerDisabled = false
                    syncHealthKitPauseState(paused: true)
                }
            }
            
            // Update Live Activity with current state
            let context = liveContextValues()
            if isRestTimerActive, let endTime = restEndTime {
                // Use startRest to update Live Activity with rest state
                workoutLiveActivityManager.startRest(
                    exerciseName: currentEx.name,
                    nextSet: currentSetIndex + 1,
                    totalSets: currentEx.sets.count,
                    currentExerciseIndex: currentExerciseIndex,
                    elapsedTime: Int(elapsedTime),
                    restEndTime: endTime,
                    workoutStartDate: workoutStartTime ?? Date(),
                    isPaused: widgetState.isPaused,
                    intervalProgress: context.intervalProgress,
                    currentIntervalName: context.intervalName,
                    targetDistanceRemaining: context.distanceRemaining,
                    targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
                )
            } else {
                workoutLiveActivityManager.updateWorkout(
                    exerciseName: currentEx.name,
                    currentSet: currentSetIndex + 1,
                    totalSets: currentEx.sets.count,
                    currentExerciseIndex: currentExerciseIndex,
                    elapsedTime: Int(elapsedTime),
                    workoutStartDate: workoutStartTime ?? Date(),
                    isPaused: widgetState.isPaused,
                    isCardio: currentEx.type == .cardio,
                    cardioModeIndex: cardioModeIndex,
                    cardioSpeed: cardioSpeed,
                    cardioIncline: cardioIncline,
                    cardioEndTime: cardioEndTime,
                    cardioDuration: cardioDuration,
                    intervalProgress: context.intervalProgress,
                    currentIntervalName: context.intervalName,
                    targetDistanceRemaining: context.distanceRemaining,
                    targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
                )
            }
        }
    }
    
    // MARK: - Live Activity Intent Handling
    
    /// Check for and handle pending actions from Live Activity intents.
    /// Call this when the app becomes active to sync widget actions with app state.
    func checkForWidgetActions() {
        let widgetState = WorkoutWidgetState.load()
        let elapsedFromWidget = elapsedTimeFromWidgetState(widgetState)
        
        // Handle pause request
        if widgetState.pauseRequested && isWorkoutActive {
            elapsedTime = elapsedFromWidget
            workoutStartTime = Date().addingTimeInterval(-elapsedTime)
            // Clear the flag first
            var updatedState = widgetState
            updatedState.pauseRequested = false
            updatedState.save()
            
            // Execute the pause
            pauseWorkout()
            return
        }
        
        // Sync to paused state if widget indicates paused (e.g., app relaunched)
        if widgetState.isPaused && !isPaused && isWorkoutActive {
            elapsedTime = elapsedFromWidget
            workoutStartTime = Date().addingTimeInterval(-elapsedTime)
            pauseWorkout()
            return
        }
        
        // Handle skip rest (widget cleared restEndTime while we're still resting)
        if isRestTimerActive && widgetState.restEndTime == nil {
            // Widget intent skipped the rest, sync app state
            stopRestTimer()
        }
        
        // Handle resume request (widget cleared paused state)
        if isPaused && !widgetState.isPaused {
            elapsedTime = elapsedFromWidget
            workoutStartTime = Date().addingTimeInterval(-elapsedTime)
            continueWorkout()
            return
        }
    }
    
    // MARK: - Live Context Helpers
    
    private func intervalLiveContext() -> (progress: Double?, name: String?) {
        guard case .interval(let repeats, _, _) = activeTarget else {
            return (nil, nil)
        }
        
        let effectiveRepeats = max(1, repeats)
        
        if currentSetIndex == 0 {
            return (0, "Warm-up")
        }
        
        let relativeIndex = currentSetIndex - 1
        let intervalBlockCount = max(1, (effectiveRepeats * 2) - 1)
        
        if relativeIndex >= intervalBlockCount {
            return (1, "Cool-down")
        }
        
        if relativeIndex % 2 == 0 {
            let intervalNumber = (relativeIndex / 2) + 1
            let progress = min(Double(intervalNumber) / Double(effectiveRepeats), 1)
            return (progress, "Interval \(intervalNumber) of \(effectiveRepeats)")
        }
        
        let restNumber = (relativeIndex + 1) / 2
        let progress = min(Double(restNumber) / Double(effectiveRepeats), 1)
        return (progress, "Rest \(restNumber)")
    }
    
    private func distanceLiveContext(
        distanceOverride: Double? = nil,
        elapsedOverride: TimeInterval? = nil
    ) -> (
        remaining: Double?,
        total: Double?,
        current: Double?,
        targetPace: Double?,
        ghostExpected: Double?,
        ghostDelta: Double?
    ) {
        guard case .distance(let targetMiles, _) = activeTarget else {
            return (nil, nil, nil, nil, nil, nil)
        }
        
        let currentDistanceMiles = max(0, distanceOverride ?? healthKitDistance)
        let remaining = max(0, targetMiles - currentDistanceMiles)
        
        let effectiveElapsed = max(0, elapsedOverride ?? elapsedTime)
        let targetPace = targetPaceMinutesPerMile
        let ghostExpected: Double?
        if let targetPace, targetPace > 0 {
            ghostExpected = max(0, effectiveElapsed / (targetPace * 60))
        } else {
            ghostExpected = nil
        }
        
        let ghostDelta: Double?
        if let ghostExpected {
            ghostDelta = currentDistanceMiles - ghostExpected
        } else {
            ghostDelta = nil
        }
        
        return (
            remaining,
            targetMiles,
            currentDistanceMiles,
            targetPace,
            ghostExpected,
            ghostDelta
        )
    }
    
    private func syncHealthKitPauseState(paused: Bool) {
        guard case .distance = activeTarget else { return }
        
        let watchBridge = AppDependencyManager.shared.watchConnectivityManager
        if paused {
            watchBridge.sendGuidedRunPause()
        } else {
            watchBridge.sendGuidedRunResume()
        }
        
        let healthKitManager = AppDependencyManager.shared.healthKitManager
        guard healthKitManager.isLiveWorkoutActive else { return }
        
        if #available(iOS 26.0, *) {
            if paused {
                healthKitManager.pauseLiveWorkout()
            } else {
                healthKitManager.resumeLiveWorkout()
            }
        }
    }
    
    func defaultTargetPace(for runType: RunType) -> Double? {
        MarathonPaceDefaults.targetPaceMinutesPerMile(for: runType)
    }
    
    func resolveTargetPace(for session: TrainingSession?, setupSpeedMPH: Double?) -> Double? {
        if let setupSpeedMPH, setupSpeedMPH > 0.1 {
            return 60 / setupSpeedMPH
        }
        
        guard let session else { return nil }
        return defaultTargetPace(for: session.runType)
    }
    
    /// Apply voice settings and target pace when a guided distance run is about to start.
    func beginGuidedDistanceRun(setupSpeedMPH: Double?, weatherSummary: String?) {
        activeWeatherSummary = weatherSummary
        configureVoiceCoachForActiveSession(setupSpeedMPH: setupSpeedMPH)
    }
    
    func toggleVoiceCoachMute() {
        guard case .distance = activeTarget else { return }
        
        isVoiceCoachMuted.toggle()
        voiceCoach.setMuted(isVoiceCoachMuted)
        
        var settings = MarathonCoachSettings.load()
        settings.isVoiceCoachEnabled = true
        settings.voiceCoachStartupMode = isVoiceCoachMuted ? .muted : .enabled
        settings.save()
    }
    
    private func configureVoiceCoachForActiveSession(setupSpeedMPH: Double?) {
        guard case .distance = activeTarget else {
            resetVoiceCoach()
            return
        }
        
        let settings = MarathonCoachSettings.load()
        voiceCoach.configure(from: settings)
        voiceCoach.resetSession()
        
        targetPaceMinutesPerMile = resolveTargetPace(
            for: activeTrainingSession,
            setupSpeedMPH: setupSpeedMPH
        )
        
        let shouldMute = !settings.isVoiceCoachEnabled || settings.voiceCoachStartupMode == .muted
        isVoiceCoachMuted = shouldMute
        voiceCoach.setMuted(shouldMute)
    }
    
    private func processVoiceCheckIn(currentDistance: Double, elapsedTime: TimeInterval) {
        guard case .distance = activeTarget else { return }
        guard !isPaused else { return }
        guard let targetPaceMinutesPerMile, targetPaceMinutesPerMile > 0 else { return }
        guard currentDistance > 0.02, elapsedTime > 0 else { return }
        
        let currentPaceMinutesPerMile = (elapsedTime / 60) / currentDistance
        guard currentPaceMinutesPerMile.isFinite, currentPaceMinutesPerMile > 0 else { return }
        
        voiceCoach.checkIn(
            currentDistance: currentDistance,
            currentPace: currentPaceMinutesPerMile,
            targetPace: targetPaceMinutesPerMile
        )
    }
    
    private func resetVoiceCoach() {
        voiceCoach.stop()
        isVoiceCoachMuted = false
        isCoachSpeaking = false
        targetPaceMinutesPerMile = nil
    }
    
    private func liveContextValues(
        distanceOverride: Double? = nil,
        elapsedOverride: TimeInterval? = nil
    ) -> (
        intervalProgress: Double?,
        intervalName: String?,
        distanceRemaining: Double?,
        distanceTotal: Double?,
        currentDistance: Double?,
        targetPace: Double?,
        ghostExpectedDistance: Double?,
        ghostDeltaDistance: Double?
    ) {
        let intervalContext = intervalLiveContext()
        let distanceContext = distanceLiveContext(
            distanceOverride: distanceOverride,
            elapsedOverride: elapsedOverride
        )
        return (
            intervalProgress: intervalContext.progress,
            intervalName: intervalContext.name,
            distanceRemaining: distanceContext.remaining,
            distanceTotal: distanceContext.total,
            currentDistance: distanceContext.current,
            targetPace: distanceContext.targetPace,
            ghostExpectedDistance: distanceContext.ghostExpected,
            ghostDeltaDistance: distanceContext.ghostDelta
        )
    }
    
    /// Push current distance from HealthKit into Live Activity + widget state.
    func updateHealthKitDistance(_ distanceMiles: Double) {
        healthKitDistance = max(0, distanceMiles)
        
        guard let currentEx = currentExercise else {
            syncWidgetState()
            return
        }
        
        let context = liveContextValues(distanceOverride: healthKitDistance)
        
        workoutLiveActivityManager.updateWorkout(
            exerciseName: currentEx.name,
            currentSet: currentSetIndex + 1,
            totalSets: currentEx.sets.count,
            currentExerciseIndex: currentExerciseIndex,
            elapsedTime: Int(elapsedTime),
            workoutStartDate: workoutStartTime ?? Date(),
            isPaused: isPaused,
            isCardio: currentEx.type == .cardio,
            cardioModeIndex: cardioModeIndex,
            cardioSpeed: cardioSpeed,
            cardioIncline: cardioIncline,
            cardioEndTime: cardioEndTime,
            cardioDuration: cardioDuration,
            intervalProgress: context.intervalProgress,
            currentIntervalName: context.intervalName,
            targetDistanceRemaining: context.distanceRemaining,
            targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
        )
        
        syncWidgetState()
    }
    
    // MARK: - Widget Sync
    
    /// Sync current workout state to widget via App Group UserDefaults
    private func syncWidgetState() {
        let exercises = activeSession?.sortedExercises ?? []
        
        // Previous exercise info
        var previousExercise: String? = nil
        var previousSetsCompleted = 0
        var previousTotalSets = 0
        var previousIsComplete = false
        
        // SAFETY: Check both that currentExerciseIndex > 0 AND that the index is within bounds
        if currentExerciseIndex > 0 && currentExerciseIndex - 1 < exercises.count {
            let prevEx = exercises[currentExerciseIndex - 1]
            previousExercise = prevEx.name
            previousTotalSets = prevEx.sets.count
            previousSetsCompleted = prevEx.sets.filter { $0.isCompleted }.count
            previousIsComplete = previousSetsCompleted == previousTotalSets && previousTotalSets > 0
        }
        
        // Next exercise info
        var nextExercise: String? = nil
        var nextSetsCompleted = 0
        var nextTotalSets = 0
        
        // SAFETY: Check that the next index is within bounds
        if currentExerciseIndex + 1 < exercises.count {
            let nextEx = exercises[currentExerciseIndex + 1]
            nextExercise = nextEx.name
            nextTotalSets = nextEx.sets.count
            nextSetsCompleted = nextEx.sets.filter { $0.isCompleted }.count
        }
        
        // Determine if current exercise is cardio
        let isCardioExercise = currentExercise?.type == .cardio
        let context = liveContextValues()
        
        let state = WorkoutWidgetState(
            isActive: isWorkoutActive,
            workoutTitle: activeSession?.title ?? "Workout",
            exerciseName: currentExercise?.name ?? "Ready",
            currentSet: currentSetIndex + 1,
            totalSets: currentExercise?.sets.count ?? 0,
            workoutStartDate: workoutStartTime ?? Date(),
            restEndTime: restEndTime,
            restDuration: isRestTimerActive ? restDuration : nil,
            pauseRequested: false,
            isPaused: isPaused,
            pausedDisplayTime: isPaused ? formattedElapsedTime : nil,
            previousExerciseName: previousExercise,
            previousSetsCompleted: previousSetsCompleted,
            previousTotalSets: previousTotalSets,
            previousIsComplete: previousIsComplete,
            nextExerciseName: nextExercise,
            nextSetsCompleted: nextSetsCompleted,
            nextTotalSets: nextTotalSets,
            totalExercises: exercises.count,
            currentExerciseIndex: currentExerciseIndex,
            isCardio: isCardioExercise,
            cardioElapsedTime: cardioElapsedTime,
            cardioDuration: cardioDuration,
            cardioSpeed: cardioSpeed,
            cardioIncline: cardioIncline,
            cardioEndTime: cardioEndTime,
            cardioModeIndex: cardioModeIndex,
            intervalProgress: context.intervalProgress,
            currentIntervalName: context.intervalName,
            targetDistanceRemaining: context.distanceRemaining,
            targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
        )
        state.save()
    }
    
    /// Public method to sync widget state after exercises are added/modified mid-workout
    func syncWidgetStateAfterExerciseChange() {
        syncWidgetState()
        
        // Also update Live Activity if active
        if let currentEx = currentExercise {
            let context = liveContextValues()
            workoutLiveActivityManager.updateWorkout(
                exerciseName: currentEx.name,
                currentSet: currentSetIndex + 1,
                totalSets: currentEx.sets.count,
                currentExerciseIndex: currentExerciseIndex,
                elapsedTime: Int(elapsedTime),
                workoutStartDate: workoutStartTime ?? Date(),
                isPaused: isPaused,
                isCardio: currentEx.type == .cardio,
                cardioModeIndex: cardioModeIndex,
                cardioSpeed: cardioSpeed,
                cardioIncline: cardioIncline,
                cardioEndTime: cardioEndTime,
                cardioDuration: cardioDuration,
                intervalProgress: context.intervalProgress,
                currentIntervalName: context.intervalName,
                targetDistanceRemaining: context.distanceRemaining,
                targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
            )
        }
    }
    
    /// Update cardio-specific state for widget/Live Activity sync
    func updateCardioState(
        mode: Int,
        endTime: Date? = nil,
        speed: Double,
        incline: Double,
        elapsedTime: TimeInterval = 0,
        duration: TimeInterval = 0,
        currentDistance: Double? = nil
    ) {
        self.cardioModeIndex = mode
        self.cardioEndTime = endTime
        self.cardioSpeed = speed
        self.cardioIncline = incline
        self.cardioElapsedTime = elapsedTime
        self.cardioDuration = duration
        if let currentDistance {
            self.healthKitDistance = max(0, currentDistance)
        }
        
        if mode == 2 {
            let distanceForCheckIn = max(currentDistance ?? self.healthKitDistance, 0)
            processVoiceCheckIn(currentDistance: distanceForCheckIn, elapsedTime: elapsedTime)
        }
        
        syncWidgetState()
        
        // Also update Live Activity if active
        if let currentEx = currentExercise {
            let context = liveContextValues(
                distanceOverride: currentDistance,
                elapsedOverride: elapsedTime
            )
            workoutLiveActivityManager.updateWorkout(
                exerciseName: currentEx.name,
                currentSet: currentSetIndex + 1,
                totalSets: currentEx.sets.count,
                currentExerciseIndex: currentExerciseIndex,
                elapsedTime: Int(elapsedTime),
                workoutStartDate: workoutStartTime ?? Date(),
                isPaused: isPaused,
                isCardio: true,
                cardioModeIndex: mode,
                cardioSpeed: speed,
                cardioIncline: incline,
                cardioEndTime: endTime,
                cardioDuration: duration,
                intervalProgress: context.intervalProgress,
                currentIntervalName: context.intervalName,
                targetDistanceRemaining: context.distanceRemaining,
                targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
            )
        }
    }
    
    // MARK: - Workout Lifecycle
    
    // MARK: Marathon Coach Session Launch
    
    /// Start a "Smart" workout pre-configured from a Marathon Coach training session.
    /// This is the context-aware entry point from the Horizon view.
    /// - Parameter trainingSession: The training session from the plan
    /// - Parameter marathonCoach: The marathon coach manager to build the workout
    /// - Returns: The configured WorkoutSession ready to start
    func startSmartSession(for trainingSession: TrainingSession, using marathonCoach: MarathonCoachManager) -> WorkoutSession {
        // Link this workout to the training plan context
        self.associatedTrainingSessionID = trainingSession.id
        self.activeTrainingSession = trainingSession
        self.activeWeatherSummary = nil
        self.isIndoorRun = false
        
        // Configure the target based on run type
        switch trainingSession.runType {
        case .speedWork:
            // Interval workout: e.g., 8x400m with 2 min rest
            let repeatCount = max(4, Int(trainingSession.targetDistance / 0.5))
            self.activeTarget = .interval(
                repeats: repeatCount,
                distanceMeters: 400,
                restSeconds: 120
            )
            
        case .tempo:
            // Sustained effort distance
            self.activeTarget = .distance(trainingSession.targetDistance, unit: .miles)
            
        case .longRun, .base, .recovery:
            // Distance-based run
            self.activeTarget = .distance(trainingSession.targetDistance, unit: .miles)
            
        case .crossTraining:
            // Open/freestyle for cross training
            self.activeTarget = .open
            
        case .rest:
            // Shouldn't happen, but handle gracefully
            self.activeTarget = .open
        }
        
        configureVoiceCoachForActiveSession(setupSpeedMPH: nil)
        
        // Build the workout session using the marathon coach
        let workout = marathonCoach.buildGymModeSession(for: trainingSession)
        
        return workout
    }
    
    /// Start a new workout session
    /// - Parameter session: The workout session to start
    func startWorkout(session: WorkoutSession) {
        
        activeSession = session
        currentExerciseIndex = 0
        currentSetIndex = 0
        workoutStartTime = Date()
        elapsedTime = 0
        isPaused = false
        healthKitDistance = 0
        guidedRunDistanceBaselineMiles = 0
        activeWeatherSummary = nil
        configureVoiceCoachForActiveSession(setupSpeedMPH: nil)
        
        // Enable screen wake lock
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Start elapsed time timer
        startElapsedTimer()
        
        // Start Live Activity
        let firstExercise = session.sortedExercises.first?.name ?? "Workout"
        let firstSets = session.sortedExercises.first?.sets.count ?? 0
        let context = liveContextValues()
        workoutLiveActivityManager.startWorkout(
            workoutTitle: session.title,
            totalExercises: session.exercises.count,
            exerciseName: firstExercise,
            workoutStartDate: workoutStartTime ?? Date(),
            currentSet: 1,
            totalSets: firstSets,
            elapsedTime: Int(elapsedTime),
            currentExerciseIndex: currentExerciseIndex,
            isPaused: isPaused,
            isCardio: session.sortedExercises.first?.type == .cardio,
            cardioModeIndex: cardioModeIndex,
            cardioSpeed: cardioSpeed,
            cardioIncline: cardioIncline,
            cardioEndTime: cardioEndTime,
            cardioDuration: cardioDuration,
            intervalProgress: context.intervalProgress,
            currentIntervalName: context.intervalName,
            targetDistanceRemaining: context.distanceRemaining,
            targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
        )
        
        // Sync to widget
        syncWidgetState()
    }
    
    /// Start a HealthKit running session if applicable
    func startHealthKitRun(hkManager: HealthKitManager) {
        guard case .distance = activeTarget else { return }
        
        let watchBridge = AppDependencyManager.shared.watchConnectivityManager
        watchBridge.activateIfNeeded()
        watchBridge.sendGuidedRunStart(
            targetDistanceMiles: targetDistance > 0 ? targetDistance : nil,
            targetPaceMinutesPerMile: targetPaceMinutesPerMile
        )
        
        hkManager.onDistanceUpdate = { [weak self] distanceMiles in
            self?.updateHealthKitDistance(distanceMiles)
        }
        
        Task {
            do {
                if #available(iOS 26.0, *) {
                    try await hkManager.startRunningWorkout(isIndoor: isIndoorRun)
                }
            } catch {
                hkManager.onDistanceUpdate = nil
            }
        }
    }
    
    /// Resume a paused workout session
    /// - Parameter session: The workout session to resume
    func resumeWorkout(session: WorkoutSession) {
        // If it's already active, just continue
        if activeSession?.id == session.id {
            continueWorkout()
            return
        }
        
        activeSession = session
        isPaused = false
        
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
        syncHealthKitPauseState(paused: false)
        
        // Resume Live Activity
        if let currentEx = currentExercise {
            let context = liveContextValues()
            workoutLiveActivityManager.updateWorkout(
                exerciseName: currentEx.name,
                currentSet: currentSetIndex + 1,
                totalSets: currentEx.sets.count,
                currentExerciseIndex: currentExerciseIndex,
                elapsedTime: Int(elapsedTime),
                workoutStartDate: workoutStartTime ?? Date(),
                isPaused: isPaused,
                isCardio: currentEx.type == .cardio,
                cardioModeIndex: cardioModeIndex,
                cardioSpeed: cardioSpeed,
                cardioIncline: cardioIncline,
                cardioEndTime: cardioEndTime,
                cardioDuration: cardioDuration,
                intervalProgress: context.intervalProgress,
                currentIntervalName: context.intervalName,
                targetDistanceRemaining: context.distanceRemaining,
                targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
            )
        }
        
        // Sync to widget
        syncWidgetState()
    }
    
    /// Continue the current active workout from a paused state
    func continueWorkout() {
        guard let session = activeSession else { return }
        isPaused = false
        
        // SAFETY: If our local elapsed time seems to have been reset (0) but the session has data,
        // trust the session's duration. The session.duration is saved on pause.
        if elapsedTime < 1.0 && session.duration > 0 {
            elapsedTime = session.duration
        }
        
        // Adjust start time to account for already elapsed time
        workoutStartTime = Date().addingTimeInterval(-elapsedTime)
        
        // Enable screen wake lock
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Restart timer
        startElapsedTimer()
        syncHealthKitPauseState(paused: false)
        
        // Resume Live Activity
        if let currentEx = currentExercise {
            let context = liveContextValues()
            workoutLiveActivityManager.updateWorkout(
                exerciseName: currentEx.name,
                currentSet: currentSetIndex + 1,
                totalSets: currentEx.sets.count,
                currentExerciseIndex: currentExerciseIndex,
                elapsedTime: Int(elapsedTime),
                workoutStartDate: workoutStartTime ?? Date(),
                isPaused: isPaused,
                isCardio: currentEx.type == .cardio,
                cardioModeIndex: cardioModeIndex,
                cardioSpeed: cardioSpeed,
                cardioIncline: cardioIncline,
                cardioEndTime: cardioEndTime,
                cardioDuration: cardioDuration,
                intervalProgress: context.intervalProgress,
                currentIntervalName: context.intervalName,
                targetDistanceRemaining: context.distanceRemaining,
                targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
            )
        }
        
        // Sync to widget
        syncWidgetState()
    }
    
    /// End the current workout and return the completed session
    /// - Returns: The completed workout session
    /// End the current workout and return the completed session
    /// - Returns: The completed workout session
    func endWorkout() -> WorkoutSession? {
        let completedSession = activeSession
        
        // Update session end time
        activeSession?.endTime = Date()
        activeSession?.duration = elapsedTime
        
        // Use the common reset logic
        resetState()
        
        return completedSession
    }
    
    func finishWorkout(healthKitManager: HealthKitManager) async -> WorkoutFinishPayload {
        let linkedTrainingSession = activeTrainingSession
        let fallbackSetDistance = estimatedDistanceFromSets(in: activeSession)
        let liveHealthKitDistance = healthKitManager.currentSessionDistance > 0 ? healthKitManager.currentSessionDistance : nil
        let watchBridge = AppDependencyManager.shared.watchConnectivityManager
        let capturedTargetPace = targetPaceMinutesPerMile
        let capturedWeatherSummary = activeWeatherSummary
        
        var healthKitSnapshot: HealthKitWorkoutSnapshot?
        var healthKitDistance: Double?
        
        if #available(iOS 26.0, *), healthKitManager.isLiveWorkoutActive {
            do {
                if let workout = try await healthKitManager.endLiveWorkout() {
                    let distanceMiles = workout.totalDistance?.doubleValue(for: .mile())
                    healthKitDistance = distanceMiles
                    healthKitSnapshot = HealthKitWorkoutSnapshot(
                        workoutID: workout.uuid,
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        duration: workout.duration,
                        distanceMiles: distanceMiles
                    )
                }
            } catch {
                if #available(iOS 26.0, *) {
                    await healthKitManager.discardLiveWorkout()
                }
            }
        }
        
        let completedSession = endWorkout()
        let bestDistance = healthKitDistance ?? liveHealthKitDistance ?? fallbackSetDistance
        if case .distance = activeTarget {
            watchBridge.sendGuidedRunEnd(discarded: false)
        }
        
        return WorkoutFinishPayload(
            completedSession: completedSession,
            linkedTrainingSession: linkedTrainingSession,
            bestDistanceMiles: bestDistance,
            healthKitSnapshot: healthKitSnapshot,
            targetPaceMinutesPerMile: capturedTargetPace,
            weatherSummary: capturedWeatherSummary
        )
    }
    
    func discardWorkout(healthKitManager: HealthKitManager) async {
        if #available(iOS 26.0, *), healthKitManager.isLiveWorkoutActive {
            await healthKitManager.discardLiveWorkout()
        }
        if case .distance = activeTarget {
            AppDependencyManager.shared.watchConnectivityManager.sendGuidedRunEnd(discarded: true)
        }
        resetState()
    }
    
    /// Reset internal state without saving/modifying the session (e.g. for discard)
    func resetState() {
        // Stop timers
        stopElapsedTimer()
        stopRestTimer()
        resetVoiceCoach()
        
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
        cardioModeIndex = 0
        cardioEndTime = nil
        cardioSpeed = 0
        cardioIncline = 0
        cardioElapsedTime = 0
        cardioDuration = 0
        isCardioInProgress = false
        guidedRunDistanceBaselineMiles = 0
        healthKitDistance = 0
        
        // Reset Marathon Coach integration
        activeTarget = .open
        associatedTrainingSessionID = nil
        activeTrainingSession = nil
        activeWeatherSummary = nil
        isIndoorRun = false
        AppDependencyManager.shared.healthKitManager.onDistanceUpdate = nil
        
        // Clear widget state
        WorkoutWidgetState.clear()
    }
    
    /// Pause the workout (stops timers but keeps session in incomplete state for resume)
    func pauseWorkout() {
        guard let session = activeSession else { return }
        
        isPaused = true
        voiceCoach.stopCurrentPrompt()
        
        // Save the current elapsed time to the session (but don't set endTime)
        session.duration = elapsedTime
        
        // Stop timers
        stopElapsedTimer()
        stopRestTimer()
        syncHealthKitPauseState(paused: true)
        
        // Disable screen wake lock
        UIApplication.shared.isIdleTimerDisabled = false
        
        // Update Live Activity to show paused state with frozen timer
        if let currentEx = currentExercise {
            let context = liveContextValues()
            workoutLiveActivityManager.updateWorkout(
                exerciseName: currentEx.name,
                currentSet: currentSetIndex + 1,
                totalSets: currentEx.sets.count,
                currentExerciseIndex: currentExerciseIndex,
                elapsedTime: Int(elapsedTime),
                workoutStartDate: workoutStartTime ?? Date(),
                isPaused: true,
                isCardio: currentEx.type == .cardio,
                cardioModeIndex: cardioModeIndex,
                cardioSpeed: cardioSpeed,
                cardioIncline: cardioIncline,
                cardioEndTime: cardioEndTime,
                cardioDuration: cardioDuration,
                intervalProgress: context.intervalProgress,
                currentIntervalName: context.intervalName,
                targetDistanceRemaining: context.distanceRemaining,
                targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
            )
        }
        
        // Sync to widget - important to do this while activeSession is still here
        syncWidgetState()
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
        guard let session = activeSession else {
            return
        }
        let exercises = session.sortedExercises

        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            currentExerciseIndex = index
            // Find the next incomplete set for this exercise
            currentSetIndex = getNextIncompleteSetIndex(for: exercise)
            
            // Synchronize Live Activity
            let context = liveContextValues()
            workoutLiveActivityManager.updateWorkout(
                exerciseName: exercise.name,
                currentSet: currentSetIndex + 1,
                totalSets: exercise.sets.count,
                currentExerciseIndex: currentExerciseIndex,
                elapsedTime: Int(elapsedTime),
                workoutStartDate: self.workoutStartTime ?? Date(),
                isPaused: isPaused,
                intervalProgress: context.intervalProgress,
                currentIntervalName: context.intervalName,
                targetDistanceRemaining: context.distanceRemaining,
                targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
            )
            
            // Sync widget state with new exercise selection
            syncWidgetState()
            
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
        distance: Double? = nil,
        speed: Double? = nil,
        incline: Double? = nil,
        intervals: [CardioInterval]? = nil,
        endedEarly: Bool = false
    ) {
        guard let set = currentSet else { return }
        
        // Update set data
        set.weight = weight
        set.reps = reps
        set.duration = duration
        set.distance = distance
        set.speed = speed
        set.incline = incline
        set.isCompleted = true
        set.wasEndedEarly = endedEarly
        
        // Store intervals if provided
        if let intervals = intervals {
            if let encoded = try? JSONEncoder().encode(intervals) {
                set.cardioIntervals = encoded
            }
        }
        
        // Haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(endedEarly ? .warning : .success)
        
        // Advance to next set/exercise
        advanceToNext()
        
        // Start rest timer (unless workout is complete)
        if isWorkoutActive && !isWorkoutComplete {
            startRestTimer(duration: defaultRestDuration)
        }
    }
    
    /// Advance to the next exercise (used for cardio completion)
    func advanceToNextExercise() {
        guard let session = activeSession else { return }
        let exercises = session.sortedExercises
        
        // Move to next exercise
        currentExerciseIndex += 1
        currentSetIndex = 0
        
        // Update Live Activity if there's a next exercise
        if currentExerciseIndex < exercises.count {
            let nextExercise = exercises[currentExerciseIndex]
            let context = liveContextValues()
            workoutLiveActivityManager.updateWorkout(
                exerciseName: nextExercise.name,
                currentSet: 1,
                totalSets: nextExercise.sets.count,
                currentExerciseIndex: currentExerciseIndex,
                elapsedTime: Int(elapsedTime),
                workoutStartDate: workoutStartTime ?? Date(),
                isPaused: isPaused,
                intervalProgress: context.intervalProgress,
                currentIntervalName: context.intervalName,
                targetDistanceRemaining: context.distanceRemaining,
                targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
            )
        }
        
        // Sync widget state
        syncWidgetState()
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
            let context = liveContextValues()
            workoutLiveActivityManager.updateWorkout(
                exerciseName: newExercise.name,
                currentSet: currentSetIndex + 1,
                totalSets: newExercise.sets.count,
                currentExerciseIndex: currentExerciseIndex,
                elapsedTime: Int(elapsedTime),
                workoutStartDate: self.workoutStartTime ?? Date(),
                isPaused: isPaused,
                intervalProgress: context.intervalProgress,
                currentIntervalName: context.intervalName,
                targetDistanceRemaining: context.distanceRemaining,
                targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
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
                let context = liveContextValues()
                workoutLiveActivityManager.updateWorkout(
                    exerciseName: nextExercise.name,
                    currentSet: currentSetIndex + 1,
                    totalSets: nextExercise.sets.count,
                    currentExerciseIndex: currentExerciseIndex,
                    elapsedTime: Int(elapsedTime),
                    workoutStartDate: self.workoutStartTime ?? Date(),
                    isPaused: isPaused,
                    intervalProgress: context.intervalProgress,
                    currentIntervalName: context.intervalName,
                    targetDistanceRemaining: context.distanceRemaining,
                    targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
                )
            }
        }
    }
    
    // MARK: - Rest Timer
    
    /// Start the rest timer
    /// - Parameter duration: Duration in seconds
    func startRestTimer(duration: TimeInterval) {
        restEndTime = Date().addingTimeInterval(duration)
        isRestTimerActive = true
        restDuration = duration
        
        // Update workout Live Activity to show rest state
        let exerciseName = currentExercise?.name ?? "Rest"
        let nextSet = currentSetIndex + 1
        let totalSets = currentExercise?.sets.count ?? 3
        let context = liveContextValues()
        
        workoutLiveActivityManager.startRest(
            exerciseName: exerciseName,
            nextSet: nextSet,
            totalSets: totalSets,
            currentExerciseIndex: currentExerciseIndex,
            elapsedTime: Int(elapsedTime),
            restEndTime: restEndTime ?? Date(),
            workoutStartDate: self.workoutStartTime ?? Date(),
            isPaused: isPaused,
            intervalProgress: context.intervalProgress,
            currentIntervalName: context.intervalName,
            targetDistanceRemaining: context.distanceRemaining,
            targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
        )
        
        // Sync rest state to widget
        syncWidgetState()
        
        restTimerCancellable?.cancel()
        restTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // Check if widget intent skipped the rest
                let widgetState = WorkoutWidgetState.load()
                
                // Don't stop rest if paused with remaining time stored
                let isPausedWithRestTime = widgetState.isPaused && (widgetState.restTimeRemaining ?? 0) > 0
                
                if widgetState.restEndTime == nil && self.isRestTimerActive && !isPausedWithRestTime {
                    // Widget skipped rest - sync to app
                    self.stopRestTimer()
                    return
                }
                
                // Check if rest time has elapsed (computed from restEndTime)
                if self.restTimeRemaining <= 0 {
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
        // Extend the rest end time
        if let currentEnd = restEndTime {
            restEndTime = currentEnd.addingTimeInterval(seconds)
        } else {
            restEndTime = Date().addingTimeInterval(seconds)
        }
        
        // Update Live Activity if active
        if isRestTimerActive, let newEndTime = restEndTime {
            let exerciseName = currentExercise?.name ?? "Rest"
            let nextSet = currentSetIndex + 1
            let totalSets = currentExercise?.sets.count ?? 3
            let context = liveContextValues()
            
            restDuration += seconds
            
            workoutLiveActivityManager.startRest(
                exerciseName: exerciseName,
                nextSet: nextSet,
                totalSets: totalSets,
                currentExerciseIndex: currentExerciseIndex,
                elapsedTime: Int(elapsedTime),
                restEndTime: newEndTime,
                workoutStartDate: self.workoutStartTime ?? Date(),
                isPaused: isPaused,
                intervalProgress: context.intervalProgress,
                currentIntervalName: context.intervalName,
                targetDistanceRemaining: context.distanceRemaining,
                targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
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
        restEndTime = nil
        restDuration = 0
        
        // Resume normal workout state in Live Activity
        if let currentActiveExercise = self.currentExercise {
            let context = liveContextValues()
            workoutLiveActivityManager.endRest(
                exerciseName: currentActiveExercise.name,
                currentSet: currentSetIndex + 1,
                totalSets: currentActiveExercise.sets.count,
                currentExerciseIndex: currentExerciseIndex,
                elapsedTime: Int(elapsedTime),
                workoutStartDate: self.workoutStartTime ?? Date(),
                isPaused: isPaused,
                intervalProgress: context.intervalProgress,
                currentIntervalName: context.intervalName,
                targetDistanceRemaining: context.distanceRemaining,
                targetDistanceTotal: context.distanceTotal,
            currentDistanceMiles: context.currentDistance,
            targetPaceMinutesPerMile: context.targetPace,
            ghostExpectedDistanceMiles: context.ghostExpectedDistance,
            ghostDeltaMiles: context.ghostDeltaDistance
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
        stopElapsedTimer()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.workoutStartTime else { return }
            self.elapsedTime = Date().timeIntervalSince(startTime)
        }
        RunLoop.main.add(timer, forMode: .common)
        elapsedTimer = timer
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }
    
    private func estimatedDistanceFromSets(in session: WorkoutSession?) -> Double? {
        guard let session else { return nil }
        
        let totalDistance = session.exercises
            .flatMap { $0.sets }
            .compactMap { $0.distance }
            .reduce(0, +)
        
        return totalDistance > 0 ? totalDistance : nil
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
            // ignore fetch errors; progressive overload suggestions are best-effort
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
    
    private func elapsedTimeFromWidgetState(_ state: WorkoutWidgetState) -> TimeInterval {
        if let paused = state.pausedDisplayTime, let parsed = parseElapsedTime(paused) {
            return parsed
        }
        return max(0, Date().timeIntervalSince(state.workoutStartDate))
    }
    
    private func parseElapsedTime(_ string: String) -> TimeInterval? {
        let parts = string.split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 {
            return TimeInterval(parts[0] * 60 + parts[1])
        }
        if parts.count == 3 {
            return TimeInterval(parts[0] * 3600 + parts[1] * 60 + parts[2])
        }
        return nil
    }
}
