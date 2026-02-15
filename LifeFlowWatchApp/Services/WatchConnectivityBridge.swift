import Foundation
import Observation
import WatchConnectivity
import LifeFlowCore
import HealthKit

// MARK: - WatchConnectivityBridge
// WCSessionDelegate callbacks arrive on a background queue. This bridge
// keeps UI-observable state (@MainActor) separate from data ingestion,
// which is routed to the background WatchDataStore @ModelActor.

@MainActor
@Observable
final class WatchConnectivityBridge: NSObject, WCSessionDelegate {
    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    private(set) var isReachable: Bool = false

    /// Throttle: don't send more than once every 5 seconds for metric snapshots.
    private var lastContextSendDate: Date = .distantPast
    private static let contextThrottleInterval: TimeInterval = 5

    var onMessage: ((WatchRunMessage) -> Void)?

    override init() {
        super.init()
        Task { @MainActor in
            activateIfNeeded()
        }
    }

    func activateIfNeeded() {
        guard let session else { return }

        if session.delegate == nil {
            session.delegate = self
        }

        if session.activationState == .notActivated {
            session.activate()
        }

        sync(session)
    }

    /// Send a message to the companion app.
    /// Event-driven messages (start, pause, end) always send immediately via sendMessage.
    /// Metric snapshots are throttled and use updateApplicationContext only.
    func send(_ message: WatchRunMessage, force: Bool = false) {
        guard let session else { return }

        activateIfNeeded()
        guard session.activationState == .activated else { return }
        guard session.isCompanionAppInstalled else { return }

        // Throttle non-forced sends (metric snapshots from tick loop)
        let now = Date()
        if !force && now.timeIntervalSince(lastContextSendDate) < Self.contextThrottleInterval {
            return
        }
        lastContextSendDate = now

        let context = message.toWCContext()
        guard !context.isEmpty else { return }

        // Dispatch WCSession operations off the MainActor to avoid
        // _dispatch_assert_queue_fail — WCSession internally serializes
        // onto its own background queue and asserts if called from wrong context.
        Self.dispatchWCSessionOps(session: session, context: context, sendMessage: force)
    }

    // NOTE: startWatchApp(with:) is iOS-only (launches the watch app from iPhone).
    // The iOS-side WatchConnectivityManager handles that call.
    // On watchOS, the app is already running — no launch needed.
    // MARK: - Watch → iPhone Workout Broadcast

    /// Broadcasts a workout start event to the iPhone companion app.
    /// Uses `sendMessage` for instant delivery when reachable, with
    /// `transferUserInfo` as a fallback for background/disconnected state.
    func broadcastWorkoutStartToPhone(workoutID: UUID, type: String) {
        guard let session else { return }

        let payload: [String: Any] = [
            "action": "START_LIVE_ACTIVITY",
            "type": type,
            "id": workoutID.uuidString
        ]

        // Use nonisolated static helper to avoid capturing @MainActor session
        Self.dispatchBroadcast(session: session, payload: payload)
    }

    private nonisolated static func dispatchBroadcast(session: WCSession, payload: [String: Any]) {
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                print("Failed to wake iPhone: \(error.localizedDescription)")
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    // MARK: - Private Helpers

    /// Nonisolated helper — dispatches WCSession calls off the MainActor.
    /// `sendMessage` is only used for event-driven sends (`sendMessage: true`);
    /// tick-loop snapshots rely on `updateApplicationContext` alone to avoid
    /// flooding the console with timeout errors when the phone is unreachable.
    private nonisolated static func dispatchWCSessionOps(
        session: WCSession,
        context: [String: Any],
        sendMessage: Bool
    ) {
        do {
            try session.updateApplicationContext(context)
        } catch {
            // This can fail if called before activation completes — non-fatal.
        }

        if sendMessage && session.isReachable {
            session.sendMessage(context, replyHandler: nil) { _ in
                // Timeout errors are expected when the iPhone app is backgrounded
                // or Bluetooth is weak. Silently ignore — applicationContext covers it.
            }
        }
    }

    private func sync(_ session: WCSession) {
        guard session.activationState == .activated else {
            isReachable = false
            return
        }

        isReachable = session.isReachable
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("WatchConnectivity activation failed: \(error.localizedDescription)")
        }
        let reachable = activationState == .activated && session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let decoded = WatchRunMessage.fromWCContext(message)
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            guard let decoded else { return }
            self.onMessage?(decoded)
        }
        if let decoded {
            Task {
                await WatchDataStore.shared.ingest(decoded)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let decoded = WatchRunMessage.fromWCContext(applicationContext)
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            guard let decoded else { return }
            self.onMessage?(decoded)
        }
        if let decoded {
            Task {
                await WatchDataStore.shared.ingest(decoded)
            }
        }
    }
}
