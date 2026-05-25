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
/// S4 接收 Watch 推送的实时心率并提供给 `RideSession`；
/// S6 在此基础上暴露细粒度信号（配对/可达/Watch 上报的 relay state/最近心率时间戳），
/// 供设备检测页合成 4 态（未连接 / 需授权 / 已就绪 / 已连接）。
@MainActor
@Observable
final class WCSManager: NSObject {
    @MainActor static let shared = WCSManager()

    /// 粗粒度状态枚举，保留供 UI/日志使用。
    private(set) var connectionState: WatchConnectionState = .disconnected

    // MARK: - S6 fine-grained signals

    /// WCSession 是否已激活。
    private(set) var isActivated: Bool = false

    /// iPhone 是否已配对 Watch。
    private(set) var isPaired: Bool = false

    /// 配对 Watch 是否已安装 Watch App。
    private(set) var isWatchAppInstalled: Bool = false

    /// 当前 WCS 链路是否可达（Watch App 是否在前台/可被唤醒）。
    private(set) var isReachable: Bool = false

    /// Watch 端最近一次上报的 relay 状态。
    private(set) var lastReportedRelayState: WatchRelayState?

    /// iPhone 最近一次收到心率的时间戳，用于判定『已连接』。
    private(set) var lastHeartRateAt: Date?

    @ObservationIgnored private let session: WCSession?
    @ObservationIgnored private var activeRideSessionID: UUID?
    @ObservationIgnored private var heartRateContinuations: [UUID: AsyncStream<HeartRateRelayMessage>.Continuation] = [:]

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
        guard let session else {
            isActivated = false
            isPaired = false
            isWatchAppInstalled = false
            isReachable = false
            connectionState = .disconnected
            return
        }

        isActivated = session.activationState == .activated
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable

        guard isActivated else {
            connectionState = .pairing
            return
        }

        if !isPaired || !isWatchAppInstalled {
            connectionState = .disconnected
        } else if isReachable {
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
            lastHeartRateAt = Date()
            connectionState = .activeWorkout
            for continuation in heartRateContinuations.values {
                continuation.yield(heartRate)
            }

        case .relayState(let relayState):
            lastReportedRelayState = relayState.state
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
            isReachable = false
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
