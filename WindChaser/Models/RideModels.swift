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

public enum GPSStatus: String, Sendable {
    case searching = "定位中"
    case ready = "GPS 就绪"
    case weak = "信号较弱"
    case unavailable = "GPS 不可用"
}

enum SensorConnectionStatus: String {
    case connected = "已连接"
    case unavailable = "未连接"
}

/// 骑行主界面展开仪表盘展示的指标。
///
/// Phase 2 后仅展示 6 项（2×3 布局）：速度、里程、用时、心率、海拔、坡度。
/// 踏频 / 功率字段从 UI 中移除，但 `BikeDataSnapshot` / `LiveMetrics` / `RideSummary`
/// 中相应字段保留，等接入后续数据源时按需启用。
enum DashboardMetric: String, CaseIterable, Identifiable {
    case speed = "速度"
    case distance = "里程"
    case duration = "用时"
    case heartRate = "心率"
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
    var courseDegrees: Double?

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

public struct RideSummary: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let elapsed: TimeInterval
    public let distanceMeters: Double
    public let averageSpeedKmh: Double
    public let maxSpeedKmh: Double
    public let averageHeartRate: Int?
    public let averageCadence: Int?
    public let averagePower: Int?
    public let maxAltitude: Double
    public let maxGrade: Double
    public let totalAscentMeters: Double
    public let calories: Int
    public let routeCoordinates: [MapCoordinate]

    public var averageSpeedDisplay: Double { averageSpeedKmh }

    nonisolated public init(
        id: UUID,
        startedAt: Date,
        elapsed: TimeInterval,
        distanceMeters: Double,
        averageSpeedKmh: Double,
        maxSpeedKmh: Double,
        averageHeartRate: Int?,
        averageCadence: Int?,
        averagePower: Int?,
        maxAltitude: Double,
        maxGrade: Double,
        totalAscentMeters: Double,
        calories: Int,
        routeCoordinates: [MapCoordinate]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.elapsed = elapsed
        self.distanceMeters = distanceMeters
        self.averageSpeedKmh = averageSpeedKmh
        self.maxSpeedKmh = maxSpeedKmh
        self.averageHeartRate = averageHeartRate
        self.averageCadence = averageCadence
        self.averagePower = averagePower
        self.maxAltitude = maxAltitude
        self.maxGrade = maxGrade
        self.totalAscentMeters = totalAscentMeters
        self.calories = calories
        self.routeCoordinates = routeCoordinates
    }
}

public struct MapCoordinate: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    nonisolated public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Raw WGS-84 coordinate from GPS hardware.
    public var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Coordinate adjusted for MapKit display (GCJ-02 in mainland China).
    public var mapDisplayCoordinate: CLLocationCoordinate2D {
        CoordinateConverter.wgs84ToGcj02(latitude: latitude, longitude: longitude)
    }
}
