import Foundation
import Observation
import WatchConnectivity
import LifeFlowCore

@MainActor
@Observable
final class WatchConnectivityBridge: NSObject, WCSessionDelegate {
    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    private(set) var isReachable: Bool = false

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

    func send(_ message: WatchRunMessage) {
        guard let session else { return }

        activateIfNeeded()
        guard session.activationState == .activated else { return }
        guard session.isCompanionAppInstalled else { return }

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

    private func sync(_ session: WCSession) {
        guard session.activationState == .activated else {
            isReachable = false
            return
        }

        isReachable = session.isReachable
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("WatchConnectivity activation failed: \(error)")
        }
        sync(session)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        sync(session)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        sync(session)
        guard let decoded = WatchRunMessage.fromWCContext(message) else { return }
        onMessage?(decoded)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        sync(session)
        guard let decoded = WatchRunMessage.fromWCContext(applicationContext) else { return }
        onMessage?(decoded)
    }
}
