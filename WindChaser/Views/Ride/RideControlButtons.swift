import Combine
import SwiftUI

struct LongPressEndButton: View {
    let onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var isPressing = false
    @State private var pressBeganAt: Date?
    @State private var lastHapticSecond = 0

    private let duration: TimeInterval = 3
    private let size: CGFloat = 64

    var body: some View {
        ZStack {
            // 实体阻尼下陷特效
            Circle()
                .fill(
                    LinearGradient(
                        colors: [RideButtonStyle.end, RideButtonStyle.end.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: RideButtonStyle.end.opacity(0.35), radius: isPressing ? 4 : 8, y: isPressing ? 1 : 4)

            // 高大发光微渐变环
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size - 8, height: size - 8)
                .shadow(color: .white.opacity(isPressing ? 0.6 : 0), radius: 6)

            Image(systemName: "stop.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RideButtonStyle.endForeground)
                .scaleEffect(isPressing ? 0.85 : 1.0)
                .rotationEffect(.degrees(isPressing ? 90 : 0))
        }
        .contentShape(Circle())
        .scaleEffect(isPressing ? 0.88 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressing)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    beginPressIfNeeded()
                }
                .onEnded { _ in
                    cancelPress()
                }
        )
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            updateProgress()
        }
    }

    private func beginPressIfNeeded() {
        guard !isPressing else { return }
        isPressing = true
        pressBeganAt = Date()
        lastHapticSecond = 0
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func cancelPress() {
        isPressing = false
        pressBeganAt = nil
        lastHapticSecond = 0
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            progress = 0
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func updateProgress() {
        guard isPressing, let pressBeganAt else { return }

        let elapsed = Date().timeIntervalSince(pressBeganAt)
        let newProgress = min(1, elapsed / duration)

        withAnimation(.linear(duration: 0.05)) {
            progress = newProgress
        }

        let second = Int(elapsed)
        if second > lastHapticSecond, second < Int(duration) {
            lastHapticSecond = second
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred() // 使用刚性震击，更具机械反馈感
        }

        if newProgress >= 1 {
            isPressing = false
            self.pressBeganAt = nil
            progress = 0
            lastHapticSecond = 0
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onComplete()
        }
    }
}

struct RideControlButtons: View {
    let isPaused: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onEnd: () -> Void

    private let buttonSize: CGFloat = 64
    private let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)

    var body: some View {
        HStack(spacing: isPaused ? 32 : 0) {
            if isPaused {
                controlButton(
                    icon: "play.fill",
                    background: RideButtonStyle.resume,
                    foreground: RideButtonStyle.resumeForeground,
                    shadowColor: RideButtonStyle.resume.opacity(0.3),
                    action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onResume()
                    }
                )
                .transition(.scale.combined(with: .opacity))

                LongPressEndButton(onComplete: onEnd)
                    .transition(.scale.combined(with: .opacity))
            } else {
                controlButton(
                    icon: "pause.fill",
                    background: RideButtonStyle.pause,
                    foreground: RideButtonStyle.pauseForeground,
                    shadowColor: Color.black.opacity(0.1),
                    action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onPause()
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: buttonSize)
        .animation(spring, value: isPaused)
    }

    private func controlButton(
        icon: String,
        background: Color,
        foreground: Color,
        shadowColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [background, background.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: shadowColor, radius: 8, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
