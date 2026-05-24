# Phase 1 PRD: 核心骑行 — WindChaser

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
- **预检面板**。开始前展示 GPS 🟢 + 各传感器状态指示灯，用户可以跳过等待直接开始。

### 电池

- **Phase 1 不做电池智能降频**。全程使用 BestForNavigation 精度。降频策略在 Phase 3 实现。

### 地图

- **只绘制已骑行轨迹**。不导入路书，不支持偏航提醒。路书功能在 Phase 3。
- **轨迹绘制依赖网络**。需要网络加载地图瓦片。无网络时轨迹数据正常记录但不显示底图（GPS 不依赖网络）。

## Testing Decisions

- **只测纯逻辑**：RideState 状态机转换正确性、BikeDataSnapshot 计算属性、SQLite CRUD（用临时文件）、GPX/CSV 导出格式正确性
- **不 mock 系统框架**：CoreLocation, CoreMotion, HealthKit 行为不做 mock 测试
- 测试文件放在 `WindChaserTests/` 目录

## Out of Scope

- Watch 任何功能（中继 + 独立码表，Phase 2 & 4）
- ActivityKit 锁屏实时活动（Phase 2）
- 外接蓝牙传感器（心率带、踏频器、功率计，Phase 2）
- 自动暂停（Phase 3）
- 电池智能降频（Phase 3）
- 日历热力图（Phase 3）
- 路书导入 + 偏航提醒（Phase 3）

## Further Notes

- iOS 16.1 为最低版本。使用 `@available(iOS 17, *)` 做渐进增强（如 `@Observable` 替代 `@ObservableObject`）
- 导航手势：仪表页 ↔ 全屏地图页，左右横扫切换
- 历史记录和设置的入口在仪表页角落，右键设置齿轮