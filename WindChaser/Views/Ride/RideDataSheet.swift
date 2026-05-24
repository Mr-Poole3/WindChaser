import SwiftUI

struct RideDataSheet: View {
    let metrics: LiveMetrics
    let palette: ThemePalette
    let isPaused: Bool
    let expansion: SheetExpansion
    let dragOffset: CGFloat
    let onToggleExpansion: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onEnd: () -> Void

    private let collapsedHeight: CGFloat = 120
    private let expandedFraction: CGFloat = 0.70

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom
            let expandedHeight = proxy.size.height * expandedFraction
            let height = currentHeight(totalHeight: proxy.size.height, expandedHeight: expandedHeight) + bottomInset

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                sheetBody(expandedHeight: expandedHeight, bottomInset: bottomInset)
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
                    .background(palette.panelBackground.opacity(0.93))
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
                    .overlay(
                        VStack {
                            Rectangle()
                                .fill(palette.borderColor)
                                .frame(height: 1)
                            Spacer()
                        }
                    )
                    .shadow(color: .black.opacity(0.08), radius: 10, y: -4)
                    .offset(y: dragOffset)
                    .gesture(dragGesture(totalHeight: proxy.size.height, expandedHeight: expandedHeight))
            }
        }
    }

    @ViewBuilder
    private func sheetBody(expandedHeight: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Button(action: onToggleExpansion) {
                VStack(spacing: 0) {
                    DragHandle(color: palette.handleColor)
                    if expansion == .collapsed {
                        CollapsedMetricRow(metrics: metrics, palette: palette)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            if expansion == .expanded {
                expandedContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, bottomInset)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: expansion)
    }

    private var expandedContent: some View {
        VStack(spacing: 20) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(DashboardMetric.allCases) { metric in
                    MetricGridCell(
                        title: metric.rawValue,
                        value: value(for: metric),
                        unit: unit(for: metric),
                        palette: palette
                    )
                }
            }
            .padding(.horizontal, 20)

            RideControlButtons(
                isPaused: isPaused,
                onPause: onPause,
                onResume: onResume,
                onEnd: onEnd
            )
            .padding(.bottom, 24)
        }
        .padding(.top, 8)
    }

    private func currentHeight(totalHeight: CGFloat, expandedHeight: CGFloat) -> CGFloat {
        switch expansion {
        case .collapsed:
            collapsedHeight
        case .expanded:
            expandedHeight
        }
    }

    private func dragGesture(totalHeight: CGFloat, expandedHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onEnded { value in
                let threshold = totalHeight * 0.12
                if value.translation.height < -threshold {
                    if expansion == .collapsed { onToggleExpansion() }
                } else if value.translation.height > threshold {
                    if expansion == .expanded { onToggleExpansion() }
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
}
