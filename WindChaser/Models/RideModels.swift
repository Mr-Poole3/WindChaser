import CoreLocation
import Foundation

enum AppTab: Hashable {
    case ride
    case history
    case settings
}

enum RideRoute: Hashable {
    case activeRide
    case report(UUID)
}

enum RideState: Equatable, Sendable, Codable {
    case idle
    case riding
    case paused
    case ended
}

enum SheetExpansion: Equatable {
    case collapsed
    case expanded
}

enum ReportMapExpansion: Equatable {
    case compact
    case expanded
}

enum GPSStatus: String {
    case searching = "定位中"
    case ready = "GPS 就绪"
    case weak = "信号较弱"
    case unavailable = "GPS 不可用"
}

enum SensorConnectionStatus: String {
    case connected = "已连接"
    case unavailable = "未连接"
}

enum DashboardMetric: String, CaseIterable, Identifiable {
    case speed = "速度"
    case distance = "里程"
    case duration = "用时"
    case heartRate = "心率"
    case cadence = "踏频"
    case power = "功率"
    case altitude = "海拔"
    case grade = "坡度"

    var id: String { rawValue }
}

struct LiveMetrics: Equatable {
    var elapsed: TimeInterval = 0
    var distanceMeters: Double = 0
    var speedKmh: Double?
    var speedValid: Bool = true
    var heartRate: Int?
    var cadence: Int?
    var power: Int?
    var altitude: Double?
    var grade: Double?

    static let preview = LiveMetrics(
        elapsed: 3_725,
        distanceMeters: 18_420,
        speedKmh: 24.3,
        heartRate: 142,
        cadence: nil,
        power: nil,
        altitude: 86,
        grade: 2.4
    )
}

struct RideSummary: Identifiable, Hashable {
    let id: UUID
    let startedAt: Date
    let elapsed: TimeInterval
    let distanceMeters: Double
    let averageSpeedKmh: Double
    let maxSpeedKmh: Double
    let averageHeartRate: Int?
    let averageCadence: Int?
    let averagePower: Int?
    let maxAltitude: Double
    let maxGrade: Double
    let totalAscentMeters: Double
    let calories: Int
    let routeCoordinates: [MapCoordinate]

    var averageSpeedDisplay: Double { averageSpeedKmh }
}

struct MapCoordinate: Hashable {
    let latitude: Double
    let longitude: Double

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
