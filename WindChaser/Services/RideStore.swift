import Foundation
import CoreLocation

public enum RideStoreError: Error {
    case invalidTransition(from: RideStoreState, to: RideStoreState)
    case noActiveSession
    case databaseError(String)
}

public enum RideStoreState: Sendable, Codable {
    case idle
    case riding
    case paused
    case ended
}

extension RideStoreState: Equatable {
    nonisolated public static func == (lhs: RideStoreState, rhs: RideStoreState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.riding, .riding), (.paused, .paused), (.ended, .ended):
            return true
        default:
            return false
        }
    }
}

/// A background central coordination Actor executing thread-safe State Machine transitions,
/// high-frequency database persistence, self-healing startup recovery, and auto-pause timeouts (3,600s).
public actor RideStore {
    public static let shared = RideStore()

    // State machine trackers
    private var state: RideStoreState = .idle
    private var currentRideID: UUID?
    private var activeDatabase: RideDatabase?
    private var rideStartTime: Date?
    private var accumulatedElapsed: TimeInterval = 0
    private var currentPauseStart: Date?

    // 1-hour automatic pause completion timer
    private var pauseTimeoutTask: Task<Void, Never>?

    // Target folder URL: Documents/rides/
    private let ridesDirectoryURL: URL

    private init() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.ridesDirectoryURL = documentsURL.appendingPathComponent("rides", isDirectory: true)

        // Ensure directories are correctly pre-allocated
        if !fileManager.fileExists(atPath: ridesDirectoryURL.path) {
            try? fileManager.createDirectory(at: ridesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
    }

    public func getCurrentState() -> RideStoreState {
        return state
    }

    public func getActiveRideID() -> UUID? {
        return currentRideID
    }

    /// Retrieve the standard rides archive directory.
    public func getRidesDirectoryURL() -> URL {
        return ridesDirectoryURL
    }

    // MARK: - State Machine Engine

    /// Start a new workout ride.
    public func startRide() throws -> UUID {
        guard state == .idle || state == .ended else {
            throw RideStoreError.invalidTransition(from: state, to: .riding)
        }

        let rideID = UUID()
        let fileURL = ridesDirectoryURL.appendingPathComponent("\(rideID.uuidString).ridesqlite")

        do {
            let database = try RideDatabase(fileURL: fileURL)
            self.activeDatabase = database
            self.currentRideID = rideID
            self.state = .riding
            self.rideStartTime = Date()
            self.accumulatedElapsed = 0
            self.currentPauseStart = nil
            return rideID
        } catch {
            throw RideStoreError.databaseError("Failed to start database: \(error.localizedDescription)")
        }
    }

    /// Pause the active workout. Starts the 1-hour automatic termination timeout.
    public func pauseRide() throws {
        guard state == .riding else {
            throw RideStoreError.invalidTransition(from: state, to: .paused)
        }

        state = .paused
        currentPauseStart = Date()

        // Schedule a 3,600-second pause expiration
        schedulePauseAutoEnd()
    }

    /// Resume the current paused workout, canceling any active auto-termination limits.
    public func resumeRide() throws {
        guard state == .paused else {
            throw RideStoreError.invalidTransition(from: state, to: .riding)
        }

        cancelPauseAutoEnd()

        if let currentPauseStart {
            accumulatedElapsed += Date().timeIntervalSince(currentPauseStart)
        }
        self.currentPauseStart = nil
        state = .riding
    }

    /// Complete current workout, finalise schemas, write metadata tables, and close database handles.
    public func endRide() throws -> RideSummary {
        guard state == .riding || state == .paused else {
            throw RideStoreError.invalidTransition(from: state, to: .ended)
        }

        cancelPauseAutoEnd()

        guard let database = activeDatabase, let rideID = currentRideID, let startTime = rideStartTime else {
            throw RideStoreError.noActiveSession
        }

        // Account for final pause durations if concluded while paused
        var finalElapsed = Date().timeIntervalSince(startTime) - accumulatedElapsed
        if state == .paused, let currentPauseStart {
            finalElapsed -= Date().timeIntervalSince(currentPauseStart)
        }
        finalElapsed = max(0, finalElapsed)

        // Compile aggregated statistics directly from samples
        let samples = database.readAllSamples()
        let summary = buildSummary(id: rideID, startedAt: startTime, elapsed: finalElapsed, samples: samples)

        do {
            try database.writeSummary(summary, finalized: true)
            database.close()

            // Reset state parameters
            self.activeDatabase = nil
            self.currentRideID = nil
            self.rideStartTime = nil
            self.accumulatedElapsed = 0
            self.currentPauseStart = nil
            self.state = .ended

            return summary
        } catch {
            database.close()
            throw RideStoreError.databaseError("Failed to finalize summary: \(error.localizedDescription)")
        }
    }

    /// Write 1Hz telemetry snapshots directly as compiled records in SQL.
    public func saveSample(_ snapshot: BikeDataSnapshot) throws {
        guard state == .riding else { return } // Suppress samples writing while paused
        guard let database = activeDatabase else {
            throw RideStoreError.noActiveSession
        }

        try database.insertSample(snapshot)
    }

    // MARK: - Auto Pause Expiry Logic

    private func schedulePauseAutoEnd() {
        cancelPauseAutoEnd()
        pauseTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_600_000_000_000) // 1 Hour (3,600s)
            guard !Task.isCancelled else { return }
            _ = try? await self?.endRide()
        }
    }

    private func cancelPauseAutoEnd() {
        pauseTimeoutTask?.cancel()
        pauseTimeoutTask = nil
    }

    // MARK: - Handlers/Exporters Helpers

    public func readAllSummaries() -> [RideSummary] {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: ridesDirectoryURL, includingPropertiesForKeys: nil) else {
            return []
        }

        var list: [RideSummary] = []
        for file in files where file.pathExtension == "ridesqlite" {
            if let db = try? RideDatabase(fileURL: file) {
                if let summary = db.readSummary() {
                    list.append(summary)
                }
                db.close()
            }
        }

        return list.sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: - Self-Healing Startup Recovery

    /// Locates and heals unfinalized workout database directories left behind.
    public func verifyOnStartupRecovery() -> [RideSummary] {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: ridesDirectoryURL, includingPropertiesForKeys: nil) else {
            return []
        }

        var recoveredSummaries: [RideSummary] = []

        for file in files where file.pathExtension == "ridesqlite" {
            do {
                let database = try RideDatabase(fileURL: file)
                let isFinal = database.isFinalized()

                if !isFinal {
                    // Start healing process
                    let samples = database.readAllSamples()
                    if !samples.isEmpty {
                        // Reassemble file-level UUID if possible
                        let originalId = UUID(uuidString: file.deletingPathExtension().lastPathComponent) ?? UUID()
                        let start = samples.first?.timestamp ?? Date()
                        let end = samples.last?.timestamp ?? Date()
                        let elapsed = max(1.0, end.timeIntervalSince(start))

                        let summary = buildSummary(id: originalId, startedAt: start, elapsed: elapsed, samples: samples)

                        // Overwrite and finalize summary
                        try database.writeSummary(summary, finalized: true)
                        recoveredSummaries.append(summary)
                    } else {
                        // Clean empty corrupted workspace files to free memory space
                        database.close()
                        try? fileManager.removeItem(at: file)
                        continue
                    }
                }
                database.close()
            } catch {
                // If opening failed completely, item is unrecoverable, ignore or purge
                continue
            }
        }

        return recoveredSummaries
    }

    // MARK: - Internal Compilations

    private func buildSummary(id: UUID, startedAt: Date, elapsed: TimeInterval, samples: [BikeDataSnapshot]) -> RideSummary {
        guard !samples.isEmpty else {
            return RideSummary(
                id: id, startedAt: startedAt, elapsed: elapsed,
                distanceMeters: 0, averageSpeedKmh: 0, maxSpeedKmh: 0,
                averageHeartRate: nil, averageCadence: nil, averagePower: nil,
                maxAltitude: 0, maxGrade: 0, totalAscentMeters: 0, calories: 0,
                routeCoordinates: []
            )
        }

        var totalDistance: Double = 0
        var maxSpeed: Double = 0
        var maxAltitude: Double = -9999.0
        var maxGrade: Double = 0
        var totalAscent: Double = 0

        var hrSum = 0
        var hrCount = 0
        var cadSum = 0
        var cadCount = 0
        var pwrSum = 0
        var pwrCount = 0

        var previousLocation: CLLocation?
        var previousAltitude: Double?

        var routeCoords: [MapCoordinate] = []

        for sample in samples {
            // Coordinate tracking
            let coord = MapCoordinate(latitude: sample.latitude, longitude: sample.longitude)
            routeCoords.append(coord)

            // Speed
            let speedKmh = sample.speed * 3.6
            if speedKmh > maxSpeed {
                maxSpeed = speedKmh
            }

            // Great Circle Distance
            let currentLocation = CLLocation(latitude: sample.latitude, longitude: sample.longitude)
            if let prev = previousLocation {
                totalDistance += currentLocation.distance(from: prev)
            }
            previousLocation = currentLocation

            // Altitude & Ascent
            if let currentAlt = sample.altitude {
                if currentAlt > maxAltitude {
                    maxAltitude = currentAlt
                }
                if let prevAlt = previousAltitude {
                    let diff = currentAlt - prevAlt
                    if diff > 0 {
                        totalAscent += diff
                    }
                }
                previousAltitude = currentAlt
            }

            // Grade
            if let grade = sample.grade {
                if abs(grade) > abs(maxGrade) {
                    maxGrade = grade
                }
            }

            // Biometrics Averaging
            if let hr = sample.heartRate {
                hrSum += hr
                hrCount += 1
            }
            if let cad = sample.cadence {
                cadSum += cad
                cadCount += 1
            }
            if let pwr = sample.power {
                pwrSum += pwr
                pwrCount += 1
            }
        }

        let computedAvgSpeed = elapsed > 0 ? (totalDistance / 1000.0) / (elapsed / 3600.0) : 0

        return RideSummary(
            id: id,
            startedAt: startedAt,
            elapsed: elapsed,
            distanceMeters: totalDistance,
            averageSpeedKmh: computedAvgSpeed,
            maxSpeedKmh: maxSpeed,
            averageHeartRate: hrCount > 0 ? hrSum / hrCount : nil,
            averageCadence: cadCount > 0 ? cadSum / cadCount : nil,
            averagePower: pwrCount > 0 ? pwrSum / pwrCount : nil,
            maxAltitude: maxAltitude == -9999.0 ? 0.0 : maxAltitude,
            maxGrade: maxGrade,
            totalAscentMeters: totalAscent,
            calories: Int(totalDistance * 0.04), // Consistent with standard formulas
            routeCoordinates: routeCoords
        )
    }
}
