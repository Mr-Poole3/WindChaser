import SwiftUI

struct RideShareCardView: View {
    let summary: RideSummary
    let palette: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            routeSection
            heroMetrics
            secondaryMetrics
            watermark
        }
        .padding(24)
        .frame(width: 390)
        .background(
            LinearGradient(
                colors: [
                    palette.panelBackground,
                    palette.cardBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(palette.borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WINDCHASER")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(3)
                .foregroundStyle(palette.accentColor)

            Text("骑行报告")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Text(MetricFormatter.date(summary.startedAt))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.secondaryText)
        }
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ROUTE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(palette.secondaryText)

            RouteThumbnailView(
                coordinates: summary.routeCoordinates,
                palette: palette
            )
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(palette.borderColor, lineWidth: 1)
            )
        }
    }

    private var heroMetrics: some View {
        HStack(spacing: 12) {
            heroMetric(
                title: "总距离",
                value: MetricFormatter.distance(kilometers: summary.distanceMeters / 1_000),
                unit: "km"
            )
            heroMetric(
                title: "总用时",
                value: MetricFormatter.duration(summary.elapsed),
                unit: ""
            )
            heroMetric(
                title: "均速",
                value: MetricFormatter.speed(kmh: summary.averageSpeedKmh),
                unit: "km/h"
            )
        }
    }

    private var secondaryMetrics: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            shareMetric("最大速度", MetricFormatter.speed(kmh: summary.maxSpeedKmh), "km/h")
            shareMetric("总爬升", MetricFormatter.altitude(meters: summary.totalAscentMeters), "m")
            shareMetric("最高海拔", MetricFormatter.altitude(meters: summary.maxAltitude), "m")
            shareMetric("卡路里", MetricFormatter.calories(summary.calories), "kcal")
        }
    }

    private var watermark: some View {
        HStack {
            Image(systemName: "bicycle")
                .font(.system(size: 14, weight: .bold))
            Text("追风码表 · WindChaser")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            Spacer()
        }
        .foregroundStyle(palette.secondaryText.opacity(0.85))
        .padding(.top, 4)
    }

    private func heroMetric(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.secondaryText)
            MetricValueText(
                value: value,
                unit: unit,
                palette: palette,
                font: .system(.title2, design: .rounded).weight(.heavy)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(palette.borderColor, lineWidth: 1)
        )
    }

    private func shareMetric(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(palette.secondaryText)
            MetricValueText(
                value: value,
                unit: unit,
                palette: palette,
                font: .system(.headline, design: .rounded).weight(.bold)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(palette.cardBackground.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
