import SwiftUI

struct PreflightView: View {
    @Environment(AppModel.self) private var appModel

    private let palette = AppPalette.shared

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    sensorChecklistCard
                        .padding(.top, 16)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }

            startRideButton
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
        .background(palette.panelBackground.ignoresSafeArea())
        .navigationTitle("设备检测")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.panelBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Sensor Checklist Card

    private var sensorChecklistCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(sensors.enumerated()), id: \.element.id) { index, sensor in
                SensorChecklistRow(item: sensor, palette: palette)

                if index < sensors.count - 1 {
                    Rectangle()
                        .fill(palette.borderColor)
                        .frame(height: 1)
                        .padding(.leading, 64)
                }
            }
        }
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
    }

    /// 设备状态清单。
    /// - GPS：使用 `AppModel.gpsStatus` 的真实状态。
    /// - 心率（Apple Watch）：本阶段尚未接入 Watch 心率链路（Phase 2 / S4 后启用），
    ///   暂时统一展示"未连接"，避免任何捏造数据。完整 4 态显示与点击说明由 S6 接入。
    private var sensors: [SensorChecklistItem] {
        [
            SensorChecklistItem(
                id: "gps",
                icon: "location.fill",
                title: "GPS信号",
                state: gpsChecklistState
            ),
            SensorChecklistItem(
                id: "heart",
                icon: "heart.fill",
                title: "心率（Apple Watch）",
                state: .disconnected(detail: "未连接")
            )
        ]
    }

    private var gpsChecklistState: SensorChecklistState {
        switch appModel.gpsStatus {
        case .ready:
            return .connected(detail: "已连接")
        case .weak:
            return .warning(detail: "信号较弱")
        case .searching:
            return .warning(detail: "搜索中")
        case .unavailable:
            return .disconnected(detail: "未连接")
        }
    }

    // MARK: - Start Ride Button

    private var startRideButton: some View {
        Button(action: {
            guard !appModel.isStartingRide else { return }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            appModel.startRide()
        }) {
            Group {
                if appModel.isStartingRide {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text("开始骑行")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
            }
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white)
            )
            .shadow(color: Color.white.opacity(0.18), radius: 12, y: 6)
        }
        .disabled(appModel.isStartingRide)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Sensor Checklist Models

private struct SensorChecklistItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let state: SensorChecklistState
}

private enum SensorChecklistState {
    case connected(detail: String)
    case warning(detail: String)
    case disconnected(detail: String)

    var detail: String {
        switch self {
        case .connected(let detail), .warning(let detail), .disconnected(let detail):
            return detail
        }
    }

    var indicatorColor: Color {
        switch self {
        case .connected:
            return AppPalette.shared.accentColor
        case .warning:
            return AppPalette.shared.warningColor
        case .disconnected:
            return Color(red: 0.40, green: 0.40, blue: 0.44)
        }
    }

    var isActive: Bool {
        switch self {
        case .connected, .warning:
            return true
        case .disconnected:
            return false
        }
    }
}

private struct SensorChecklistRow: View {
    let item: SensorChecklistItem
    let palette: AppPalette

    var body: some View {
        HStack(spacing: 14) {
            iconBadge

            Text(item.title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Spacer(minLength: 8)

            statusPill
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(badgeFill)
                .frame(width: 36, height: 36)

            Image(systemName: item.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(badgeForeground)
        }
    }

    private var badgeFill: Color {
        item.state.isActive ? item.state.indicatorColor.opacity(0.16) : palette.borderColor
    }

    private var badgeForeground: Color {
        item.state.isActive ? item.state.indicatorColor : palette.secondaryText
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Text(item.state.detail)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(item.state.isActive ? palette.primaryText : palette.secondaryText)
                .lineLimit(1)

            Circle()
                .fill(item.state.indicatorColor)
                .frame(width: 8, height: 8)
                .shadow(
                    color: item.state.isActive ? item.state.indicatorColor.opacity(0.6) : .clear,
                    radius: 4
                )
        }
    }
}

// MARK: - Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        PreflightView()
    }
    .environment(AppModel())
    .preferredColorScheme(.dark)
}
