# Phase 2 PRD: Watch 中继 + 锁屏实时活动 — WindChaser

## Problem Statement

Phase 1 完成了 iPhone 端核心骑行功能（GPS 速度/距离、地图轨迹、仪表盘）。但骑行过程中用户通常把手机揣兜里或锁屏——每次看数据都要掏手机解锁很危险。而且心率带、踏频器、功率计等蓝牙外设的数据无法在 iPhone 上直接获取（外设只连 Apple Watch），仪表盘的心率/踏频/功率字段是空的。

## Solution

Apple Watch 作为传感器中继站——通过 CoreBluetooth 连接心率带/踏频器/功率计，通过 WatchConnectivity 每秒推送传感器数据到 iPhone。iPhone 锁屏时通过 ActivityKit 实时活动在锁屏上展示核心骑行数据，无需解锁即可查看。HealthKit 作为心率数据的兜底通道——骑行结束后补齐 WCS 丢帧造成的空白。

## User Stories

1. 作为一名骑手，我在 Apple Watch 上打开配套 App，它自动连接我的蓝牙心率带、踏频器和功率计，界面上只显示一个连接状态指示灯，不需要任何操作
2. 作为一名骑手，Watch 连接外设后，iPhone App 的预检面板能看到心率 🟢、踏频 🟢、功率 🟢 的状态，我知道传感器已经就绪
3. 作为一名骑手，骑行时 iPhone 仪表盘实时显示心率、踏频和功率数据，数据来自 Watch 转发，延迟不超过 1 秒
4. 作为一名骑手，骑行过程中心率数据如果短暂断开又恢复（比如经过信号干扰区），我能看到数据重新出现，并提供最终连续的数据
5. 作为一名骑手，我在等红灯时手腕靠近 Watch 即可看到连接状态指示灯（当外设断连时，指示灯显示警告）
6. 作为一名骑手，数据显示异常时——比如心率带断连超过 3 秒——仪表盘对应字段旁边出现一个灰色小圆点提示"数据已过期"，超过 3 秒后显示 "--"
7. 作为一名骑手，锁屏后 iPhone 屏幕显示骑行实时活动，核心字段（速度、心率）在锁屏上持续刷新，不需要解锁手机
8. 作为一名骑手，锁屏实时活动的刷新频率自适应：巡航时减少刷新省电，冲刺加速/急刹时立刻刷新
9. 作为一名骑手，骑行结束后，除了表盘显示的实时心率，App 自动从 HealthKit 拉取完整心率数据，与 WCS 接收的数据合并，确保没有空白段
10. 作为一名骑手，我在骑行详情页查看心率曲线时，曲线是连续完整的——即时骑行中途有 WCS 暂时断开的情况

## Implementation Decisions

### Watch 中继 App

- **App 形态**：极简纯中继模式。启动后只显示连接状态指示灯（心率/踏频/功率各自的连接状态）。无其他 UI，用户不与其交互。
- **传感器连接**：Watch 端 CoreBluetooth 连接 BLE 心率带（Heart Rate Service）、踏频/速度传感器（Cycling Speed and Cadence Service）、功率计（Cycling Power Service）。均遵循蓝牙 SIG 标准协议。
- **数据推送**：每秒一次，通过 `WCSession.sendMessage(_:replyHandler:)` 发送自定义 payload 给 iPhone。

```swift
// Payload 结构 (Watch → iPhone, 每秒一次)
let payload: [String: Any] = [
    "hr": 142,        // 心率 bpm (来自 BLE HR Service)
    "cadence": 87,    // 踏频 rpm (来自 BLE CSC Service)
    "power": 210,     // 功率 watts (来自 BLE CP Service)
    "timestamp": Date().timeIntervalSince1970
]
```

### WCS 数据通道

- **WCSessionManager actor**：iPhone 端管理所有 WCSessionDelegate 回调。收到 payload 后写入共享数据流。
- **WCS 不可达时的策略**：消息队列满或设备失联时，sendMessage 抛出错误。不重试（让下一秒的推送自然覆盖）。

### 数据新鲜度 UI

- **分层策略（D 方案）**：
  - 断开 0-3 秒：显示最后已知值 + 灰色小圆点（表示"数据已过期"）
  - 断开 > 3 秒：字段显示 "--"
  - 恢复连接后：立即显示新数据，移除灰点和 "--"
- 每个传感器字段独立判断新鲜度（心率可能恢复、踏频仍断开）。

### HealthKit 兜底

- **HKWorkout 关联**：骑行结束时，`HKWorkout` 由 **Phase 4** 创建。心率样本在骑行过程中已由 Watch 自动写入 HealthKit（系统行为）。
- **对账逻辑**：骑行结束后，用 `HKSampleQuery` 查询该时间段内 HealthKit 中的所有心率样本。与 WCS 接收的心率数据按时间戳合并（以 HealthKit 为准填补 WCS 空白段）。
- **注意**：踏频和功率没有 HealthKit 原生数据类型（截至 iOS 18），无兜底通道。WCS 丢帧意味着踏频/功率空白段无法补齐。

### ActivityKit 锁屏实时活动

- **刷新策略（B+C 方案）**：
  - 分层调度：核心字段（速度）每 1 秒更新、次要字段（心率/功率）每 3 秒更新、准静态字段（里程/爬升）每 10 秒更新
  - 变化阈值叠加：速度变化 > 2 km/h、功率变化 > 10W 时强制刷新（无视调度间隔）
  - 巡航时无意义变化不推，突发情况立刻推
- **显示字段**：锁屏组件显示速度（大字）+ 心率 + 距离。与 App 主界面浮层的 4 字段一致。

### 集成到 Phase 1 管线

- **RideViewModel 数据来源扩展**：原来的 `BikeDataSnapshot` 新增 `hr`, `cadence`, `power` 字段（Phase 1 已预留但为空），Phase 2 由 WCSManager 填充。
- **仪表盘自定义扩展**：用户可在设置中选择是否显示心率/踏频/功率字段（如果没连接这些传感器，隐藏比显示 "--" 更好）。

## Testing Decisions

- WCS payload 解析正确性（模拟 Watch 端发送的各种数据组合）
- 数据新鲜度时间窗口逻辑（0-3 秒冻结、>3 秒 "--"、恢复清空）
- HealthKit 心率对账合并逻辑（WCS 数据 + HK 数据按时间戳合并的正确性）
- ActivityKit 更新调度器（分层 + 阈值叠加的刷新决策逻辑）
- 不 mock WCSession（系统框架行为不测）、不 mock CoreBluetooth

## Out of Scope

- Watch 独立码表 UI（Phase 4）
- 灵动岛（不做）
- 踏频/功率数据的跨设备冗余存储（只有一个通道——WCS）
- HealthKit 踏频/功率类型（iOS 系统不支持）

## Further Notes

- Watch App 必须配置 Background Mode：`Uses Bluetooth LE accessories`
- iPhone App 必须配置 Background Mode：`Location updates`（已有 Phase 1）+ `Uses Bluetooth LE accessories`（新增，确保后台也能接收 WCS 数据）
- ActivityKit 本地更新节流：系统可能在高频更新 10 分钟后降频。变化阈值策略可缓解，但不保证突破系统限制