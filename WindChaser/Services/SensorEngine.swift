import Foundation
import CoreLocation

private extension CLLocation {
    func bearing(to destination: CLLocation) -> Double {
        let lat1 = coordinate.latitude * .pi / 180
        let lat2 = destination.coordinate.latitude * .pi / 180
        let deltaLon = (destination.coordinate.longitude - coordinate.longitude) * .pi / 180

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let radians = atan2(y, x)
        let degrees = radians * 180 / .pi
        return degrees >= 0 ? degrees : degrees + 360
    }
}

private func resolvedCourse(from location: CLLocation, previous: CLLocation?) -> Double? {
    if location.course >= 0 {
        return location.course
    }

    guard let previous else { return nil }

    let distance = location.distance(from: previous)
    guard distance >= 3 else { return nil }

    return previous.bearing(to: location)
}

@MainActor
private final class LocationManagerHelper: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onStatusUpdate: ((CLAuthorizationStatus) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdates() {
        manager.startUpdatingLocation()
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
    }

    func requestOneShotLocation() {
        manager.requestLocation()
    }

    func getGpsSignalStatus() -> GPSStatus {
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            return .searching
        case .restricted, .denied:
            return .unavailable
        case .authorizedWhenInUse, .authorizedAlways:
            if let location = manager.location {
                return Self.gpsStatus(for: location)
            }
            return .searching
        @unknown default:
            return .unavailable
        }
    }

    static func gpsStatus(for location: CLLocation) -> GPSStatus {
        let accuracy = location.horizontalAccuracy
        if accuracy < 0 {
            return .unavailable
        } else if accuracy <= 15 {
            return .ready
        } else {
            return .weak
        }
    }

    nonisolated static func selectBestLocation(from locations: [CLLocation]) -> CLLocation? {
        locations
            .filter { LocationQuality.isAcceptable($0, allowRelaxedAccuracy: true) }
            .min(by: { $0.horizontalAccuracy < $1.horizontalAccuracy })
            ?? locations.last
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = Self.selectBestLocation(from: locations) else { return }
        Task { @MainActor in
            onLocationUpdate?(location)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            onStatusUpdate?(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // requestLocation() can fail transiently; continuous updates will recover.
    }
}

private enum LocationQuality {
    static let maxAge: TimeInterval = 12
    static let strictAccuracy = 40.0
    static let relaxedAccuracy = 80.0

    nonisolated static func isAcceptable(_ location: CLLocation, allowRelaxedAccuracy: Bool) -> Bool {
        guard location.horizontalAccuracy >= 0 else { return false }
        guard abs(location.timestamp.timeIntervalSinceNow) <= maxAge else { return false }

        let limit = allowRelaxedAccuracy ? relaxedAccuracy : strictAccuracy
        return location.horizontalAccuracy <= limit
    }
}

/// A thread-safe, background high-performance telemetry engine that manages both mock simulation
/// and real CoreLocation GPS feeds, emitting snapshots of sports biometrics and grade metrics at a stable 1Hz frequency.
public actor SensorEngine {
    public static let shared = SensorEngine()

    private static nonisolated let defaultMockRoute: [MapCoordinate] = [
        MapCoordinate(latitude: 39.9042, longitude: 116.4074),
        MapCoordinate(latitude: 39.9055, longitude: 116.4090),
        MapCoordinate(latitude: 39.9070, longitude: 116.4115),
        MapCoordinate(latitude: 39.9088, longitude: 116.4140),
        MapCoordinate(latitude: 39.9105, longitude: 116.4168),
        MapCoordinate(latitude: 39.9120, longitude: 116.4195),
        MapCoordinate(latitude: 39.9135, longitude: 116.4220),
        MapCoordinate(latitude: 39.9150, longitude: 116.4248)
    ]

    private var locationHelper: LocationManagerHelper?
    private var isSimulating = false
    private var isTracking = false

    // ── 1Hz timer (shared by both GPS and simulation) ──
    private var timerTask: Task<Void, Never>?

    // ── Mock Route simulation state ──
    private var mockRoute: [MapCoordinate]
    private var currentMockIndex = 0
    private var lastAltitude: Double = 50.0

    // Biometrics generation boundaries
    private var mockHeartRate = 135
    private var mockCadence = 88
    private var mockPower = 180

    // ── Real GPS: decoupled capture → 1Hz broadcast pipeline ──
    private var latestRealLocation: CLLocation?
    private var hasNewRealLocation = false
    private var lastBroadcastLocation: CLLocation?
    private var lastBroadcastTime: Date?

    // ── GPS signal tracking ──
    private var lastLocation: CLLocation?
    private var mockGpsStatus: GPSStatus = .ready
    private var freshLocationContinuation: CheckedContinuation<MapCoordinate?, Never>?
    private var freshLocationTimeoutTask: Task<Void, Never>?

    // ── Active continuations for real-time 1Hz subscription streams ──
    private var continuations: [UUID: AsyncStream<BikeDataSnapshot>.Continuation] = [:]

    private init() {
        self.mockRoute = Self.defaultMockRoute
    }

    /// Request permissions for CoreLocation GPS tracking.
    public func requestPermissions() {
        Task {
            let helper = await ensureLocationHelper()
            await MainActor.run {
                helper.requestPermission()
            }
        }
    }

    /// Retrieve the current GPS signal health.
    public func getGpsStatus() async -> GPSStatus {
        if isSimulating {
            return mockGpsStatus
        }
        let helper = await ensureLocationHelper()
        return await MainActor.run {
            helper.getGpsSignalStatus()
        }
    }

    /// Latest known coordinate for map seeding before the first ride sample arrives.
    public func lastKnownCoordinate() -> MapCoordinate? {
        guard let lastLocation else { return nil }
        return coordinate(from: lastLocation)
    }

    /// Request a one-shot location refresh before starting a ride.
    public func requestFreshLocationFix() {
        Task {
            let helper = await ensureLocationHelper()
            await MainActor.run {
                helper.requestOneShotLocation()
            }
        }
    }

    /// Wait for a reasonably accurate GPS fix before showing the rider on the map.
    public func awaitAccurateCoordinate(maxWaitSeconds: TimeInterval = 8) async -> MapCoordinate? {
        if let lastLocation, LocationQuality.isAcceptable(lastLocation, allowRelaxedAccuracy: false) {
            return coordinate(from: lastLocation)
        }

        return await withCheckedContinuation { continuation in
            freshLocationContinuation = continuation
            freshLocationTimeoutTask?.cancel()
            freshLocationTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(maxWaitSeconds * 1_000_000_000))
                await self?.finishFreshLocationRequest(with: self?.lastKnownCoordinate())
            }
            Task {
                await self.requestFreshLocationFix()
            }
        }
    }

    private func finishFreshLocationRequest(with coordinate: MapCoordinate?) {
        freshLocationTimeoutTask?.cancel()
        freshLocationTimeoutTask = nil
        guard let freshLocationContinuation else { return }
        self.freshLocationContinuation = nil
        freshLocationContinuation.resume(returning: coordinate)
    }

    private func coordinate(from location: CLLocation) -> MapCoordinate {
        MapCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    /// Safely register a subscription stream for newly produced 1Hz bike telemetry frames.
    public func subscribe() -> AsyncStream<BikeDataSnapshot> {
        let id = UUID()
        return AsyncStream<BikeDataSnapshot> { continuation in
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.removeContinuation(id: id)
                }
            }
            self.continuations[id] = continuation
        }
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    /// Select between live GPS hardware mode or realistic sandbox simulation mode.
    public func setSimulationMode(_ enabled: Bool) {
        guard isSimulating != enabled else { return }
        isSimulating = enabled
        if isSimulating {
            stopGpsTracking()
            if isTracking {
                startTimer()
            }
        } else {
            stopTimer()
            if isTracking {
                startGpsTracking()
            }
        }
    }

    public func activeSimulationMode() -> Bool {
        return isSimulating
    }

    /// Begin feeding telemetry snapshots (either GPS or Sim).
    public func startEngine() {
        guard !isTracking else { return }
        isTracking = true

        if isSimulating {
            startTimer()
        } else {
            startGpsTracking()
        }
    }

    /// End sensor telemetry aggregation loops.
    public func stopEngine() {
        isTracking = false
        stopTimer()
        stopGpsTracking()
    }

    // MARK: - Unified 1Hz Timer

    /// Stable 1Hz broadcast clock. Both real GPS and simulation mode use this timer
    /// to emit snapshots at a guaranteed cadence regardless of raw sensor frequency.
    private func startTimer() {
        stopTimer()
        // Reset simulation progress when starting fresh
        if isSimulating {
            currentMockIndex = 0
            lastAltitude = 50.0
        }
        // Reset GPS broadcast state
        hasNewRealLocation = false

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                guard !Task.isCancelled else { break }
                await self?.tick()
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// Fired once per second by the unified timer.
    private func tick() {
        if isSimulating {
            produceSimulatedSnapshot()
        } else {
            broadcastFromLatestLocation()
        }
    }

    // MARK: - Real GPS: 1Hz broadcast from latest captured location

    /// Build and broadcast a snapshot from the most recently captured GPS location.
    /// Speed is computed via position-delta when movement ≥ 3 m, falling back to
    /// `CLLocation.speed` for low-speed / stationary readings — this gives lower
    /// latency than relying solely on the Doppler-derived `speed` property.
    private func broadcastFromLatestLocation() {
        guard let location = latestRealLocation, hasNewRealLocation else { return }
        hasNewRealLocation = false

        let now = Date()

        // ── Speed: position-delta primary, hardware fallback ──
        var velocityMs = max(0, location.speed)
        if let lastLoc = lastBroadcastLocation,
           let lastTime = lastBroadcastTime {
            let distance = location.distance(from: lastLoc)
            let timeDelta = now.timeIntervalSince(lastTime)
            if distance >= 3.0, timeDelta > 0.1 {
                velocityMs = distance / timeDelta
            }
        }

        // ── Grade ──
        var calculatedGrade: Double?
        if let lastLoc = lastBroadcastLocation {
            let distance = location.distance(from: lastLoc)
            if distance > 2.0 {
                let altChange = location.altitude - lastLoc.altitude
                calculatedGrade = (altChange / distance) * 100.0
            }
        }

        let previousLocation = lastBroadcastLocation
        lastBroadcastLocation = location
        lastBroadcastTime = now

        let snapshot = BikeDataSnapshot(
            timestamp: location.timestamp,
            receivedAt: now,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            speed: velocityMs,
            heartRate: nil,
            cadence: nil,
            power: nil,
            grade: calculatedGrade,
            course: resolvedCourse(from: location, previous: previousLocation)
        )

        broadcast(snapshot)
    }

    // MARK: - Simulation Implementation

    /// Produce a simulated snapshot where speed is always derived from coordinate spacing
    /// (never random), ensuring speed and distance remain physically consistent.
    private func produceSimulatedSnapshot() {
        guard !mockRoute.isEmpty else { return }

        let currentCoord = mockRoute[currentMockIndex]
        let nextIndex = (currentMockIndex + 1) % mockRoute.count
        let nextCoord = mockRoute[nextIndex]

        // Calculate great-circle distance between consecutive route points
        let locCurrent = CLLocation(latitude: currentCoord.latitude, longitude: currentCoord.longitude)
        let locNext = CLLocation(latitude: nextCoord.latitude, longitude: nextCoord.longitude)
        let distanceDelta = locCurrent.distance(from: locNext) // meters

        // Speed = distance / 1s (tick interval); floor at 2.0 m/s (~7.2 km/h)
        // for realistic cycling pace when route points are very close together.
        let simulatedSpeedMs = max(2.0, distanceDelta)

        // Simulate grade & climbing dynamics
        let gradeDelta = Double.random(in: -2.0...5.0)
        let newAltitude = lastAltitude + (simulatedSpeedMs * (gradeDelta / 100.0))
        lastAltitude = max(10.0, newAltitude)

        currentMockIndex = nextIndex

        // Fluctuating biometrics (HeartRate, Cadence, Power)
        mockHeartRate = max(100, min(190, mockHeartRate + Int.random(in: -3...4)))
        mockCadence = max(60, min(115, mockCadence + Int.random(in: -4...5)))
        mockPower = max(80, min(450, mockPower + Int.random(in: -15...18)))

        let now = Date()

        let snapshot = BikeDataSnapshot(
            timestamp: now,
            receivedAt: now,
            latitude: currentCoord.latitude,
            longitude: currentCoord.longitude,
            altitude: lastAltitude,
            speed: simulatedSpeedMs,
            heartRate: mockHeartRate,
            cadence: mockCadence,
            power: mockPower,
            grade: gradeDelta,
            course: locCurrent.bearing(to: locNext)
        )

        broadcast(snapshot)
    }

    // MARK: - CoreLocation Telemetry Integrations

    private func ensureLocationHelper() async -> LocationManagerHelper {
        if let locationHelper {
            return locationHelper
        }

        let helper = await MainActor.run {
            let helper = LocationManagerHelper()
            helper.onLocationUpdate = { [weak self] location in
                guard let self else { return }
                Task {
                    await self.receiveRealLocation(location)
                }
            }
            return helper
        }

        locationHelper = helper
        return helper
    }

    private func startGpsTracking() {
        Task {
            let helper = await ensureLocationHelper()
            await MainActor.run {
                helper.startUpdates()
            }
        }
        startTimer()
    }

    private func stopGpsTracking() {
        stopTimer()
        Task {
            guard let helper = locationHelper else { return }
            await MainActor.run {
                helper.stopUpdates()
            }
        }
    }

    /// Capture incoming CLLocation updates. Stores the latest for 1Hz broadcast;
    /// does NOT emit snapshots directly — decoupling raw GPS frequency from UI cadence.
    private func receiveRealLocation(_ location: CLLocation) {
        guard LocationQuality.isAcceptable(
            location,
            allowRelaxedAccuracy: lastLocation == nil
        ) else {
            return
        }

        // Fresh location continuation for pre-ride warm-up
        if let freshLocationContinuation,
           LocationQuality.isAcceptable(location, allowRelaxedAccuracy: false) {
            finishFreshLocationRequest(with: coordinate(from: location))
        }

        // Accuracy degradation filter: discard a position that is ≥ 25 m worse than
        // the previous one when within 20 m of it.  BUT with a 3-second timeout: if
        // we haven't broadcast anything in 3 seconds, accept the degraded fix anyway
        // to prevent the UI from freezing in urban canyons.
        let now = Date()
        if let lastLocation,
           lastLocation.horizontalAccuracy > 0,
           location.horizontalAccuracy > lastLocation.horizontalAccuracy + 25,
           location.distance(from: lastLocation) < 20 {
            if let lastBroadcastTime, now.timeIntervalSince(lastBroadcastTime) < 3.0 {
                return
            }
        }

        self.lastLocation = location
        self.latestRealLocation = location
        self.hasNewRealLocation = true
    }

    // MARK: - Event Broadcaster

    private func broadcast(_ snapshot: BikeDataSnapshot) {
        for (_, continuation) in continuations {
            let result = continuation.yield(snapshot)
            if case .dropped = result {
                // Buffer full — consumer is not keeping up.
                // The 1Hz throttle above makes this unlikely with unbounded AsyncStream,
                // but retained as a defensive safety net.
            }
        }
    }
}