import Foundation
import WatchConnectivity

/// 暴露 WatchConnectivity 的原始信号（激活完成、是否可达），
/// 不再持有派生 UI 状态或心率 —— UI 自己根据这两路信号 + HealthKit 状态推导显示。
@MainActor
@Observable
final class WatchConnectivityStatus: NSObject {
    private(set) var isReachable: Bool = false
    private(set) var isActivated: Bool = false
    private(set) var activeSessionID: UUID?

    private let session: WCSession?

    override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
    }

    func start() {
        guard let session else {
            isReachable = false
            isActivated = false
            return
        }
        session.delegate = self
        session.activate()
        refreshFromSession()
    }

    private func refreshFromSession() {
        guard let session else {
            isReachable = false
            isActivated = false
            return
        }
        isActivated = session.activationState == .activated
        isReachable = session.isReachable
    }

    func sendHeartRate(_ bpm: Int, watchTimestamp: Date = .now) {
        guard let activeSessionID,
              let session,
              session.activationState == .activated,
              session.isReachable else {
            return
        }

        let message = WatchMessage.heartRate(
            HeartRateRelayMessage(
                bpm: bpm,
                watchTimestamp: watchTimestamp,
                sessionID: activeSessionID
            )
        )

        do {
            session.sendMessage(
                try message.dictionaryPayload(),
                replyHandler: nil,
                errorHandler: { error in
                    print("Failed to send heart rate message: \(error)")
                }
            )
        } catch {
            print("Failed to encode heart rate message: \(error)")
        }
    }

    /// 主动把当前 relay 状态推送给 iPhone，用于驱动设备检测页的 4 态显示。
    func sendRelayState(_ state: WatchRelayState, detail: String? = nil) {
        guard let session,
              session.activationState == .activated,
              session.isReachable else {
            return
        }

        let message = WatchMessage.relayState(
            WatchRelayStateMessage(
                state: state,
                detail: detail
            )
        )

        do {
            session.sendMessage(
                try message.dictionaryPayload(),
                replyHandler: nil,
                errorHandler: { error in
                    print("Failed to send relay state message: \(error)")
                }
            )
        } catch {
            print("Failed to encode relay state message: \(error)")
        }
    }

    private func receive(_ message: WatchMessage) {
        switch message {
        case .sessionContext(let context):
            activeSessionID = context.sessionID
        case .control, .heartRate, .relayState:
            break
        }
    }
}

extension WatchConnectivityStatus: WCSessionDelegate {
    nonisolated func session(
        _: WCSession,
        activationDidCompleteWith _: WCSessionActivationState,
        error _: Error?
    ) {
        Task { @MainActor in
            refreshFromSession()
        }
    }

    nonisolated func sessionReachabilityDidChange(_: WCSession) {
        Task { @MainActor in
            refreshFromSession()
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
                print("Failed to decode iPhone message: \(error)")
            }
        }
    }
}
