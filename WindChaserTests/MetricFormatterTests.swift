import XCTest
@testable import WindChaser

final class MetricFormatterTests: XCTestCase {
    func testDurationUnderOneHour() {
        XCTAssertEqual(MetricFormatter.duration(125), "02:05")
    }

    func testDurationOverOneHour() {
        XCTAssertEqual(MetricFormatter.duration(3_725), "1:02:05")
    }

    func testDistanceAbbreviation() {
        XCTAssertEqual(MetricFormatter.distance(kilometers: 18.4), "18.4")
        XCTAssertEqual(MetricFormatter.distance(kilometers: 102.6), "103")
    }

    func testSpeedThresholds() {
        XCTAssertEqual(MetricFormatter.speed(kmh: 24.3), "24.3")
        XCTAssertEqual(MetricFormatter.speed(kmh: 1.2), "<1.5")
        XCTAssertEqual(MetricFormatter.speed(kmh: nil, isValid: false), "--")
    }

    func testSpeedUnit() {
        XCTAssertEqual(MetricFormatter.speedUnit(kmh: 24.3), "km/h")
        XCTAssertEqual(MetricFormatter.speedUnit(kmh: 1.2), "km/h")
        XCTAssertEqual(MetricFormatter.speedUnit(kmh: nil, isValid: false), "")
    }
}
