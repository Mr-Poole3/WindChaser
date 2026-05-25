import Foundation
import Observation
import CoreLocation

@Observable
@MainActor
public final class RideSession {
    /// 进入页面但用户尚未按"开始"前保持 `.idle`。
    private(set) var state: RideState = .idle
    private(set) var metrics = LiveMetrics()
    private(set) var routeCoordinates: [MapCoordinate] = []
    private(set) var currentCoordinate: MapCoordinate?

    private var subscriptionTask: Task<Void, Never>?
    private var elapsedTimer: Task<Void, Never>?
    private var lastSampleCoordinate: MapCoordinate?
    private var lastMapCoordinateAt: Date?
    private var startedAt = Date()
    private var pausedAccumulated: TimeInterval = 0
    private var pauseBeganAt: Date?
    private var rideID: UUID?

    private weak var appModel: AppModel?

    init(appModel: AppModel) {
        self.appModel = appModel
    }

    var isPaused: Bool { state == .paused }
    var isRecording: Bool { state == .riding || state == .paused }

    // MARK: - Recording lifecycle

    /// 完成定位预热并启动计时与轨迹采集。
    ///
    /// 用户在设备检测页按下 `开始骑行` 后调用此方法：
    /// 1. 等待一次精准 GPS 锁定
    /// 2. 订阅传感器流
    /// 3. 写入 RideStore，进入 `.riding`，启动计时器
    ///
    /// 成功返回 `true` 后，调用方应导航到骑行主界面。
    func prepare() async -> Bool {
        await SensorEngine.shared.requestFreshLocationFix()
        if let seed = await SensorEngine.shared.awaitAccurateCoordinate() {
            currentCoordinate = seed
            lastSampleCoordinate = seed
            lastMapCoordinateAt = Date()
        }
        listenToSensorStream()

        do {
            let id = try await RideStore.shared.startRide()
            rideID = id
            startedAt = Date()
            pausedAccumulated = 0
            metrics.elapsed = 0
            metrics.distanceMeters = 0
            routeCoordinates = currentCoordinate.map { [$0] } ?? []
            state = .riding
            startElapsedTimer()
            return true
        } catch {
            print("Failed to start ride in RideStore: \(error)")
            return false
        }
    }

    private func startElapsedTimer() {
        elapsedTimer?.cancel()
        elapsedTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled, let self else { break }

                await MainActor.run {
                    guard self.state == .riding else { return }
                    self.metrics.elapsed = Date().timeIntervalSince(self.startedAt) - self.pausedAccumulated
                }
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
        let coord = MapCoordinate(latitude: snapshot.latitude, longitude: snapshot.longitude)
        currentCoordinate = coord

        let storeState = await RideStore.shared.getCurrentState()
        if storeState == .ended && self.state != .ended {
            self.state = .ended
            self.appModel?.finishRide()
            return
        }

        guard state == .riding else { return }

        metrics.speedKmh = snapshot.speed * 3.6
        metrics.speedValid = snapshot.speed >= 0
        metrics.heartRate = snapshot.heartRate
        metrics.cadence = snapshot.cadence
        metrics.power = snapshot.power
        metrics.altitude = snapshot.altitude
        metrics.grade = snapshot.grade
        metrics.courseDegrees = snapshot.course

        if let lastSampleCoordinate {
            let previous = CLLocation(latitude: lastSampleCoordinate.latitude, longitude: lastSampleCoordinate.longitude)
            let current = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let delta = current.distance(from: previous)
            metrics.distanceMeters += delta
        }
        lastSampleCoordinate = coord

        updateRouteCoordinates(with: coord)

        do {
            try await RideStore.shared.saveSample(snapshot)
        } catch {
            print("Failed to persist snapshot: \(error)")
        }
    }

    private func updateRouteCoordinates(with coord: MapCoordinate) {
        if routeCoordinates.isEmpty {
            routeCoordinates = [coord]
            lastMapCoordinateAt = Date()
            return
        }

        if routeCoordinates.count == 1, let seed = routeCoordinates.first {
            let seedLocation = CLLocation(latitude: seed.latitude, longitude: seed.longitude)
            let currentLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            if currentLocation.distance(from: seedLocation) >= 25 {
                routeCoordinates = [coord]
                lastMapCoordinateAt = Date()
                return
            }
        }

        if shouldAppendMapCoordinate(coord) {
            routeCoordinates.append(coord)
            lastMapCoordinateAt = Date()
        }
    }

    private func shouldAppendMapCoordinate(_ coord: MapCoordinate) -> Bool {
        guard let last = routeCoordinates.last else { return true }

        let lastLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)
        let currentLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let movedEnough = currentLocation.distance(from: lastLocation) >= 8

        if movedEnough { return true }

        if let lastMapCoordinateAt {
            return Date().timeIntervalSince(lastMapCoordinateAt) >= 3
        }

        return false
    }

    func pause() {
        guard state == .riding else { return }
        state = .paused
        pauseBeganAt = Date()
        elapsedTimer?.cancel()

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
        startElapsedTimer()

        Task {
            try? await RideStore.shared.resumeRide()
        }
    }

    func finish() async -> RideSummary? {
        elapsedTimer?.cancel()
        elapsedTimer = nil
        subscriptionTask?.cancel()
        subscriptionTask = nil

        // 若用户从未按下"开始"直接退出，则没有可总结的记录
        guard isRecording || state == .ended else {
            state = .ended
            return nil
        }

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
