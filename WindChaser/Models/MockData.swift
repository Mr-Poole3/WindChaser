import CoreLocation
import Foundation

enum MockData {
    static let sampleRoute: [MapCoordinate] = [
        MapCoordinate(latitude: 39.9042, longitude: 116.4074),
        MapCoordinate(latitude: 39.9055, longitude: 116.4090),
        MapCoordinate(latitude: 39.9070, longitude: 116.4115),
        MapCoordinate(latitude: 39.9088, longitude: 116.4140),
        MapCoordinate(latitude: 39.9105, longitude: 116.4168),
        MapCoordinate(latitude: 39.9120, longitude: 116.4195),
        MapCoordinate(latitude: 39.9135, longitude: 116.4220),
        MapCoordinate(latitude: 39.9150, longitude: 116.4248)
    ]

    static let historyRecords: [RideSummary] = [
        RideSummary(
            id: UUID(uuidString: "A1000001-0000-0000-0000-000000000001")!,
            startedAt: Date().addingTimeInterval(-86_400),
            elapsed: 5_420,
            distanceMeters: 32_500,
            averageSpeedKmh: 21.6,
            maxSpeedKmh: 48.2,
            averageHeartRate: 138,
            averageCadence: nil,
            averagePower: nil,
            maxAltitude: 112,
            maxGrade: 6.8,
            totalAscentMeters: 420,
            calories: 680,
            routeCoordinates: sampleRoute
        ),
        RideSummary(
            id: UUID(uuidString: "A1000001-0000-0000-0000-000000000002")!,
            startedAt: Date().addingTimeInterval(-172_800),
            elapsed: 3_180,
            distanceMeters: 15_200,
            averageSpeedKmh: 17.2,
            maxSpeedKmh: 36.5,
            averageHeartRate: 129,
            averageCadence: nil,
            averagePower: nil,
            maxAltitude: 95,
            maxGrade: 4.2,
            totalAscentMeters: 180,
            calories: 410,
            routeCoordinates: Array(sampleRoute.prefix(5))
        ),
        RideSummary(
            id: UUID(uuidString: "A1000001-0000-0000-0000-000000000003")!,
            startedAt: Date().addingTimeInterval(-604_800),
            elapsed: 7_890,
            distanceMeters: 58_300,
            averageSpeedKmh: 26.6,
            maxSpeedKmh: 52.1,
            averageHeartRate: 145,
            averageCadence: nil,
            averagePower: nil,
            maxAltitude: 156,
            maxGrade: 8.1,
            totalAscentMeters: 890,
            calories: 1_120,
            routeCoordinates: sampleRoute
        )
    ]
}
