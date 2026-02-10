//
//  AppDependencyManager.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation
import SwiftData
import LifeFlowCore

/// Manages the shared ModelContainer for the main app.
/// This ensures we always use the correct App Group configuration.
final class AppDependencyManager {
    static let shared = AppDependencyManager()

    private struct InboundWatchRunBuffer {
        var startedAt: Date
        var endedAt: Date?
        var snapshots: [TelemetrySnapshotDTO] = []
        var events: [WatchRunMessage] = []
    }

    let sharedModelContainer: ModelContainer

    /// Shared GymModeManager instance that persists across view lifecycle
    let gymModeManager: GymModeManager = GymModeManager()

    /// Shared MarathonCoachManager instance for race training plans
    let marathonCoachManager: MarathonCoachManager = MarathonCoachManager()

    /// Shared HealthKitManager instance for workout data syncing
    let healthKitManager: HealthKitManager = HealthKitManager()

    /// Shared WatchConnectivity bridge for optional watch mirroring.
    let watchConnectivityManager: WatchConnectivityManager = WatchConnectivityManager()

    private var inboundWatchRuns: [UUID: InboundWatchRunBuffer] = [:]
    private var fallbackIncomingRunID = UUID()

    private init() {
        let appGroupIdentifier = HydrationSettings.appGroupID
        let schema = Schema([
            DayLog.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            ExerciseSet.self,
            Goal.self,
            DailyEntry.self,
            WorkoutRoutine.self,
            TrainingPlan.self,
            TrainingSession.self,
            TelemetryPoint.self,
            RunEvent.self,
            WatchRunStateSnapshot.self
        ])

        // Use the shared App Group container
        let modelConfiguration = ModelConfiguration(
            url: URL.storeURL(for: appGroupIdentifier)
        )

        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        watchConnectivityManager.onHeartRateUpdate = { [healthKitManager] heartRate in
            Task { @MainActor in
                healthKitManager.applyMirroredHeartRate(heartRate)
            }
        }

        watchConnectivityManager.onRunMessage = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.consumeWatchRunMessage(message)
            }
        }
    }

    @MainActor
    private func consumeWatchRunMessage(_ message: WatchRunMessage) {
        let runID = resolveRunID(for: message)

        switch message.event {
        case .runStarted:
            fallbackIncomingRunID = runID
            inboundWatchRuns[runID] = InboundWatchRunBuffer(
                startedAt: message.timestamp,
                snapshots: message.metricSnapshot.map { [$0] } ?? [],
                events: [message]
            )

        case .metricSnapshot:
            if inboundWatchRuns[runID] == nil {
                inboundWatchRuns[runID] = InboundWatchRunBuffer(startedAt: message.timestamp)
            }
            if let metricSnapshot = message.metricSnapshot {
                inboundWatchRuns[runID]?.snapshots.append(metricSnapshot)
            }
            inboundWatchRuns[runID]?.events.append(message)

        case .runPaused, .runResumed, .fuelLogged, .lapMarked:
            if inboundWatchRuns[runID] == nil {
                inboundWatchRuns[runID] = InboundWatchRunBuffer(startedAt: message.timestamp)
            }
            inboundWatchRuns[runID]?.events.append(message)

        case .runEnded:
            if inboundWatchRuns[runID] == nil {
                inboundWatchRuns[runID] = InboundWatchRunBuffer(startedAt: message.timestamp)
            }
            inboundWatchRuns[runID]?.endedAt = message.timestamp
            inboundWatchRuns[runID]?.events.append(message)

            finalizeInboundWatchRun(id: runID, discarded: message.discarded ?? false)
        }
    }

    @MainActor
    private func finalizeInboundWatchRun(id: UUID, discarded: Bool) {
        guard let buffer = inboundWatchRuns[id] else { return }
        inboundWatchRuns[id] = nil

        guard !discarded else { return }

        let modelContext = sharedModelContainer.mainContext

        if workoutSessionExists(id: id, in: modelContext) {
            return
        }

        let endDate = buffer.endedAt ?? buffer.snapshots.last?.timestamp ?? Date()
        let duration = max(1, endDate.timeIntervalSince(buffer.startedAt))

        let distanceMiles = buffer.snapshots.last?.distanceMiles ?? 0
        let averageHeartRate: Double? = {
            let values = buffer.snapshots.compactMap(\.heartRateBPM)
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }()

        let workoutSession = WorkoutSession(
            id: id,
            title: "Watch Run",
            type: "Running",
            duration: duration,
            calories: 0,
            source: "Watch",
            timestamp: buffer.startedAt,
            distanceMiles: distanceMiles,
            averageHeartRate: averageHeartRate,
            sourceName: "Apple Watch",
            sourceBundleID: "com.apple.watch",
            isLifeFlowNative: false,
            perceivedEffort: nil,
            liquidLossEstimate: nil,
            ghostRunnerDelta: nil
        )

        workoutSession.startTime = buffer.startedAt
        workoutSession.endTime = endDate

        for snapshot in buffer.snapshots {
            let telemetryPoint = TelemetryPoint(
                timestamp: snapshot.timestamp,
                distanceMiles: snapshot.distanceMiles,
                heartRateBPM: snapshot.heartRateBPM,
                paceSecondsPerMile: snapshot.paceSecondsPerMile,
                cadenceSPM: snapshot.cadenceSPM,
                gradePercent: snapshot.gradePercent,
                fuelRemainingGrams: snapshot.fuelRemainingGrams
            )
            telemetryPoint.workoutSession = workoutSession
            workoutSession.telemetryPoints.append(telemetryPoint)
        }

        for event in buffer.events {
            let runEvent = RunEvent(
                timestamp: event.timestamp,
                kind: event.event.rawValue,
                payloadJSON: eventPayloadJSON(event)
            )
            runEvent.workoutSession = workoutSession
            workoutSession.runEvents.append(runEvent)

            let snapshot = WatchRunStateSnapshot(
                timestamp: event.timestamp,
                lifecycleState: event.lifecycleState?.rawValue ?? "running",
                elapsedSeconds: max(0, event.timestamp.timeIntervalSince(buffer.startedAt)),
                distanceMiles: event.metricSnapshot?.distanceMiles ?? distanceMiles,
                heartRateBPM: event.heartRateBPM,
                paceSecondsPerMile: event.metricSnapshot?.paceSecondsPerMile,
                fuelRemainingGrams: event.metricSnapshot?.fuelRemainingGrams
            )
            snapshot.workoutSession = workoutSession
            workoutSession.stateSnapshots.append(snapshot)
        }

        modelContext.insert(workoutSession)
        try? modelContext.save()

        linkWorkoutToTodaysSessionIfNeeded(
            workoutSession: workoutSession,
            modelContext: modelContext
        )
    }

    @MainActor
    private func workoutSessionExists(id: UUID, in modelContext: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        let existing = (try? modelContext.fetch(descriptor)) ?? []
        return !existing.isEmpty
    }

    @MainActor
    private func linkWorkoutToTodaysSessionIfNeeded(
        workoutSession: WorkoutSession,
        modelContext: ModelContext
    ) {
        marathonCoachManager.loadActivePlan(modelContext: modelContext)

        guard let session = marathonCoachManager.todaysSession,
              !session.isCompleted else {
            return
        }

        let completedDistance = max(0, workoutSession.distanceMiles ?? 0)
        marathonCoachManager.autoCompleteSession(
            session,
            actualDistance: completedDistance,
            modelContext: modelContext,
            defaultEffort: 2
        )

        session.healthKitWorkoutID = workoutSession.id
        try? modelContext.save()
    }

    private func resolveRunID(for message: WatchRunMessage) -> UUID {
        if let runID = message.runID {
            return runID
        }

        return fallbackIncomingRunID
    }

    private func eventPayloadJSON(_ message: WatchRunMessage) -> String? {
        var payload: [String: Any] = [:]
        if let carbs = message.carbsGrams {
            payload["carbsGrams"] = carbs
        }
        if let lap = message.lapIndex {
            payload["lapIndex"] = lap
        }
        if let discarded = message.discarded {
            payload["discarded"] = discarded
        }
        if let lifecycleState = message.lifecycleState {
            payload["lifecycleState"] = lifecycleState.rawValue
        }

        guard !payload.isEmpty,
              JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }
}
