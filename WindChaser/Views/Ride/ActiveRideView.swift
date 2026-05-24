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
                RouteMapView(
                    coordinates: session.routeCoordinates,
                    palette: palette
                )
                .ignoresSafeArea()

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
                ProgressView()
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
