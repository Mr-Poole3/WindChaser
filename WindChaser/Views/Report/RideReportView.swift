import SwiftUI

struct RideReportView: View {
    let summary: RideSummary
    var showsDoneButton: Bool = true
    var onDone: (() -> Void)?

    @State private var mapExpansion: ReportMapExpansion = .compact
    @State private var showsSharePlaceholder = false

    private var palette: ThemePalette {
        SolarTheme.palette()
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                if mapExpansion == .expanded {
                    // 展开状态：地图固定于上方（占比大），下方显示精简指标
                    expandedMapSection(totalHeight: proxy.size.height)
                    expandedSummaryStrip
                        .frame(height: proxy.size.height * 0.28)
                        .background(palette.panelBackground)
                        .overlay(
                            VStack {
                                Rectangle()
                                    .fill(palette.borderColor)
                                    .frame(height: 1)
                                Spacer()
                            }
                        )
                } else {
                    // 紧凑状态：地图作为卡片嵌入，随页面整体滚动
                    ScrollView {
                        VStack(spacing: 24) {
                            // 1. 轨迹地图卡片（支持点击展开）
                            mapCardSection(totalHeight: proxy.size.height)

                            // 2. 性能核心卡片
                            reportGroupCard(
                                title: "性能核心",
                                subtitle: "PERFORMANCE CORE",
                                icon: "bolt.fill",
                                accentColor: palette.accentColor
                            ) {
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                                    reportCell("总用时", MetricFormatter.duration(summary.elapsed), "")
                                    reportCell("总距离", MetricFormatter.distance(kilometers: summary.distanceMeters / 1_000), "km")
                                    reportCell("平均速度", MetricFormatter.speed(kmh: summary.averageSpeedKmh), "km/h")
                                    reportCell("最大速度", MetricFormatter.speed(kmh: summary.maxSpeedKmh), "km/h")
                                }
                            }

                            // 3. 体能与动力卡片
                            reportGroupCard(
                                title: "体能与动力",
                                subtitle: "BIOMETRICS & WATTS",
                                icon: "heart.text.square.fill",
                                accentColor: .red
                            ) {
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                                    reportCell("均心率", MetricFormatter.heartRate(summary.averageHeartRate), summary.averageHeartRate == nil ? "—" : "bpm")
                                    reportCell("均踏频", MetricFormatter.cadence(summary.averageCadence), summary.averageCadence == nil ? "—" : "rpm")
                                    reportCell("平均功率", MetricFormatter.power(summary.averagePower), summary.averagePower == nil ? "—" : "W")
                                    reportCell("卡路里", MetricFormatter.calories(summary.calories), "kcal")
                                }
                            }

                            // 4. 地形与海拔卡片
                            reportGroupCard(
                                title: "地形与海拔",
                                subtitle: "TERRAIN & ELEVATION",
                                icon: "mountain.2.fill",
                                accentColor: .blue
                            ) {
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                                    reportCell("总爬升", MetricFormatter.altitude(meters: summary.totalAscentMeters), "m")
                                    reportCell("最高海拔", MetricFormatter.altitude(meters: summary.maxAltitude), "m")
                                    reportCell("最大坡度", MetricFormatter.grade(percent: summary.maxGrade), "%")
                                    Spacer().frame(height: 1) // Layout balancer
                                }
                            }

                            shareButton
                                .padding(.top, 8)
                                .padding(.bottom, 24)
                        }
                        .padding(16)
                    }
                    .background(palette.panelBackground)
                }
            }
        }
        .navigationTitle("骑行报告")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(showsDoneButton)
        .background(palette.panelBackground)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let gpxURL = exportGPX() {
                        ShareLink(item: gpxURL) {
                            Label("导出 GPX", systemImage: "map")
                        }
                    }
                    if let csvURL = exportCSV() {
                        ShareLink(item: csvURL) {
                            Label("导出 CSV", systemImage: "doc.text")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(palette.accentColor)
                }
            }

            if showsDoneButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onDone?()
                    } label: {
                        Text("完成")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                    }
                }
            }
        }
        .alert("分享图片", isPresented: $showsSharePlaceholder) {
            Button("好", role: .cancel) {}
        } message: {
            Text("分享功能将在后续接入。极简酷炫骑行水印海报正在装配中！")
        }
    }

    // 1. 嵌入滚动视图的地图卡片组件
    @ViewBuilder
    private func mapCardSection(totalHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.accentColor)
                    .frame(width: 28, height: 28)
                    .background(palette.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 1) {
                    Text("骑行轨迹")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                    Text("ROUTE MAP & TRACK")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text("全屏")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundStyle(palette.secondaryText.opacity(0.8))
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(palette.borderColor)
                .clipShape(Capsule())
            }

            // 高端圆角约束地图视窗
            RouteMapView(
                coordinates: summary.routeCoordinates,
                palette: palette,
                interactionEnabled: false
            )
            .frame(height: totalHeight * 0.28)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.borderColor, lineWidth: 1)
            )
        }
        .padding(18)
        .background(palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(palette.borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(palette == .nightDark ? 0.25 : 0.02), radius: 10, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                mapExpansion = .expanded
            }
        }
    }

    // 2. 展开模式下的自适应顶部大地图视图
    @ViewBuilder
    private func expandedMapSection(totalHeight: CGFloat) -> some View {
        let mapHeight = totalHeight * 0.72

        ZStack(alignment: .bottomTrailing) {
            RouteMapView(
                coordinates: summary.routeCoordinates,
                palette: palette,
                interactionEnabled: false
            )
            .frame(height: mapHeight)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    mapExpansion = .compact
                }
            }

            // 地图指示标签
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 10, weight: .bold))
                Text("收起地图")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(palette.cardBackground.opacity(0.85))
            .background(.ultraThinMaterial)
            .foregroundStyle(palette.primaryText)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(palette.borderColor, lineWidth: 1)
            )
            .padding(12)
            .shadow(color: .black.opacity(0.06), radius: 4)
            .allowsHitTesting(false)
        }
    }

    private var expandedSummaryStrip: some View {
        HStack(spacing: 0) {
            compactMetric(title: "总用时", value: MetricFormatter.duration(summary.elapsed), unit: "")
            Divider()
                .background(palette.borderColor)
                .frame(height: 36)
            compactMetric(
                title: "总距离",
                value: MetricFormatter.distance(kilometers: summary.distanceMeters / 1_000),
                unit: "km"
            )
            Divider()
                .background(palette.borderColor)
                .frame(height: 36)
            compactMetric(
                title: "平均速度",
                value: MetricFormatter.speed(kmh: summary.averageSpeedKmh),
                unit: "km/h"
            )
        }
        .padding(.horizontal, 16)
    }

    private func compactMetric(title: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(palette.secondaryText)
            MetricValueText(
                value: value,
                unit: unit,
                palette: palette,
                font: .system(.title2, design: .rounded).weight(.heavy)
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func reportGroupCard<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        accentColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accentColor)
                    .frame(width: 28, height: 28)
                    .background(accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                    Text(subtitle.uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
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

    private func reportCell(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(palette.secondaryText)
            MetricValueText(
                value: value,
                unit: unit,
                palette: palette,
                font: .system(.title3, design: .rounded).weight(.bold)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shareButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showsSharePlaceholder = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .bold))
                Text("分享酷炫水印大图")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .tracking(1.5)
            }
            .foregroundStyle(palette == .nightDark ? Color.black : Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(palette == .nightDark ? palette.accentColor : palette.primaryText)
                )
                .shadow(color: (palette == .nightDark ? palette.accentColor : palette.primaryText).opacity(0.3), radius: 10, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func exportGPX() -> URL? {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("rides")
            .appendingPathComponent("\(summary.id.uuidString).ridesqlite")
        guard let db = try? RideDatabase(fileURL: fileURL) else { return nil }
        let url = db.gpxExportURL()
        db.close()
        return url
    }

    private func exportCSV() -> URL? {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("rides")
            .appendingPathComponent("\(summary.id.uuidString).ridesqlite")
        guard let db = try? RideDatabase(fileURL: fileURL) else { return nil }
        let url = db.csvExportURL()
        db.close()
        return url
    }
}
