# Claude Code Statusline

> **v1.0.0** · A colorful, informative status bar for Claude Code.
>
> Claude Code 彩色狀態列——context 用量、費用追蹤、Git 狀態、rate limits，一眼看完。

Inspired by [YAHA 學堂](https://www.youtube.com/@yaboruei)'s video: [Claude Code 最該裝的不是 Skill，是這個腳本](https://youtu.be/wHRFuTqlpD8?si=-iWSGmMA3w7z40V-)

## Preview / 預覽

```
[Opus] my-project (main +2 ~3)
████░░░░░░ 45% │ $1.87 · 12m0s
5h: 35% (reset 2h 15m) │ 7d: 62% (reset 3d 5h)
```

| 行 | 內容 |
|---|---|
| 第一行 | 模型名稱、資料夾名稱、Git 分支（含 staged/modified 檔案數） |
| 第二行 | 彩色 context 進度條（綠 <70%、黃 70-90%、紅 >90%）、session 費用、經過時間 |
| 第三行 | 5 小時 / 7 天 rate limit 用量與重置倒數（僅 Pro/Max 用戶） |

## Quick Install / 快速安裝

```bash
git clone https://github.com/barley-dev/claude-statusline.git
cd claude-statusline
./install.sh
```

重啟 Claude Code 即可看到狀態列。

## What the Installer Does / 安裝腳本做了什麼

1. 檢查 `jq` 是否已安裝（必要依賴）
2. 將 `statusline.sh` 寫入 `~/.claude/statusline.sh`
3. **安全合併** `statusLine` 設定到 `~/.claude/settings.json`
   - 修改前自動備份（`settings.json.bak`）
   - 不覆蓋其他設定——只新增/更新 `statusLine`
   - 已有 statusLine 設定時會詢問是否覆蓋
   - 偵測到 JSON 格式錯誤時拒絕寫入

## Uninstall / 反安裝

```bash
./uninstall.sh
```

移除 `statusline.sh` 並從 `settings.json` 刪除 `statusLine` 設定。其他設定完全不受影響。

## Requirements / 系統需求

- [Claude Code](https://claude.com/claude-code)
- [jq](https://jqlang.github.io/jq/) — JSON 處理工具
  - macOS: `brew install jq`
  - Ubuntu: `sudo apt install jq`

## Features / 功能

| 功能 | 說明 |
|---|---|
| Context 進度條 | 10 格進度條，依用量自動變色 |
| 模型名稱 | 顯示當前模型（Opus、Sonnet 等） |
| Git 狀態 | 分支名稱、staged (+N) 和 modified (~N) 檔案數 |
| Session 費用 | 累計美金費用 |
| 經過時間 | 分鐘與秒 |
| Rate Limits | 5 小時 / 7 天用量與重置倒數 |
| 自動適應 | 適用任何模型與 context window 大小 |
| 安全安裝 | 備份設定、驗證 JSON、不盲目覆蓋 |

## Running Tests / 執行測試

```bash
# 功能測試（33 個）
./test_statusline.sh

# 安裝腳本測試（22 個）
./test_installer.sh
```

## How It Works / 運作原理

Claude Code 每次回覆後，會將 session 資料以 JSON 格式透過 stdin 傳給你的 statusline 腳本。腳本用 `jq` 解析欄位，以 ANSI 顏色格式化輸出，Claude Code 再將輸出顯示在終端機底部。全程在本機執行，不消耗 API tokens。

## Acknowledgments / 致謝

本專案基於 [YAHA 學堂](https://www.youtube.com/@yaboruei) 的[教學影片](https://youtu.be/wHRFuTqlpD8?si=-iWSGmMA3w7z40V-)。影片介紹了 Claude Code statusline 腳本的概念與基礎做法。我們在此基礎上新增了 rate limits 顯示、安全安裝腳本、TDD 測試套件，並修復了 macOS 上 `seq 1 0` 的相容性 bug。

## License

MIT
