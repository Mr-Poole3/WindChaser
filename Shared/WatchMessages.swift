import Foundation

/// Cross-target message envelope for WatchConnectivity payloads.
///
/// The concrete payloads stay small and Codable so they can be encoded into a
/// `Data` blob or bridged into a `[String: Any]` dictionary by the WCS layer.
enum WatchMessage: Codable, Equatable, Sendable {
    case control(RideControlCommand)
    case heartRate(HeartRateRelayMessage)
    case relayState(WatchRelayStateMessage)
}

enum RideControlCommand: Codable, Equatable, Sendable {
    case start(sessionID: UUID, startedAt: Date)
    case pause(sessionID: UUID)
    case resume(sessionID: UUID)
    case end(sessionID: UUID)
}

struct HeartRateRelayMessage: Codable, Equatable, Sendable {
    let bpm: Int
    let watchTimestamp: Date
    let sessionID: UUID

    init(bpm: Int, watchTimestamp: Date, sessionID: UUID) {
        self.bpm = bpm
        self.watchTimestamp = watchTimestamp
        self.sessionID = sessionID
    }
}

struct WatchRelayStateMessage: Codable, Equatable, Sendable {
    let state: WatchRelayState
    let generatedAt: Date
    let detail: String?

    init(state: WatchRelayState, generatedAt: Date = .now, detail: String? = nil) {
        self.state = state
        self.generatedAt = generatedAt
        self.detail = detail
    }
}

enum WatchRelayState: String, Codable, CaseIterable, Equatable, Sendable {
    case disconnected
    case waitingForPhone
    case needsAuthorization
    case relaying
}

enum SensorFreshness: String, Codable, Equatable, Sendable {
    case unavailable
    case fresh
    case stale
    case expired
}

