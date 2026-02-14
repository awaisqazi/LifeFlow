import AVFoundation
import CoreMotion
import Foundation
import HealthKit
import Observation
import SwiftData
import WatchKit
import WidgetKit
import LifeFlowCore

@MainActor
@Observable
final class WatchWorkoutManager: NSObject {
    enum MetricSet: String, Codable {
        case primary
        case secondary
    }

    private struct StateSnapshotDraft {
        var timestamp: Date
        var lifecycleState: WatchRunLifecycleState
        var elapsedSeconds: TimeInterval
        var distanceMiles: Double
        var heartRateBPM: Double?
        var paceSecondsPerMile: Double?
        var fuelRemainingGrams: Double?
    }

    private let healthStore = HKHealthStore()
    private let motionManager = CMMotionManager()
    private let speechSynthesizer = AVSpeechSynthesizer()

    private let biomechanicalAnalyzer = BiomechanicalAnalyzer()
    private let coachPromptEngine = CoachPromptEngine(cooldown: 25)

    private(set) var connectivityBridge = WatchConnectivityBridge()
    private(set) var thermalGovernor = ThermalGovernor()

    private var adaptiveEngine = AdaptiveMarathonEngine(
        weightKg: 70,
        baseline: ReadinessInput(
            acuteLoad: 100,
            chronicLoad: 100,
            restingHeartRateDelta: 0,
            hrvDeltaPercent: 0
        )
    )

    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    private var tickTask: Task<Void, Never>?
    private var motionSamples: [MotionSample] = []
    private var telemetryBuffer: [TelemetrySnapshotDTO] = []
    private var stateSnapshotBuffer: [StateSnapshotDraft] = []

    private var activeSessionRecord: WatchWorkoutSession?
    private var lastPromptAt: Date?
    private var lastAlert: EngineAlert?
    private var lapIndex: Int = 0
    private var lastDistanceTimestamp: Date?
    private var lastDistanceMilesForPace: Double = 0
    private var lastWidgetPublishDate: Date = .distantPast
    private var currentActivity: NSUserActivity?

    private var totalEnergyKcal: Double = 0

    private(set) var lifecycleState: WatchRunLifecycleState = .idle
    private(set) var isAuthorized: Bool = false
    private(set) var startedAt: Date?
    private(set) var elapsedSeconds: TimeInterval = 0

    private(set) var currentHeartRateBPM: Double?
    private(set) var currentDistanceMiles: Double = 0
    private(set) var currentPaceSecondsPerMile: Double?
    private(set) var currentCadenceSPM: Double?
    private(set) var currentGradePercent: Double?

    private(set) var fuelingStatus = FuelingStatus(remainingGlycogenGrams: 420, level: .nominal)
    private(set) var latestBiomechanicalMetrics = BiomechanicalMetrics(
        verticalOscillationCm: 0,
        groundContactBalancePercent: 50
    )

    private(set) var latestDecision: EngineDecision?
    private(set) var latestPrompt: CoachingPrompt?
    private(set) var activeAlert: EngineAlert?

    private(set) var lastCompletedSession: WatchWorkoutSession?
    private(set) var liveWorkoutUUID: UUID?
    private(set) var lastErrorMessage: String?

    var metricSet: MetricSet = .primary
    var configuredGelCarbsGrams: Double = 25

    private var modelContext: ModelContext {
        WatchDataStore.shared.modelContainer.mainContext
    }

    override init() {
        super.init()

        connectivityBridge.onMessage = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.handleIncomingMessage(message)
            }
        }

        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            return
        }

        let status = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        isAuthorized = status == .sharingAuthorized
    }

    func requestAuthorizationIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            lastErrorMessage = "Health data is unavailable on this watch."
            isAuthorized = false
            return
        }

        if isAuthorized {
            return
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning)
        ]

        let shareTypes: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning)
        ]

        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
            refreshAuthorizationStatus()
        } catch {
            lastErrorMessage = "Health authorization failed: \(error.localizedDescription)"
            isAuthorized = false
        }
    }

    func startRun(style: RunType = .base, isIndoor: Bool = false) async {
        guard lifecycleState == .idle || lifecycleState == .ended else { return }

        await requestAuthorizationIfNeeded()
        guard isAuthorized else { return }

        lifecycleState = .preparing
        lastErrorMessage = nil

        do {
            let config = HKWorkoutConfiguration()
            config.activityType = .running
            config.locationType = isIndoor ? .indoor : .outdoor

            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()

            session.delegate = self
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

            let startDate = Date()
            session.startActivity(with: startDate)
            try await beginCollection(builder: builder, at: startDate)

            workoutSession = session
            workoutBuilder = builder

            startedAt = startDate
            elapsedSeconds = 0
            currentDistanceMiles = 0
            currentPaceSecondsPerMile = nil
            currentHeartRateBPM = nil
            currentCadenceSPM = nil
            currentGradePercent = 0
            totalEnergyKcal = 0
            lapIndex = 0
            lastDistanceTimestamp = startDate
            lastDistanceMilesForPace = 0
            lastPromptAt = nil
            lastAlert = nil
            telemetryBuffer.removeAll(keepingCapacity: true)
            stateSnapshotBuffer.removeAll(keepingCapacity: true)

            let readiness = readinessInput(for: style)
            await adaptiveEngine.updateBaseline(readiness)

            let record = WatchWorkoutSession(startedAt: startDate)
            modelContext.insert(record)
            try? modelContext.save()
            activeSessionRecord = record

            recordEvent(kind: .started)
            lifecycleState = .running

            startMotionUpdates()
            startTickLoop()

            sendConnectivity(
                WatchRunMessage(
                    event: .runStarted,
                    runID: record.id,
                    lifecycleState: .running
                ),
                force: true
            )

            publishWidgetState(force: true)
            donateSmartStackActivity()
        } catch {
            lifecycleState = .idle
            lastErrorMessage = "Unable to start run: \(error.localizedDescription)"
        }
    }

    func pauseRun() {
        guard lifecycleState == .running else { return }
        workoutSession?.pause()
        lifecycleState = .paused
        recordEvent(kind: .paused)

        sendConnectivity(
            WatchRunMessage(
                event: .runPaused,
                runID: activeSessionRecord?.id,
                lifecycleState: .paused
            ),
            force: true
        )

        publishWidgetState(force: true)
    }

    func resumeRun() {
        guard lifecycleState == .paused else { return }
        workoutSession?.resume()
        lifecycleState = .running
        recordEvent(kind: .resumed)

        sendConnectivity(
            WatchRunMessage(
                event: .runResumed,
                runID: activeSessionRecord?.id,
                lifecycleState: .running
            ),
            force: true
        )

        publishWidgetState(force: true)
    }

    func endRun(discarded: Bool = false) async {
        guard lifecycleState == .running || lifecycleState == .paused || lifecycleState == .preparing else {
            return
        }

        tickTask?.cancel()
        tickTask = nil
        stopMotionUpdates()

        let endDate = Date()

        if discarded {
            workoutBuilder?.discardWorkout()
            workoutSession?.end()
        } else if let builder = workoutBuilder {
            workoutSession?.end()

            do {
                try await endCollection(builder: builder, at: endDate)
                let workout = try await finishWorkout(builder: builder)
                liveWorkoutUUID = workout.uuid
            } catch {
                lastErrorMessage = "Failed to finalize workout: \(error.localizedDescription)"
            }
        }

        lifecycleState = .ended

        if let record = activeSessionRecord {
            record.endedAt = endDate
            record.totalEnergyBurned = totalEnergyKcal
            record.totalDistanceMiles = currentDistanceMiles
            record.averageHeartRate = currentHeartRateBPM
            if !discarded {
                record.healthKitWorkoutID = liveWorkoutUUID
            }
            try? modelContext.save()
            lastCompletedSession = record
        }

        recordEvent(kind: .ended, payload: ["discarded": discarded])

        await flushTelemetry(force: true)

        sendConnectivity(
            WatchRunMessage(
                event: .runEnded,
                runID: activeSessionRecord?.id,
                lifecycleState: .ended,
                discarded: discarded
            ),
            force: true
        )

        schedulePostRunRefresh()
        publishWidgetState(force: true)

        workoutSession = nil
        workoutBuilder = nil
        activeSessionRecord = nil
        activeAlert = nil
    }

    func logNutrition(carbsGrams: Double? = nil) {
        let carbs = max(15, min(40, carbsGrams ?? configuredGelCarbsGrams))

        Task {
            let status = await adaptiveEngine.logGel(carbsGrams: carbs)
            await MainActor.run {
                fuelingStatus = status
                activeAlert = nil
                recordEvent(kind: .fuelLogged, payload: ["carbs": carbs])
                sendConnectivity(
                    WatchRunMessage(
                        event: .fuelLogged,
                        runID: activeSessionRecord?.id,
                        lifecycleState: lifecycleState,
                        carbsGrams: carbs
                    ),
                    force: true
                )
                WKInterfaceDevice.current().play(.click)
                publishWidgetState(force: true)
            }
        }
    }

    func markLap() {
        lapIndex += 1

        if let builder = workoutBuilder {
            let event = HKWorkoutEvent(
                type: .lap,
                dateInterval: DateInterval(start: Date(), duration: 0),
                metadata: nil
            )
            builder.addWorkoutEvents([event]) { _, _ in }
        }

        recordEvent(kind: .lapMarked, payload: ["lap": lapIndex])

        sendConnectivity(
            WatchRunMessage(
                event: .lapMarked,
                runID: activeSessionRecord?.id,
                lifecycleState: lifecycleState,
                lapIndex: lapIndex
            ),
            force: true
        )

        WKInterfaceDevice.current().play(.notification)
    }

    func dismissActiveAlert() {
        guard activeAlert != nil else { return }
        activeAlert = nil
        recordEvent(kind: .alertAcknowledged)

        sendConnectivity(
            WatchRunMessage(
                event: .metricSnapshot,
                runID: activeSessionRecord?.id,
                lifecycleState: lifecycleState
            ),
            force: true
        )
    }

    func toggleMetricSet() {
        metricSet = metricSet == .primary ? .secondary : .primary
    }

    func savePostRunCheckIn(effort: Int, reflection: String) {
        guard let session = lastCompletedSession else { return }

        session.postRunEffort = max(1, min(5, effort))
        let trimmed = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
        session.postRunReflection = trimmed.isEmpty ? nil : trimmed
        session.requiresRefinementSync = true

        try? modelContext.save()
    }

    func applyPendingIntentActions() {
        let actions = IntentActionRelay.consumeAll()
        guard !actions.isEmpty else { return }

        for action in actions {
            switch action.kind {
            case .startRun:
                if lifecycleState == .paused {
                    resumeRun()
                } else if lifecycleState == .idle || lifecycleState == .ended {
                    Task {
                        await startRun(style: .base)
                    }
                }
            case .logNutrition:
                logNutrition(carbsGrams: action.value)
            case .markLap:
                markLap()
            case .dismissAlert:
                dismissActiveAlert()
            case .toggleMetrics:
                toggleMetricSet()
            }
        }
    }

    private func startTickLoop() {
        tickTask?.cancel()

        tickTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await self.tick()
            }
        }
    }

    private func tick() async {
        applyPendingIntentActions()

        guard let startedAt else { return }
        elapsedSeconds = max(0, Date().timeIntervalSince(startedAt))

        guard lifecycleState == .running else {
            enqueueStateSnapshot(timestamp: Date())
            await flushTelemetry(force: false)
            publishWidgetState()
            return
        }

        let now = Date()
        await updateBiomechanicalMetricsIfNeeded()

        let pace = estimatePace(now: now)
        currentPaceSecondsPerMile = pace

        let zone = currentHeartRateBPM.map(Self.heartRateZone)
        let caloriesPerMinute: Double? = elapsedSeconds > 0
            ? (totalEnergyKcal / max(elapsedSeconds / 60.0, 0.1))
            : nil

        let liveMetrics = LiveRunMetrics(
            timestamp: now,
            heartRateBPM: currentHeartRateBPM,
            paceSecondsPerMile: pace,
            distanceMiles: currentDistanceMiles,
            cadenceSPM: currentCadenceSPM,
            gradePercent: currentGradePercent,
            caloriesPerMinute: caloriesPerMinute,
            heartRateZone: zone
        )

        let decision = await adaptiveEngine.ingest(metrics: liveMetrics)
        latestDecision = decision
        fuelingStatus = decision.fuelingStatus

        let nextAlert = decision.alerts.first
        if nextAlert != lastAlert {
            lastAlert = nextAlert
            activeAlert = nextAlert
            if let alert = nextAlert {
                playHaptic(for: alert)
            }
        }

        if thermalGovernor.mode.allowsVoicePrompts,
           let prompt = coachPromptEngine.prompt(for: decision, now: now, lastPromptAt: lastPromptAt) {
            lastPromptAt = now
            latestPrompt = prompt
            speak(prompt)
        }

        let snapshot = TelemetrySnapshotDTO(
            timestamp: now,
            distanceMiles: currentDistanceMiles,
            heartRateBPM: currentHeartRateBPM,
            paceSecondsPerMile: pace,
            cadenceSPM: currentCadenceSPM,
            gradePercent: currentGradePercent,
            fuelRemainingGrams: fuelingStatus.remainingGlycogenGrams
        )

        telemetryBuffer.append(snapshot)
        enqueueStateSnapshot(timestamp: now)

        sendConnectivity(
            WatchRunMessage(
                event: .metricSnapshot,
                runID: activeSessionRecord?.id,
                lifecycleState: lifecycleState,
                metricSnapshot: snapshot,
                heartRateBPM: currentHeartRateBPM
            )
        )

        await flushTelemetry(force: false)
        publishWidgetState()
    }

    private func enqueueStateSnapshot(timestamp: Date) {
        let draft = StateSnapshotDraft(
            timestamp: timestamp,
            lifecycleState: lifecycleState,
            elapsedSeconds: elapsedSeconds,
            distanceMiles: currentDistanceMiles,
            heartRateBPM: currentHeartRateBPM,
            paceSecondsPerMile: currentPaceSecondsPerMile,
            fuelRemainingGrams: fuelingStatus.remainingGlycogenGrams
        )

        stateSnapshotBuffer.append(draft)
    }

    private func updateBiomechanicalMetricsIfNeeded() async {
        guard !motionSamples.isEmpty else { return }

        let samples = motionSamples
        motionSamples.removeAll(keepingCapacity: true)

        latestBiomechanicalMetrics = await biomechanicalAnalyzer.calculateMetrics(from: samples)
    }

    private func estimatePace(now: Date) -> Double? {
        guard currentDistanceMiles > 0, elapsedSeconds > 0 else { return nil }

        guard let lastDistanceTimestamp else {
            lastDistanceTimestamp = now
            lastDistanceMilesForPace = currentDistanceMiles
            return elapsedSeconds / currentDistanceMiles
        }

        let deltaDistance = currentDistanceMiles - lastDistanceMilesForPace
        let deltaTime = now.timeIntervalSince(lastDistanceTimestamp)

        self.lastDistanceTimestamp = now
        self.lastDistanceMilesForPace = currentDistanceMiles

        guard deltaDistance > 0.001, deltaTime > 0 else {
            return elapsedSeconds / currentDistanceMiles
        }

        return deltaTime / deltaDistance
    }

    private func speak(_ prompt: CoachingPrompt) {
        let utterance = AVSpeechUtterance(string: prompt.message)
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.03

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-fatal; haptics still deliver urgency cues.
        }

        speechSynthesizer.speak(utterance)
    }

    private func playHaptic(for alert: EngineAlert) {
        switch alert {
        case .split:
            WKInterfaceDevice.current().play(.notification)
        case .paceVariance:
            WKInterfaceDevice.current().play(.click)
        case .fuelWarning:
            WKInterfaceDevice.current().play(.notification)
        case .cardiacDrift:
            WKInterfaceDevice.current().play(.retry)
        case .fuelCritical, .highHeartRate:
            WKInterfaceDevice.current().play(.retry)
            WKInterfaceDevice.current().play(.failure)
        }
    }

    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }

        let hz = max(15, min(100, thermalGovernor.mode.sensorSampleRateHz))
        motionManager.deviceMotionUpdateInterval = 1.0 / hz

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            guard self.lifecycleState == .running else { return }

            let sample = MotionSample(
                verticalAcceleration: motion.userAcceleration.z,
                lateralBalance: motion.userAcceleration.x
            )

            self.motionSamples.append(sample)
            if self.motionSamples.count > 800 {
                self.motionSamples.removeFirst(self.motionSamples.count - 800)
            }
        }
    }

    private func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }

    private func sendConnectivity(_ message: WatchRunMessage, force: Bool = false) {
        connectivityBridge.send(message, force: force)
    }

    private func recordEvent(kind: RunEventKind, payload: [String: Any]? = nil) {
        guard let activeSessionRecord else { return }

        let payloadJSON = payload.flatMap { dictionary -> String? in
            guard JSONSerialization.isValidJSONObject(dictionary),
                  let data = try? JSONSerialization.data(withJSONObject: dictionary, options: []),
                  let string = String(data: data, encoding: .utf8) else {
                return nil
            }
            return string
        }

        let event = RunEvent(timestamp: Date(), kind: kind, payloadJSON: payloadJSON)
        event.workoutSession = activeSessionRecord
        if activeSessionRecord.runEvents == nil {
            activeSessionRecord.runEvents = []
        }
        activeSessionRecord.runEvents?.append(event)

        try? modelContext.save()
    }

    private func flushTelemetry(force: Bool) async {
        guard let activeSessionRecord else {
            telemetryBuffer.removeAll(keepingCapacity: true)
            stateSnapshotBuffer.removeAll(keepingCapacity: true)
            return
        }

        guard force || telemetryBuffer.count >= 60 || stateSnapshotBuffer.count >= 60 else {
            return
        }

        for snapshot in telemetryBuffer {
            let point = TelemetryPoint(
                timestamp: snapshot.timestamp,
                distanceMiles: snapshot.distanceMiles,
                heartRateBPM: snapshot.heartRateBPM,
                paceSecondsPerMile: snapshot.paceSecondsPerMile,
                cadenceSPM: snapshot.cadenceSPM,
                gradePercent: snapshot.gradePercent,
                fuelRemainingGrams: snapshot.fuelRemainingGrams
            )
            point.workoutSession = activeSessionRecord
            if activeSessionRecord.telemetryPoints == nil {
                activeSessionRecord.telemetryPoints = []
            }
            activeSessionRecord.telemetryPoints?.append(point)
        }

        for draft in stateSnapshotBuffer {
            let state = WatchRunStateSnapshot(
                timestamp: draft.timestamp,
                lifecycleState: draft.lifecycleState,
                elapsedSeconds: draft.elapsedSeconds,
                distanceMiles: draft.distanceMiles,
                heartRateBPM: draft.heartRateBPM,
                paceSecondsPerMile: draft.paceSecondsPerMile,
                fuelRemainingGrams: draft.fuelRemainingGrams
            )
            state.workoutSession = activeSessionRecord
            if activeSessionRecord.stateSnapshots == nil {
                activeSessionRecord.stateSnapshots = []
            }
            activeSessionRecord.stateSnapshots?.append(state)
        }

        telemetryBuffer.removeAll(keepingCapacity: true)
        stateSnapshotBuffer.removeAll(keepingCapacity: true)

        try? modelContext.save()
    }

    private func publishWidgetState(force: Bool = false) {
        let now = Date()
        // Throttle widget updates to every 15 seconds.
        // WidgetCenter.shared.invalidateRelevance dispatches to ChronoCore queue
        // which conflicts with WatchConnectivity threads → _dispatch_assert_queue_fail.
        // Widget timelines only refresh at ~15s intervals anyway.
        guard force || now.timeIntervalSince(lastWidgetPublishDate) >= 15 else { return }
        lastWidgetPublishDate = now

        let state = WatchWidgetState(
            lastUpdated: now,
            lifecycleState: lifecycleState,
            elapsedSeconds: elapsedSeconds,
            distanceMiles: currentDistanceMiles,
            heartRateBPM: currentHeartRateBPM,
            paceSecondsPerMile: currentPaceSecondsPerMile,
            fuelRemainingGrams: fuelingStatus.remainingGlycogenGrams
        )

        WatchWidgetStateStore.save(state)
        WidgetCenter.shared.reloadTimelines(ofKind: LifeFlowWidgetKinds.runStatus)
    }

    private func handleIncomingMessage(_ message: WatchRunMessage) {
        if let heartRate = message.heartRateBPM, heartRate > 0 {
            currentHeartRateBPM = heartRate
        }
    }

    private func schedulePostRunRefresh() {
        // CloudKit sync will happen automatically when app enters background
        // SwiftUI watchOS apps don't use WKExtension.shared() for background tasks
        // Instead, sync is triggered via WatchExtensionDelegate.handleScenePhase
    }

    private func donateSmartStackActivity() {
        // Reuse a single NSUserActivity to prevent rapid creation/invalidation
        // which causes "sendUserActivityToServer called after invalidated" errors.
        if currentActivity == nil {
            let activity = NSUserActivity(activityType: "com.Fez.LifeFlow.workout")
            activity.title = "LifeFlow Run"
            activity.isEligibleForPrediction = true
            activity.isEligibleForSearch = false
            currentActivity = activity
        }

        currentActivity?.userInfo = [
            "lifecycle_state": lifecycleState.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        currentActivity?.becomeCurrent()
    }

    private func readinessInput(for style: RunType) -> ReadinessInput {
        let bias: Double
        switch style {
        case .longRun:
            bias = 1.08
        case .tempo, .speedWork:
            bias = 1.16
        case .recovery:
            bias = 0.92
        case .base, .crossTraining, .rest:
            bias = 1.0
        }

        return ReadinessInput(
            acuteLoad: 100 * bias,
            chronicLoad: 100,
            restingHeartRateDelta: 0,
            hrvDeltaPercent: 0
        )
    }

    private static func heartRateZone(_ bpm: Double) -> Int {
        let maxHR = 190.0
        let fraction = max(0, min(1.2, bpm / maxHR))

        switch fraction {
        case ..<0.60:
            return 1
        case ..<0.70:
            return 2
        case ..<0.80:
            return 3
        case ..<0.90:
            return 4
        default:
            return 5
        }
    }

    private func beginCollection(builder: HKLiveWorkoutBuilder, at date: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: date) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "LifeFlowWatch",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to begin workout collection."]
                    ))
                }
            }
        }
    }

    private func endCollection(builder: HKLiveWorkoutBuilder, at date: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: date) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "LifeFlowWatch",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to end workout collection."]
                    ))
                }
            }
        }
    }

    private func finishWorkout(builder: HKLiveWorkoutBuilder) async throws -> HKWorkout {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout, Error>) in
            builder.finishWorkout { workout, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let workout {
                    continuation.resume(returning: workout)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "LifeFlowWatch",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to finish workout."]
                    ))
                }
            }
        }
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            switch toState {
            case .running:
                if self.lifecycleState == .paused {
                    self.lifecycleState = .running
                }
            case .paused:
                self.lifecycleState = .paused
            case .ended:
                if self.lifecycleState != .ended {
                    self.lifecycleState = .ended
                }
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        Task { @MainActor in
            self.lastErrorMessage = "Workout session error: \(error.localizedDescription)"
        }
    }
}

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { continue }
                guard let statistics = workoutBuilder.statistics(for: quantityType) else { continue }

                switch quantityType {
                case HKQuantityType(.heartRate):
                    if let value = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                        self.currentHeartRateBPM = value
                    }

                case HKQuantityType(.activeEnergyBurned):
                    if let value = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        self.totalEnergyKcal = value
                    }

                case HKQuantityType(.distanceWalkingRunning):
                    if let meters = statistics.sumQuantity()?.doubleValue(for: .meter()) {
                        self.currentDistanceMiles = meters / 1_609.344
                    }

                default:
                    break
                }
            }
        }
    }
}
