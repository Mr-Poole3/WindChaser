import XCTest
@testable import WindChaser

final class RoutePolylineSimplifierTests: XCTestCase {
    func testReturnsOriginalWhenWithinLimit() {
        let coordinates = [
            MapCoordinate(latitude: 39.90, longitude: 116.40),
            MapCoordinate(latitude: 39.91, longitude: 116.41),
            MapCoordinate(latitude: 39.92, longitude: 116.42)
        ]

        let simplified = RoutePolylineSimplifier.simplify(coordinates, maxPoints: 10)
        XCTAssertEqual(simplified.count, coordinates.count)
        XCTAssertEqual(simplified.first, coordinates.first)
        XCTAssertEqual(simplified.last, coordinates.last)
    }

    func testReducesPointCountWhileKeepingEndpoints() {
        let coordinates = (0..<100).map { index in
            MapCoordinate(latitude: 39.90 + Double(index) * 0.001, longitude: 116.40)
        }

        let simplified = RoutePolylineSimplifier.simplify(coordinates, maxPoints: 12)
        XCTAssertEqual(simplified.count, 12)
        XCTAssertEqual(simplified.first, coordinates.first)
        XCTAssertEqual(simplified.last, coordinates.last)
    }
}
