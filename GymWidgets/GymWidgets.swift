//
//  GymWidgets.swift
//  GymWidgets
//
//  Workout widgets for home screen - shows active workout status.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct WorkoutEntry: TimelineEntry {
    let date: Date
    let state: WorkoutWidgetState
}

// MARK: - Timeline Provider

struct WorkoutTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutEntry {
        WorkoutEntry(date: Date(), state: .idle)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WorkoutEntry) -> Void) {
        let state = WorkoutWidgetState.load()
        let entry = WorkoutEntry(date: Date(), state: state)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutEntry>) -> Void) {
        let state = WorkoutWidgetState.load()
        let entry = WorkoutEntry(date: Date(), state: state)
        
        // If workout is active, reload more frequently
        // Otherwise, reload in 15 minutes or when app triggers it
        let reloadDate: Date
        if state.isActive {
            // Active workout: check every 30 seconds for state changes
            reloadDate = Date().addingTimeInterval(30)
        } else {
            // Idle: reload less frequently
            reloadDate = Date().addingTimeInterval(900) // 15 mins
        }
        
        let timeline = Timeline(entries: [entry], policy: .after(reloadDate))
        completion(timeline)
    }
}

// MARK: - Widget Definition

struct GymWidgets: Widget {
    let kind: String = "GymWidgets"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkoutTimelineProvider()) { entry in
            GymWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.black
                }
        }
        .configurationDisplayName("Workout")
        .description("Track your active workout or start a new one.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    GymWidgets()
} timeline: {
    WorkoutEntry(date: .now, state: .idle)
    WorkoutEntry(date: .now, state: WorkoutWidgetState(
        isActive: true,
        workoutTitle: "Push Day",
        exerciseName: "Bench Press",
        currentSet: 2,
        totalSets: 4,
        workoutStartDate: Date().addingTimeInterval(-300),
        restEndTime: nil,
        pauseRequested: false,
        isPaused: false,
        pausedDisplayTime: nil,
        previousExerciseName: "Warm Up",
        previousSetsCompleted: 3,
        previousTotalSets: 3,
        previousIsComplete: true,
        nextExerciseName: "Incline Press",
        nextSetsCompleted: 0,
        nextTotalSets: 3,
        totalExercises: 5,
        currentExerciseIndex: 2
    ))
}

#Preview(as: .systemMedium) {
    GymWidgets()
} timeline: {
    WorkoutEntry(date: .now, state: WorkoutWidgetState(
        isActive: true,
        workoutTitle: "Push Day",
        exerciseName: "Bench Press",
        currentSet: 2,
        totalSets: 4,
        workoutStartDate: Date().addingTimeInterval(-300),
        restEndTime: Date().addingTimeInterval(45),
        pauseRequested: false,
        isPaused: false,
        pausedDisplayTime: nil,
        previousExerciseName: "Warm Up",
        previousSetsCompleted: 3,
        previousTotalSets: 3,
        previousIsComplete: true,
        nextExerciseName: "Incline Press",
        nextSetsCompleted: 0,
        nextTotalSets: 3,
        totalExercises: 5,
        currentExerciseIndex: 2
    ))
}

#Preview(as: .systemLarge) {
    GymWidgets()
} timeline: {
    WorkoutEntry(date: .now, state: WorkoutWidgetState(
        isActive: true,
        workoutTitle: "Full Body",
        exerciseName: "Squat",
        currentSet: 2,
        totalSets: 3,
        workoutStartDate: Date().addingTimeInterval(-600),
        restEndTime: nil,
        pauseRequested: false,
        isPaused: true,
        pausedDisplayTime: "10:00",
        previousExerciseName: "Bench Press",
        previousSetsCompleted: 3,
        previousTotalSets: 3,
        previousIsComplete: true,
        nextExerciseName: "Deadlift",
        nextSetsCompleted: 1,
        nextTotalSets: 3,
        totalExercises: 6,
        currentExerciseIndex: 3
    ))
}
