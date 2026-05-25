import SwiftUI

struct RiderLocationMarker: View {
    let courseDegrees: Double?
    let headingUpEnabled: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(RideButtonStyle.routeOrange)
                .frame(width: 38, height: 38)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                .frame(width: 38, height: 38)

            Image(systemName: "bicycle")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(markerRotation))
        }
    }

    private var markerRotation: Double {
        guard !headingUpEnabled, let courseDegrees else { return 0 }
        return courseDegrees
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
