import SwiftUI

struct ContentView: View {
    @State private var connectivity = WatchConnectivityStatus()
    @State private var heartRate = WatchHeartRateRelay()

    var body: some View {
        VStack(spacing: 10) {
            logo
            statusDot
            statusText
            subtitleText
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .task {
            connectivity.start()
            await heartRate.bootstrap()
        }
        .onChange(of: heartRate.sampleSequence) {
            guard let bpm = heartRate.currentHeartRate,
                  let timestamp = heartRate.lastHeartRateAt else {
                return
            }
            connectivity.sendHeartRate(bpm, watchTimestamp: timestamp)
        }
        .onChange(of: relayState, initial: true) { _, newState in
            connectivity.sendRelayState(newState)
        }
        .onChange(of: connectivity.isReachable) { _, becameReachable in
            if becameReachable {
                connectivity.sendRelayState(relayState)
            }
        }
        .onChange(of: connectivity.controlCommandSequence) {
            guard let command = connectivity.latestControlCommand else { return }
            Task {
                await handleControlCommand(command)
            }
        }
    }

    // MARK: - Sections

    private var logo: some View {
        Image(systemName: "wind")
            .font(.system(size: 26, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .accessibilityHidden(true)
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 14, height: 14)
            .shadow(color: statusColor.opacity(0.7), radius: 6)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var statusText: some View {
        switch relayState {
        case .relaying:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(heartRate.currentHeartRate.map(String.init) ?? "--")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("bpm")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }

        case .needsAuthorization:
            Text("需授权")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

        case .waitingForPhone:
            Text("等待 iPhone")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

        case .disconnected:
            Text("连接中断")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var subtitleText: some View {
        Text(subtitle)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.62))
            .padding(.horizontal, 4)
    }

    // MARK: - Derived state

    private var relayState: WatchRelayState {
        // 1. HealthKit 明确拒绝 → 需授权
        if heartRate.authorizationStatus == .denied {
            return .needsAuthorization
        }

        // 2. WCS 已激活但不可达 → 连接中断
        if connectivity.isActivated && !connectivity.isReachable {
            return .disconnected
        }

        // 3. workout 正在跑且已收到心率 → 心率传输中
        if heartRate.isWorkoutActive && heartRate.currentHeartRate != nil {
            return .relaying
        }

        // 4. 其余情况都归为「等待 iPhone」——
        //    包括「未决定 / 已授权但还没拿到第一拍心率」「workout 还在启动」
        return .waitingForPhone
    }

    private var subtitle: String {
        switch relayState {
        case .relaying:
            "由 iPhone 控制骑行"
        case .needsAuthorization:
            "请在 Watch 端开启心率读取权限"
        case .waitingForPhone:
            "由 iPhone 控制骑行"
        case .disconnected:
            "请确认 iPhone 已解锁并在身边"
        }
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

    private func handleControlCommand(_ command: RideControlCommand) async {
        switch command {
        case .start:
            await heartRate.startWorkoutIfNeeded()
        case .pause:
            heartRate.pauseWorkout()
        case .resume:
            heartRate.resumeWorkout()
        case .end:
            await heartRate.stopWorkout()
        }
        connectivity.sendRelayState(relayState)
    }
}

#Preview {
    ContentView()
}
