# Claude Code Statusline

**v1.2.0** · Claude Code 彩色狀態列——context 用量、費用追蹤、Git 狀態、rate limits，一眼看完。

[English](README.en.md)

靈感來源：[YAHA 學堂](https://www.youtube.com/@yaboruei)——[Claude Code 最該裝的不是 Skill，是這個腳本](https://youtu.be/wHRFuTqlpD8?si=-iWSGmMA3w7z40V-)

## 預覽

```
[Opus] my-project (main +2 ~3)
████░░░░░░ Ctx 45% │ $1.87 · 12m0s
5h: 35% (reset 2h 15m) │ 7d: 62% (reset 3d 5h)
```

| 行 | 內容 |
|---|---|
| 第一行 | 模型名稱、資料夾名稱、Git 分支（含 staged/modified 檔案數） |
| 第二行 | 彩色 context 進度條（綠 <70%、黃 70-90%、紅 >90%）、`Ctx` 百分比、session 費用、經過時間 |
| 第三行 | 5 小時 / 7 天 rate limit 用量與重置倒數（僅 Pro/Max 用戶顯示） |

## 安裝方式

```bash
git clone https://github.com/barley-dev/claude-statusline.git
cd claude-statusline
./install.sh
```

重啟 Claude Code 就會在底部看到狀態列。

## 安裝腳本做了什麼

1. 檢查 `jq` 是否已安裝（必要依賴）
2. 將 `statusline.sh`（v1.1+，含 Ctx 前綴與行數切換）寫入 `~/.claude/statusline.sh`
3. 將 `statusline-config.sh` 寫入 `~/.claude/statusline-config.sh`（每行切換管理）
4. 將 `/statusline` 指令寫入 `~/.claude/commands/statusline.md`
5. **安全合併** `statusLine` 設定到 `~/.claude/settings.json`
   - 修改前自動備份（`settings.json.bak`）
   - 不覆蓋其他設定——只新增/更新 `statusLine`
   - 已有 statusLine 設定時會詢問是否覆蓋
   - 偵測到 JSON 格式錯誤時拒絕寫入，保護你的設定檔

## `/statusline` 指令

安裝後，在 Claude Code 中輸入 `/statusline` 即可開啟互動式設定選單：

```
Claude Code Statusline 設定

目前狀態：
  第一行（模型/資料夾/Git）：顯示中
  第二行（進度條/費用/時間）：顯示中
  第三行（Rate Limits）：顯示中

請選擇操作：
  1. 切換第一行顯示
  2. 切換第二行顯示
  3. 切換第三行顯示
  4. 結束
```

透過對話即可即時切換每一行的顯示/隱藏，不需要手動編輯設定檔。

## 每行獨立切換

v1.1.0 支援個別控制三行的顯示狀態：

| 行 | 切換方式 |
|---|---|
| 第一行 | 透過 `/statusline` 選單，或直接修改 `~/.claude/statusline-config.json` |
| 第二行 | 同上 |
| 第三行 | 同上（Rate Limit 行，Free 用戶可選擇隱藏） |

## 反安裝

```bash
./uninstall.sh
```

移除 `statusline.sh` 並從 `settings.json` 刪除 `statusLine` 設定。其他設定完全不受影響。

## 系統需求

- [Claude Code](https://claude.com/claude-code)
- [jq](https://jqlang.github.io/jq/) — JSON 處理工具
  - macOS: `brew install jq`
  - Ubuntu: `sudo apt install jq`

## 功能一覽

| 功能 | 說明 |
|---|---|
| Context 進度條 | 10 格進度條，依用量自動變色，前綴顯示 `Ctx` |
| 模型名稱 | 顯示當前模型（Opus、Sonnet 等） |
| Git 狀態 | 分支名稱、staged (+N) 和 modified (~N) 檔案數 |
| Session 費用 | 累計美金費用 |
| 經過時間 | 分鐘與秒數 |
| Rate Limits | 5 小時 / 7 天用量，含重置倒數計時 |
| 自動適應 | 適用任何模型與 context window 大小（200K / 1M 都行） |
| 安全安裝 | 備份設定、驗證 JSON、不盲目覆蓋 |
| 互動設定 | `/statusline` 指令開啟對話式設定選單（v1.1.0+） |
| 每行切換 | 獨立控制三行的顯示/隱藏（v1.1.0+） |
| 架構修復 | 相容 Claude Code 2.1.x plugin 系統（v1.2.0） |

## 執行測試

```bash
# 功能測試（33 個）
./test_statusline.sh

# 安裝腳本測試（22 個）
./test_installer.sh
```

## 運作原理

Claude Code 每次回覆完畢後，會將 session 資料以 JSON 格式透過 stdin 傳給 statusline 腳本。腳本用 `jq` 解析欄位，以 ANSI 顏色碼格式化輸出，Claude Code 再將輸出顯示在終端機底部。

全程在本機執行，**不消耗 API tokens**。

## 致謝

本專案基於 [YAHA 學堂](https://www.youtube.com/@yaboruei)的[教學影片](https://youtu.be/wHRFuTqlpD8?si=-iWSGmMA3w7z40V-)。影片介紹了 Claude Code statusline 腳本的概念與基礎做法。我們在此基礎上新增了以下功能，並修復了 macOS 相容性問題：

- Rate limits 即時顯示（5h / 7d 用量 + 重置倒數）
- 安全安裝/反安裝腳本（備份、JSON 驗證、合併不覆蓋）
- 完整 TDD 測試套件（55 個測試）
- 修復 macOS `seq 1 0` 導致進度條在 0% 和 100% 顯示錯誤的 bug
- `/statusline` 互動式設定選單（v1.1.0）
- 每行獨立切換顯示功能（v1.1.0）
- 架構修復：相容 Claude Code 2.1.x（v1.2.0）

## 授權

MIT
