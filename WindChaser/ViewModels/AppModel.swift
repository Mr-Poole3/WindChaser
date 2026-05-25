import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AppModel {
    var selectedTab: AppTab = .ride
    var rideNavigationPath = NavigationPath()
    var rideSession: RideSession?
    var historyRecords: [RideSummary] = []
    var gpsStatus: GPSStatus = .searching
    var isStartingRide = false

    init() {
        // 1. Core Boot Self-Healing Database Recovery Checks
        Task {
            // Scans and heals any unfinalized coordinate tables in WAL mode on Actor context
            _ = await RideStore.shared.verifyOnStartupRecovery()

            // Read local SQLite compiled lists
            let savedRecs = await RideStore.shared.readAllSummaries()

            // Populate the Main UI Thread arrays - start with real data only
            await MainActor.run {
                self.historyRecords = savedRecs
            }
        }

        // 2. Setup telemetry feeds with real GPS (simulation mode OFF)
        Task {
            // Request location permissions first
            await SensorEngine.shared.requestPermissions()
            
            // Use real GPS by default (set to false for production)
            await SensorEngine.shared.setSimulationMode(false)
            await SensorEngine.shared.startEngine()

            // Keep updating GPS signal strength indicator in real-time
            while true {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // Audits every 2s
                let status = await SensorEngine.shared.getGpsStatus()
                await MainActor.run {
                    self.gpsStatus = status
                }
            }
        }
    }

    /// 设备检测页按下「开始骑行」后：完成 GPS 预热、写入 RideStore、启动计时，
    /// 然后导航到骑行主界面。到达页面时已经处于 `.riding` 状态。
    func startRide() {
        guard !isStartingRide, rideSession == nil else { return }

        isStartingRide = true
        Task {
            let session = RideSession(appModel: self)
            let prepared = await session.prepare()
            if prepared {
                rideSession = session
                rideNavigationPath.append(RideRoute.activeRide)
            }
            isStartingRide = false
        }
    }

    func finishRide() {
        guard let rideSession else { return }

        Task {
            if let record = await rideSession.finish() {
                self.historyRecords.insert(record, at: 0)
                self.rideSession = nil
                self.rideNavigationPath.append(RideRoute.report(record.id))
            } else {
                self.rideSession = nil
                self.rideNavigationPath = NavigationPath()
            }
        }
    }

    func completeReport() {
        rideNavigationPath = NavigationPath()
        selectedTab = .ride
    }

    func record(for id: UUID) -> RideSummary? {
        historyRecords.first { $0.id == id }
    }
}
