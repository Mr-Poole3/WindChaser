import Foundation

struct BikeDataSnapshot: Sendable, Codable, Equatable {
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let speed: Double // raw speed in m/s
    let heartRate: Int?
    let cadence: Int?
    let power: Int?
    let grade: Double?
}
