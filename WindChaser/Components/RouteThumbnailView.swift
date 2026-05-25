import SwiftUI

enum RoutePolylineSimplifier {
    static func simplify(_ coordinates: [MapCoordinate], maxPoints: Int) -> [MapCoordinate] {
        guard coordinates.count > maxPoints, maxPoints >= 2 else { return coordinates }

        let step = Double(coordinates.count - 1) / Double(maxPoints - 1)
        return (0..<maxPoints).map { index in
            let sourceIndex = min(coordinates.count - 1, Int((Double(index) * step).rounded()))
            return coordinates[sourceIndex]
        }
    }
}

/// Lightweight route preview for list rows. Avoids spawning MapKit for every history card.
struct RouteThumbnailView: View {
    let coordinates: [MapCoordinate]
    let palette: ThemePalette

    private var simplifiedCoordinates: [MapCoordinate] {
        RoutePolylineSimplifier.simplify(coordinates, maxPoints: 48)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.cardBackground,
                                palette.panelBackground
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if simplifiedCoordinates.count >= 2 {
                    Canvas { context, size in
                        drawRoute(in: &context, size: size)
                    }
                } else {
                    Image(systemName: "map")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.secondaryText.opacity(0.45))
                }
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
    }

    private func drawRoute(in context: inout GraphicsContext, size: CGSize) {
        let coords = simplifiedCoordinates
        guard coords.count >= 2 else { return }

        let latitudes = coords.map(\.latitude)
        let longitudes = coords.map(\.longitude)
        guard
            let minLat = latitudes.min(),
            let maxLat = latitudes.max(),
            let minLon = longitudes.min(),
            let maxLon = longitudes.max()
        else { return }

        let latSpan = max(maxLat - minLat, 0.00005)
        let lonSpan = max(maxLon - minLon, 0.00005)
        let padding: CGFloat = 8
        let drawableWidth = max(size.width - padding * 2, 1)
        let drawableHeight = max(size.height - padding * 2, 1)

        func point(for coordinate: MapCoordinate) -> CGPoint {
            let x = padding + CGFloat((coordinate.longitude - minLon) / lonSpan) * drawableWidth
            let y = padding + (1 - CGFloat((coordinate.latitude - minLat) / latSpan)) * drawableHeight
            return CGPoint(x: x, y: y)
        }

        var path = Path()
        path.move(to: point(for: coords[0]))
        for coordinate in coords.dropFirst() {
            path.addLine(to: point(for: coordinate))
        }

        context.stroke(
            path,
            with: .color(RideButtonStyle.routeOrange),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        )
    }
}
