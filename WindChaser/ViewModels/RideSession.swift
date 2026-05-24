import Foundation
import Observation
import CoreLocation

@Observable
@MainActor
public final class RideSession {
    private(set) var state: RideState = .riding
    private(set) var metrics = LiveMetrics()
    private(set) var routeCoordinates: [MapCoordinate] = []

    private var subscriptionTask: Task<Void, Never>?
    private var startedAt = Date()
    private var pausedAccumulated: TimeInterval = 0
    private var pauseBeganAt: Date?
    private var rideID: UUID?

    private weak var appModel: AppModel?

    init(appModel: AppModel) {
        self.appModel = appModel
        setupAndStart()
    }

    deinit {
        subscriptionTask?.cancel()
    }

    var isPaused: Bool { state == .paused }

    private func setupAndStart() {
        Task {
            do {
                // Initialize background writing folder and open sqlite database handles
                let id = try await RideStore.shared.startRide()
                self.rideID = id

                // Let the SensorEngine start emitting live telemetry
                await SensorEngine.shared.startEngine()

                // Listen to high-fidelity 1Hz snapshots stream
                listenToSensorStream()
            } catch {
                print("Failed to start ride in RideStore: \(error)")
            }
        }
    }

    private func listenToSensorStream() {
        subscriptionTask?.cancel()
        subscriptionTask = Task { [weak self] in
            guard let self else { return }
            let stream = await SensorEngine.shared.subscribe()
            for await snapshot in stream {
                guard !Task.isCancelled else { break }
                await self.handleSnapshot(snapshot)
            }
        }
    }

    private func handleSnapshot(_ snapshot: BikeDataSnapshot) async {
        // Safe check for pause timeouts ending the workout inside RideStore under the hood
        let storeState = await RideStore.shared.getCurrentState()
        if storeState == .ended && self.state != .ended {
            self.state = .ended
            self.appModel?.finishRide()
            return
        }

        guard state == .riding else { return }

        // Compile physical metrics based on 1Hz sensor snapshot
        metrics.elapsed = Date().timeIntervalSince(startedAt) - pausedAccumulated
        metrics.speedKmh = snapshot.speed * 3.6
        metrics.speedValid = true
        metrics.heartRate = snapshot.heartRate
        metrics.cadence = snapshot.cadence
        metrics.power = snapshot.power
        metrics.altitude = snapshot.altitude
        metrics.grade = snapshot.grade

        let coord = MapCoordinate(latitude: snapshot.latitude, longitude: snapshot.longitude)
        if routeCoordinates.isEmpty {
            routeCoordinates.append(coord)
        } else if routeCoordinates.last != coord {
            if let lastCoord = routeCoordinates.last {
                let loc1 = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
                let loc2 = CLLocation(latitude: snapshot.latitude, longitude: snapshot.longitude)
                metrics.distanceMeters += loc2.distance(from: loc1)
            }
            routeCoordinates.append(coord)
        }

        // Direct async SQL insertion (does WAL writing on Actor thread)
        do {
            try await RideStore.shared.saveSample(snapshot)
        } catch {
            print("Failed to persist snapshot: \(error)")
        }
    }

    func pause() {
        guard state == .riding else { return }
        state = .paused
        pauseBeganAt = Date()

        Task {
            try? await RideStore.shared.pauseRide()
        }
    }

    func resume() {
        guard state == .paused else { return }
        if let pauseBeganAt {
            pausedAccumulated += Date().timeIntervalSince(pauseBeganAt)
        }
        self.pauseBeganAt = nil
        state = .riding

        Task {
            try? await RideStore.shared.resumeRide()
        }
    }

    func finish() async -> RideSummary? {
        subscriptionTask?.cancel()
        subscriptionTask = nil

        await SensorEngine.shared.stopEngine()

        state = .ended

        do {
            let summary = try await RideStore.shared.endRide()
            return summary
        } catch {
            print("Failed to end ride in RideStore: \(error)")
            return nil
        }
    }
}
