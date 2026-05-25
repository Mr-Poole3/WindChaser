import SwiftUI

struct ContentView: View {
    @StateObject private var connectivityStatus = WatchConnectivityStatus()

    var body: some View {
        VStack(spacing: 12) {
            logo
            statusDot
            statusText
            subtitleText
            heartRateText
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .task {
            connectivityStatus.start()
        }
    }

    private var logo: some View {
        Image(systemName: "wind")
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .accessibilityHidden(true)
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 16, height: 16)
            .shadow(color: statusColor.opacity(0.7), radius: 8)
            .accessibilityHidden(true)
    }

    private var statusText: some View {
        Text(statusTitle)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
    }

    private var subtitleText: some View {
        Text("由 iPhone 控制骑行")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.62))
    }

    @ViewBuilder
    private var heartRateText: some View {
        if relayState == .relaying, let currentHeartRate = connectivityStatus.currentHeartRate {
            Text("\(currentHeartRate) bpm")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(statusColor)
        }
    }

    private var relayState: WatchRelayState {
        connectivityStatus.relayState
    }

    private var statusColor: Color {
        switch relayState {
        case .disconnected:
            .red
        case .waitingForPhone:
            .yellow
        case .needsAuthorization:
            .orange
        case .relaying:
            .green
        }
    }

    private var statusTitle: String {
        switch relayState {
        case .disconnected:
            "连接中断"
        case .waitingForPhone:
            "等待 iPhone"
        case .needsAuthorization:
            "需授权"
        case .relaying:
            "心率传输中"
        }
    }
}

#Preview {
    ContentView()
}
