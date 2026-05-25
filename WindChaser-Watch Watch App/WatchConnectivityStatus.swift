import Combine
import WatchConnectivity

@MainActor
final class WatchConnectivityStatus: NSObject, ObservableObject {
    @Published private(set) var relayState: WatchRelayState = .waitingForPhone
    @Published private(set) var currentHeartRate: Int?

    private let session: WCSession?

    override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
    }

    func start() {
        guard let session else {
            relayState = .disconnected
            return
        }

        session.delegate = self
        session.activate()
        refreshState(from: session)
    }

    private func refreshState(from session: WCSession) {
        guard session.activationState == .activated else {
            relayState = .waitingForPhone
            return
        }

        relayState = session.isReachable ? .waitingForPhone : .disconnected
    }
}

extension WatchConnectivityStatus: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if error != nil {
                relayState = .disconnected
            } else {
                refreshState(from: session)
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            refreshState(from: session)
        }
    }
}
