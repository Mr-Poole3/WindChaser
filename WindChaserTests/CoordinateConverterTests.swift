import XCTest
@testable import WindChaser

final class CoordinateConverterTests: XCTestCase {
    func testOutsideChinaReturnsOriginalCoordinate() {
        let converted = CoordinateConverter.wgs84ToGcj02(latitude: 37.7749, longitude: -122.4194)
        XCTAssertEqual(converted.latitude, 37.7749, accuracy: 0.000001)
        XCTAssertEqual(converted.longitude, -122.4194, accuracy: 0.000001)
    }

    func testInsideChinaAppliesOffset() {
        let converted = CoordinateConverter.wgs84ToGcj02(latitude: 39.9042, longitude: 116.4074)
        XCTAssertNotEqual(converted.latitude, 39.9042, accuracy: 0.000001)
        XCTAssertNotEqual(converted.longitude, 116.4074, accuracy: 0.000001)
        XCTAssertTrue(CoordinateConverter.isInChina(latitude: converted.latitude, longitude: converted.longitude))
    }
}
