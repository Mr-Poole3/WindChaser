import XCTest
@testable import WindChaser

final class RideDatabaseExportTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testCSVExportContainsHeaderAndSampleRow() throws {
        let dbURL = tempDirectory.appendingPathComponent("test.ridesqlite")
        let db = try RideDatabase(fileURL: dbURL)

        let snapshot = BikeDataSnapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            latitude: 39.9042,
            longitude: 116.4074,
            altitude: 52.0,
            speed: 6.0,
            heartRate: 142,
            cadence: 88,
            power: 180,
            grade: 2.4
        )

        try db.insertSample(snapshot)
        let csvURL = try XCTUnwrap(db.csvExportURL())
        let csv = try String(contentsOf: csvURL, encoding: .utf8)

        XCTAssertTrue(csv.hasPrefix("Timestamp,Latitude,Longitude,Speed(kmh),HeartRate(bpm),Cadence(rpm),Power(W),Altitude(m),Grade(%)"))
        XCTAssertTrue(csv.contains("39.9042"))
        XCTAssertTrue(csv.contains("116.4074"))
        XCTAssertTrue(csv.contains("21.60"))
        db.close()
    }

    func testGPXExportContainsTrackPoint() throws {
        let dbURL = tempDirectory.appendingPathComponent("test.ridesqlite")
        let db = try RideDatabase(fileURL: dbURL)

        let snapshot = BikeDataSnapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            latitude: 39.9042,
            longitude: 116.4074,
            altitude: 52.0,
            speed: 6.0,
            heartRate: 142,
            cadence: nil,
            power: nil,
            grade: nil
        )

        try db.insertSample(snapshot)
        let gpxURL = try XCTUnwrap(db.gpxExportURL())
        let gpx = try String(contentsOf: gpxURL, encoding: .utf8)

        XCTAssertTrue(gpx.contains("<gpx version=\"1.1\" creator=\"WindChaser Pro\""))
        XCTAssertTrue(gpx.contains("<trkpt lat=\"39.904200\" lon=\"116.407400\">"))
        XCTAssertTrue(gpx.contains("<gpxtpx:hr>142</gpxtpx:hr>"))
        db.close()
    }
}
