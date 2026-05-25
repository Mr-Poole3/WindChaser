import SwiftUI

/// 骑行主界面底部面板（可滑动展开）。
///
/// 进入页面时骑行已经在记录中，因此面板只处理 `.riding` / `.paused` / `.ended` 三态：
/// - 收起态：总时间 | 当前速度（放大居中） | 总距离 + 主按钮
/// - 展开态：8 个详细骑行指标 + 主按钮
/// - 主按钮按 `RideState` 切换：
///     - `.riding` → 「暂停」
///     - `.paused` → 「继续」+「长按结束」(2s)
///     - `.ended`  → 「保存中…」加载指示
struct ActiveRideBottomPanel: View {
    let state: RideState
    let metrics: LiveMetrics
    let onPause: () -> Void
    let onResume: () -> Void
    let onEnd: () -> Void

    @State private var expansion: SheetExpansion = .collapsed

    private let palette = AppPalette.shared
    private let themePalette = ThemePalette.nightDark

    private let collapsedHeight: CGFloat = 220
    private let expandedFraction: CGFloat = 0.72

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom
            let expandedHeight = proxy.size.height * expandedFraction
            let panelHeight = sheetHeight(expandedHeight: expandedHeight) + bottomInset

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                sheetBody(bottomInset: bottomInset)
                    .frame(height: panelHeight)
                    .frame(maxWidth: .infinity)
                    .background(panelBackground)
                    .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
                    .overlay(topBorder)
                    .shadow(color: .black.opacity(0.45), radius: 16, y: -4)
                    .gesture(dragGesture)
                    .animation(.spring(response: 0.38, dampingFraction: 0.85), value: expansion)
                    .animation(.spring(response: 0.38, dampingFraction: 0.85), value: state)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func sheetHeight(expandedHeight: CGFloat) -> CGFloat {
        switch expansion {
        case .collapsed:
            return collapsedHeight
        case .expanded:
            return max(expandedHeight, collapsedHeight)
        }
    }

    private var panelBackground: some View {
        palette.panelBackground.opacity(0.97)
    }

    private var topBorder: some View {
        VStack {
            Rectangle()
                .fill(palette.borderColor)
                .frame(height: 1)
            Spacer()
        }
    }

    // MARK: - Body

    @ViewBuilder
    private func sheetBody(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            handleArea

            if expansion == .expanded {
                expandedMetricsGrid
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            } else {
                collapsedMetricsBar
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 18)
                    .transition(.opacity)
            }

            primaryActionRow
                .padding(.horizontal, 20)
                .padding(.bottom, 12 + bottomInset)
        }
    }

    /// 顶部把手区域：点击在收起 / 展开之间切换。
    private var handleArea: some View {
        Button {
            toggleExpansion()
        } label: {
            Capsule()
                .fill(palette.handleColor)
                .frame(width: 44, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Collapsed metrics

    private var collapsedMetricsBar: some View {
        HStack(alignment: .top, spacing: 12) {
            sideMetricColumn(
                title: "总时间",
                value: MetricFormatter.duration(metrics.elapsed),
                unit: nil,
                alignment: .leading
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            centerSpeedColumn

            sideMetricColumn(
                title: "总距离",
                value: MetricFormatter.distance(kilometers: metrics.distanceMeters / 1_000),
                unit: "公里",
                alignment: .trailing
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func sideMetricColumn(
        title: String,
        value: String,
        unit: String?,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(palette.secondaryText)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let unit {
                Text(unit)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.secondaryText)
            }
        }
    }

    private var centerSpeedColumn: some View {
        let speedText = MetricFormatter.speed(kmh: metrics.speedKmh, isValid: metrics.speedValid)
        let unitText = MetricFormatter.speedUnit(kmh: metrics.speedKmh, isValid: metrics.speedValid)

        return VStack(spacing: 2) {
            Text("当前速度")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(palette.secondaryText)

            Text(speedText)
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Text(unitText.isEmpty ? "km/h" : unitText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Expanded grid

    private var expandedMetricsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(DashboardMetric.allCases) { metric in
                MetricGridCell(
                    title: metric.rawValue,
                    value: value(for: metric),
                    unit: unit(for: metric),
                    palette: themePalette
                )
            }
        }
    }

    private func value(for metric: DashboardMetric) -> String {
        switch metric {
        case .speed:
            MetricFormatter.speed(kmh: metrics.speedKmh, isValid: metrics.speedValid)
        case .distance:
            MetricFormatter.distance(kilometers: metrics.distanceMeters / 1_000)
        case .duration:
            MetricFormatter.duration(metrics.elapsed)
        case .heartRate:
            MetricFormatter.heartRate(metrics.heartRate)
        case .cadence:
            MetricFormatter.cadence(metrics.cadence)
        case .power:
            MetricFormatter.power(metrics.power)
        case .altitude:
            MetricFormatter.altitude(meters: metrics.altitude)
        case .grade:
            MetricFormatter.grade(percent: metrics.grade)
        }
    }

    private func unit(for metric: DashboardMetric) -> String {
        switch metric {
        case .speed:
            MetricFormatter.speedUnit(kmh: metrics.speedKmh, isValid: metrics.speedValid)
        case .distance:
            MetricFormatter.distanceUnit(kilometers: metrics.distanceMeters / 1_000)
        case .duration:
            ""
        case .heartRate:
            metrics.heartRate == nil ? "" : "bpm"
        case .cadence:
            metrics.cadence == nil ? "" : "rpm"
        case .power:
            metrics.power == nil ? "" : "W"
        case .altitude:
            metrics.altitude == nil ? "" : "m"
        case .grade:
            metrics.grade == nil ? "" : "%"
        }
    }

    // MARK: - Primary Action

    @ViewBuilder
    private var primaryActionRow: some View {
        switch state {
        case .riding:
            primaryFilledButton(title: "暂停", action: onPause)
        case .paused:
            HStack(spacing: 12) {
                LongPressEndButton(duration: 2.0, onComplete: onEnd)
                    .frame(maxWidth: .infinity)
                primaryFilledButton(title: "继续", action: onResume)
                    .frame(maxWidth: .infinity)
            }
        case .idle, .ended:
            ProgressView()
                .tint(palette.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
    }

    private func primaryFilledButton(
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white)
                )
                .shadow(color: Color.white.opacity(0.18), radius: 10, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onEnded { value in
                let threshold: CGFloat = 50
                if value.translation.height < -threshold, expansion == .collapsed {
                    setExpansion(.expanded)
                } else if value.translation.height > threshold, expansion == .expanded {
                    setExpansion(.collapsed)
                }
            }
    }

    private func toggleExpansion() {
        setExpansion(expansion == .collapsed ? .expanded : .collapsed)
    }

    private func setExpansion(_ next: SheetExpansion) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
            expansion = next
        }
    }
}
