//
//  WorkoutWidgetIntents.swift
//  GymWidgets
//
//  AppIntents for interactive workout widget buttons.
//

import AppIntents
import WidgetKit

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
        state.save()
        
        return .result()
    }
}

// MARK: - Pause Workout Intent

struct PauseWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Workout"
    static var description = IntentDescription("Pauses the current active workout.")

    func perform() async throws -> some IntentResult {
        var state = WorkoutWidgetState.load()
        state.isPaused = true
        state.save()
        return .result()
    }
}

// MARK: - Resume Workout Intent

struct ResumeWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Workout"
    static var description = IntentDescription("Resumes the paused workout.")

    func perform() async throws -> some IntentResult {
        var state = WorkoutWidgetState.load()
        state.isPaused = false
        state.save()
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
