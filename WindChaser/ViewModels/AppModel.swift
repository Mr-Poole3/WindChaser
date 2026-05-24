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

    init() {
        // 1. Core Boot Self-Healing Database Recovery Checks
        Task {
            // Scans and heals any unfinalized coordinate tables in WAL mode on Actor context
            let healedRecs = await RideStore.shared.verifyOnStartupRecovery()

            // Read local SQLite compiled lists
            let savedRecs = await RideStore.shared.readAllSummaries()

            // Populate the Main UI Thread arrays
            await MainActor.run {
                if savedRecs.isEmpty && healedRecs.isEmpty {
                    // Fallback to gorgeous preset lists if filesystem is completely empty
                    self.historyRecords = MockData.historyRecords
                } else {
                    self.historyRecords = savedRecs
                }
            }
        }

        // 2. Setup telemetry feeds and default simulation toggles
        Task {
            await SensorEngine.shared.setSimulationMode(true)
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

    func startRide() {
        rideSession = RideSession(appModel: self)
        rideNavigationPath.append(RideRoute.activeRide)
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
