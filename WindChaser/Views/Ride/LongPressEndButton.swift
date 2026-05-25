import Combine
import SwiftUI

/// 长按 2 秒结束骑行的胶囊按钮。
///
/// 交互细节：
/// - 按下时白色进度从左向右填充
/// - 每过一秒触发刚性触感反馈
/// - 充满 2s 后触发 `.success` 通知触感并回调 `onComplete`
/// - 中途松手则进度回退、不触发结束
struct LongPressEndButton: View {
    let duration: TimeInterval
    let onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var isPressing = false
    @State private var pressBeganAt: Date?
    @State private var lastHapticSecond = 0

    private let palette = AppPalette.shared

    var body: some View {
        ZStack(alignment: .leading) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(palette.dangerColor)

                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.28))
                        .frame(width: proxy.size.width * progress)
                        .animation(.linear(duration: 0.05), value: progress)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(isPressing ? "继续按住…" : "长按结束")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 52)
        .clipShape(Capsule(style: .continuous))
        .shadow(color: palette.dangerColor.opacity(0.35), radius: 10, y: 4)
        .scaleEffect(isPressing ? 0.98 : 1.0)
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isPressing)
        .contentShape(Capsule(style: .continuous))
        .gesture(pressGesture)
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            tick()
        }
        .accessibilityLabel("长按结束骑行")
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in beginPressIfNeeded() }
            .onEnded { _ in cancelPressIfNotCompleted() }
    }

    private func beginPressIfNeeded() {
        guard !isPressing else { return }
        isPressing = true
        pressBeganAt = Date()
        lastHapticSecond = 0
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func cancelPressIfNotCompleted() {
        guard isPressing else { return }
        isPressing = false
        pressBeganAt = nil
        lastHapticSecond = 0
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            progress = 0
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func tick() {
        guard isPressing, let pressBeganAt else { return }

        let elapsed = Date().timeIntervalSince(pressBeganAt)
        let newProgress = min(1, CGFloat(elapsed / duration))
        progress = newProgress

        let second = Int(elapsed)
        if second > lastHapticSecond, second < Int(duration.rounded()) {
            lastHapticSecond = second
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }

        if newProgress >= 1 {
            isPressing = false
            self.pressBeganAt = nil
            lastHapticSecond = 0
            progress = 0
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onComplete()
        }
    }
}
