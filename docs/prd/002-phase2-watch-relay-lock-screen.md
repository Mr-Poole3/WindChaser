# Phase 2 PRD: Watch 心率中继 + 锁屏实时活动 — WindChaser

## Problem Statement

Phase 1 让 iPhone 端可以独立完成 GPS 骑行记录（速度、距离、轨迹、仪表盘、存储）。但仍然有三个体验空缺：

1. 骑行时手机通常揣兜里或锁屏，每次查看数据都要掏手机解锁，不安全。
2. iPhone 自身没有心率传感器，骑行报告里缺少这项核心健康指标。
3. 骑行结束后，骑行记录没有写入系统健康 App / Activity 圆环，对 Apple 生态用户体验不完整。

## Solution

通过 Apple Watch 配套 App + ActivityKit + HealthKit 三件事配合：

1. Watch 端启动 `HKWorkoutSession + HKLiveWorkoutBuilder` 读取内置心率，通过 WatchConnectivity 实时推送给 iPhone。
2. iPhone 锁屏时通过 ActivityKit Live Activity 展示骑行核心数据（总时间、当前速度、总距离）。
3. 骑行结束时写入完整 `HKWorkout`（含 `HKWorkoutRoute` 和心率样本），让记录进入系统健康 App 和 Activity 圆环。

本阶段不接入任何 BLE 骑行外设；踏频 / 功率字段从 UI 中删除（数据模型字段保留，等 Phase 4 或之后再启用）。Watch 端为纯被动中继，不提供任何骑行控制 UI。

## User Stories

1. 作为骑手，我打开 Apple Watch 上的 WindChaser，首次会被引导开启 HealthKit 心率权限。
2. 作为骑手，我在 iPhone 设备检测页能看到 Watch 心率的连接状态（未连接 / 需授权 / 已就绪），点击可看说明。
3. 作为骑手，iPhone 上即使没戴 Watch 也能照常开始骑行；Watch 不可用时只在 UI 上提示心率不可用，不阻塞骑行。
4. 作为骑手，骑行开始后，Watch 自动启动一次 cycling workout，开始读取并发送心率给 iPhone。
5. 作为骑手，骑行中的展开仪表盘显示实时心率（来自 Watch）。
6. 作为骑手，心率短暂丢帧时（0-3 秒），仪表盘显示最后已知值 + 灰点提示数据已过期。
7. 作为骑手，丢帧超过 3 秒时，心率显示 `--`，恢复连接后立即清空灰点显示新值。
8. 作为骑手，锁屏后能看到骑行 Live Activity：总时间、当前速度（大字）、总距离。
9. 作为骑手，骑行暂停时锁屏 Live Activity 速度显示 `0.0` 并显示"已暂停"状态。
10. 作为骑手，骑行结束后，记录自动写入 HealthKit（HKWorkout + HKWorkoutRoute + 心率样本），出现在系统健康 App 和 Activity 圆环。
11. 作为骑手，骑行报告里的心率曲线是连续完整的——iPhone 在结束时从 HealthKit 拉取本次骑行时段内所有心率样本，补齐 WCS 实时通道丢失的段。
12. 作为骑手，我可以在设置里关闭锁屏实时活动。

## Implementation Decisions

### Watch App 角色与 UI

- **角色**：纯心率中继。无开始 / 暂停 / 结束按钮，这些归 Phase 4。
- **UI**：单页极简状态灯
  - 顶部 WindChaser logo
  - 中央状态圆点（绿 / 黄 / 红）+ 主文案：`心率传输中` / `等待 iPhone` / `需授权` / `连接中断`
  - 副文案 `由 iPhone 控制骑行`
  - 心率传输状态时同时显示当前 `bpm`
- **AppIcon**：复用 iOS 端品牌图形，按 watchOS 尺寸重新导出。允许 Phase 2 收尾前补齐完整尺寸集，不阻塞主功能开发。

### 心率数据源

- Watch 端 `HKWorkoutSession(activityType: .cycling)` + `HKLiveWorkoutBuilder`
- iPhone 端 `RideSession` 开始时通过 WCS 命令触发 Watch 启动 workout
- iPhone 端 pause / resume / end 同样通过命令同步给 Watch
- Watch App 启动时如果发现本地存在未结束的 workout（上次崩溃或失联），自愈清理

### WatchConnectivity 通道

- **心率推送 Watch → iPhone**：`sendMessage(_:replyHandler:)` 每秒一次
  - 不带 replyHandler 以减少握手延迟
  - 不可达时直接丢弃，不重试、不排队
- **控制命令 iPhone → Watch**：`sendMessage` 单向
  - 不可达时也不排队
- payload 结构示例：

```swift
struct HeartRateRelayMessage: Codable {
    let bpm: Int
    let watchTimestamp: Date
    let sessionID: UUID  // 与 RideSession 对应
}

enum RideControlCommand: Codable {
    case start(sessionID: UUID, startedAt: Date)
    case pause
    case resume
    case end
}
```

### 双端不可达策略

- **Watch 不可达 / Watch App 未打开 / 未授权**：iPhone 骑行照常进行，心率 UI 显示 `--` / `未连接`，仅在设备检测页与骑行展开面板上以视觉状态提示。
- **Watch 心率丢帧**：
  - 0-3 秒：显示最后已知值 + 灰色小圆点（数据已过期）
  - >3 秒：显示 `--`
  - 恢复后立即清空灰点，显示新值
- **首次使用**：用户必须在 Watch 上手动打开一次 WindChaser 并授予 HealthKit 心率读取权限。iPhone 设备检测页提供引导说明。

### 时间边界与心率合并

- **iPhone RideSession 是主时间线**：骑行开始时间、暂停 / 继续累计时间、结束时间，全部以 iPhone 为准。
- HealthKit 回填查询窗口使用 `[startedAt - 30s, endedAt + 30s]` 宽松窗口，抵抗 WCS 延迟与 Watch 启动慢。
- 心率合并策略：按 1 秒分桶
  - WCS 实时心率优先保留
  - 缺失桶用 HK 样本填充
- SQLite samples 表新增 `heart_rate_source` 字段：`wcs | healthkit | none`，方便排查与可选 UI 展示。

### HealthKit 集成

- **骑行结束时写入完整 HKWorkout**：
  - 类型 `.cycling`
  - 距离 `HKQuantityTypeIdentifier.distanceCycling`
  - 时长 `duration`
  - 卡路里 `HKQuantityTypeIdentifier.activeEnergyBurned`（基于时长 + MET 估算公式；Phase 4 接入功率后可精确化）
  - `HKWorkoutRoute` 写入完整 GPS 轨迹
  - 关联合并后的心率样本
- **权限**：启动时申请 `read: heartRate`，`write: workouts, workoutRoute, distanceCycling, activeEnergyBurned`
- **未授权**：不阻塞骑行；结束时跳过 HealthKit 写入，UI 给一次可点击的设置入口提示。

### ActivityKit 锁屏 Live Activity

- **字段**：`总时间` + `当前速度`（大字） + `总距离`。**不显示心率**。
- **时间字段**：使用 `Text(timerInterval:)` 本地自渲染，不消耗 ActivityKit 推送配额。
- **刷新策略**：默认每 5 秒推送一次；当下列任一事件发生时立即推送：
  - 速度变化 > 2 km/h
  - 骑行状态切换（暂停 / 继续 / 结束）
- **生命周期**：
  - `RideSession.startRide()` 成功后立即创建
  - 暂停时保留卡片，速度字段显示 `0.0`，状态文案 `已暂停`
  - 继续时恢复正常更新
  - 结束时立即结束并设置 `dismissalPolicy: .after(now + 10s)`，让用户短暂看到结束态
- **设置开关**：默认开启；用户在骑行中关闭会立即结束当前 Live Activity，不影响骑行本身记录。
- **灵动岛**：不做。

### iPhone UI 调整

- **设备检测页**：
  - 删除 `踏频传感器`、`功率计`、`速度传感器` 三行
  - 只保留 `GPS信号` + `心率（Apple Watch）` 两行
  - 心率行点击弹出说明：如何在 Watch 上打开 App、授权 HealthKit
- **骑行展开仪表盘**：
  - 8 宫格改为 6 项 2×3 布局：速度、距离、时长、心率、海拔、坡度
  - 心率字段支持过期灰点状态
- **骑行报告**：
  - 移除"平均踏频 / 平均功率"行
  - 心率曲线展示合并后的最终结果（不在历史界面显示实时灰点）
- **设置页**：
  - 新增 `锁屏实时活动` 开关，默认开启
- **数据模型**：
  - `BikeDataSnapshot.cadence / power` 字段保留，UI 不显示
  - SQLite schema 不动，避免数据库迁移

### Xcode 项目结构

- 新增 `Shared/` 目录，跨 target 共享模型（`WatchMessage`, `HeartRateRelayState`, `RideActivityAttributes`, `SensorFreshness` 等），通过 file system synchronized group 同时加入 iOS / Watch / Widget target。
- 新增 `WindChaser Watch App` target（watchOS App）。
- 新增 `WindChaserLiveActivity` Widget Extension target（仅 iOS）。

## Testing Decisions

- WCS payload 序列化 / 反序列化往返
- 心率新鲜度判断（0-3s 灰点 / >3s `--` / 恢复清空）
- HealthKit 心率合并逻辑（WCS + HK 按 1s 分桶合并）
- HKWorkout + HKWorkoutRoute 写入流程（含权限缺失场景的降级）
- ActivityKit 刷新触发逻辑（5s 间隔 + 速度阈值 + 状态切换强制）
- 不 mock WCSession / HealthKit / ActivityKit / CoreLocation；端到端测试在真机上完成

## Out of Scope

- BLE 骑行外设接入（心率带 / 踏频器 / 功率计）— 推迟到 Phase 4 之后
- Watch 端开始 / 暂停 / 结束控制 UI — Phase 4
- Watch 独立 GPS 与独立存储 — Phase 4
- 灵动岛
- 锁屏 Live Activity 显示心率（仅 App 内仪表盘显示）

## Further Notes

- iPhone Background Modes：保留 Phase 1 的 `Location updates`；不依赖额外后台模式让 Live Activity 工作（ActivityKit 由系统调度）
- Watch Background Modes：`Workout Processing`
- ActivityKit 高频更新有系统节流限制；5s 平均频率 + 阈值策略远低于触发阈值
- `cadence / power` 字段保留以便 Phase 4 BLE 接入或其他来源补全时无需 schema 变更
