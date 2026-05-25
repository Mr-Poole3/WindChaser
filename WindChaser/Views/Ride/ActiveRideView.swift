import SwiftUI

struct ActiveRideView: View {
    @Environment(AppModel.self) private var appModel
    @State private var sheetExpansion: SheetExpansion = .collapsed
    @State private var dragOffset: CGFloat = 0

    private var palette: ThemePalette {
        SolarTheme.palette()
    }

    var body: some View {
        ZStack {
            if let session = appModel.rideSession {
                ActiveRideMapLayer(
                    coordinates: session.routeCoordinates,
                    currentCoordinate: session.currentCoordinate,
                    courseDegrees: session.metrics.courseDegrees,
                    palette: palette
                )
                .equatable()

                RideDataSheet(
                    metrics: session.metrics,
                    palette: palette,
                    isPaused: session.isPaused,
                    expansion: sheetExpansion,
                    dragOffset: dragOffset,
                    onToggleExpansion: toggleSheet,
                    onPause: { session.pause() },
                    onResume: { session.resume() },
                    onEnd: { appModel.finishRide() }
                )
                .ignoresSafeArea(edges: .bottom)
            } else {
                ProgressView("正在准备骑行…")
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func toggleSheet() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            sheetExpansion = sheetExpansion == .collapsed ? .expanded : .collapsed
        }
    }
}
