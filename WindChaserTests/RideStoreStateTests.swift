import XCTest
@testable import WindChaser

final class RideStoreStateTests: XCTestCase {
    func testStateEquality() {
        XCTAssertEqual(RideStoreState.riding, RideStoreState.riding)
        XCTAssertNotEqual(RideStoreState.riding, RideStoreState.paused)
    }
}
