# Phase 4 PRD: Watch 独立码表 — WindChaser

## Problem Statement

Phase 2 让 Apple Watch 作为传感器中继站把心率/踏频/功率推给 iPhone。但用户有时不想带手机——短途通勤、小区绕圈训练、手机没电。此时 Watch 只能采集传感器数据却无法独立记录骑行，GPS 和存储缺失让 Watch 在脱离 iPhone 时毫无用处。

## Solution

Apple Watch 在检测不到 iPhone 时自动切换为独立码表模式——启动自带的 GPS 定位，独立记录速度、距离、轨迹和所有传感器数据（心率、踏频、功率）。Watch 端显示完整码表 UI（可翻页仪表 + 数据页 + 地图缩略图）。骑行结束后，数据暂存在 Watch 本地，等 iPhone 恢复连接后自动同步到 iPhone 的 SQLite 存储库和 HealthKit。

## User Stories

1. 作为一名骑手，我只戴 Apple Watch 出门骑车时，Watch 自动检测到 iPhone 不可达并切换到独立码表模式
2. 作为一名骑手，Watch 独立模式下码表界面第 1 页显示 4 个核心字段：速度、心率、距离、时长（大字体，黑底白字）
3. 作为一名骑手，我通过横扫（翻页）看到第 2 页更多数据：踏频、功率、坡度、海拔
4. 作为一名骑手，我再翻一页看到第 3 页：地图缩略图，显示我的当前位置和已骑行轨迹
5. 作为一名骑手，开始/暂停/结束按键固定在 Watch 屏幕底部，任何翻页状态下都能操作
6. 作为一名骑手，Watch 独立骑行结束后，骑行记录保存在 Watch 本地
7. 作为一名骑手，当我回到 iPhone 身边并打开 iPhone App 时，Watch 上的独立骑行自动同步到 iPhone，在历史列表中出现
8. 作为一名骑手，同步完成后的骑行记录会自动写入 HealthKit 体能训练
9. 作为一名骑手，我在 iPhone 上结束一次骑行后，记录自动写入 HealthKit 体能训练并计入 Activity 圆环
10. 作为一名骑手，如果我在 Watch 骑行中途 iPhone 恢复了连接（比如去车上拿了下手机），Watch 不切换到中继模式，保持独立记录直到本次骑行结束
11. 作为一名骑手，Watch 独立骑行时 GPS 使用 Apple Watch 自带的定位（精度不如 iPhone 但在户外完全可用）

## Implementation Decisions

### 模式切换

- **启动检测**：Watch App 启动时检测 WCSession 的 `isReachable`。如果 iPhone 可达 → Phase 2 中继模式；如果 iPhone 不可达 → 独立码表模式。
- **一次骑行不切换模式**：骑行过程中（即 `.riding` 或 `.paused` 状态下）即使 iPhone 变为可达，也不中途切换。避免一次骑行出现两个不连续的数据源。

### Watch 独立 UI

- **3 页可翻页**（TabView + PageTabViewStyle 或数字表冠）：
  - Page 1：仪表页 — 速度、心率、距离、时长（大字体）
  - Page 2：数据页 — 踏频、功率、坡度、海拔
  - Page 3：地图页 — 地图缩略图（MKMapView on watchOS），当前位置 + 已骑行轨迹
- **底部固定栏**：开始 / 暂停 / 结束，三态切换逻辑同 Phase 1
- **UI 风格**：黑底白字，最小设计，complication 风格字体

### Watch 独立数据采集

- **GPS**：`CLLocationManager` 在 Watch 端独立运行，使用 `kCLLocationAccuracyBestForNavigation`
- **气压计**：`CMAltimeter` 在 Watch 端采集（大部分 Apple Watch 有气压计）
- **心率**：复用 Phase 2 的 `HKWorkoutSession + HKLiveWorkoutBuilder`，不再走 WCS 转发，而是直接由 Watch 本地记录
- **踏频 / 功率 / BLE 外设**：本阶段仍然不支持，留待未来阶段；`BikeDataSnapshot.cadence / power` 字段保留为 `nil`
- **存储**：Watch 本地 SQLite 文件（或受限于 Watch 存储空间，可降到 CSV 文件）。一次骑行采样数据量：3 小时 × 3600 点 × ~100 bytes ≈ 360KB，Watch 完全能承受。

### 数据同步

- **同步时机**：iPhone App 启动时检测 Watch 是否有未同步的骑行记录。通过 WCSession 的 `transferUserInfo(_:)` 传输元数据，采样数据用 `transferFile(_:metadata:)` 传输完整的 SQLite/CSV 文件。
- **HealthKit 写入**：
  - Phase 2 已经在 iPhone 端建立完整的 HKWorkout / HKWorkoutRoute / 心率合并写入管线。
  - Watch 独立骑行同步到 iPhone 后，**复用同一管线**写入 HealthKit，不重复实现。
  - 独立模式下 Watch 自己**不写 HealthKit**，避免与同步后 iPhone 写入造成重复条目。
- **去重**：基于骑行开始时间戳 + 设备来源做去重。同一骑行不会重复导入。
- **同步状态**：iPhone 历史列表中 Watch 来源的骑行卡片标注"⌚"图标，直到同步完成。

### 与中继模式的关系

```
┌───────────────────────────────────────────┐
│          Watch App 启动                    │
│              │                             │
│     WCSession.isReachable?                 │
│      │                │                    │
│     是               否                    │
│      │                │                    │
│      ▼                ▼                    │
│  Phase 2          Phase 4                  │
│  中继模式          独立码表模式             │
│  (无UI,           (3页UI,                 │
│   纯数据转发)      独立GPS+存储)            │
│                                            │
│  一次骑行中不切换模式                        │
└───────────────────────────────────────────┘
```

## Testing Decisions

- Watch 模式切换逻辑（isReachable 的各类情况）
- Watch 独立 SQLite/CSV 文件的生成和数据完整性
- 同步传输后数据一致性（Watch 文件 vs iPhone 导入后）
- 去重逻辑（重复同步不会产生重复记录）
- 不 mock WCSession / CoreLocation 行为

## Out of Scope

- Watch 独立地图导航（路书功能只在 iPhone 端）
- Watch 的 ActivityKit 或复杂并发症（complications）
- 蜂窝版 Watch 独立网络功能（不走互联网，纯本地）
- Watch ↔ iPhone 实时双向数据合并（如果中途模式切换）
- BLE 骑行外设接入（心率带 / 踏频器 / 功率计）— 推迟到更后阶段

## Further Notes

- Watch 存储有限（通常 32GB 总存储），但这对于文本数据完全够用。一次骑行 360KB 数据，用户骑 100 次才 36MB
- Watch 端文件传输建议用 `transferFile` 而非 `transferUserInfo`（前者专门为大文件设计，支持断点续传）
- 独立模式下不写 HealthKit。HWWorkout 在同步到 iPhone 后由 iPhone 统一写入