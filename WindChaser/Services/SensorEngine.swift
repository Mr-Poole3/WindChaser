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
    private var timerTask: Task<Void, Never>?

    // Mock Route simulation state
    private var mockRoute: [MapCoordinate]
    private var currentMockIndex = 0
    private var lastAltitude: Double = 50.0
    private var lastLocation: CLLocation?

    // Biometrics generation boundaries
    private var mockHeartRate = 135
    private var mockCadence = 88
    private var mockPower = 180

    // Active continuations for real-time 1Hz subscription streams
    private var continuations: [UUID: AsyncStream<BikeDataSnapshot>.Continuation] = [:]

    // Authorization / Status trackers
    private var mockGpsStatus: GPSStatus = .ready
    private var freshLocationContinuation: CheckedContinuation<MapCoordinate?, Never>?
    private var freshLocationTimeoutTask: Task<Void, Never>?

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
                startSimulationTimer()
            }
        } else {
            stopSimulationTimer()
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
            startSimulationTimer()
        } else {
            startGpsTracking()
        }
    }

    /// End sensor telemetry aggregation loops.
    public func stopEngine() {
        isTracking = false
        stopSimulationTimer()
        stopGpsTracking()
    }

    // MARK: - Simulation Implementation

    private func startSimulationTimer() {
        stopSimulationTimer()
        currentMockIndex = 0
        lastAltitude = 50.0

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 Second standard intervals
                guard !Task.isCancelled else { break }
                await self?.produceSimulatedSnapshot()
            }
        }
    }

    private func stopSimulationTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func produceSimulatedSnapshot() {
        guard !mockRoute.isEmpty else { return }

        // Compute current coordinates & step forward
        let currentCoord = mockRoute[currentMockIndex]
        let nextIndex = (currentMockIndex + 1) % mockRoute.count
        let nextCoord = mockRoute[nextIndex]

        // Calculate direct great-circle spacing to compute velocity
        let locCurrent = CLLocation(latitude: currentCoord.latitude, longitude: currentCoord.longitude)
        let locNext = CLLocation(latitude: nextCoord.latitude, longitude: nextCoord.longitude)
        let distanceDelta = locCurrent.distance(from: locNext) // in meters

        // Simulate speed around the delta or fallback to realistic cycling pacing
        let simulatedSpeedMs = distanceDelta > 0.1 ? distanceDelta : Double.random(in: 5.5...7.5) // ~20-27 kmh

        // Simulate grade & climbing dynamics
        let gradeDelta = Double.random(in: -2.0...5.0)
        let newAltitude = lastAltitude + (simulatedSpeedMs * (gradeDelta / 100.0))
        lastAltitude = max(10.0, newAltitude) // Avoid going sub-sea level randomly

        currentMockIndex = nextIndex

        // Fluctuating biometrics (HeartRate, Cadence, Power) inside physical capabilities
        mockHeartRate = max(100, min(190, mockHeartRate + Int.random(in: -3...4)))
        mockCadence = max(60, min(115, mockCadence + Int.random(in: -4...5)))
        mockPower = max(80, min(450, mockPower + Int.random(in: -15...18)))

        let snapshot = BikeDataSnapshot(
            timestamp: Date(),
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
    }

    private func stopGpsTracking() {
        Task {
            guard let helper = locationHelper else { return }
            await MainActor.run {
                helper.stopUpdates()
            }
        }
    }

    private func receiveRealLocation(_ location: CLLocation) {
        guard LocationQuality.isAcceptable(
            location,
            allowRelaxedAccuracy: lastLocation == nil
        ) else {
            return
        }

        if let freshLocationContinuation,
           LocationQuality.isAcceptable(location, allowRelaxedAccuracy: false) {
            finishFreshLocationRequest(with: coordinate(from: location))
        }

        // Prefer monotonically improving accuracy; ignore clearly worse fixes.
        if let lastLocation,
           lastLocation.horizontalAccuracy > 0,
           location.horizontalAccuracy > lastLocation.horizontalAccuracy + 25,
           location.distance(from: lastLocation) < 20 {
            return
        }

        // Compute speed and grade indicators on real hardware reports
        let velocityMs = max(0, location.speed)

        var calculatedGrade: Double?
        if let lastLocation {
            let distance = location.distance(from: lastLocation)
            if distance > 2.0 {
                let altChange = location.altitude - lastLocation.altitude
                calculatedGrade = (altChange / distance) * 100.0
            }
        }

        let previousLocation = lastLocation
        self.lastLocation = location

        let snapshot = BikeDataSnapshot(
            timestamp: location.timestamp,
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

    // MARK: - Event Broadcaster

    private func broadcast(_ snapshot: BikeDataSnapshot) {
        for (_, continuation) in continuations {
            let result = continuation.yield(snapshot)
            if case .dropped = result {
                // Buffer filled, drop or queue cleanup
            }
        }
    }
}
