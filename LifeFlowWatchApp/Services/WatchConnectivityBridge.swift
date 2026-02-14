import Foundation
import Observation
import WatchConnectivity
import LifeFlowCore

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

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let errorMessage = error?.localizedDescription
        let isActivated = activationState == .activated
        let reachable = session.isReachable
        Task { @MainActor in
            if let errorMessage {
                print("WatchConnectivity activation failed: \(errorMessage)")
            }
            self.isReachable = isActivated ? reachable : false
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let isActivated = session.activationState == .activated
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = isActivated ? reachable : false
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let isActivated = session.activationState == .activated
        let reachable = session.isReachable
        let decoded = WatchRunMessage.fromWCContext(message)
        Task { @MainActor in
            self.isReachable = isActivated ? reachable : false
            guard let decoded else { return }
            self.onMessage?(decoded)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let isActivated = session.activationState == .activated
        let reachable = session.isReachable
        let decoded = WatchRunMessage.fromWCContext(applicationContext)
        Task { @MainActor in
            self.isReachable = isActivated ? reachable : false
            guard let decoded else { return }
            self.onMessage?(decoded)
        }
    }
}
