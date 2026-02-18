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

    private struct SessionStatusSnapshot: Sendable {
        let isReachable: Bool
        let isWatchPaired: Bool
        let isWatchAppInstalled: Bool

        nonisolated
        init(session: WCSession) {
            let activated = session.activationState == .activated
            self.isReachable = activated ? session.isReachable : false
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    private enum IncomingPayload: Sendable {
        case startLiveActivity(workoutType: String)
        case runMessage(WatchRunMessage)
        case heartRate(Double)
        case none

        nonisolated
        static func decode(from dictionary: [String: Any]) -> IncomingPayload {
            if let action = dictionary["action"] as? String, action == "START_LIVE_ACTIVITY" {
                let workoutType = dictionary["type"] as? String ?? "Run"
                return .startLiveActivity(workoutType: workoutType)
            }

            if let message = WatchRunMessage.fromWCContext(dictionary) {
                return .runMessage(message)
            }

            if let heartRate = dictionary["heartRate"] as? Double {
                return .heartRate(heartRate)
            }

            return .none
        }
    }

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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.startWatchApp(with: config) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
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
        let snapshot = SessionStatusSnapshot(session: session)
        Task { @MainActor [weak self] in
            self?.applyStatus(snapshot)
        }
    }

    @MainActor
    private func applyStatus(_ snapshot: SessionStatusSnapshot) {
        isReachable = snapshot.isReachable
        isWatchPaired = snapshot.isWatchPaired
        isWatchAppInstalled = snapshot.isWatchAppInstalled
    }

    @MainActor
    private func consumePayload(_ payload: IncomingPayload, status: SessionStatusSnapshot) {
        applyStatus(status)

        switch payload {
        case .startLiveActivity(let workoutType):
            launchLiveActivityFromWatch(workoutType: workoutType)
            WidgetCenter.shared.reloadAllTimelines()
        case .runMessage(let message):
            if let heartRate = message.heartRateBPM, heartRate > 0 {
                onHeartRateUpdate?(heartRate)
            }
            onRunMessage?(message)
        case .heartRate(let heartRate):
            onHeartRateUpdate?(heartRate)
        case .none:
            break
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
            workoutTitle: workoutType,
            totalExercises: 1
        )

        let initialState = GymWorkoutAttributes.ContentState(
            exerciseName: workoutType,
            currentSet: 0,
            totalSets: 0,
            elapsedTime: 0,
            isResting: false,
            restTimeRemaining: 0,
            isPaused: false,
            isCardio: true
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
        let snapshot = SessionStatusSnapshot(session: session)
        Task { @MainActor in
            self.applyStatus(snapshot)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        let snapshot = SessionStatusSnapshot(session: session)
        Task { @MainActor in
            self.applyStatus(snapshot)
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let snapshot = SessionStatusSnapshot(session: session)
        Task { @MainActor in
            self.applyStatus(snapshot)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let decoded = IncomingPayload.decode(from: message)
        let status = SessionStatusSnapshot(session: session)
        Task { @MainActor in
            self.consumePayload(decoded, status: status)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let decoded = IncomingPayload.decode(from: applicationContext)
        let status = SessionStatusSnapshot(session: session)
        Task { @MainActor in
            self.consumePayload(decoded, status: status)
        }
    }
}
