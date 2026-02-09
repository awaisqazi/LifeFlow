//
//  WatchConnectivityManager.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import Foundation
import Observation
import WatchConnectivity

@Observable
final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    
    private(set) var isReachable: Bool = false
    private(set) var isWatchPaired: Bool = false
    private(set) var isWatchAppInstalled: Bool = false
    
    var onHeartRateUpdate: ((Double) -> Void)?
    
    override init() {
        super.init()
        activateIfNeeded()
    }
    
    func activateIfNeeded() {
        guard let session else { return }
        guard session.delegate == nil else { return }
        session.delegate = self
        session.activate()
        syncStatus(from: session)
    }
    
    func sendGuidedRunStart(targetDistanceMiles: Double?, targetPaceMinutesPerMile: Double?) {
        var payload: [String: Any] = ["startedAt": Date().timeIntervalSince1970]
        if let targetDistanceMiles {
            payload["targetDistanceMiles"] = targetDistanceMiles
        }
        if let targetPaceMinutesPerMile {
            payload["targetPaceMinutesPerMile"] = targetPaceMinutesPerMile
        }
        send(event: "guided_run_started", payload: payload)
    }
    
    func sendGuidedRunPause() {
        send(event: "guided_run_paused", payload: ["timestamp": Date().timeIntervalSince1970])
    }
    
    func sendGuidedRunResume() {
        send(event: "guided_run_resumed", payload: ["timestamp": Date().timeIntervalSince1970])
    }
    
    func sendGuidedRunEnd(discarded: Bool = false) {
        send(event: "guided_run_ended", payload: [
            "discarded": discarded,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    private func send(event: String, payload: [String: Any]) {
        guard let session else { return }
        guard session.activationState == .activated else { return }
        
        var context = payload
        context["event"] = event
        
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
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
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
        syncStatus(from: session)
        
        if let heartRate = message["heartRate"] as? Double {
            Task { @MainActor in
                self.onHeartRateUpdate?(heartRate)
            }
        }
    }
}
