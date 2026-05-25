import SwiftUI

/// 骑行者当前位置标记：与设计稿一致的绿色脉冲圆点。
struct RiderLocationMarker: View {
    let courseDegrees: Double?
    let headingUpEnabled: Bool

    @State private var pulse = false

    private let accent = AppPalette.shared.accentColor

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 56, height: 56)
                .scaleEffect(pulse ? 1.35 : 0.85)
                .opacity(pulse ? 0 : 0.9)

            Circle()
                .stroke(Color.white.opacity(0.95), lineWidth: 3)
                .frame(width: 22, height: 22)

            Circle()
                .fill(accent)
                .frame(width: 18, height: 18)
                .shadow(color: accent.opacity(0.6), radius: 8)
        }
        .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulse)
        .onAppear { pulse = true }
    }
}

/// Isolates map updates from high-frequency metric refreshes during an active ride.
struct ActiveRideMapLayer: View, Equatable {
    let coordinates: [MapCoordinate]
    let currentCoordinate: MapCoordinate?
    let courseDegrees: Double?
    let palette: ThemePalette

    var body: some View {
        RouteMapView(
            coordinates: coordinates,
            palette: palette,
            mode: .liveTracking,
            courseDegrees: courseDegrees,
            currentCoordinate: currentCoordinate
        )
    }

    static func == (lhs: ActiveRideMapLayer, rhs: ActiveRideMapLayer) -> Bool {
        lhs.coordinates.count == rhs.coordinates.count
            && lhs.coordinates.last == rhs.coordinates.last
            && lhs.currentCoordinate == rhs.currentCoordinate
            && lhs.courseDegrees.map { Int($0.rounded()) } == rhs.courseDegrees.map { Int($0.rounded()) }
            && lhs.palette == rhs.palette
    }
}
