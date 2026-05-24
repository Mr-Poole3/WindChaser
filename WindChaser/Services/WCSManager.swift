import Foundation

public enum WatchConnectionState: String, Sendable, Codable {
    case disconnected = "未连接"
    case pairing = "配对中"
    case connected = "已连接"
    case activeWorkout = "运动传输中"
}

/// A background central Actor managing Apple Watch CoreSync connectivity (placeholder for watchOS companion app).
public actor WCSManager {
    public static let shared = WCSManager()

    private var connectionState: WatchConnectionState = .disconnected
    private var heartRateSamplesBuffer: [Int] = []

    private init() {}

    public func getConnectionState() -> WatchConnectionState {
        return connectionState
    }

    /// Triggers Watch integration diagnostics.
    public func startWatchSession() async {
        connectionState = .pairing
        try? await Task.sleep(nanoseconds: 1_200_000_000) // Simulate Watch pairing handshake latency
        connectionState = .connected
    }

    /// Terminates Watch synchronization connectivity loops.
    public func stopWatchSession() {
        connectionState = .disconnected
        heartRateSamplesBuffer.removeAll()
    }

    /// Feeds remote biometric indicators straight from standard watchOS complications.
    public func pushSampleHeartRate(_ bpm: Int) {
        guard connectionState == .connected || connectionState == .activeWorkout else { return }
        connectionState = .activeWorkout
        heartRateSamplesBuffer.append(bpm)
    }

    public func popLatestHeartRates() -> [Int] {
        let current = heartRateSamplesBuffer
        heartRateSamplesBuffer.removeAll()
        return current
    }
}
