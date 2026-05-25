import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showsGridCustomizationPlaceholder = false

    private var palette: ThemePalette {
        SolarTheme.palette()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Hardware Cockpit Diagnostics Section
                    // Phase 2: 仅保留 GPS 与心率（Apple Watch）两项，与设备检测页对齐。
                    // 踏频 / 功率 / 速度传感器从 UI 中移除；心率 4 态接入由 S6 完成。
                    settingsSectionCard(
                        title: "硬件与数据传感器",
                        subtitle: "SENSOR DIAGNOSTICS & TELEMETRY",
                        icon: "wifi"
                    ) {
                        VStack(spacing: 0) {
                            sensorStatusRow(
                                icon: "location.fill",
                                name: "核心定位 (GPS)",
                                statusText: appModel.gpsStatus.rawValue,
                                active: appModel.gpsStatus == .ready,
                                activeColor: appModel.gpsStatus == .ready ? .green : .orange
                            )

                            dividerLine()

                            sensorStatusRow(
                                icon: "heart.fill",
                                name: "心率（Apple Watch）",
                                statusText: "未连接",
                                active: false,
                                activeColor: .red
                            )
                        }
                    }

                    // 2. Dash Configuration Button View
                    settingsSectionCard(
                        title: "仪表盘自定义",
                        subtitle: "DASHBOARD METRIC PREFERENCES",
                        icon: "square.grid.2x2.fill"
                    ) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showsGridCustomizationPlaceholder = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(palette.accentColor)
                                    .frame(width: 32, height: 32)
                                    .background(palette.accentColor.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("自定义宫格配置与排序")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(palette.primaryText)
                                    Text("调整 6 种骑行指标的显示顺序")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(palette.secondaryText)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(palette.secondaryText.opacity(0.6))
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }

                    // 3. Technical Specs Footer
                    versionFooterView
                        .padding(.top, 16)
                }
                .padding(16)
            }
            .background(palette.panelBackground)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .alert("即将推出", isPresented: $showsGridCustomizationPlaceholder) {
                Button("好", role: .cancel) {}
            } message: {
                Text("物理传感器配对与宫格顺序自定义将在后续固件更新中发布。")
            }
        }
    }

    private func settingsSectionCard<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.accentColor)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                    Text(subtitle.uppercased())
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
            }

            content()
        }
        .padding(18)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(palette.borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(palette == .nightDark ? 0.25 : 0.02), radius: 10, y: 4)
    }

    private func sensorStatusRow(
        icon: String,
        name: String,
        statusText: String,
        active: Bool,
        activeColor: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(active ? palette.primaryText : palette.secondaryText.opacity(0.7))
                .frame(width: 32, height: 32)
                .background(active ? palette.accentColor.opacity(0.1) : palette.borderColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Spacer()

            // 精密指示环 & 脉冲标签
            HStack(spacing: 6) {
                Circle()
                    .fill(activeColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: activeColor.opacity(0.8), radius: 3)

                Text(statusText)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(activeColor)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(activeColor.opacity(0.08))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(activeColor.opacity(0.15), lineWidth: 1)
            )
        }
        .padding(.vertical, 10)
    }

    private func dividerLine() -> some View {
        Rectangle()
            .fill(palette.borderColor)
            .frame(height: 1)
            .padding(.vertical, 4)
    }

    private var versionFooterView: some View {
        VStack(spacing: 6) {
            Image(systemName: "wind")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(palette.secondaryText.opacity(0.7))

            Text("WINDCHASER PRO")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(2.5)
                .foregroundStyle(palette.primaryText)

            Text("ENGINEERED FOR ELITE ATHLETES")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(palette.secondaryText)

            Text("v1.2.0 (Build 2026.05)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.secondaryText.opacity(0.6))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
