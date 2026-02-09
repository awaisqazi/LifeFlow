//
//  WorkoutWidgetIntents.swift
//  GymWidgets
//
//  AppIntents for interactive workout widget buttons.
//

import AppIntents
import WidgetKit
import ActivityKit

// MARK: - Start Workout Intent

struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Workout"
    static var description = IntentDescription("Opens the app to start a workout.")
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        // Just opens the app - deep linking handled by URL scheme
        return .result()
    }
}

// MARK: - Add Reps Intent

struct AddRepsIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Reps"
    static var description = IntentDescription("Increments the rep count for tracking.")
    
    @Parameter(title: "Count")
    var count: Int
    
    init() {
        self.count = 1
    }
    
    init(count: Int) {
        self.count = count
    }
    
    func perform() async throws -> some IntentResult {
        // For now, this just reloads the widget
        // In a full implementation, this would update SwiftData via the shared container
        // and track reps for the current set
        
        // Note: Full rep tracking from widget would require:
        // 1. Reading current reps from UserDefaults
        // 2. Incrementing and saving back
        // 3. App would then sync this on next open
        
        // Reload widget to reflect any state changes
        WidgetCenter.shared.reloadTimelines(ofKind: "GymWidgets")
        
        return .result()
    }
}

// MARK: - Add Rest Time Intent

struct AddRestTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Rest Time"
    static var description = IntentDescription("Adds time to the current rest timer.")
    
    @Parameter(title: "Seconds")
    var seconds: Int
    
    init() {
        self.seconds = 15
    }
    
    init(seconds: Int) {
        self.seconds = seconds
    }
    
    func perform() async throws -> some IntentResult {
        // Read current state
        var state = WorkoutWidgetState.load()
        
        // Add time to rest end
        if let currentRestEnd = state.restEndTime {
            state.restEndTime = currentRestEnd.addingTimeInterval(TimeInterval(seconds))
            if let restDuration = state.restDuration {
                state.restDuration = restDuration + TimeInterval(seconds)
            }
            state.save()
        }
        
        return .result()
    }
}

// MARK: - Skip Rest Intent

struct SkipRestIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Rest"
    static var description = IntentDescription("Skips the current rest timer.")
    
    func perform() async throws -> some IntentResult {
        // Read current state and clear rest
        var state = WorkoutWidgetState.load()
        state.restEndTime = nil
        state.restDuration = nil
        state.save()
        
        await updateLiveActivity(with: state)
        
        return .result()
    }
}

// MARK: - Pause Workout Intent

struct PauseWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Workout"
    static var description = IntentDescription("Pauses the current active workout.")

    func perform() async throws -> some IntentResult {
        var state = WorkoutWidgetState.load()
        let elapsedSeconds = max(0, Date().timeIntervalSince(state.workoutStartDate))
        state.isPaused = true
        state.pauseRequested = true
        state.pausedDisplayTime = formattedElapsedTime(from: elapsedSeconds)
        
        // Save cardio time remaining for timed cardio (so we can restore on resume)
        if state.isCardio && state.cardioModeIndex == 0, let cardioEnd = state.cardioEndTime {
            let remaining = max(0, cardioEnd.timeIntervalSinceNow)
            state.cardioTimeRemaining = remaining
            // Clear the end time so the countdown stops
            state.cardioEndTime = nil
        }
        
        // For freestyle cardio, save elapsed time
        if state.isCardio && state.cardioModeIndex == 1 {
            state.cardioElapsedTime = max(0, Date().timeIntervalSince(state.workoutStartDate))
        }
        
        // Save rest time remaining (so we can restore on resume)
        if let restEnd = state.restEndTime {
            let remaining = max(0, restEnd.timeIntervalSinceNow)
            state.restTimeRemaining = remaining
            // Clear the end time so the countdown stops
            state.restEndTime = nil
        }
        
        state.save()
        
        await updateLiveActivity(with: state)
        
        // Post Darwin notification to signal main app to update Live Activity
        let notificationName = CFNotificationName("com.Fez.LifeFlow.workoutStateChanged" as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notificationName,
            nil,
            nil,
            true
        )
        
        return .result()
    }
}

// MARK: - Resume Workout Intent

struct ResumeWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Workout"
    static var description = IntentDescription("Resumes the paused workout.")

    func perform() async throws -> some IntentResult {
        var state = WorkoutWidgetState.load()
        let elapsedSeconds = pausedElapsedSeconds(from: state)
        state.isPaused = false
        state.pauseRequested = false
        state.pausedDisplayTime = nil
        state.workoutStartDate = Date().addingTimeInterval(-elapsedSeconds)
        
        // Restore cardio end time for timed cardio
        if state.isCardio && state.cardioModeIndex == 0, let remaining = state.cardioTimeRemaining, remaining > 0 {
            state.cardioEndTime = Date().addingTimeInterval(remaining)
            state.cardioTimeRemaining = nil
        }
        
        // Restore rest end time
        if let remaining = state.restTimeRemaining, remaining > 0 {
            state.restEndTime = Date().addingTimeInterval(remaining)
            state.restTimeRemaining = nil
        }
        
        state.save()
        
        await updateLiveActivity(with: state)
        
        // Post Darwin notification to signal main app to update Live Activity
        let notificationName = CFNotificationName("com.Fez.LifeFlow.workoutStateChanged" as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notificationName,
            nil,
            nil,
            true
        )
        
        return .result()
    }
}

// MARK: - Skip Exercise Intent

struct SkipExerciseIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Exercise"
    static var description = IntentDescription("Skips the current exercise set.")

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: "GymWidgets")
        return .result()
    }
}

// MARK: - Live Activity Updates

private func updateLiveActivity(with state: WorkoutWidgetState) async {
    let elapsedSeconds = pausedElapsedSeconds(from: state)
    
    // Calculate rest time remaining - use stored value when paused, otherwise calculate from end time
    let restRemaining: Int
    if let storedRemaining = state.restTimeRemaining, storedRemaining > 0 {
        restRemaining = Int(storedRemaining)
    } else if let restEnd = state.restEndTime {
        restRemaining = Int(max(0, restEnd.timeIntervalSinceNow))
    } else {
        restRemaining = 0
    }
    
    let contentState = GymWorkoutAttributes.ContentState(
        exerciseName: state.exerciseName,
        currentSet: state.currentSet,
        totalSets: state.totalSets,
        currentExerciseIndex: state.currentExerciseIndex,
        elapsedTime: Int(elapsedSeconds),
        workoutStartDate: state.workoutStartDate,
        isResting: state.isResting,
        restTimeRemaining: restRemaining,
        restEndTime: state.restEndTime,
        isPaused: state.isPaused,
        isCardio: state.isCardio,
        cardioModeIndex: state.cardioModeIndex,
        cardioSpeed: state.cardioSpeed,
        cardioIncline: state.cardioIncline,
        cardioEndTime: state.cardioEndTime,
        cardioDuration: state.cardioDuration,
        cardioTimeRemaining: state.cardioTimeRemaining,
        intervalProgress: state.intervalProgress,
        currentIntervalName: state.currentIntervalName,
        targetDistanceRemaining: state.targetDistanceRemaining,
        targetDistanceTotal: state.targetDistanceTotal,
        currentDistanceMiles: state.currentDistanceMiles,
        targetPaceMinutesPerMile: state.targetPaceMinutesPerMile,
        ghostExpectedDistanceMiles: state.ghostExpectedDistanceMiles,
        ghostDeltaMiles: state.ghostDeltaMiles
    )
    
    let content = ActivityContent(state: contentState, staleDate: nil)
    for activity in Activity<GymWorkoutAttributes>.activities {
        await activity.update(content)
    }
}

private func pausedElapsedSeconds(from state: WorkoutWidgetState) -> TimeInterval {
    if let display = state.pausedDisplayTime, let parsed = parseElapsedTime(display) {
        return parsed
    }
    return max(0, Date().timeIntervalSince(state.workoutStartDate))
}

private func formattedElapsedTime(from seconds: TimeInterval) -> String {
    let totalSeconds = max(0, Int(seconds))
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let remainingSeconds = totalSeconds % 60
    
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
    }
    
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}

private func parseElapsedTime(_ string: String) -> TimeInterval? {
    let parts = string.split(separator: ":").map { Int($0) }
    guard parts.allSatisfy({ $0 != nil }) else { return nil }
    let values = parts.compactMap { $0 }
    
    if values.count == 2 {
        return TimeInterval(values[0] * 60 + values[1])
    }
    
    if values.count == 3 {
        return TimeInterval(values[0] * 3600 + values[1] * 60 + values[2])
    }
    
    return nil
}
