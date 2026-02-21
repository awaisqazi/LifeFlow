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
        let storeURL = URL.storeURL(for: appGroupIdentifier)
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

        do {
            let initialContainer = try Self.makeSharedContainer(schema: schema, storeURL: storeURL)

            do {
                try Self.validateSharedStoreSchema(initialContainer)
                sharedModelContainer = initialContainer
            } catch {
                guard Self.shouldResetSharedStore(after: error) else {
                    throw error
                }

                Self.destroyStoreFiles(at: storeURL)

                let rebuiltContainer = try Self.makeSharedContainer(schema: schema, storeURL: storeURL)
                try Self.validateSharedStoreSchema(rebuiltContainer)
                sharedModelContainer = rebuiltContainer
            }
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

    private static func makeSharedContainer(schema: Schema, storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func validateSharedStoreSchema(_ container: ModelContainer) throws {
        // Validate a recently added entity to catch stale/partial schemas early.
        var descriptor = FetchDescriptor<TrainingPlan>()
        descriptor.fetchLimit = 1
        _ = try container.mainContext.fetch(descriptor)
    }

    private static func shouldResetSharedStore(after error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.localizedDescription.localizedCaseInsensitiveContains("no such table") {
            return true
        }

        if let reason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String,
           reason.localizedCaseInsensitiveContains("no such table") {
            return true
        }

        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            return shouldResetSharedStore(after: underlyingError)
        }

        return false
    }

    private static func destroyStoreFiles(at storeURL: URL) {
        let fileManager = FileManager.default
        let auxiliaryPaths = [
            storeURL,
            URL(fileURLWithPath: "\(storeURL.path)-wal"),
            URL(fileURLWithPath: "\(storeURL.path)-shm")
        ]

        for path in auxiliaryPaths {
            try? fileManager.removeItem(at: path)
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
        do {
            try modelContext.save()
        } catch {
            print("AppDependencyManager: Failed to save workout session: \(error)")
        }

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
        do {
            try modelContext.save()
        } catch {
            print("AppDependencyManager: Failed to save session link: \(error)")
        }
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
