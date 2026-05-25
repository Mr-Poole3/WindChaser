import Foundation
import WatchConnectivity

/// 暴露 WatchConnectivity 的原始信号（激活完成、是否可达），
/// 不再持有派生 UI 状态或心率 —— UI 自己根据这两路信号 + HealthKit 状态推导显示。
@MainActor
@Observable
final class WatchConnectivityStatus: NSObject {
    private(set) var isReachable: Bool = false
    private(set) var isActivated: Bool = false

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
}
