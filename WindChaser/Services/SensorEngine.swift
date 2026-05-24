import Foundation
import CoreLocation

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

        #if !targetEnvironment(simulator)
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        #endif
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

    func getGpsSignalStatus() -> GPSStatus {
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            return .searching
        case .restricted, .denied:
            return .unavailable
        case .authorizedWhenInUse, .authorizedAlways:
            if let accuracy = manager.location?.horizontalAccuracy {
                if accuracy < 0 {
                    return .unavailable
                } else if accuracy <= 15 {
                    return .ready
                } else {
                    return .weak
                }
            }
            return .searching
        @unknown default:
            return .unavailable
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
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
}

/// A thread-safe, background high-performance telemetry engine that manages both mock simulation
/// and real CoreLocation GPS feeds, emitting snapshots of sports biometrics and grade metrics at a stable 1Hz frequency.
public actor SensorEngine {
    public static let shared = SensorEngine()

    private let helper: LocationManagerHelper
    private var isSimulating = false
    private var timerTask: Task<Void, Never>?

    // Mock Route simulation state
    private var mockRoute: [MapCoordinate] = MockData.sampleRoute
    private var currentMockIndex = 0
    private var lastAltitude: Double = 50.0

    // Biometrics generation boundaries
    private var mockHeartRate = 135
    private var mockCadence = 88
    private var mockPower = 180

    // Active continuations for real-time 1Hz subscription streams
    private var continuations: [UUID: AsyncStream<BikeDataSnapshot>.Continuation] = [:]

    // Authorization / Status trackers
    private var mockGpsStatus: GPSStatus = .ready

    private init() {
        // LocationManagerHelper must be initialized on the Main Thread
        let helper = LocationManagerHelper()
        self.helper = helper

        // Wire up CoreLocation forwards
        helper.onLocationUpdate = { [weak self] location in
            guard let self else { return }
            Task {
                await self.receiveRealLocation(location)
            }
        }
    }

    /// Request permissions for CoreLocation GPS tracking.
    public func requestPermissions() {
        Task { @MainActor in
            helper.requestPermission()
        }
    }

    /// Retrieve the current GPS signal health.
    public func getGpsStatus() -> GPSStatus {
        if isSimulating {
            return mockGpsStatus
        }
        return helper.getGpsSignalStatus()
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
            startSimulationTimer()
        } else {
            stopSimulationTimer()
            startGpsTracking()
        }
    }

    public func activeSimulationMode() -> Bool {
        return isSimulating
    }

    /// Begin feeding telemetry snapshots (either GPS or Sim).
    public func startEngine() {
        if isSimulating {
            startSimulationTimer()
        } else {
            startGpsTracking()
        }
    }

    /// End sensor telemetry aggregation loops.
    public func stopEngine() {
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
            grade: gradeDelta
        )

        broadcast(snapshot)
    }

    // MARK: - CoreLocation Telemetry Integrations

    private func startGpsTracking() {
        Task { @MainActor in
            helper.startUpdates()
        }
    }

    private func stopGpsTracking() {
        Task { @MainActor in
            helper.stopUpdates()
        }
    }

    private func receiveRealLocation(_ location: CLLocation) {
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

        self.lastLocation = location

        // Keep biometrics ticking on simulated Bluetooth fallback when hardware isn't attached
        mockHeartRate = max(100, min(185, mockHeartRate + Int.random(in: -2...3)))
        mockCadence = max(70, min(110, mockCadence + Int.random(in: -3...3)))
        mockPower = max(100, min(380, mockPower + Int.random(in: -10...12)))

        let snapshot = BikeDataSnapshot(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            speed: velocityMs,
            heartRate: mockHeartRate,
            cadence: mockCadence,
            power: mockPower,
            grade: calculatedGrade
        )

        broadcast(snapshot)
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        receiveRealLocation(location)
    }

    private func handleStatusUpdate(_ status: CLAuthorizationStatus) {
        // Transmit potential telemetry error messages if permissions reject
    }

    // MARK: - Event Broadcaster

    private func broadcast(_ snapshot: BikeDataSnapshot) {
        for (id, continuation) in continuations {
            let result = continuation.yield(snapshot)
            if case .dropped = result {
                // Buffer filled, drop or queue cleanup
            }
        }
    }
}
