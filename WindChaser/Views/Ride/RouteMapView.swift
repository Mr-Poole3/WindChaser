import MapKit
import SwiftUI

enum RouteMapDisplayMode: Equatable {
    case overview
    case liveTracking
}

struct RouteMapView: View, Equatable {
    let coordinates: [MapCoordinate]
    let palette: ThemePalette
    var mode: RouteMapDisplayMode = .overview
    var interactionEnabled: Bool = false
    var courseDegrees: Double?
    var currentCoordinate: MapCoordinate?

    @State private var position: MapCameraPosition = .automatic
    @State private var lastTrackedCenter: CLLocationCoordinate2D?
    @State private var lastTrackedHeading: Double?
    @State private var followsRider = true
    @State private var headingUpEnabled = true
    @State private var isProgrammaticCameraUpdate = false

    private var displayCoordinates: [MapCoordinate] {
        switch mode {
        case .overview:
            RoutePolylineSimplifier.simplify(coordinates, maxPoints: 600)
        case .liveTracking:
            RoutePolylineSimplifier.simplify(coordinates, maxPoints: 180)
        }
    }

    private var allowsInteraction: Bool {
        interactionEnabled || mode == .liveTracking
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            styledMap
                .ignoresSafeArea()

            if mode == .liveTracking {
                mapControlButtons
                    .padding(.top, 8)
                    .padding(.trailing, 12)
            }
        }
        .onAppear {
            followsRider = mode == .liveTracking
            headingUpEnabled = mode == .liveTracking
            updateCamera(force: true)
        }
        .onChange(of: coordinates.count) {
            updateCamera(force: mode == .overview)
        }
        .onChange(of: coordinates.last) {
            updateCamera(force: false)
        }
        .onChange(of: currentCoordinate) {
            guard mode == .liveTracking else { return }
            updateCamera(force: false)
        }
        .onChange(of: courseDegrees) {
            guard mode == .liveTracking else { return }
            updateCamera(force: false)
        }
    }

    @ViewBuilder
    private var styledMap: some View {
        switch mode {
        case .overview:
            if palette.mapStyle == .standard {
                mapContent
                    .mapStyle(.standard(elevation: .flat))
            } else {
                mapContent
                    .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            }
        case .liveTracking:
            mapContent
                .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
                .onMapCameraChange(frequency: .onEnd) { _ in
                    guard allowsInteraction, !isProgrammaticCameraUpdate else { return }
                    followsRider = false
                }
        }
    }

    private var mapContent: some View {
        Map(
            position: $position,
            interactionModes: allowsInteraction ? [.pan, .zoom, .rotate] : []
        ) {
            if displayCoordinates.count >= 2 {
                MapPolyline(coordinates: displayCoordinates.map(\.mapDisplayCoordinate))
                    .stroke(RideButtonStyle.routeOrange, lineWidth: 4)
            }

            if mode == .overview, let last = displayCoordinates.last {
                Marker("Current", coordinate: last.mapDisplayCoordinate)
            }

            if mode == .liveTracking, let current = currentCoordinate ?? coordinates.last {
                Annotation("我的位置", coordinate: current.mapDisplayCoordinate, anchor: .center) {
                    RiderLocationMarker(
                        courseDegrees: courseDegrees,
                        headingUpEnabled: headingUpEnabled
                    )
                }
            }
        }
        .mapControls {
            // Hide MapKit's default compass; it overlaps the status bar and duplicates our heading control.
        }
    }

    @ViewBuilder
    private var mapControlButtons: some View {
        VStack(spacing: 10) {
            if followsRider {
                Button {
                    headingUpEnabled.toggle()
                    updateCamera(force: true)
                } label: {
                    Image(systemName: headingUpEnabled ? "location.north.line.fill" : "location.north.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Circle())
                }
                .accessibilityLabel(headingUpEnabled ? "车头朝上" : "正北朝上")
            }

            if !followsRider {
                Button {
                    followsRider = true
                    updateCamera(force: true)
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Circle())
                }
                .accessibilityLabel("回到当前位置")
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
    }

    private func updateCamera(force: Bool) {
        guard !coordinates.isEmpty else { return }

        switch mode {
        case .overview:
            fitRoute()
        case .liveTracking:
            followCurrentPosition(force: force)
        }
    }

    private func followCurrentPosition(force: Bool) {
        guard followsRider || force else { return }
        guard let last = currentCoordinate ?? coordinates.last else { return }

        let targetHeading = cameraHeading
        let displayCoordinate = last.mapDisplayCoordinate

        if !force, let lastTrackedCenter, let lastTrackedHeading {
            let lastLocation = CLLocation(latitude: displayCoordinate.latitude, longitude: displayCoordinate.longitude)
            let cameraLocation = CLLocation(latitude: lastTrackedCenter.latitude, longitude: lastTrackedCenter.longitude)
            let moved = lastLocation.distance(from: cameraLocation)
            let headingDelta = angularDifference(from: lastTrackedHeading, to: targetHeading)

            if moved < 6, headingDelta < 8 {
                return
            }
        }

        lastTrackedCenter = displayCoordinate
        lastTrackedHeading = targetHeading
        setCameraPosition(
            .camera(
                MapCamera(
                    centerCoordinate: displayCoordinate,
                    distance: 650,
                    heading: targetHeading,
                    pitch: 0
                )
            )
        )
    }

    private var cameraHeading: Double {
        guard headingUpEnabled, let courseDegrees else {
            return lastTrackedHeading ?? 0
        }
        return courseDegrees
    }

    private func fitRoute() {
        guard !coordinates.isEmpty else { return }

        if coordinates.count == 1, let only = coordinates.first {
            setCameraPosition(.region(MKCoordinateRegion(
                center: only.mapDisplayCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))
            return
        }

        let rects = coordinates.map {
            MKMapRect(origin: MKMapPoint($0.mapDisplayCoordinate), size: MKMapSize(width: 0, height: 0))
        }
        var union = rects[0]
        for rect in rects.dropFirst() {
            union = union.union(rect)
        }
        setCameraPosition(.rect(union.insetBy(dx: -union.size.width * 0.35, dy: -union.size.height * 0.35)))
    }

    private func setCameraPosition(_ newPosition: MapCameraPosition) {
        isProgrammaticCameraUpdate = true
        position = newPosition
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            isProgrammaticCameraUpdate = false
        }
    }

    private func angularDifference(from lhs: Double, to rhs: Double) -> Double {
        var delta = abs(lhs - rhs).truncatingRemainder(dividingBy: 360)
        if delta > 180 {
            delta = 360 - delta
        }
        return delta
    }

    static func == (lhs: RouteMapView, rhs: RouteMapView) -> Bool {
        let lhsHeading = lhs.courseDegrees.map { Int($0.rounded()) }
        let rhsHeading = rhs.courseDegrees.map { Int($0.rounded()) }

        return lhs.coordinates.count == rhs.coordinates.count
            && lhs.coordinates.last == rhs.coordinates.last
            && lhs.currentCoordinate == rhs.currentCoordinate
            && lhsHeading == rhsHeading
            && lhs.palette == rhs.palette
            && lhs.mode == rhs.mode
            && lhs.interactionEnabled == rhs.interactionEnabled
    }
}
