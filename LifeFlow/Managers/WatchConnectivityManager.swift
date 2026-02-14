//
//  WatchConnectivityManager.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//  Updated for iOS 26: Live Activity bridging + iPhone→Watch workout launch.
//

import Foundation
import Observation
import WatchConnectivity
import LifeFlowCore
import ActivityKit
import HealthKit
import WidgetKit

@Observable
final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    private(set) var isReachable: Bool = false
    private(set) var isWatchPaired: Bool = false
    private(set) var isWatchAppInstalled: Bool = false

    var onHeartRateUpdate: ((Double) -> Void)?
    var onRunMessage: ((WatchRunMessage) -> Void)?

    override init() {
        super.init()
        activateIfNeeded()
    }

    func activateIfNeeded() {
        guard let session else { return }

        if session.delegate == nil {
            session.delegate = self
        }

        if session.activationState == .notActivated {
            session.activate()
        }

        syncStatus(from: session)
    }

    // MARK: - iPhone → Watch Workout Launch

    /// Launches the LifeFlow workout app on the paired Apple Watch.
    /// Uses HealthKit's `startWatchApp(with:)` to seamlessly transition
    /// the UI to the user's wrist from an iPhone-initiated guided run.
    func startGuidedRunOnWatch(config: HKWorkoutConfiguration) async throws {
        let healthStore = HKHealthStore()
        try await healthStore.startWatchApp(with: config)
    }

    func sendGuidedRunStart(targetDistanceMiles: Double?, targetPaceMinutesPerMile: Double?) {
        let message = WatchRunMessage(
            event: .runStarted,
            lifecycleState: .running,
            metricSnapshot: TelemetrySnapshotDTO(
                timestamp: Date(),
                distanceMiles: targetDistanceMiles ?? 0,
                paceSecondsPerMile: targetPaceMinutesPerMile.map { $0 * 60 }
            )
        )

        sendWatchRunMessage(message)
    }

    func sendGuidedRunPause() {
        sendWatchRunMessage(
            WatchRunMessage(
                event: .runPaused,
                lifecycleState: .paused
            )
        )
    }

    func sendGuidedRunResume() {
        sendWatchRunMessage(
            WatchRunMessage(
                event: .runResumed,
                lifecycleState: .running
            )
        )
    }

    func sendGuidedRunEnd(discarded: Bool = false) {
        sendWatchRunMessage(
            WatchRunMessage(
                event: .runEnded,
                lifecycleState: .ended,
                discarded: discarded
            )
        )
    }

    func sendWatchRunMessage(_ message: WatchRunMessage) {
        guard let session else { return }

        activateIfNeeded()
        guard session.activationState == .activated else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        let context = message.toWCContext()
        guard !context.isEmpty else { return }

        do {
            try session.updateApplicationContext(context)
        } catch {
            print("WatchConnectivity updateApplicationContext failed: \(error)")
        }

        if session.isReachable {
            session.sendMessage(context, replyHandler: nil) { error in
                print("WatchConnectivity sendMessage failed: \(error)")
            }
        }
    }

    private func syncStatus(from session: WCSession) {
        guard session.activationState == .activated else {
            Task { @MainActor in
                self.isReachable = false
                self.isWatchPaired = session.isPaired
                self.isWatchAppInstalled = session.isWatchAppInstalled
            }
            return
        }

        Task { @MainActor in
            self.isReachable = session.isReachable
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    private func consumePayload(_ payload: [String: Any], from session: WCSession) {
        syncStatus(from: session)

        // MARK: Watch → iPhone Live Activity Bridge
        // When the Watch app starts a workout, it sends a `START_LIVE_ACTIVITY`
        // action. The iPhone responds by spinning up an ActivityKit Live Activity
        // on the Lock Screen, so the user sees their workout at a glance.
        if let action = payload["action"] as? String, action == "START_LIVE_ACTIVITY" {
            let workoutType = payload["type"] as? String ?? "Run"
            Task { @MainActor in
                launchLiveActivityFromWatch(workoutType: workoutType)
                // Also refresh all widget timelines so the glanceable UI updates
                WidgetCenter.shared.reloadAllTimelines()
            }
            return
        }

        if let message = WatchRunMessage.fromWCContext(payload) {
            Task { @MainActor in
                if let heartRate = message.heartRateBPM, heartRate > 0 {
                    self.onHeartRateUpdate?(heartRate)
                }
                self.onRunMessage?(message)
            }
            return
        }

        if let heartRate = payload["heartRate"] as? Double {
            Task { @MainActor in
                self.onHeartRateUpdate?(heartRate)
            }
        }
    }

    // MARK: - Live Activity Launch

    /// Creates a Live Activity on iOS when the Watch broadcasts a workout start.
    /// This allows the Lock Screen and Dynamic Island to show workout progress
    /// even though the workout was initiated from the Watch.
    @MainActor
    private func launchLiveActivityFromWatch(workoutType: String) {
        // Only launch if ActivityKit allows it
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = GymWorkoutAttributes(
            exerciseName: workoutType,
            startDate: Date()
        )

        let initialState = GymWorkoutAttributes.ContentState(
            currentSet: 0,
            totalSets: 0,
            reps: 0,
            weight: 0,
            isResting: false,
            restTimeRemaining: 0,
            exerciseName: workoutType,
            isCardioMode: true,
            cardioElapsedTime: 0,
            isPaused: false
        )

        let content = ActivityContent(state: initialState, staleDate: nil)

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("Failed to start Live Activity from Watch: \(error)")
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            print("WatchConnectivity activation failed: \(error)")
        }
        Task { @MainActor in
            self.syncStatus(from: session)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.syncStatus(from: session)
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.syncStatus(from: session)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.consumePayload(message, from: session)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.consumePayload(applicationContext, from: session)
        }
    }
}
