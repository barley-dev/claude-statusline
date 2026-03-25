# Claude Code Statusline — Extension Design Spec

> Date: 2026-03-25
> Version: v1.1.0 (extending v1.0.0)
> Author: 奕儒 + Claude

## Overview

將現有的 Claude Code Statusline（三行彩色狀態列腳本）擴展為兩個可分發的產品：

1. **Claude Code Plugin** — Terminal CLI 使用者透過 plugin 系統安裝
2. **VS Code Extension** — VS Code 使用者透過 Marketplace 安裝（獨立 repo）

兩者共用同一份「顯示規格」，確保體驗一致。

## Goals

- 讓非程式背景的使用者也能直覺上手
- 對話式中英文選單，用戶只要回覆數字即可操作
- 每行資訊可獨立開關，預設全開
- 先完成 Terminal Plugin，再移植 VS Code Extension

## Non-Goals

- 不做自訂主題設定檔（YAGNI）
- 不做自訂顏色設定（用內建色彩門檻）
- 不做 MCP server 或 LSP server

---

## Changes from v1.0.0

以下為 v1.1.0 新增或變更的行為，v1.0.0 使用者升級後會注意到：

| 變更 | 說明 |
|------|------|
| **Line 2 新增 `Ctx` 前綴** | 百分比前顯示 `Ctx 45%` 而非 `45%`，避免與 usage 混淆 |
| **行數開關功能** | 新增設定檔可關閉任意行，v1.0.0 為固定三行 |
| **Plugin 安裝方式** | 新增 plugin 格式安裝，`install.sh` 保留向後相容 |

> 無 breaking changes — v1.0.0 的 `install.sh` 和 `statusline.sh` 行為不變，故版本號為 1.1.0。

### 升級路徑

- **Plugin 用戶**：直接安裝 plugin，會自動設定 `statusLine`
- **v1.0.0 install.sh 用戶**：先跑 `uninstall.sh` 移除舊版，再安裝 plugin
- 兩種安裝方式不能同時存在，避免衝突

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
│   └── statusline.md            # /statusline slash command（對話式選單指令）
├── settings.json                # Plugin settings（statusLine 指向腳本）
├── scripts/
│   ├── statusline.sh            # 主 statusline 腳本（從 v1.0.0 演進）
│   └── config.sh                # 設定讀寫工具（bash）
├── install.sh                   # 傳統安裝方式（向後相容）
├── uninstall.sh                 # 傳統反安裝
├── VERSION
├── README.md                    # 繁體中文（主版本）
├── README.en.md                 # English（翻譯版）
├── test_statusline.sh
├── test_installer.sh
└── tests/
    ├── test_plugin.sh           # Plugin 結構驗證測試
    └── test_config.sh           # 設定讀寫測試
```

### plugin.json

依據已安裝 plugin（superpowers）的實際格式，只需 `name` + `description`：

```json
{
  "name": "claude-statusline",
  "description": "Colorful 3-line statusline with context window, Git info, cost tracking, and rate limits. Configurable via conversational menu with bilingual (中文/English) instructions."
}
```

> 注意：`version`、`author`、`repository` 等欄位在目前 plugin 系統中未被使用，不寫入避免誤導。版本號由 `VERSION` 檔案統一管理。

### settings.json（Plugin 根目錄）

```json
{
  "statusLine": {
    "type": "command",
    "command": "${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh"
  }
}
```

- Plugin 安裝時，Claude Code 自動讀取此 settings.json 並套用
- `${CLAUDE_PLUGIN_ROOT}` 由 Claude Code 提供，指向 plugin 安裝目錄
- **驗證風險**：需在 Phase 1c 確認此變數在 `statusLine.command` 中能正確展開。若不行，fallback 方案為透過 post-install hook 寫入絕對路徑

### Slash Command: `/statusline`（對話式選單）

**機制說明：** slash command 是一份 Markdown 指令檔（`commands/statusline.md`），Claude 讀取後以對話方式呈現選單。使用者回覆數字即可操作，不需要打指令。這不是 TUI 互動選單，而是 Claude 模擬的對話式選單體驗。

**`commands/statusline.md` 指令內容概要：**

指示 Claude 執行以下流程：

1. 讀取 `~/.claude/statusline-config.json` 取得目前設定
2. 呈現第一層選單（帶中英文說明）
3. 等待使用者回覆數字
4. 根據選擇進入對應子流程或執行動作
5. 每次操作後更新 config 檔案

**第一層（Claude 呈現）：**

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

請選擇 / Choose (1-3):
```

**第二層（使用者選 1 後，Claude 呈現）：**

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

請選擇要切換的項目 / Choose item to toggle (1-4):
```

**操作後確認（使用者選 3）：**

```
✅ → ❌ Rate Limits 已關閉 / Rate Limits disabled
設定已儲存 / Settings saved

目前狀態 / Current: ✅ Line 1  ✅ Line 2  ❌ Line 3
```

### 設定儲存

使用 `~/.claude/statusline-config.json`：

```json
{
  "lines": {
    "model_git": true,
    "progress_cost": true,
    "rate_limits": true
  }
}
```

- 位於使用者的 `~/.claude/` 目錄下，不在 plugin 目錄內，因此不會被 plugin 更新覆蓋
- Plugin 更新時不會被覆蓋（不在 plugin 目錄內）
- `scripts/config.sh` 提供讀寫工具，slash command 透過 Claude 呼叫 bash 操作
- 檔案不存在時 fallback 為全部開啟（向後相容 v1.0.0）
- Malformed JSON 保護：讀取失敗時 fallback 為預設值，不 crash

### 安裝與反安裝方式

| 方式 | 安裝 | 反安裝 |
|------|------|--------|
| **Plugin（推薦）** | `/plugin` 安裝 | `claude plugin uninstall`（Claude Code 自動清除 settings） |
| **傳統腳本** | `./install.sh` | `./uninstall.sh`（移除 `~/.claude/statusline.sh` + settings） |

- 兩種方式不能同時存在
- `install.sh` / `uninstall.sh` 保留在 repo 中供不使用 plugin 系統的用戶使用
- Plugin 反安裝後 `~/.claude/statusline-config.json` 會保留（使用者設定不刪）

### 與 v1.0.0 的向後相容

- `install.sh` 保留，提供非 plugin 安裝方式
- 無 `statusline-config.json` 時 fallback 為全部顯示（與 v1.0.0 行為一致）
- 既有的 55 個測試全部保留並通過

### README 語言調整

- `README.md` → **繁體中文**（主版本），GitHub 預設顯示
- `README.en.md` → **English**（翻譯版），頂部互相連結
- 這是對 v1.0.0 的修正（v1.0.0 誤將英文作為主版本）

### 新增測試規劃

| 測試檔案 | 測試內容 | 預估數量 |
|----------|---------|---------|
| `tests/test_plugin.sh` | plugin.json 存在且合法、目錄結構正確、settings.json 格式正確 | ~5 |
| `tests/test_config.sh` | config 讀取/寫入/預設值/malformed fallback/行數切換邏輯 | ~10 |
| `test_statusline.sh` | 既有 33 個 + 新增 Ctx 前綴測試 + 行數開關測試 | ~40 |
| `test_installer.sh` | 既有 22 個（不變） | 22 |

預估總測試數：**~77 個**（從 55 個增加）

---

## Phase 2: VS Code Extension（獨立 repo）

### 技術風險與 Go/No-Go Gate

**在 Phase 1 完成後、Phase 2 開始前，必須先完成資料來源研究：**

- **Timebox**：2 天
- **研究目標**：確認 VS Code 中的 Claude Code Extension 是否提供可讀取的 session 資料
- **可能的資料來源**：
  1. Claude Code Extension 的 API（`vscode.extensions.getExtension()`）
  2. Session 檔案（Claude Code 可能將資料寫入本地）
  3. Extension-to-Extension messaging
- **Go 條件**：至少一種方式可穩定取得 model、context_window、cost、rate_limits
- **No-Go 條件**：無可用 API 且無 session 檔案 → defer Phase 2，等 Anthropic 開放 API

### 技術棧

- Language: TypeScript
- API: VS Code Extension API
- 打包: vsce (Visual Studio Code Extension CLI)
- 發佈: VS Code Marketplace
- Repo: `barley-dev/vscode-claude-statusline`（獨立 repo，技術棧不同不適合 monorepo）

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

VS Code 原生 Quick Pick API 支援真正的互動式選單（上下鍵選擇、Enter 確認）。選單結構和中英文說明與 Terminal 版對應。透過 Command Palette (`Cmd+Shift+P` → `Statusline: Settings`) 觸發。

### VS Code Extension 結構

```
vscode-claude-statusline/
├── package.json                 # Extension manifest
├── src/
│   ├── extension.ts             # Entry point
│   ├── statusBar.ts             # Status bar item 管理
│   ├── tooltip.ts               # Tooltip 渲染
│   ├── quickPick.ts             # 設定選單（多層，原生互動式）
│   ├── dataSource.ts            # 資料取得（抽象層）
│   └── config.ts                # 設定管理
├── tests/
│   ├── statusBar.test.ts
│   ├── tooltip.test.ts
│   ├── quickPick.test.ts
│   └── config.test.ts
├── README.md                    # 繁體中文（主版本）
├── README.en.md                 # English（翻譯版）
├── CHANGELOG.md
└── tsconfig.json
```

---

## Phase 3: 版本同步機制

### 需要同步的版本號位置

| 位置 | 產品 | 格式 |
|------|------|------|
| `VERSION` | Plugin | `1.1.0` |
| `install.sh` → `VERSION=` | Plugin | `"1.1.0"` |
| Git tag (plugin repo) | Plugin | `v1.1.0` |
| `package.json` → `version` | VS Code Extension | `"1.1.0"` |
| Git tag (vscode repo) | VS Code Extension | `v1.1.0` |

> 兩個 repo 的版本號保持一致，確保功能對等。

### 同步方式

**Plugin repo** — 建立 `scripts/release.sh`：
1. 讀取 `VERSION` 檔案作為 single source of truth
2. 更新 `install.sh` 中的 `VERSION=`
3. Git commit + tag
4. 提示推送確認

**VS Code repo** — `package.json` 的 `version` 欄位手動或腳本同步。

---

## Implementation Order

```
Phase 1: Claude Code Plugin
  1a. README 語言修正（中文主版本 + 英文翻譯）
  1b. 重構 statusline.sh（支援 config 讀取、行數切換、Ctx 前綴）
  1c. 建立 plugin 目錄結構 + plugin.json + settings.json
  1d. 實作 scripts/config.sh（設定讀寫工具）
  1e. 實作 commands/statusline.md（對話式選單指令）
  1f. 新增測試（plugin 結構 + config + 行數切換）
  1g. 更新 README 雙語文件（加入 plugin 安裝說明）
  1h. 發佈到 GitHub（tag v1.1.0）

Phase 2: VS Code Extension（Go/No-Go gate 後）
  2a. 研究 Claude Code VS Code Extension 資料來源（timebox 2 天）
  2b. Go/No-Go 決策
  2c. 建立獨立 repo + VS Code Extension 專案骨架
  2d. 實作 Status Bar item
  2e. 實作 Tooltip 渲染
  2f. 實作 Quick Pick 設定選單
  2g. 實作 dataSource 抽象層
  2h. 測試套件
  2i. 發佈到 VS Code Marketplace

Phase 3: 版本同步
  3a. 建立 scripts/release.sh（Plugin repo）
  3b. 建立跨 repo 版本同步流程
```

---

## Success Criteria

### Phase 1: Claude Code Plugin
- [ ] Plugin 結構符合 Claude Code plugin 規範
- [ ] `settings.json` 正確指向 `statusline.sh`
- [ ] `/statusline` 對話式選單可正常呈現中英文選項
- [ ] 使用者透過回覆數字可切換任意行的開關
- [ ] `statusline-config.json` 正確讀寫、malformed fallback 正常
- [ ] Line 2 顯示 `Ctx` 前綴
- [ ] 所有既有 55 個測試通過 + 新增測試通過（目標 ~77 個）
- [ ] README.md 為繁體中文主版本

### Phase 2: VS Code Extension
- [ ] 資料來源研究完成，Go/No-Go 決策已做
- [ ] VS Code 底部狀態列正確顯示精簡資訊
- [ ] 點擊展開完整三行 Tooltip
- [ ] Quick Pick 設定選單與 Terminal 版功能對等
- [ ] 發佈到 VS Code Marketplace

### Phase 3: 版本同步
- [ ] `VERSION` 檔案修改後，`release.sh` 一次同步所有版本號
- [ ] 兩個 repo 版本號保持一致
