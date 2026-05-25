import Foundation
import HealthKit

/// 在 Watch 端把 HealthKit 内置心率封装成一个可观察的来源。
///
/// Phase 2 / S3：
/// - 启动 `HKWorkoutSession(.cycling)` + `HKLiveWorkoutBuilder` 读心率
/// - 首次启动请求 `read: heartRate` 权限
/// - 启动时调用 `recoverHangingWorkout()` 自愈上次崩溃遗留的活动 session
/// - 本切片心率仅在 Watch 本地暴露给 UI，**不通过 WCS 发到 iPhone**（S4 才做）
@MainActor
@Observable
final class WatchHeartRateRelay: NSObject {
    enum AuthorizationStatus: Sendable {
        case notDetermined
        case denied
        case authorized
    }

    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    private(set) var isWorkoutActive: Bool = false
    private(set) var isWorkoutPaused: Bool = false
    private(set) var currentHeartRate: Int?
    private(set) var lastHeartRateAt: Date?
    private(set) var sampleSequence: Int = 0
    /// workout 在跑但已超过 `staleAfter` 没收到心率样本，
    /// 通常意味着手表未佩戴或心率传感器接触不良。
    private(set) var isHeartRateStalled: Bool = false

    /// 心率样本超过这个时长没更新就视为陈旧，UI 应清空显示并提醒用户检查佩戴。
    private let staleAfter: TimeInterval = 8

    private let healthStore = HKHealthStore()
    private let heartRateType = HKQuantityType(.heartRate)
    private let heartRateUnit = HKUnit(from: "count/min")

    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var freshnessTask: Task<Void, Never>?

    // MARK: - Public API

    /// 应在 App 首次出现时调用。
    ///
    /// 步骤：
    /// 1. 自愈上次崩溃留下的活动 workout（如果有）
    /// 2. 请求 HealthKit 心率读取权限
    /// 3. 等待 iPhone 通过 WCS 下发 start 命令后再启动 workout
    func bootstrap() async {
        await recoverHangingWorkout()
        await requestAuthorization()
    }

    /// 请求心率读取权限与 workout 写入权限。
    ///
    /// 注意：`HKHealthStore.authorizationStatus(for:)` 只可靠表达写入/共享权限，
    /// 不适合用来判断 read-only 的心率读取权限。`HKWorkoutSession` 需要 workout
    /// 写权限才能启动；S8 会补完整 HKWorkout 写入，本阶段只用它驱动实时心率采集。
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .denied
            return
        }
        do {
            try await healthStore.requestAuthorization(
                toShare: [HKObjectType.workoutType()],
                read: [heartRateType]
            )
            authorizationStatus = .authorized
        } catch {
            print("HealthKit authorization request failed: \(error)")
            authorizationStatus = .denied
        }
    }

    /// 启动一次 cycling workout session，如果还没有的话。
    ///
    /// `HKHealthStore.authorizationStatus(for:)` 只能区分「未决定 / 拒绝」与「已选择共享」，
    /// 实际是否能读心率要等 builder 真正拿到数据才能判定，这里采用乐观启动策略。
    func startWorkoutIfNeeded() async {
        guard authorizationStatus != .denied else { return }
        guard workoutSession == nil else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        configuration.locationType = .outdoor

        do {
            let session = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            session.delegate = self
            builder.delegate = self

            let startDate = Date()
            session.startActivity(with: startDate)
            try await builder.beginCollection(at: startDate)

            workoutSession = session
            workoutBuilder = builder
            isWorkoutActive = true
            isWorkoutPaused = false
            startFreshnessTicker()
        } catch {
            print("Failed to start workout session: \(error)")
            authorizationStatus = .denied
            cleanupWorkoutState()
        }
    }

    func pauseWorkout() {
        guard let workoutSession, isWorkoutActive, !isWorkoutPaused else { return }
        workoutSession.pause()
        isWorkoutPaused = true
        currentHeartRate = nil
        lastHeartRateAt = nil
        isHeartRateStalled = false
    }

    func resumeWorkout() {
        guard let workoutSession, isWorkoutPaused else { return }
        workoutSession.resume()
        isWorkoutPaused = false
    }

    /// 结束当前 workout（如果有），并清空缓存。
    ///
    /// Phase 2 / S3 本身不需要写 HKWorkout —— 那是 S8。
    func stopWorkout() async {
        guard let session = workoutSession, let builder = workoutBuilder else { return }
        let endDate = Date()
        session.end()
        do {
            try await builder.endCollection(at: endDate)
            try await builder.finishWorkout()
        } catch {
            print("Failed to end workout session: \(error)")
        }
        cleanupWorkoutState()
    }

    /// 启动时尝试结束上次崩溃遗留的 workout。
    ///
    /// `HKHealthStore.recoverActiveWorkoutSession()` 在 watchOS 10+ 上可用；
    /// 如果没有遗留 session，会返回 nil。
    func recoverHangingWorkout() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            if let recovered = try await healthStore.recoverActiveWorkoutSession() {
                recovered.end()
            }
        } catch {
            print("Recovering hanging workout failed: \(error)")
        }
    }

    // MARK: - Private

    private func cleanupWorkoutState() {
        freshnessTask?.cancel()
        freshnessTask = nil
        workoutSession = nil
        workoutBuilder = nil
        isWorkoutActive = false
        isWorkoutPaused = false
        currentHeartRate = nil
        lastHeartRateAt = nil
        sampleSequence = 0
        isHeartRateStalled = false
    }

    fileprivate func ingest(heartRateSample bpm: Int) {
        guard isWorkoutActive, !isWorkoutPaused else { return }
        currentHeartRate = bpm
        lastHeartRateAt = Date()
        sampleSequence += 1
        isHeartRateStalled = false
    }

    /// 启动一个 1s 节奏的 ticker，定期检查心率样本是否陈旧。
    ///
    /// 当 workout 在跑但 `lastHeartRateAt` 超过 `staleAfter` 没更新时：
    /// - 清空 `currentHeartRate`（避免 UI 卡住旧值）
    /// - 把 `isHeartRateStalled` 置为 `true`，让 UI 提醒用户检查佩戴
    private func startFreshnessTicker() {
        freshnessTask?.cancel()
        freshnessTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self else { break }
                await MainActor.run {
                    self.evaluateFreshness()
                }
            }
        }
    }

    private func evaluateFreshness() {
        guard isWorkoutActive, !isWorkoutPaused else {
            isHeartRateStalled = false
            return
        }

        guard let lastHeartRateAt else {
            isHeartRateStalled = false
            return
        }

        if Date().timeIntervalSince(lastHeartRateAt) > staleAfter {
            currentHeartRate = nil
            isHeartRateStalled = true
        } else {
            isHeartRateStalled = false
        }
    }

    fileprivate func handleSessionStateChange(_ state: HKWorkoutSessionState) {
        switch state {
        case .running:
            isWorkoutActive = true
            isWorkoutPaused = false
        case .paused:
            isWorkoutActive = true
            isWorkoutPaused = true
            currentHeartRate = nil
            lastHeartRateAt = nil
            isHeartRateStalled = false
        case .ended, .stopped:
            isWorkoutActive = false
            isWorkoutPaused = false
            currentHeartRate = nil
            lastHeartRateAt = nil
            isHeartRateStalled = false
        default:
            break
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchHeartRateRelay: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from _: HKWorkoutSessionState,
        date _: Date
    ) {
        Task { @MainActor in
            handleSessionStateChange(toState)
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            print("HKWorkoutSession failed: \(error)")
            cleanupWorkoutState()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchHeartRateRelay: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let heartRateType = HKQuantityType(.heartRate)
        guard collectedTypes.contains(heartRateType) else { return }

        let unit = HKUnit(from: "count/min")
        guard let statistics = workoutBuilder.statistics(for: heartRateType),
              let value = statistics.mostRecentQuantity()?.doubleValue(for: unit) else {
            return
        }

        let bpm = Int(value.rounded())
        Task { @MainActor in
            ingest(heartRateSample: bpm)
        }
    }
}
