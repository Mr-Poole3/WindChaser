# Phase 1 — Issue #1 讨论定稿

GitHub Issue：[#1 Phase 1: 核心骑行](https://github.com/Mr-Poole3/WindChaser/issues/1)

Cloud Agent 无权限直接编辑 Issue，定稿内容见 [`issue-1-body.md`](./issue-1-body.md)（完整 Issue 正文，含讨论结论）。

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

将 `issue-1-body.md` 全文复制到 Issue #1 描述即可同步 GitHub。
