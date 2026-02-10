//
//  WatchConnectivityManager.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import Foundation
import Observation
import WatchConnectivity
import LifeFlowCore

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

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            print("WatchConnectivity activation failed: \(error)")
        }
        syncStatus(from: session)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        syncStatus(from: session)
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        syncStatus(from: session)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        consumePayload(message, from: session)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        consumePayload(applicationContext, from: session)
    }
}
