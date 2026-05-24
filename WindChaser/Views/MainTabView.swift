import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        TabView(selection: $appModel.selectedTab) {
            RideTabRoot()
                .tabItem {
                    Label("骑行", systemImage: "bicycle")
                }
                .tag(AppTab.ride)

            HistoryListView()
                .tabItem {
                    Label("历史", systemImage: "clock.arrow.circlepath")
                }
                .tag(AppTab.history)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
    }
}

struct RideTabRoot: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        NavigationStack(path: $appModel.rideNavigationPath) {
            PreflightView()
                .navigationDestination(for: RideRoute.self) { route in
                    switch route {
                    case .activeRide:
                        ActiveRideView()
                    case .report(let id):
                        if let record = appModel.record(for: id) {
                            RideReportView(summary: record) {
                                appModel.completeReport()
                            }
                        } else {
                            ContentUnavailableView("记录不存在", systemImage: "exclamationmark.triangle")
                        }
                    }
                }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppModel())
}
