import SwiftUI

import SwiftUI

struct PreflightView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isPulsing = false

    private var palette: ThemePalette {
        SolarTheme.palette()
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // 具有科技呼吸感的 GPS 图标
            ZStack {
                Circle()
                    .stroke(statusColor.opacity(0.15), lineWidth: 4)
                    .frame(width: 110, height: 110)
                    .scaleEffect(isPulsing ? 1.3 : 0.9)
                    .opacity(isPulsing ? 0 : 0.8)

                Circle()
                    .stroke(statusColor.opacity(0.25), lineWidth: 1)
                    .frame(width: 90, height: 90)
                    .scaleEffect(isPulsing ? 1.15 : 0.95)

                Image(systemName: "location.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(statusColor)
                    .shadow(color: statusColor.opacity(0.3), radius: isPulsing ? 12 : 4, y: 2)
                    .scaleEffect(isPulsing ? 1.03 : 0.97)
            }
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: isPulsing)

            // 高大上的 GPS Cockpit 卡片
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("定位传感器")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(2.0)
                        .foregroundStyle(palette.secondaryText)
                    Text(appModel.gpsStatus.rawValue.uppercased())
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(statusColor)
                }

                Divider()
                    .background(palette.borderColor)

                Text("确认定位正常后即可开始记录。多传感器融合芯片将在后台提供精确的速度、功率及海拔坡度融合计算。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(palette.borderColor, lineWidth: 1)
            )
            .shadow(color: .black.opacity(palette == .nightDark ? 0.35 : 0.03), radius: 15, y: 6)
            .padding(.horizontal, 24)

            Spacer()

            // 独家定制的极简酷炫大型开始按钮
            Button(action: {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                appModel.startRide()
            }) {
                Text("开始新骑行".uppercased())
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .tracking(2.0)
                    .foregroundStyle(palette == .nightDark ? Color.black : Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Capsule()
                            .fill(palette == .nightDark ? palette.accentColor : palette.primaryText)
                    )
                    .shadow(color: (palette == .nightDark ? palette.accentColor : palette.primaryText).opacity(0.35), radius: 12, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear {
            isPulsing = true
        }
        .navigationTitle("骑行")
        .navigationBarTitleDisplayMode(.inline)
        .background(palette.panelBackground)
    }

    private var statusColor: Color {
        switch appModel.gpsStatus {
        case .ready:
            palette == .nightDark ? palette.accentColor : .green
        case .searching:
            .orange
        case .weak:
            .yellow
        case .unavailable:
            .red
        }
    }
}

// 按钮微缩放手感交互
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
