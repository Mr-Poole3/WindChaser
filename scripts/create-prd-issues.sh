#!/bin/bash
# 创建 WindChaser 4 个 Phase 的 GitHub Issues
# 运行前确保: gh auth status 显示已登录

set -e

REPO="Mr-Poole3/WindChaser"
LABEL="ready-for-agent"

echo "=== 检查仓库 ==="
gh repo view "$REPO" --json name 2>/dev/null || {
    echo "仓库 $REPO 不存在，请先在 GitHub 创建"
    exit 1
}

echo ""
echo "=== 创建 Issue #1: Phase 1 核心骑行 ==="
gh issue create --repo "$REPO" \
  --title "Phase 1: 核心骑行 — GPS 码表 + 地图 + 仪表盘 + 存储" \
  --body "$(cat <<'BODY'
## Problem Statement

骑行爱好者需要一个 iPhone 原生码表 App。用户打开手机就能记录骑行，看到实时速度、距离、轨迹和海拔坡度，骑完后能查看历史记录并导出数据。现有方案（Strava、行者）要么收费、要么广告多、要么数据归属受限。

## Solution

一个极简但完整的 iPhone 骑行码表。全屏地图 + 底部数据浮层 + 上滑展开仪表盘。iOS 16.1 最低支持，SwiftUI 原生体验。SQLite 本地存储（每骑行一个文件），支持 GPX/CSV 导出，HealthKit 写入体能训练。

## User Stories

1. 作为一名骑手，我打开 App 看到一个预检面板，显示 GPS 信号状态和传感器就绪情况，这样我知道设备是否准备就绪
2. 作为一名骑手，我点击"开始"后骑行计时开始，地图全屏显示我的位置，车头方向始终朝上，这样我能快速判断前方路线
3. 作为一名骑手，我在地图底部浮层看到已进行时长、心率、距离和当前速度四个核心数据（图标 + 大字），这样瞄一眼就能掌握骑行状态
4. 作为一名骑手，我上滑浮层展开完整的仪表盘，看到速度、里程、用时、心率、踏频、功率、海拔、坡度 8 宫格数据，这样我可以查看所有详细指标
5. 作为一名骑手，我可以在设置里自定义仪表宫格显示的字段和顺序，这样不同骑行类型我可以看不同的数据组合
6. 作为一名骑手，我骑行时地图上实时绘制走过的轨迹线（彩色），这样我能直观看到骑了多远、路线长什么样
7. 作为一名骑手，我在等红灯时手动暂停骑行，暂停后恢复继续记录，最长支持 1 小时暂停，这样统计的用时和平均速度不会因为等红灯而失真
8. 作为一名骑手，我点击"结束"按钮后骑行记录保存，数据写入 HealthKit 体能训练并计入 Activity 圆环，这样一次完整的骑行被归档
9. 作为一名骑手，我在历史列表看到每次骑行的卡片（日期、距离、用时、轨迹缩略图），按时间倒序排列，点击进入详情
10. 作为一名骑手，我可以在骑行详情页查看完整数据图表和地图轨迹回放
11. 作为一名骑手，我可以将一次骑行导出为 GPX 文件分享给 Strava（有网络时）、行者等第三方 App
12. 作为一名骑手，我可以将一次骑行导出为 CSV 文件，用 Numbers 或 Excel 在自己电脑上做数据分析
13. 作为一名骑手，如果 App 异常退出（崩溃、关机、杀进程），我的骑行记录自动标记为结束，数据不会丢失，下次打开时可查看
14. 作为一名骑手，我在手机无信号的山里骑行时，地图的已骑行轨迹依然正常绘制，因为 GPS 不依赖网络

## Implementation Decisions

### 架构

- **MVVM + Actor 分离**。传感器采集（SensorEngine actor）、状态机与存储（RideStore actor）、WCS 通信（WCSManager actor）各自封装为独立 Swift actor。ViewModel（@MainActor）从 actor 订阅数据并桥接到 @Published。
- **统一采样循环**。SensorEngine 以固定 1Hz 频率从各路传感器读最新值，打包为 BikeDataSnapshot struct，广播给 UI、存储和后续的 ActivityKit。
- **RideState 枚举**：`.idle → .riding → .paused → .ended`，pause 最长 1 小时后自动 end。状态机在 RideStore actor 内集中管理。

### 存储

- **SQLite 文件存储**。每次骑行一个 `.ridesqlite` 文件，包含 `samples` 表（timestamp, lat, lon, altitude, speed, hr, cadence, power, ...）。WAL 模式，每秒 INSERT + COMMIT，事务保护防数据损坏。
- **HealthKit 写入**。骑行结束时写入 HKWorkout（距离、时长、卡路里），关联心率样本（HKQuantitySample）和 GPS 路线（HKWorkoutRoute）。
- **GPX/CSV 导出**。导出本质是 `SELECT * FROM samples ORDER BY timestamp` 然后格式转换，零数据迁移成本。
- **异常退出处理**。检测到上次骑行状态为 `.riding` 或 `.paused` 时，标记该骑行为"异常结束"，采样数据截止到最后一条 SQLite 记录。

### UI 交互

- **全屏地图 + 底部数据浮层**。MKMapView（车头向上跟随模式），浮层显示 4 个核心数据（时长/心率/距离/速度）。上滑展开为 8 宫格仪表盘（可自定义字段和顺序）。
- **地图离线**。使用系统 MKMapView 底图，App 内提示用户在 iOS 设置中提前下载离线地图区域。
- **预检面板**。开始前展示 GPS + 各传感器状态指示灯，用户可以跳过等待直接开始。
- **地图**：只绘制已骑行轨迹。不导入路书，不支持偏航提醒。轨迹绘制依赖网络加载底图瓦片，GPS 不依赖网络。

## Testing Decisions

- **只测纯逻辑**：RideState 状态机转换正确性、BikeDataSnapshot 计算属性、SQLite CRUD（用临时文件）、GPX/CSV 导出格式正确性
- **不 mock 系统框架**：CoreLocation, CoreMotion, HealthKit 行为不做 mock 测试

## Out of Scope

- Watch 任何功能（Phase 2 & 4）
- ActivityKit 锁屏实时活动（Phase 2）
- 外接蓝牙传感器（Phase 2）
- 自动暂停、电池智能降频、日历热力图、路书导入 + 偏航提醒（Phase 3）

## Further Notes

- iOS 16.1 为最低版本。使用 `@available(iOS 17, *)` 做渐进增强
- 预估周期：6-8 周

BODY
)" \
  --label "$LABEL"

echo ""
echo "=== 创建 Issue #2: Phase 2 Watch 中继 + 锁屏 ==="
gh issue create --repo "$REPO" \
  --title "Phase 2: Watch 中继 + 锁屏实时活动 — 传感器数据 & ActivityKit" \
  --body "$(cat <<'BODY'
## Problem Statement

Phase 1 完成了 iPhone 端核心骑行功能。但骑行过程中用户通常把手机揣兜里或锁屏——每次看数据都要掏手机解锁很危险。而且心率带、踏频器、功率计等蓝牙外设的数据无法在 iPhone 上直接获取（外设只连 Apple Watch），仪表盘的心率/踏频/功率字段是空的。

## Solution

Apple Watch 作为传感器中继站——通过 CoreBluetooth 连接心率带/踏频器/功率计，通过 WatchConnectivity 每秒推送传感器数据到 iPhone。iPhone 锁屏时通过 ActivityKit 实时活动在锁屏上展示核心骑行数据，无需解锁即可查看。HealthKit 作为心率数据的兜底通道——骑行结束后补齐 WCS 丢帧造成的空白。

## User Stories

1. 作为一名骑手，我在 Apple Watch 上打开配套 App，它自动连接我的蓝牙心率带、踏频器和功率计，界面上只显示一个连接状态指示灯，不需要任何操作
2. 作为一名骑手，Watch 连接外设后，iPhone App 的预检面板能看到心率、踏频、功率的状态
3. 作为一名骑手，骑行时 iPhone 仪表盘实时显示心率、踏频和功率数据，数据来自 Watch 转发，延迟不超过 1 秒
4. 作为一名骑手，骑行过程中心率数据如果短暂断开又恢复（比如经过信号干扰区），我能看到数据重新出现
5. 作为一名骑手，数据显示异常时——比如心率带断连超过 3 秒——仪表盘对应字段旁边出现一个灰色小圆点提示"数据已过期"，超过 3 秒后显示 "--"
6. 作为一名骑手，锁屏后 iPhone 屏幕显示骑行实时活动，核心字段（速度、心率）在锁屏上持续刷新，不需要解锁手机
7. 作为一名骑手，锁屏实时活动的刷新频率自适应：巡航时减少刷新省电，冲刺加速/急刹时立刻刷新
8. 作为一名骑手，骑行结束后，App 自动从 HealthKit 拉取完整心率数据，与 WCS 接收的数据合并，确保没有空白段
9. 作为一名骑手，我在骑行详情页查看心率曲线时，曲线是连续完整的——即时骑行中途有 WCS 暂时断开的情况

## Implementation Decisions

### Watch 中继 App

- **形态**：极简纯中继模式。启动后只显示连接状态指示灯。无其他 UI，用户不与其交互。
- **传感器连接**：Watch 端 CoreBluetooth 连接 BLE 心率带（HR Service）、踏频/速度传感器（CSC Service）、功率计（CP Service）。均遵循蓝牙 SIG 标准协议。
- **数据推送**：每秒一次，通过 `WCSession.sendMessage` 发送自定义 payload（hr, cadence, power, timestamp）。

### WCS 数据通道

- **WCSessionManager actor**：iPhone 端管理所有 WCSessionDelegate 回调。收到 payload 后写入共享数据流。
- **WCS 不可达时**：消息队列满或设备失联时不重试，让下一秒推送自然覆盖。

### 数据新鲜度 UI

- **分层策略（D 方案）**：
  - 断开 0-3 秒：显示最后已知值 + 灰色小圆点
  - 断开 > 3 秒：字段显示 "--"
  - 恢复连接后：立即显示新数据，移除过期标记
- 每个传感器字段独立判断新鲜度。

### HealthKit 兜底

- 骑行结束后用 `HKSampleQuery` 查询该时段 HealthKit 心率样本，与 WCS 数据按时间戳合并。
- 踏频和功率无 HealthKit 原生数据类型（截至 iOS 18），无兜底通道。

### ActivityKit 锁屏实时活动

- **刷新策略（B+C 方案）**：分层调度（速度 1s、心率/功率 3s、里程/爬升 10s）+ 变化阈值叠加（速度变化 > 2 km/h、功率变化 > 10W 强制刷新）。

## Testing Decisions

- WCS payload 解析正确性、数据新鲜度时间窗口逻辑、HealthKit 心率对账合并、ActivityKit 更新调度器
- 不 mock WCSession、CoreBluetooth

## Out of Scope

- Watch 独立码表 UI（Phase 4）
- 灵动岛（不做）
- HealthKit 踏频/功率类型（iOS 系统不支持）

## Further Notes

- Watch App 配置 Background Mode：`Uses Bluetooth LE accessories`
- iPhone App 新增 Background Mode：`Uses Bluetooth LE accessories`
- 预估周期：3-4 周

BODY
)" \
  --label "$LABEL"

echo ""
echo "=== 创建 Issue #3: Phase 3 智能体验 ==="
gh issue create --repo "$REPO" \
  --title "Phase 3: 智能体验 — 自动暂停 + 电池降频 + 热力图 + 路书" \
  --body "$(cat <<'BODY'
## Problem Statement

前两个 Phase 做完了基础骑行和传感器接入。但四个体验问题尚未解决：(1) 红灯停车时不会自动暂停，拉低统计；(2) GPS 全程高精度 + ActivityKit 高频刷新让电池在长距离骑行中吃不消；(3) 历史记录只能线性浏览；(4) 用户想跟着别人分享的路线骑行时，没有路线预览和偏离提示。

## Solution

四个独立功能：自动暂停、电池智能降频、日历热力图、路书导入与偏航提醒。

## User Stories

### 自动暂停
1. 作为一名骑手，当我在红灯前停车超过 5 秒后，骑行自动暂停，不需要手动去点"暂停"按钮
2. 作为一名骑手，绿灯后我开始移动，骑行自动恢复记录
3. 作为一名骑手，自动暂停和手动暂停互不冲突
4. 作为一名骑手，我在设置里可以开关自动暂停功能并调整触发等待时间（3s / 5s / 10s）

### 电池智能降频
5. 作为一名骑手，在长直平路巡航超过 2 分钟时，App 自动降低 GPS 精度和刷新频率帮我省电
6. 作为一名骑手，当我开始加速、减速、转弯或爬坡时，App 立刻恢复最高精度和全速刷新
7. 作为一名骑手，我在设置里可以看到当前电池优化状态，并可以选择关闭自动降频

### 日历热力图
8. 作为一名骑手，我在历史记录页面可以切换到日历视图，以热力图查看每个月的骑行频率
9. 作为一名骑手，热力图颜色深浅对应骑行距离，一眼看出这个月骑得多不多
10. 作为一名骑手，点击日历上的某个日期可以看到该日骑行的摘要卡片

### 路书导入
11. 作为一名骑手，我可以在 App 内导入 GPX 路书文件（无需网络）
12. 作为一名骑手，地图上同时显示预告路线（虚线）和已骑行轨迹（实线）
13. 作为一名骑手，当我偏离路书超过设定距离时，浮层弹出视觉提示（需要网络）
14. 作为一名骑手，我可以在设置里调整偏航提醒触发距离（50m / 100m / 200m）

## Implementation Decisions

### 自动暂停
- 检测器：速度 < 1.5 km/h 持续 N 秒触发暂停，速度 > 3 km/h 持续 3 秒触发恢复
- 与手动暂停一致使用 .paused 状态，区别仅在触发源
- 设置项：开关 + 触发等待时间滑块

### 电池智能降频
- GPS 精度降级：巡航时 BestForNavigation → NearestTenMeters
- distanceFilter 调大（0 → 10m）+ ActivityKit 间隔拉长（1s → 5s）
- 恢复条件：速度突变、转弯、爬坡检测
- 状态机：.fullPower ↔ .powerSaving

### 日历热力图
- SwiftUI LazyVGrid 7 列周视图，按月分段
- 颜色映射：0km（灰白）→ 10km（淡绿）→ 50km（中绿）→ 100km+（深绿）
- 数据源：SQLite 聚合查询每日累计距离

### 路书导入
- UIDocumentPickerViewController 选 .gpx 文件，XML 解析提取坐标
- 无网络可用（解析和绘制），偏航检测需网络
- 偏航提醒为非阻塞旗帜图标

## Testing Decisions

- 自动暂停触发/恢复逻辑、电池降频状态机、日历热力图颜色映射、GPX 解析兼容性、偏航距离计算

## Out of Scope

- 在线路线推荐/热门路书库、社交功能、坡度预测、Watch 独立码表（Phase 4）、语音播报

## Further Notes

- 预估周期：3-4 周

BODY
)" \
  --label "$LABEL"

echo ""
echo "=== 创建 Issue #4: Phase 4 Watch 独立码表 ==="
gh issue create --repo "$REPO" \
  --title "Phase 4: Watch 独立码表 — 脱离 iPhone 独立记录骑行" \
  --body "$(cat <<'BODY'
## Problem Statement

Phase 2 让 Apple Watch 作为传感器中继站。但用户有时不想带手机出门——短途通勤、小区绕圈训练、手机没电。此时 Watch 只能采集传感器数据却无法独立记录骑行，GPS 和存储缺失让 Watch 在脱离 iPhone 时毫无用处。

## Solution

Apple Watch 在检测不到 iPhone 时自动切换为独立码表模式——启动自带 GPS 定位，独立记录速度、距离、轨迹和所有传感器数据。Watch 端显示完整码表 UI（可翻页仪表 + 数据页 + 地图缩略图）。骑行结束后数据暂存 Watch 本地，等 iPhone 恢复连接后自动同步。

## User Stories

1. 作为一名骑手，我只戴 Apple Watch 出门骑车时，Watch 自动检测到 iPhone 不可达并切换到独立码表模式
2. 作为一名骑手，Watch 独立模式第 1 页显示 4 个核心字段：速度、心率、距离、时长（大字体，黑底白字）
3. 作为一名骑手，横扫翻到第 2 页更多数据：踏频、功率、坡度、海拔
4. 作为一名骑手，再翻一页看到第 3 页：地图缩略图，显示当前位置和已骑行轨迹
5. 作为一名骑手，开始/暂停/结束按键固定在屏幕底部，任何翻页状态下都能操作
6. 作为一名骑手，Watch 独立骑行结束后记录保存在本地
7. 作为一名骑手，当我回到 iPhone 身边并打开 App 时，Watch 上的骑行自动同步到 iPhone 历史列表
8. 作为一名骑手，同步完成后骑行记录自动写入 HealthKit
9. 作为一名骑手，如果骑行中途 iPhone 恢复连接，Watch 不切换模式，保持独立记录直到本次结束
10. 作为一名骑手，Watch 独立骑行时使用自带 GPS（精度不如 iPhone 但在户外完全可用）

## Implementation Decisions

### 模式切换
- 启动检测：WCSession.isReachable。iPhone 可达 → Phase 2 中继模式；不可达 → 独立码表模式。
- 一次骑行中不切换模式，避免数据源不连续。

### Watch 独立 UI
- 3 页可翻页：Page 1 仪表（速度/心率/距离/时长）、Page 2 数据（踏频/功率/坡度/海拔）、Page 3 地图缩略图
- 底部固定操作栏

### Watch 独立数据采集
- GPS：CLLocationManager 在 Watch 端运行，BestForNavigation 精度
- 气压计：CMAltimeter 采集
- 传感器：CoreBluetooth 外设直接解析
- 存储：Watch 本地 SQLite 文件（3 小时骑行约 360KB）

### 数据同步
- iPhone App 启动时检测未同步记录
- transferUserInfo 传元数据，transferFile 传采样数据文件
- 基于"开始时间戳 + 设备来源"去重
- 同步后由 iPhone 统一写入 HealthKit

### 模式关系
```
Watch App 启动
├── isReachable? 是 → Phase 2 中继模式
└── isReachable? 否 → Phase 4 独立码表模式
一次骑行中不切换
```

## Testing Decisions

- Watch 模式切换逻辑、独立存储文件完整性、同步数据一致性、去重逻辑

## Out of Scope

- Watch 独立地图导航（路书）、Watch ActivityKit/complications、蜂窝版独立网络、中途模式切换

## Further Notes

- Watch 存储完全够用（100 次骑行约 36MB）
- 文件传输用 transferFile（支持断点续传）
- 独立模式下不写 HealthKit，同步后由 iPhone 统一写入
- 预估周期：4-6 周

BODY
)" \
  --label "$LABEL"

echo ""
echo "=== 完成 ==="
echo "4 个 Issue 已创建在 $REPO"
gh issue list --repo "$REPO" --state open --label "$LABEL"