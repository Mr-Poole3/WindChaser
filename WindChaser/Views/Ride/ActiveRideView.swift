import SwiftUI

struct ActiveRideView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showsEndConfirmation = false

    private let palette = AppPalette.shared
    private let themePalette = ThemePalette.nightDark

    var body: some View {
        ZStack(alignment: .top) {
            if let session = appModel.rideSession {
                ActiveRideMapLayer(
                    coordinates: session.routeCoordinates,
                    currentCoordinate: session.currentCoordinate,
                    courseDegrees: session.metrics.courseDegrees,
                    palette: themePalette
                )
                .equatable()
                .ignoresSafeArea()

                topStatusBar
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                bottomPanel(for: session)
            } else {
                ProgressView("正在准备骑行…")
                    .tint(palette.primaryText)
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(palette.panelBackground)
            }
        }
        .background(palette.panelBackground)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "结束本次骑行？",
            isPresented: $showsEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("结束骑行", role: .destructive) {
                appModel.finishRide()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("当前的距离、时间与轨迹将保存到历史。")
        }
    }

    // MARK: - Top Status Bar (GPS + close)

    private var topStatusBar: some View {
        HStack {
            gpsIndicator
            Spacer()
            topMenuButton
        }
    }

    private var gpsIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: gpsIcon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(gpsColor)

            Text(appModel.gpsStatus.rawValue)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var topMenuButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showsEndConfirmation = true
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(Color.black.opacity(0.55))
                )
                .overlay(
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .accessibilityLabel("结束骑行")
    }

    private var gpsIcon: String {
        switch appModel.gpsStatus {
        case .ready:
            return "location.fill"
        case .weak:
            return "location"
        case .searching:
            return "location.circle"
        case .unavailable:
            return "location.slash"
        }
    }

    private var gpsColor: Color {
        switch appModel.gpsStatus {
        case .ready:
            return palette.accentColor
        case .weak, .searching:
            return palette.warningColor
        case .unavailable:
            return palette.dangerColor
        }
    }

    // MARK: - Bottom Panel

    @ViewBuilder
    private func bottomPanel(for session: RideSession) -> some View {
        ActiveRideBottomPanel(
            state: session.state,
            metrics: session.metrics,
            onPause: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                session.pause()
            },
            onResume: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                session.resume()
            },
            onEnd: {
                appModel.finishRide()
            }
        )
    }
}
