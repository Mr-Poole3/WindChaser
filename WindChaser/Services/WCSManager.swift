import Foundation
import WatchConnectivity

public enum WatchConnectionState: String, Sendable, Codable {
    case disconnected = "未连接"
    case pairing = "配对中"
    case connected = "已连接"
    case activeWorkout = "运动传输中"
}

/// iPhone 端 WatchConnectivity 管理器。
///
/// S4 只接收 Watch 推送的实时心率并提供给 `RideSession`；暂停/继续/结束等控制命令由 S5 完成。
@MainActor
final class WCSManager: NSObject {
    static let shared = WCSManager()

    private(set) var connectionState: WatchConnectionState = .disconnected

    private let session: WCSession?
    private var activeRideSessionID: UUID?
    private var heartRateContinuations: [UUID: AsyncStream<HeartRateRelayMessage>.Continuation] = [:]

    private override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
    }

    func startWatchSession() {
        guard let session else {
            connectionState = .disconnected
            return
        }

        session.delegate = self
        session.activate()
        refreshConnectionState()
    }

    func setActiveRideSession(_ sessionID: UUID?) {
        activeRideSessionID = sessionID
        sendSessionContext(sessionID)
    }

    func heartRateStream() -> AsyncStream<HeartRateRelayMessage> {
        AsyncStream { continuation in
            let id = UUID()
            heartRateContinuations[id] = continuation
            continuation.onTermination = { _ in
                Task { @MainActor in
                    WCSManager.shared.heartRateContinuations[id] = nil
                }
            }
        }
    }

    private func refreshConnectionState() {
        guard let session, session.activationState == .activated else {
            connectionState = .pairing
            return
        }

        if !session.isPaired || !session.isWatchAppInstalled {
            connectionState = .disconnected
        } else if session.isReachable {
            connectionState = .connected
        } else {
            connectionState = .pairing
        }
    }

    private func sendSessionContext(_ sessionID: UUID?) {
        guard let session, session.activationState == .activated, session.isReachable else { return }

        let message = WatchMessage.sessionContext(
            WatchSessionContextMessage(sessionID: sessionID)
        )
        do {
            session.sendMessage(
                try message.dictionaryPayload(),
                replyHandler: nil,
                errorHandler: { error in
                    print("Failed to send Watch session context: \(error)")
                }
            )
        } catch {
            print("Failed to encode Watch session context: \(error)")
        }
    }

    private func receive(_ message: WatchMessage) {
        switch message {
        case .heartRate(let heartRate):
            guard heartRate.sessionID == activeRideSessionID else { return }
            connectionState = .activeWorkout
            for continuation in heartRateContinuations.values {
                continuation.yield(heartRate)
            }

        case .relayState(let relayState):
            if relayState.state == .relaying {
                connectionState = .activeWorkout
            } else {
                refreshConnectionState()
            }

        case .control, .sessionContext:
            break
        }
    }
}

extension WCSManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith _: WCSessionActivationState,
        error _: Error?
    ) {
        Task { @MainActor in
            refreshConnectionState()
            sendSessionContext(activeRideSessionID)
        }
    }

    nonisolated func sessionDidBecomeInactive(_: WCSession) {
        Task { @MainActor in
            connectionState = .disconnected
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        Task { @MainActor in
            refreshConnectionState()
        }
    }

    nonisolated func sessionReachabilityDidChange(_: WCSession) {
        Task { @MainActor in
            refreshConnectionState()
            sendSessionContext(activeRideSessionID)
        }
    }

    nonisolated func session(
        _: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            do {
                receive(try WatchMessage.decode(from: message))
            } catch {
                print("Failed to decode Watch message: \(error)")
            }
        }
    }
}
