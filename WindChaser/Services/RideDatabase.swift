import Foundation
import SQLite3
import CoreLocation

enum RideDatabaseError: Error {
    case failedToOpen(String)
    case failedToPrepare(String)
    case failedToExecute(String)
    case databaseNotOpen
}

final class RideDatabase {
    let fileURL: URL
    private var db: OpaquePointer?
    private var insertSampleStmt: OpaquePointer?

    init(fileURL: URL) throws {
        self.fileURL = fileURL
        try openAndInitialize()
    }

    deinit {
        close()
    }

    private func openAndInitialize() throws {
        // Ensure path exists
        let directoryURL = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }

        if sqlite3_open_v2(fileURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) != SQLITE_OK {
            let errorMsg = getErrorMessage()
            throw RideDatabaseError.failedToOpen("Failed to open database at \(fileURL.path): \(errorMsg)")
        }

        // Configure WAL mode and synchronous settings
        try executePragma("PRAGMA journal_mode=WAL;")
        try executePragma("PRAGMA synchronous=NORMAL;")

        // Create samples table
        let createSamplesSQL = """
        CREATE TABLE IF NOT EXISTS samples (
            timestamp REAL PRIMARY KEY,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            altitude REAL,
            speed REAL NOT NULL,
            heartRate INTEGER,
            cadence INTEGER,
            power INTEGER,
            grade REAL
        );
        """
        try executeSQL(createSamplesSQL)

        // Create summary table
        let createSummarySQL = """
        CREATE TABLE IF NOT EXISTS summary (
            id TEXT PRIMARY KEY,
            startedAt REAL NOT NULL,
            elapsed REAL NOT NULL,
            distanceMeters REAL NOT NULL,
            averageSpeedKmh REAL NOT NULL,
            maxSpeedKmh REAL NOT NULL,
            averageHeartRate INTEGER,
            averageCadence INTEGER,
            averagePower INTEGER,
            maxAltitude REAL NOT NULL,
            maxGrade REAL NOT NULL,
            totalAscentMeters REAL NOT NULL,
            calories INTEGER NOT NULL,
            finalized INTEGER NOT NULL DEFAULT 0
        );
        """
        try executeSQL(createSummarySQL)

        // Prepare compilation statements for single-second insertion
        let insertSQL = """
        INSERT INTO samples (timestamp, latitude, longitude, altitude, speed, heartRate, cadence, power, grade)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        if sqlite3_prepare_v2(db, insertSQL, -1, &insertSampleStmt, nil) != SQLITE_OK {
            let errorMsg = getErrorMessage()
            throw RideDatabaseError.failedToPrepare("Failed to prepare sample insertion statement: \(errorMsg)")
        }
    }

    func close() {
        if let insertSampleStmt {
            sqlite3_finalize(insertSampleStmt)
            self.insertSampleStmt = nil
        }
        if let db {
            sqlite3_close_v2(db)
            self.db = nil
        }
    }

    private func executePragma(_ pragma: String) throws {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, pragma, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    private func executeSQL(_ sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw RideDatabaseError.failedToExecute(getErrorMessage())
        }
    }

    private func getErrorMessage() -> String {
        guard let db else { return "Database not open" }
        if let err = sqlite3_errmsg(db) {
            return String(cString: err)
        }
        return "Unknown error"
    }

    // MARK: - API Methods

    func insertSample(_ snapshot: BikeDataSnapshot) throws {
        guard let db, let insertSampleStmt else {
            throw RideDatabaseError.databaseNotOpen
        }

        sqlite3_reset(insertSampleStmt)
        sqlite3_clear_bindings(insertSampleStmt)

        // 1. timestamp REAL
        sqlite3_bind_double(insertSampleStmt, 1, snapshot.timestamp.timeIntervalSince1970)
        // 2. latitude REAL
        sqlite3_bind_double(insertSampleStmt, 2, snapshot.latitude)
        // 3. longitude REAL
        sqlite3_bind_double(insertSampleStmt, 3, snapshot.longitude)

        // 4. altitude REAL (optional)
        if let altitude = snapshot.altitude {
            sqlite3_bind_double(insertSampleStmt, 4, altitude)
        } else {
            sqlite3_bind_null(insertSampleStmt, 4)
        }

        // 5. speed REAL
        sqlite3_bind_double(insertSampleStmt, 5, snapshot.speed)

        // 6. heartRate INTEGER (optional)
        if let hr = snapshot.heartRate {
            sqlite3_bind_int(insertSampleStmt, 6, Int32(hr))
        } else {
            sqlite3_bind_null(insertSampleStmt, 6)
        }

        // 7. cadence INTEGER (optional)
        if let cad = snapshot.cadence {
            sqlite3_bind_int(insertSampleStmt, 7, Int32(cad))
        } else {
            sqlite3_bind_null(insertSampleStmt, 7)
        }

        // 8. power INTEGER (optional)
        if let pwr = snapshot.power {
            sqlite3_bind_int(insertSampleStmt, 8, Int32(pwr))
        } else {
            sqlite3_bind_null(insertSampleStmt, 8)
        }

        // 9. grade REAL (optional)
        if let grade = snapshot.grade {
            sqlite3_bind_double(insertSampleStmt, 9, grade)
        } else {
            sqlite3_bind_null(insertSampleStmt, 9)
        }

        if sqlite3_step(insertSampleStmt) != SQLITE_DONE {
            throw RideDatabaseError.failedToExecute("Failed to insert sample: \(getErrorMessage())")
        }
    }

    func writeSummary(_ summary: RideSummary, finalized: Bool) throws {
        guard let db else {
            throw RideDatabaseError.databaseNotOpen
        }

        let replaceSQL = """
        INSERT OR REPLACE INTO summary (
            id, startedAt, elapsed, distanceMeters, averageSpeedKmh, maxSpeedKmh,
            averageHeartRate, averageCadence, averagePower, maxAltitude, maxGrade,
            totalAscentMeters, calories, finalized
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, replaceSQL, -1, &stmt, nil) == SQLITE_OK else {
            throw RideDatabaseError.failedToPrepare("Failed to prepare summary statement: \(getErrorMessage())")
        }

        defer {
            sqlite3_finalize(stmt)
        }

        sqlite3_bind_text(stmt, 1, (summary.id.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 2, summary.startedAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 3, summary.elapsed)
        sqlite3_bind_double(stmt, 4, summary.distanceMeters)
        sqlite3_bind_double(stmt, 5, summary.averageSpeedKmh)
        sqlite3_bind_double(stmt, 6, summary.maxSpeedKmh)

        if let avgHr = summary.averageHeartRate {
            sqlite3_bind_int(stmt, 7, Int32(avgHr))
        } else {
            sqlite3_bind_null(stmt, 7)
        }

        if let avgCad = summary.averageCadence {
            sqlite3_bind_int(stmt, 8, Int32(avgCad))
        } else {
            sqlite3_bind_null(stmt, 8)
        }

        if let avgPwr = summary.averagePower {
            sqlite3_bind_int(stmt, 9, Int32(avgPwr))
        } else {
            sqlite3_bind_null(stmt, 9)
        }

        sqlite3_bind_double(stmt, 10, summary.maxAltitude)
        sqlite3_bind_double(stmt, 11, summary.maxGrade)
        sqlite3_bind_double(stmt, 12, summary.totalAscentMeters)
        sqlite3_bind_int(stmt, 13, Int32(summary.calories))
        sqlite3_bind_int(stmt, 14, finalized ? 1 : 0)

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw RideDatabaseError.failedToExecute("Failed to execute summary write: \(getErrorMessage())")
        }
    }

    func isFinalized() -> Bool {
        guard let db else { return false }
        let sql = "SELECT finalized FROM summary LIMIT 1;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_int(stmt, 0) == 1
        }
        return false
    }

    func readSummary() -> RideSummary? {
        guard let db else { return nil }
        let sql = """
        SELECT id, startedAt, elapsed, distanceMeters, averageSpeedKmh, maxSpeedKmh,
               averageHeartRate, averageCadence, averagePower, maxAltitude, maxGrade,
               totalAscentMeters, calories
        FROM summary LIMIT 1;
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }

        if sqlite3_step(stmt) == SQLITE_ROW {
            guard let idStringC = sqlite3_column_text(stmt, 0),
                  let id = UUID(uuidString: String(cString: idStringC)) else {
                return nil
            }

            let startedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
            let elapsed = sqlite3_column_double(stmt, 2)
            let distanceMeters = sqlite3_column_double(stmt, 3)
            let averageSpeedKmh = sqlite3_column_double(stmt, 4)
            let maxSpeedKmh = sqlite3_column_double(stmt, 5)

            let averageHeartRate = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 6))
            let averageCadence = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 7))
            let averagePower = sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 8))

            let maxAltitude = sqlite3_column_double(stmt, 9)
            let maxGrade = sqlite3_column_double(stmt, 10)
            let totalAscentMeters = sqlite3_column_double(stmt, 11)
            let calories = Int(sqlite3_column_int(stmt, 12))

            let routeCoordinates = readSamplesAsCoordinates()

            return RideSummary(
                id: id,
                startedAt: startedAt,
                elapsed: elapsed,
                distanceMeters: distanceMeters,
                averageSpeedKmh: averageSpeedKmh,
                maxSpeedKmh: maxSpeedKmh,
                averageHeartRate: averageHeartRate,
                averageCadence: averageCadence,
                averagePower: averagePower,
                maxAltitude: maxAltitude,
                maxGrade: maxGrade,
                totalAscentMeters: totalAscentMeters,
                calories: calories,
                routeCoordinates: routeCoordinates
            )
        }

        return nil
    }

    func readSamplesAsCoordinates() -> [MapCoordinate] {
        guard let db else { return [] }
        let sql = "SELECT latitude, longitude FROM samples ORDER BY timestamp ASC;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        var list: [MapCoordinate] = []
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let lat = sqlite3_column_double(stmt, 0)
            let lon = sqlite3_column_double(stmt, 1)
            list.append(MapCoordinate(latitude: lat, longitude: lon))
        }

        return list
    }

    func readAllSamples() -> [BikeDataSnapshot] {
        guard let db else { return [] }
        let sql = "SELECT timestamp, latitude, longitude, altitude, speed, heartRate, cadence, power, grade FROM samples ORDER BY timestamp ASC;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        var list: [BikeDataSnapshot] = []
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0))
            let latitude = sqlite3_column_double(stmt, 1)
            let longitude = sqlite3_column_double(stmt, 2)
            let altitude = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 3)
            let speed = sqlite3_column_double(stmt, 4)
            let hr = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 5))
            let cad = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 6))
            let pwr = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 7))
            let grade = sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 8)

            list.append(BikeDataSnapshot(
                timestamp: timestamp,
                latitude: latitude,
                longitude: longitude,
                altitude: altitude,
                speed: speed,
                heartRate: hr,
                cadence: cad,
                power: pwr,
                grade: grade
            ))
        }

        return list
    }

    // MARK: - Export Formats

    func csvExportURL() -> URL? {
        let samples = readAllSamples()
        guard !samples.isEmpty else { return nil }

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let filename = "ride_\(fileURL.deletingPathExtension().lastPathComponent).csv"
        let outputURL = tempDir.appendingPathComponent(filename)

        var csvString = "Timestamp,Latitude,Longitude,Speed(kmh),HeartRate(bpm),Cadence(rpm),Power(W),Altitude(m),Grade(%)\n"
        let dateFormatter = ISO8601DateFormatter()

        for sample in samples {
            let timeStr = dateFormatter.string(from: sample.timestamp)
            let speedKmh = sample.speed * 3.6
            let hrStr = sample.heartRate != nil ? "\(sample.heartRate!)" : ""
            let cadStr = sample.cadence != nil ? "\(sample.cadence!)" : ""
            let pwrStr = sample.power != nil ? "\(sample.power!)" : ""
            let altStr = sample.altitude != nil ? String(format: "%.1f", sample.altitude!) : ""
            let gradeStr = sample.grade != nil ? String(format: "%.1f", sample.grade!) : ""

            let row = "\(timeStr),\(sample.latitude),\(sample.longitude),\(String(format: "%.2f", speedKmh)),\(hrStr),\(cadStr),\(pwrStr),\(altStr),\(gradeStr)\n"
            csvString.append(row)
        }

        do {
            try csvString.write(to: outputURL, atomically: true, encoding: .utf8)
            return outputURL
        } catch {
            return nil
        }
    }

    func gpxExportURL() -> URL? {
        let samples = readAllSamples()
        let summary = readSummary()
        guard !samples.isEmpty else { return nil }

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let filename = "track_\(fileURL.deletingPathExtension().lastPathComponent).gpx"
        let outputURL = tempDir.appendingPathComponent(filename)

        let idStr = summary?.id.uuidString ?? UUID().uuidString
        let dateStr = summary != nil ? ISO8601DateFormatter().string(from: summary!.startedAt) : ISO8601DateFormatter().string(from: samples[0].timestamp)

        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="WindChaser Pro" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <time>\(dateStr)</time>
          </metadata>
          <trk>
            <name>WindChaser Ride \(idStr)</name>
            <trkseg>
        """

        let dateFormatter = ISO8601DateFormatter()

        for sample in samples {
            let latStr = String(format: "%.6f", sample.latitude)
            let lonStr = String(format: "%.6f", sample.longitude)
            let sTime = dateFormatter.string(from: sample.timestamp)

            gpx.append("\n      <trkpt lat=\"\(latStr)\" lon=\"\(lonStr)\">")
            if let alt = sample.altitude {
                gpx.append("\n        <ele>\(String(format: "%.1f", alt))</ele>")
            }
            gpx.append("\n        <time>\(sTime)</time>")

            // Add extensions for heartrate, cadence, power if available (standard Garmin TPX style)
            if sample.heartRate != nil || sample.cadence != nil || sample.power != nil {
                gpx.append("\n        <extensions>")
                gpx.append("\n          <gpxtpx:TrackPointExtension xmlns:gpxtpx=\"http://www.garmin.com/xmlschemas/TrackPointExtension/v1\">")
                if let hr = sample.heartRate {
                    gpx.append("\n            <gpxtpx:hr>\(hr)</gpxtpx:hr>")
                }
                if let cad = sample.cadence {
                    gpx.append("\n            <gpxtpx:cad>\(cad)</gpxtpx:cad>")
                }
                gpx.append("\n          </gpxtpx:TrackPointExtension>")
                if let pwr = sample.power {
                    gpx.append("\n          <power>\(pwr)</power>")
                }
                gpx.append("\n        </extensions>")
            }
            gpx.append("\n      </trkpt>")
        }

        gpx.append("""

            </trkseg>
          </trk>
        </gpx>
        """)

        do {
            try gpx.write(to: outputURL, atomically: true, encoding: .utf8)
            return outputURL
        } catch {
            return nil
        }
    }
}
