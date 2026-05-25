import XCTest
@testable import WindChaser

@MainActor
final class WatchMessagesTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func testControlMessageRoundTrip() throws {
        let sessionID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let startedAt = Date(timeIntervalSince1970: 1_770_000_000)
        let message = WatchMessage.control(.start(sessionID: sessionID, startedAt: startedAt))

        let decoded = try roundTrip(message)

        XCTAssertEqual(decoded, message)
    }

    func testHeartRateMessageRoundTrip() throws {
        let message = WatchMessage.heartRate(
            HeartRateRelayMessage(
                bpm: 142,
                watchTimestamp: Date(timeIntervalSince1970: 1_770_000_042),
                sessionID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
            )
        )

        let decoded = try roundTrip(message)

        XCTAssertEqual(decoded, message)
    }

    func testRelayStateMessageRoundTrip() throws {
        let message = WatchMessage.relayState(
            WatchRelayStateMessage(
                state: .needsAuthorization,
                generatedAt: Date(timeIntervalSince1970: 1_770_000_100),
                detail: "HealthKit authorization is required"
            )
        )

        let decoded = try roundTrip(message)

        XCTAssertEqual(decoded, message)
    }

    func testSessionContextMessageRoundTrip() throws {
        let message = WatchMessage.sessionContext(
            WatchSessionContextMessage(
                sessionID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                generatedAt: Date(timeIntervalSince1970: 1_770_000_200)
            )
        )

        let decoded = try roundTrip(message)

        XCTAssertEqual(decoded, message)
    }

    func testDictionaryPayloadRoundTrip() throws {
        let message = WatchMessage.heartRate(
            HeartRateRelayMessage(
                bpm: 138,
                watchTimestamp: Date(timeIntervalSince1970: 1_770_000_300),
                sessionID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
            )
        )

        let payload = try message.dictionaryPayload()
        let decoded = try WatchMessage.decode(from: payload)

        XCTAssertEqual(decoded, message)
    }

    private func roundTrip(_ message: WatchMessage) throws -> WatchMessage {
        let data = try encoder.encode(message)
        return try decoder.decode(WatchMessage.self, from: data)
    }
}
