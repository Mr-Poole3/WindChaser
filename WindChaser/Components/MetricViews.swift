import SwiftUI

struct DragHandle: View {
    let color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: 40, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
    }
}

struct MetricValueText: View {
    let value: String
    let unit: String
    let palette: ThemePalette
    var font: Font = .system(.title2, design: .rounded).weight(.bold)

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(font)
                .monospacedDigit()
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette == .nightDark ? palette.accentColor : palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

struct MetricGridCell: View {
    let title: String
    let value: String
    let unit: String
    let palette: ThemePalette

    var body: some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)

            MetricValueText(
                value: value,
                unit: unit,
                palette: palette,
                font: .system(.title2, design: .rounded).weight(.heavy)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(palette.borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(palette == .nightDark ? 0.3 : 0.03), radius: 8, y: 4)
    }
}

struct CollapsedMetricRow: View {
    let metrics: LiveMetrics
    let palette: ThemePalette

    var body: some View {
        HStack(alignment: .bottom) {
            sideMetric(
                title: "时长",
                value: MetricFormatter.duration(metrics.elapsed),
                unit: ""
            )

            Spacer(minLength: 8)

            VStack(spacing: 4) {
                Text("速度".uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(palette.secondaryText)
                MetricValueText(
                    value: MetricFormatter.speed(kmh: metrics.speedKmh, isValid: metrics.speedValid),
                    unit: MetricFormatter.speedUnit(kmh: metrics.speedKmh, isValid: metrics.speedValid),
                    palette: palette,
                    font: .system(size: 34, weight: .black, design: .rounded)
                )
            }

            Spacer(minLength: 8)

            sideMetric(
                title: "距离",
                value: MetricFormatter.distance(kilometers: metrics.distanceMeters / 1_000),
                unit: MetricFormatter.distanceUnit(kilometers: metrics.distanceMeters / 1_000)
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private func sideMetric(title: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(palette.secondaryText)
            MetricValueText(
                value: value,
                unit: unit,
                palette: palette,
                font: .system(.title3, design: .rounded).weight(.bold)
            )
        }
        .frame(maxWidth: 88)
    }
}
