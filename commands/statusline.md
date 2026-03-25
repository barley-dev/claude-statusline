---
description: "設定 Statusline 顯示選項 / Configure statusline display settings"
---

You are managing the Claude Code Statusline configuration. Follow these instructions precisely.

## Step 1: Read Current Config

Run this command to read the current configuration:

```bash
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}" && bash "$CLAUDE_HOME/claude-statusline/scripts/config.sh" read 2>/dev/null || echo '{"lines":{"model_git":true,"progress_cost":true,"rate_limits":true}}'
```

If the command fails or config.sh is not found, use the default: all three lines enabled.

Parse the JSON output to determine which lines are currently enabled (`true` or `false` for each key: `model_git`, `progress_cost`, `rate_limits`).

## Step 2: Present Main Menu

Display EXACTLY this menu format, in a single code block. Do not add extra explanation before the menu:

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

Then STOP and wait for the user's response. Do not continue until they reply.

## Step 3: Handle Selection

### If user selects 1 (Display Settings):

Read the config again (Step 1), then display this menu. Replace `[✅|❌]` with actual status, and `[開啟中 / Currently ON|已關閉 / Currently OFF]` accordingly:

```
顯示設定 / Display Settings
─────────────────────────────
目前狀態 / Current: [✅|❌] Line 1  [✅|❌] Line 2  [✅|❌] Line 3

1. [✅|❌] 模型 + Git 資訊 / Model + Git Info
   → [Opus 4.6 (1M)] project-name (main +2 ~1)
   → Toggle: [開啟中 / Currently ON | 已關閉 / Currently OFF]

2. [✅|❌] 進度條 + 費用 + 時間 / Progress + Cost + Time
   → ████░░░░░░ Ctx 45% │ $1.50 · 10m30s
   → Toggle: [開啟中 / Currently ON | 已關閉 / Currently OFF]

3. [✅|❌] Rate Limits（僅 Pro/Max）
   → 5h: 30% (reset 2h 15m) │ 7d: 10% (reset 5d 3h)
   → Toggle: [開啟中 / Currently ON | 已關閉 / Currently OFF]

4. ← 返回 / Back

請選擇要切換的項目 / Choose item to toggle (1-4):
```

Then STOP and wait for the user's response.

When user selects 1, 2, or 3, run the corresponding toggle command. Toggle means: if currently `true`, set to `false`; if currently `false`, set to `true`.

```bash
# For option 1 (model_git):
bash "$HOME/.claude/claude-statusline/scripts/config.sh" set model_git [true|false]

# For option 2 (progress_cost):
bash "$HOME/.claude/claude-statusline/scripts/config.sh" set progress_cost [true|false]

# For option 3 (rate_limits):
bash "$HOME/.claude/claude-statusline/scripts/config.sh" set rate_limits [true|false]
```

After toggling, show confirmation and updated status:

```
[✅ → ❌ | ❌ → ✅] [Line 名稱 / Line Name] [已關閉 / disabled | 已開啟 / enabled]
設定已儲存 / Settings saved

目前狀態 / Current: [✅|❌] Line 1  [✅|❌] Line 2  [✅|❌] Line 3
```

Then show the Display Settings menu again for further changes. If user selects 4 (Back), return to the main menu (Step 2).

### If user selects 2 (Preview):

Run a preview using sample data:

```bash
echo '{"model":{"display_name":"Opus 4.6 (1M)"},"cwd":"'"$(pwd)"'","context_window":{"used_percentage":45},"cost":{"total_cost_usd":1.50,"total_duration_ms":600000}}' | bash "$HOME/.claude/claude-statusline/scripts/statusline.sh"
```

Show the output to the user with a brief note:

```
預覽 / Preview（使用範例資料 / using sample data）:

[output here]

statusline 會在每次 Claude 回覆後自動更新。
The statusline updates automatically after each Claude response.
```

Then return to the main menu (Step 2).

### If user selects 3 (Reset):

Run:

```bash
bash "$HOME/.claude/claude-statusline/scripts/config.sh" reset
```

Show:

```
✅ 已恢復預設設定（全部三行開啟）
✅ Default settings restored (all 3 lines enabled)
```

Then return to the main menu (Step 2).

## Important Rules

- Always present menus in BOTH Chinese AND English as shown above
- Always STOP and wait for user input after presenting a menu
- If config.sh is not found, tell the user: "找不到 config.sh，請確認 plugin 已正確安裝。/ config.sh not found, please verify the plugin is installed correctly."
- After any config change, remind the user: "變更會在下次 Claude 回覆後生效。/ Changes take effect after the next Claude response."
- Use `$HOME/.claude/claude-statusline/scripts/config.sh` as the full path for all config operations
