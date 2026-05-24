# Phase 1 — Issue 讨论定稿

| 状态 | Issue |
|------|--------|
| **当前（定稿）** | [#7 Phase 1: 核心骑行](https://github.com/Mr-Poole3/WindChaser/issues/7) |
| **已废弃** | [#1](https://github.com/Mr-Poole3/WindChaser/issues/1) — 需仓库管理员手动关闭/删除 |

定稿正文见 [`issue-1-body.md`](./issue-1-body.md)（与 #7 描述一致）。

## 讨论新增要点（摘要）

| 议题 | 决定 |
|------|------|
| WCSManager | Phase 1 建空壳，Phase 2 接入 |
| SQLite | 1Hz INSERT + 每秒 COMMIT |
| 暂停 | 方案 A：暂停不写点、不计距/均速 |
| 当前速度 UI | 1Hz 瞬时速度，无平滑 |
| 当前速度存库 | 原始 speed |
| 低速 UI | < 1.5 km/h 显示 `<1.5km/h` |
| 无效 GPS | 显示 `--` |

## 权限说明

Agent 可 **创建** Issue，但无法 **删除 / 关闭 / 改标签**。请在本机或 GitHub 网页：

1. 关闭或删除 [#1](https://github.com/Mr-Poole3/WindChaser/issues/1)
2. 为 [#7](https://github.com/Mr-Poole3/WindChaser/issues/7) 添加 `ready-for-agent` 标签
