import SwiftUI

import SwiftUI

struct HistoryListView: View {
    @Environment(AppModel.self) private var appModel

    private var palette: ThemePalette {
        SolarTheme.palette()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if appModel.historyRecords.isEmpty {
                        ContentUnavailableView("尚无骑行记录", systemImage: "clock.arrow.circlepath")
                            .foregroundStyle(palette.secondaryText)
                            .padding(.top, 60)
                    } else {
                        ForEach(appModel.historyRecords) { record in
                            NavigationLink(value: record.id) {
                                HistoryRowView(record: record, palette: palette)
                            }
                            .buttonStyle(CardTapButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .navigationTitle("历史记录")
            .background(palette.panelBackground)
            .navigationDestination(for: UUID.self) { id in
                if let record = appModel.record(for: id) {
                    RideReportView(summary: record, showsDoneButton: false)
                }
            }
        }
    }
}

struct HistoryRowView: View {
    let record: RideSummary
    let palette: ThemePalette

    var body: some View {
        HStack(spacing: 16) {
            // 高端微裁边缩略图
            RouteMapView(
                coordinates: record.routeCoordinates,
                palette: palette,
                interactionEnabled: false
            )
            .frame(width: 96, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(palette.borderColor, lineWidth: 1)
            )
            .allowsHitTesting(false)

            // 信息排版精细调整 — 右对齐或错落有致
            VStack(alignment: .leading, spacing: 6) {
                Text(MetricFormatter.date(record.startedAt))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                HStack(spacing: 4) {
                    Text(MetricFormatter.distance(kilometers: record.distanceMeters / 1_000))
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(palette == .nightDark ? palette.accentColor : palette.primaryText)
                    Text("KM")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(palette.secondaryText)

                    Text("·")
                        .foregroundStyle(palette.secondaryText)

                    Text(MetricFormatter.duration(record.elapsed))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(palette.primaryText)
                }

                Text("均速 \(MetricFormatter.speed(kmh: record.averageSpeedKmh)) km/h")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(palette.secondaryText.opacity(0.5))
        }
        .padding(14)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(palette == .nightDark ? 0.25 : 0.02), radius: 8, y: 3)
    }
}

// 卡片专用点击动效，带来极高阶手感
struct CardTapButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
