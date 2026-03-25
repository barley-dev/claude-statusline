# Claude Code Statusline — Extension Design Spec

> Date: 2026-03-25
> Version: v2.0.0 (extending v1.0.0)
> Author: 奕儒 + Claude

## Overview

將現有的 Claude Code Statusline（三行彩色狀態列腳本）擴展為兩個可分發的產品：

1. **Claude Code Plugin** — Terminal CLI 使用者透過 plugin 系統安裝
2. **VS Code Extension** — VS Code 使用者透過 Marketplace 安裝

兩者共用同一份「顯示規格」，確保體驗一致。

## Goals

- 讓非程式背景的使用者也能直覺上手
- 多層中英文選單，用選的不用打指令
- 每行資訊可獨立開關，預設全開
- 先完成 Terminal Plugin，再移植 VS Code Extension

## Non-Goals

- 不做自訂主題設定檔（YAGNI）
- 不做自訂顏色設定（用內建色彩門檻）
- 不做 MCP server 或 LSP server

---

## Shared Display Spec（共用顯示規格）

### 三行資訊定義

| Line | 內容 | 範例 |
|------|------|------|
| **Line 1** | 模型名稱 + context 大小 + 資料夾名 + Git 分支/staged/modified | `[Opus 4.6 (1M)] project-name (main +2 ~1)` |
| **Line 2** | 進度條 + context 百分比 + 費用 + 累計時間 | `████░░░░░░ Ctx 45% │ $1.50 · 10m30s` |
| **Line 3** | 5h / 7d rate limits + 重置倒數（僅 Pro/Max） | `5h: 30% (reset 2h 15m) │ 7d: 10% (reset 5d 3h)` |

### 行為規則

- 每行可獨立開關，預設全部開啟
- Line 3 僅在 `rate_limits.five_hour` AND `rate_limits.seven_day` 都存在時才顯示
- 若使用者關閉 Line 3 但資料存在，仍不顯示（尊重使用者設定）

### 顏色門檻（共用）

| 百分比 | 顏色 | 用途 |
|--------|------|------|
| < 70% | 綠色 | Context window、Rate limits |
| 70% - 89% | 黃色 | 警告 |
| ≥ 90% | 紅色 | 危險 |

### 標示規範

- Context window 百分比前綴 `Ctx`，避免與 usage 混淆
- 模型名稱包含 context 大小（如 `Opus 4.6 (1M)`），來自 `model.display_name`

---

## Phase 1: Claude Code Plugin (Terminal)

### Plugin 結構

```
claude-statusline/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── commands/
│   └── statusline.md            # /statusline slash command
├── hooks/
│   └── hooks.json               # SessionStart hook（可選）
├── settings.json                # 預設設定（行數開關）
├── scripts/
│   ├── statusline.sh            # 主 statusline 腳本（從 v1.0.0 演進）
│   └── config.sh                # 設定讀寫工具
├── install.sh                   # 傳統安裝方式（向後相容）
├── uninstall.sh                 # 傳統反安裝
├── VERSION
├── README.md
├── README.zh-TW.md
├── test_statusline.sh
├── test_installer.sh
└── tests/
    ├── test_plugin.sh           # Plugin 格式測試
    └── test_menu.sh             # 選單邏輯測試
```

### plugin.json

```json
{
  "name": "claude-statusline",
  "description": "Colorful 3-line statusline with context window, Git info, cost tracking, and rate limits. Configurable via interactive menu.",
  "version": "2.0.0",
  "author": {
    "name": "barley-dev"
  },
  "repository": "https://github.com/barley-dev/claude-statusline",
  "license": "MIT"
}
```

### Slash Command: `/statusline`

**第一層選單：**

```
📊 Statusline 設定 / Settings
─────────────────────────────
1. 顯示設定 / Display Settings
   → 選擇要顯示哪些資訊行
   → Choose which info lines to show

2. 預覽 / Preview
   → 用目前設定預覽 statusline 效果
   → Preview statusline with current settings

3. 重設 / Reset
   → 恢復預設設定（顯示全部三行）
   → Restore default settings (show all 3 lines)
```

**第二層選單（選 1 後）：**

```
顯示設定 / Display Settings
─────────────────────────────
目前狀態 / Current: ✅ Line 1  ✅ Line 2  ✅ Line 3

1. ✅ 模型 + Git 資訊 / Model + Git Info
   → [Opus 4.6 (1M)] project-name (main +2 ~1)
   → Toggle: 開啟中 / Currently ON

2. ✅ 進度條 + 費用 + 時間 / Progress + Cost + Time
   → ████░░░░░░ Ctx 45% │ $1.50 · 10m30s
   → Toggle: 開啟中 / Currently ON

3. ✅ Rate Limits（僅 Pro/Max）
   → 5h: 30% (reset 2h 15m) │ 7d: 10% (reset 5d 3h)
   → Toggle: 開啟中 / Currently ON

4. ← 返回 / Back
```

### 設定儲存

Plugin 使用 `${CLAUDE_PLUGIN_DATA}/config.json` 儲存使用者設定：

```json
{
  "lines": {
    "model_git": true,
    "progress_cost": true,
    "rate_limits": true
  }
}
```

- `CLAUDE_PLUGIN_DATA` 是 Claude Code 提供的持久化目錄，plugin 更新後設定不會遺失
- statusline.sh 啟動時讀取此設定，決定輸出哪些行

### 與 v1.0.0 的向後相容

- `install.sh` 保留，提供非 plugin 安裝方式
- 無 `config.json` 時 fallback 為全部顯示（與 v1.0.0 行為一致）
- 既有的 55 個測試全部保留並通過

---

## Phase 2: VS Code Extension

### 技術棧

- Language: TypeScript
- API: VS Code Extension API
- 打包: vsce (Visual Studio Code Extension CLI)
- 發佈: VS Code Marketplace

### UI 設計

**Status Bar Item（常駐底部）：**

```
Opus 4.6 (1M) │ Ctx 45% │ $1.50
```

- 位於 VS Code 底部狀態列
- 點擊展開 Tooltip 顯示完整三行
- 右鍵或 Command Palette 進入設定

**Tooltip（hover/click 展開）：**

顯示完整三行資訊，包含 Git 和 Rate Limits。格式與 Terminal 版相同但用 Markdown 渲染。

**Quick Pick 選單（設定用）：**

與 Terminal 版的 `/statusline` 選單對應，同樣的多層結構、同樣的中英文說明。透過 Command Palette (`Cmd+Shift+P` → `Statusline: Settings`) 觸發。

### 資料來源（待研究）

VS Code Extension 需要取得 Claude Code 的 session 資料。可能的方式：

1. **讀取 Claude Code Extension 的 API** — 如果 Claude Code VS Code Extension 有提供
2. **讀取 session 檔案** — Claude Code 可能將 session 資料寫入本地檔案
3. **透過 Extension-to-Extension API** — VS Code 的 `vscode.extensions.getExtension()` 互動

> 這是 Phase 2 開始前必須先釐清的技術風險。

### VS Code Extension 結構

```
vscode-claude-statusline/
├── package.json                 # Extension manifest
├── src/
│   ├── extension.ts             # Entry point
│   ├── statusBar.ts             # Status bar item 管理
│   ├── tooltip.ts               # Tooltip 渲染
│   ├── quickPick.ts             # 設定選單（多層）
│   ├── dataSource.ts            # 資料取得（抽象層）
│   └── config.ts                # 設定管理
├── tests/
│   ├── statusBar.test.ts
│   ├── tooltip.test.ts
│   ├── quickPick.test.ts
│   └── config.test.ts
├── README.md
├── README.zh-TW.md
├── CHANGELOG.md
└── tsconfig.json
```

---

## Phase 3: 版本同步機制

### 需要同步的版本號位置

| 位置 | 格式 |
|------|------|
| `VERSION` | `2.0.0` |
| `plugin.json` → `version` | `"2.0.0"` |
| `install.sh` → `VERSION=` | `"2.0.0"` |
| `package.json` (VS Code) → `version` | `"2.0.0"` |
| Git tag | `v2.0.0` |

### 同步方式

建立 `scripts/release.sh`：
1. 讀取 `VERSION` 檔案作為 single source of truth
2. 更新所有其他位置
3. Git commit + tag
4. 提示推送確認

---

## Implementation Order

```
Phase 1: Claude Code Plugin
  1a. 重構 statusline.sh（支援 config 讀取、行數切換）
  1b. 建立 plugin 目錄結構 + plugin.json
  1c. 實作 /statusline slash command（多層選單）
  1d. 實作 config.sh（設定讀寫）
  1e. 新增測試（plugin 結構 + 選單邏輯）
  1f. 更新 README 雙語文件
  1g. 發佈到 GitHub + 建立 custom marketplace

Phase 2: VS Code Extension
  2a. 研究 Claude Code VS Code Extension 資料來源
  2b. 建立 VS Code Extension 專案骨架
  2c. 實作 Status Bar item
  2d. 實作 Tooltip 渲染
  2e. 實作 Quick Pick 設定選單
  2f. 實作 dataSource 抽象層
  2g. 測試套件
  2h. 發佈到 VS Code Marketplace

Phase 3: 版本同步
  3a. 建立 release.sh
  3b. 整合兩個產品的版本號
```

---

## Success Criteria

- [ ] Plugin 安裝後，`/statusline` 可正常顯示多層中英文選單
- [ ] 使用者可透過選單切換任意行的開關
- [ ] 所有既有 55 個測試通過 + 新增測試通過
- [ ] VS Code Extension 底部狀態列正確顯示資訊
- [ ] 點擊展開完整三行 Tooltip
- [ ] Quick Pick 設定選單與 Terminal 版功能對等
- [ ] `VERSION` 檔案修改後，release.sh 一次同步所有版本號
