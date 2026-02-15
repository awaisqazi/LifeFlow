import Foundation
import SwiftData
import LifeFlowCore
import os

// MARK: - WatchDataStore (@ModelActor)
// Refactored from @MainActor to @ModelActor so that all SwiftData context
// operations (inserts, fetches, CloudKit sync) happen on a background
// serial executor. This prevents main-thread congestion and Watchdog
// terminations under heavy WCSession callback floods on watchOS 26.

@ModelActor
actor WatchDataStore {
    // MARK: - Shared Instance

    /// Thread-safe shared accessor. The actor is lazily initialized on first access.
    /// Because `WatchDataStore` is a `@ModelActor`, its `modelContainer` and
    /// `modelContext` are synthesized by the macro on a private background executor.
    static let shared: WatchDataStore = {
        let container = WatchDataStore.createModelContainer()
        return WatchDataStore(modelContainer: container)
    }()

    private static let logger = Logger(subsystem: "com.Fez.LifeFlow.watch", category: "DataStore")

    // MARK: - Container Factory

    /// Creates the ModelContainer with a three-tier fallback:
    /// 1. Persistent local store (no CloudKit — the iPhone handles sync)
    /// 2. Delete corrupted store files and retry
    /// 3. In-memory fallback to prevent crash loops
    nonisolated static func createModelContainer() -> ModelContainer {
        // Use the actual top-level @Model types — NOT the nested VersionedSchema copies.
        // Using Schema(versionedSchema:) registers WatchRunSchemaV1.WatchWorkoutSession,
        // which is a different type than the top-level WatchWorkoutSession used throughout the app.
        let schema = Schema([
            WatchWorkoutSession.self,
            TelemetryPoint.self,
            RunEvent.self,
            WatchRunStateSnapshot.self
        ])
        let storeURL = Self.storeURL(appGroupID: LifeFlowSharedConfig.appGroupID)

        // watchOS: Use local-only persistence.
        //
        // CloudKit on watchOS causes _dispatch_assert_queue_fail crashes because
        // CloudKit's push notification registration internally runs on the
        // WatchConnectivity background queue instead of the main queue.
        // The iPhone app handles CloudKit sync; the watch syncs via WatchConnectivity.
        let localConfig = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [localConfig]
            )
            logger.info("Local ModelContainer initialized successfully.")
            return container
        } catch {
            logger.error("Local store init failed: \(error.localizedDescription). Deleting corrupted store and retrying.")

            // Attempt 2: Delete corrupted store files and retry
            deleteStoreFiles(at: storeURL)

            let freshConfig = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )

            do {
                let container = try ModelContainer(
                    for: schema,
                    configurations: [freshConfig]
                )
                logger.info("Fresh local ModelContainer initialized after store reset.")
                return container
            } catch {
                // Attempt 3: In-memory fallback to prevent crash loops
                logger.fault("All persistent stores failed. Using in-memory container.")
                let memoryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                return try! ModelContainer(
                    for: schema,
                    configurations: [memoryConfig]
                )
            }
        }
    }

    // MARK: - Store Helpers

    /// Deletes the SQLite store and its companion -wal/-shm files.
    private nonisolated static func deleteStoreFiles(at url: URL) {
        let fm = FileManager.default
        let suffixes = ["", "-wal", "-shm"]
        for suffix in suffixes {
            let fileURL = URL(fileURLWithPath: url.path + suffix)
            try? fm.removeItem(at: fileURL)
        }
    }

    private nonisolated static func storeURL(appGroupID: String) -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            fatalError("Missing App Group container for \(appGroupID)")
        }

        return container.appendingPathComponent("LifeFlowWatch.sqlite")
    }

    // MARK: - Background Data Ingestion

    /// Ingest a WatchRunMessage payload from WCSession on this background actor,
    /// keeping SwiftData operations entirely off the main thread.
    func ingest(_ message: WatchRunMessage) {
        Self.logger.debug("Ingesting WatchRunMessage on background actor: \(message.event.rawValue)")

        // MARK: Session Lookup / Creation
        let session: WatchWorkoutSession
        if let runID = message.runID, let existing = findSession(by: runID) {
            session = existing
        } else if message.event == .runStarted, let runID = message.runID {
            let newSession = WatchWorkoutSession(id: runID, startedAt: message.timestamp)
            modelContext.insert(newSession)
            session = newSession
        } else {
            // No runID or session — can't persist without a session anchor.
            return
        }

        // MARK: Telemetry Ingestion
        if let snapshot = message.metricSnapshot {
            let point = TelemetryPoint(
                timestamp: snapshot.timestamp,
                distanceMiles: snapshot.distanceMiles,
                heartRateBPM: snapshot.heartRateBPM,
                paceSecondsPerMile: snapshot.paceSecondsPerMile,
                cadenceSPM: snapshot.cadenceSPM,
                gradePercent: snapshot.gradePercent,
                fuelRemainingGrams: snapshot.fuelRemainingGrams
            )
            point.workoutSession = session
            if session.telemetryPoints == nil { session.telemetryPoints = [] }
            session.telemetryPoints?.append(point)
        }

        // MARK: Run Event Mapping
        let eventKind: RunEventKind? = {
            switch message.event {
            case .runStarted:  return .started
            case .runPaused:   return .paused
            case .runResumed:  return .resumed
            case .runEnded:    return .ended
            case .fuelLogged:  return .fuelLogged
            case .lapMarked:   return .lapMarked
            case .metricSnapshot: return nil // Telemetry-only, no discrete event
            }
        }()

        if let eventKind {
            var payloadDict: [String: Any] = [:]
            if let carbs = message.carbsGrams { payloadDict["carbs"] = carbs }
            if let lap = message.lapIndex { payloadDict["lap"] = lap }
            if let discarded = message.discarded { payloadDict["discarded"] = discarded }

            let payloadJSON: String? = payloadDict.isEmpty ? nil : {
                guard JSONSerialization.isValidJSONObject(payloadDict),
                      let data = try? JSONSerialization.data(withJSONObject: payloadDict),
                      let str = String(data: data, encoding: .utf8) else { return nil }
                return str
            }()

            let event = RunEvent(timestamp: message.timestamp, kind: eventKind, payloadJSON: payloadJSON)
            event.workoutSession = session
            if session.runEvents == nil { session.runEvents = [] }
            session.runEvents?.append(event)
        }

        // MARK: State Snapshot
        if let lifecycle = message.lifecycleState {
            let snapshot = WatchRunStateSnapshot(
                timestamp: message.timestamp,
                lifecycleState: lifecycle,
                elapsedSeconds: 0, // Not available in WatchRunMessage; updated from telemetry
                distanceMiles: message.metricSnapshot?.distanceMiles ?? 0,
                heartRateBPM: message.heartRateBPM,
                paceSecondsPerMile: message.metricSnapshot?.paceSecondsPerMile,
                fuelRemainingGrams: message.metricSnapshot?.fuelRemainingGrams
            )
            snapshot.workoutSession = session
            if session.stateSnapshots == nil { session.stateSnapshots = [] }
            session.stateSnapshots?.append(snapshot)
        }

        // MARK: Session Lifecycle Updates
        switch message.event {
        case .runEnded:
            session.endedAt = message.timestamp
            if let snapshot = message.metricSnapshot {
                session.totalDistanceMiles = snapshot.distanceMiles
            }
            if let hr = message.heartRateBPM {
                session.averageHeartRate = hr
            }
        default:
            break
        }

        // MARK: Persist
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Failed to save ingested data: \(error.localizedDescription)")
        }
    }

    // MARK: - Session Lookup

    /// Finds an existing WatchWorkoutSession by its UUID.
    private func findSession(by id: UUID) -> WatchWorkoutSession? {
        let predicate = #Predicate<WatchWorkoutSession> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }
}
