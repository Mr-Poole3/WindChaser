import Foundation

public struct BikeDataSnapshot: Sendable, Codable, Equatable {
    public let timestamp: Date
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double?
    public let speed: Double // raw speed in m/s
    public let heartRate: Int?
    public let cadence: Int?
    public let power: Int?
    public let grade: Double?
    public let course: Double?

    nonisolated public init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        altitude: Double?,
        speed: Double,
        heartRate: Int?,
        cadence: Int?,
        power: Int?,
        grade: Double?,
        course: Double? = nil
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.speed = speed
        self.heartRate = heartRate
        self.cadence = cadence
        self.power = power
        self.grade = grade
        self.course = course
    }
}
