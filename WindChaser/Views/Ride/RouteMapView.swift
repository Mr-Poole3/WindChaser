import MapKit
import SwiftUI

struct RouteMapView: View {
    let coordinates: [MapCoordinate]
    let palette: ThemePalette
    var interactionEnabled: Bool = false

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Group {
            if palette.mapStyle == .standard {
                mapContent
                    .mapStyle(.standard(elevation: .realistic))
            } else {
                mapContent
                    .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll))
            }
        }
        .onAppear {
            fitRoute()
        }
        .onChange(of: coordinates.count) {
            fitRoute()
        }
    }

    private var mapContent: some View {
        Map(position: $position, interactionModes: interactionEnabled ? .all : []) {
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates.map(\.clLocationCoordinate))
                    .stroke(RideButtonStyle.routeOrange, lineWidth: 4)
            }

            if let last = coordinates.last {
                Marker("Current", coordinate: last.clLocationCoordinate)
            }
        }
    }

    private func fitRoute() {
        guard !coordinates.isEmpty else { return }

        if coordinates.count == 1, let only = coordinates.first {
            position = .region(MKCoordinateRegion(
                center: only.clLocationCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
            return
        }

        let rects = coordinates.map {
            MKMapRect(origin: MKMapPoint($0.clLocationCoordinate), size: MKMapSize(width: 0, height: 0))
        }
        var union = rects[0]
        for rect in rects.dropFirst() {
            union = union.union(rect)
        }
        position = .rect(union.insetBy(dx: -union.size.width * 0.35, dy: -union.size.height * 0.35))
    }
}
