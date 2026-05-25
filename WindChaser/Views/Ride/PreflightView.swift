import SwiftUI

struct PreflightView: View {
    @Environment(AppModel.self) private var appModel

    private let palette = AppPalette.shared
    private let wcsManager = WCSManager.shared

    @State private var showsHeartInstructions = false

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
        .sheet(isPresented: $showsHeartInstructions) {
            HeartConnectionInstructionsSheet(state: heartChecklistState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Sensor Checklist Card

    private var sensorChecklistCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(sensors.enumerated()), id: \.element.id) { index, sensor in
                SensorChecklistRow(
                    item: sensor,
                    palette: palette,
                    onTap: sensor.id == "heart" ? { showsHeartInstructions = true } : nil
                )

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
    /// - 心率（Apple Watch）：4 态由 `WCSManager` + Watch 上报的 `WatchRelayState` 合成。
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
                state: heartChecklistState
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

    /// 心率（Apple Watch）4 态合成：
    /// 1. 最近 < 10s 收到过心率 → 已连接（绿）
    /// 2. Watch 上报需要授权 → 需授权（黄）
    /// 3. 链路完整通畅 → 已就绪（蓝灰）
    /// 4. 其余 → 未连接（灰）
    private var heartChecklistState: SensorChecklistState {
        if let lastSeen = wcsManager.lastHeartRateAt,
           Date().timeIntervalSince(lastSeen) < 10 {
            return .connected(detail: "已连接")
        }

        if wcsManager.lastReportedRelayState == .needsAuthorization {
            return .warning(detail: "需授权")
        }

        if wcsManager.isActivated
            && wcsManager.isPaired
            && wcsManager.isWatchAppInstalled
            && wcsManager.isReachable {
            return .ready(detail: "已就绪")
        }

        return .disconnected(detail: "未连接")
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
    case ready(detail: String)
    case warning(detail: String)
    case disconnected(detail: String)

    var detail: String {
        switch self {
        case .connected(let detail),
             .ready(let detail),
             .warning(let detail),
             .disconnected(let detail):
            return detail
        }
    }

    var indicatorColor: Color {
        switch self {
        case .connected, .ready:
            return AppPalette.shared.accentColor
        case .warning:
            return AppPalette.shared.warningColor
        case .disconnected:
            return Color(red: 0.40, green: 0.40, blue: 0.44)
        }
    }

    var isActive: Bool {
        switch self {
        case .connected, .ready, .warning:
            return true
        case .disconnected:
            return false
        }
    }
}

private struct SensorChecklistRow: View {
    let item: SensorChecklistItem
    let palette: AppPalette
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 14) {
                iconBadge

                Text(item.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Spacer(minLength: 8)

                statusPill

                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.secondaryText.opacity(0.75))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
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

// MARK: - Heart Connection Instructions Sheet

private struct HeartConnectionInstructionsSheet: View {
    let state: SensorChecklistState

    @Environment(\.dismiss) private var dismiss

    private let palette = AppPalette.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusHeader

                    VStack(alignment: .leading, spacing: 16) {
                        instructionSection(
                            number: 1,
                            title: "佩戴 Apple Watch 并解锁",
                            detail: "Watch 需正常佩戴在手腕上，且与配对 iPhone 在 10 米范围内。"
                        )
                        instructionSection(
                            number: 2,
                            title: "打开 WindChaser Watch App",
                            detail: "在 Watch 上找到 WindChaser 应用并打开，首次使用需手动启动一次。"
                        )
                        instructionSection(
                            number: 3,
                            title: "在 Watch 上授权心率与运动",
                            detail: "弹出 HealthKit 授权时，请允许『心率读取』与『运动数据写入』两项权限。"
                        )
                        instructionSection(
                            number: 4,
                            title: "开始骑行后 5–10 秒内确认连接",
                            detail: "iPhone 开始骑行后，Watch 会自动进入运动会话并开始上报心率，链路状态会变为『已连接』。"
                        )
                    }

                    troubleshootingSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(palette.panelBackground.ignoresSafeArea())
            .navigationTitle("心率（Apple Watch）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(palette.primaryText)
                }
            }
            .toolbarBackground(palette.panelBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private var statusHeader: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(state.indicatorColor)
                .frame(width: 14, height: 14)
                .shadow(color: state.indicatorColor.opacity(0.5), radius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text("当前状态：\(state.detail)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Text(headerSubtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()
        }
        .padding(16)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.borderColor, lineWidth: 1)
        )
    }

    private var headerSubtitle: String {
        switch state {
        case .connected:
            return "Apple Watch 正在实时上报心率。"
        case .ready:
            return "链路已就绪，开始骑行后将自动接收心率。"
        case .warning:
            return "请在 Watch 上完成 HealthKit 授权。"
        case .disconnected:
            return "Apple Watch 未连接或 Watch App 未运行。"
        }
    }

    private func instructionSection(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(palette.cardBackground)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.primaryText)
            }
            .overlay(
                Circle().stroke(palette.borderColor, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                Text(detail)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var troubleshootingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("仍未连接？")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            VStack(alignment: .leading, spacing: 6) {
                bullet("确认 iPhone 与 Watch 蓝牙均开启，且处于已配对状态。")
                bullet("在 iPhone Watch App → 我的手表 → 通用 → 后台 App 刷新 中允许 WindChaser。")
                bullet("在 Watch 设置 → 健康 → 数据访问 中确认 WindChaser 已被授权。")
            }
        }
        .padding(16)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.borderColor, lineWidth: 1)
        )
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(palette.secondaryText)
            Text(text)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
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
