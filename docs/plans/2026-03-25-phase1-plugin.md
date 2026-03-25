# Phase 1: Claude Code Plugin Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 將 v1.0.0 statusline 腳本重構為 Claude Code Plugin 格式，新增對話式設定選單和行數開關功能。

**Architecture:** Plugin 由三個核心元件組成：(1) `scripts/statusline.sh` — 從 config 讀取行數開關並條件輸出，(2) `scripts/config.sh` — 讀寫 `~/.claude/statusline-config.json`，(3) `commands/statusline.md` — 指示 Claude 呈現對話式中英文選單。所有 v1.0.0 行為向後相容。

**Tech Stack:** Bash, jq, Claude Code Plugin system

**Spec:** `docs/specs/2026-03-25-statusline-extension-design.md`

---

## 分工與模型指派

| 角色 | 模型 | 負責任務 |
|------|------|---------|
| **主 Context (Opus)** | Opus | 規劃、Review、選單設計、最終整合、發佈 |
| **SubAgent A (Sonnet)** | Sonnet | Task 1: config.sh TDD |
| **SubAgent B (Sonnet)** | Sonnet | Task 2: statusline.sh 重構 TDD |
| **SubAgent C (Sonnet)** | Sonnet | Task 3: Plugin 結構 + settings.json |
| **SubAgent D (Sonnet)** | Sonnet | Task 5: README 重構 |
| **Review Agent (Opus)** | Opus | 每個 Task 完成後 Code Review |

**並行策略：**
- Task 1 (config.sh) 和 Task 3 (plugin structure) 可並行
- Task 2 (statusline.sh) 依賴 Task 1 完成（需要 config.sh）
- Task 4 (slash command) 由 Opus 主 context 完成（需要設計判斷）
- Task 5 (README) 可與 Task 1-3 並行
- Task 6 (整合測試) 在 Task 1-4 全部完成後執行

```
          ┌─ SubAgent A: Task 1 (config.sh) ──┐
          │                                     ├─ SubAgent B: Task 2 (statusline.sh) ─┐
Start ────┼─ SubAgent C: Task 3 (plugin struct)─┘                                      ├─ Task 6 (整合) → Task 7 (發佈)
          │                                                                             │
          ├─ SubAgent D: Task 5 (README) ───────────────────────────────────────────────┘
          │
          └─ Opus: Task 4 (slash command) ──────────────────────────────────────────────┘
```

---

## File Structure

### 新建檔案

| 檔案 | 職責 |
|------|------|
| `.claude-plugin/plugin.json` | Plugin manifest（name + description） |
| `settings.json`（根目錄） | Plugin settings — statusLine 指向 scripts/statusline.sh |
| `scripts/statusline.sh` | 主 statusline 腳本（從根目錄 statusline.sh 演進，支援 config） |
| `scripts/config.sh` | 設定讀寫工具（讀取/寫入/重設 statusline-config.json） |
| `commands/statusline.md` | `/statusline` 對話式選單指令 |
| `tests/test_config.sh` | config.sh 測試（~10 tests） |
| `tests/test_plugin.sh` | Plugin 結構驗證測試（~5 tests） |
| `README.en.md` | English README（從現有 README.md 改名而來） |

### 修改檔案

| 檔案 | 變更 |
|------|------|
| `statusline.sh`（根目錄） | 保留為 legacy 版本，不修改（install.sh 用） |
| `test_statusline.sh` | 新增 Ctx 前綴測試 + 行數開關測試（指向 scripts/statusline.sh） |
| `README.md` | 改為繁體中文主版本 |
| `README.zh-TW.md` | 刪除（合併進 README.md） |
| `install.sh` | 更新版本號為 1.1.0 |
| `VERSION` | 更新為 1.1.0 |

---

## Task 1: config.sh — 設定讀寫工具

**Assigned to: Sonnet SubAgent A**

**Files:**
- Create: `scripts/config.sh`
- Create: `tests/test_config.sh`

### config.sh API 設計

```bash
# 讀取設定（輸出 JSON，檔案不存在或 malformed 時輸出預設值）
scripts/config.sh read

# 寫入單一行的開關
scripts/config.sh set model_git true|false
scripts/config.sh set progress_cost true|false
scripts/config.sh set rate_limits true|false

# 重設為預設值（全開）
scripts/config.sh reset

# 讀取單一行的值（輸出 true 或 false）
scripts/config.sh get model_git
```

- [ ] **Step 1: 建立測試骨架**

建立 `tests/test_config.sh`，包含 test helpers（assert_eq, setup, teardown）：

```bash
#!/bin/bash
PASS=0; FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_SCRIPT="$SCRIPT_DIR/scripts/config.sh"
TEST_DIR="/tmp/test-claude-config-$$"

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ✓ $name"; ((PASS++))
    else
        echo "  ✗ $name"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        ((FAIL++))
    fi
}

setup() { rm -rf "$TEST_DIR"; mkdir -p "$TEST_DIR"; }
teardown() { rm -rf "$TEST_DIR"; }
```

- [ ] **Step 2: 寫 read 的 failing tests（含 malformed fallback）**

```bash
echo "--- read 預設值 ---"
setup
output=$(CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" read)
assert_eq "無檔案時 model_git 預設 true" \
    "true" "$(echo "$output" | jq -r '.lines.model_git')"
assert_eq "無檔案時 progress_cost 預設 true" \
    "true" "$(echo "$output" | jq -r '.lines.progress_cost')"
assert_eq "無檔案時 rate_limits 預設 true" \
    "true" "$(echo "$output" | jq -r '.lines.rate_limits')"

echo "--- malformed JSON fallback ---"
setup
echo '{invalid' > "$TEST_DIR/statusline-config.json"
output=$(CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" read)
assert_eq "malformed JSON fallback model_git" \
    "true" "$(echo "$output" | jq -r '.lines.model_git')"
```

- [ ] **Step 3: Run tests — verify FAIL**

Run: `bash tests/test_config.sh`
Expected: FAIL（config.sh 不存在）

- [ ] **Step 4: 實作 config.sh read**

建立 `scripts/config.sh`：

```bash
#!/bin/bash
set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CONFIG_FILE="$CLAUDE_HOME/statusline-config.json"

DEFAULT_CONFIG='{"lines":{"model_git":true,"progress_cost":true,"rate_limits":true}}'

cmd_read() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$DEFAULT_CONFIG"
        return
    fi
    # malformed JSON fallback
    if ! jq . "$CONFIG_FILE" >/dev/null 2>&1; then
        echo "$DEFAULT_CONFIG"
        return
    fi
    cat "$CONFIG_FILE"
}

case "${1:-read}" in
    read) cmd_read ;;
    *) echo "Usage: config.sh read|set|get|reset" >&2; exit 1 ;;
esac
```

- [ ] **Step 5: Run tests — verify read + malformed tests PASS**

Run: `bash tests/test_config.sh`
Expected: 4 PASS

- [ ] **Step 6: 寫 edge case failing tests（invalid key/value/command）**

```bash
echo "--- 輸入驗證 ---"
setup
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set invalid_key true 2>/dev/null; result=$?
assert_eq "invalid key 回傳非零" "1" "$result"

CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set model_git maybe 2>/dev/null; result=$?
assert_eq "invalid value 回傳非零" "1" "$result"

CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" unknown_command 2>/dev/null; result=$?
assert_eq "unknown command 回傳非零" "1" "$result"
```

- [ ] **Step 7: Run tests — verify edge case tests FAIL**（set/command 尚未實作）

- [ ] **Step 8: 寫 set 的 failing tests**

```bash
echo "--- set ---"
setup
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set model_git false
output=$(CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" read)
assert_eq "set model_git false" \
    "false" "$(echo "$output" | jq -r '.lines.model_git')"
assert_eq "set 後其他值不變" \
    "true" "$(echo "$output" | jq -r '.lines.progress_cost')"
```

- [ ] **Step 9: 實作 config.sh set**

在 config.sh 中新增：

```bash
cmd_set() {
    local key="$1" value="$2"
    # 驗證 key
    case "$key" in
        model_git|progress_cost|rate_limits) ;;
        *) echo "Invalid key: $key" >&2; exit 1 ;;
    esac
    # 驗證 value
    case "$value" in
        true|false) ;;
        *) echo "Invalid value: $value (use true/false)" >&2; exit 1 ;;
    esac
    # 讀取現有或預設
    local current
    current=$(cmd_read)
    # 確保目錄存在
    mkdir -p "$(dirname "$CONFIG_FILE")"
    # 更新並寫入（先寫 temp 再 mv，避免 race condition）
    local tmpfile
    tmpfile=$(mktemp "${CONFIG_FILE}.XXXXXX")
    if echo "$current" | jq ".lines.$key = $value" > "$tmpfile"; then
        mv "$tmpfile" "$CONFIG_FILE"
    else
        rm -f "$tmpfile"
        echo "Failed to write config" >&2; exit 1
    fi
}
```

- [ ] **Step 10: Run tests — verify set tests PASS**

- [ ] **Step 11: 寫 get 的 failing tests**

```bash
echo "--- get ---"
setup
output=$(CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" get model_git)
assert_eq "get 預設值" "true" "$output"

CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set rate_limits false
output=$(CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" get rate_limits)
assert_eq "get 設定後的值" "false" "$output"
```

- [ ] **Step 12: 實作 config.sh get**

```bash
cmd_get() {
    local key="$1"
    case "$key" in
        model_git|progress_cost|rate_limits) ;;
        *) echo "Invalid key: $key" >&2; exit 1 ;;
    esac
    cmd_read | jq -r ".lines.$key"
}
```

- [ ] **Step 13: Run tests — verify get tests PASS**

- [ ] **Step 14: 寫 reset 的 failing tests**

```bash
echo "--- reset ---"
setup
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set model_git false
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set rate_limits false
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" reset
output=$(CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" read)
assert_eq "reset 後 model_git 回到 true" \
    "true" "$(echo "$output" | jq -r '.lines.model_git')"
assert_eq "reset 後 rate_limits 回到 true" \
    "true" "$(echo "$output" | jq -r '.lines.rate_limits')"
```

- [ ] **Step 15: 實作 config.sh reset**

```bash
cmd_reset() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    echo "$DEFAULT_CONFIG" | jq . > "$CONFIG_FILE"
}
```

- [ ] **Step 16: Run all config tests — verify ALL PASS**

Run: `bash tests/test_config.sh`
Expected: ~10 tests, all PASS

- [ ] **Step 17: Commit**

```bash
git add scripts/config.sh tests/test_config.sh
git commit -m "feat: add config.sh for statusline settings read/write/reset"
```

---

## Task 2: statusline.sh 重構 — 支援 config 讀取和 Ctx 前綴

**Assigned to: Sonnet SubAgent B**
**Depends on: Task 1 完成（需要 config.sh）**

**Files:**
- Create: `scripts/statusline.sh`（從根目錄 `statusline.sh` 複製並修改）
- Modify: `test_statusline.sh`（新增測試，改指向 `scripts/statusline.sh`）

**注意：** 根目錄的 `statusline.sh` 保持不動（legacy install.sh 用戶仍依賴它）。

- [ ] **Step 1: 複製 statusline.sh 到 scripts/**

```bash
mkdir -p scripts
cp statusline.sh scripts/statusline.sh
chmod +x scripts/statusline.sh
```

- [ ] **Step 2: 建立 test_statusline_v2.sh 測試新版本**

建立 `tests/test_statusline_v2.sh`，複製 `test_statusline.sh` 的 helpers，但 `SCRIPT` 指向 `scripts/statusline.sh`：

```bash
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/statusline.sh"
```

- [ ] **Step 3: 寫 Ctx 前綴的 failing test**

```bash
echo "--- Ctx 前綴 ---"
BASIC='{"model":{"display_name":"Opus"},"cwd":"/tmp","context_window":{"used_percentage":45},"cost":{"total_cost_usd":1.50,"total_duration_ms":600000}}'
assert_contains "Line 2 顯示 Ctx 前綴" "$BASIC" "Ctx 45%"
```

- [ ] **Step 4: Run test — verify FAIL**（目前輸出 `45%` 沒有 `Ctx`）

- [ ] **Step 5: 修改 scripts/statusline.sh 加入 Ctx 前綴**

修改 Line 2 的 echo：

```bash
# 舊：
echo -e "$bar ${bar_color}${percentage}%${RESET} │ ${DIM}${cost_str} · ${time_str}${RESET}"
# 新：
echo -e "$bar ${bar_color}Ctx ${percentage}%${RESET} │ ${DIM}${cost_str} · ${time_str}${RESET}"
```

- [ ] **Step 6: Run test — verify Ctx PASS**

- [ ] **Step 7: 寫行數開關的 failing tests**

```bash
echo "--- 行數開關 ---"
# 需要設定 CLAUDE_HOME 讓 config.sh 可以讀取
TEST_DIR="/tmp/test-statusline-v2-$$"
mkdir -p "$TEST_DIR"

# 關閉 Line 1
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set model_git false
output=$(echo "$BASIC" | CLAUDE_HOME="$TEST_DIR" "$SCRIPT" 2>/dev/null | strip_ansi)
line_count=$(echo "$output" | wc -l | tr -d ' ')
assert_eq "關閉 Line 1 後只剩 1 行" "1" "$line_count"
assert_contains "關閉 Line 1 後第一行是進度條" "$output" "Ctx 45%"

# 關閉 Line 3
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" reset
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set rate_limits false
RATE_INPUT='{"model":{"display_name":"Opus"},"cwd":"/tmp","context_window":{"used_percentage":25},"cost":{"total_cost_usd":0.5,"total_duration_ms":60000},"rate_limits":{"five_hour":{"used_percentage":23,"resets_at":9999999999},"seven_day":{"used_percentage":41,"resets_at":9999999999}}}'
output=$(echo "$RATE_INPUT" | CLAUDE_HOME="$TEST_DIR" "$SCRIPT" 2>/dev/null)
line_count=$(echo "$output" | wc -l | tr -d ' ')
assert_eq "關閉 Line 3 + 有 rate_limits 仍只有 2 行" "2" "$line_count"

# 全關
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set model_git false
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set progress_cost false
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set rate_limits false
output=$(echo "$BASIC" | CLAUDE_HOME="$TEST_DIR" "$SCRIPT" 2>/dev/null)
assert_eq "全關時無輸出" "" "$output"

rm -rf "$TEST_DIR"
```

- [ ] **Step 8: Run tests — verify FAIL**

- [ ] **Step 9: 修改 scripts/statusline.sh 加入 config 讀取和行數開關**

在腳本開頭加入 config 讀取：

```bash
#!/bin/bash
input=$(cat)

# ── 讀取設定 ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_SCRIPT="$SCRIPT_DIR/config.sh"
if [ -x "$CONFIG_SCRIPT" ]; then
    show_model_git=$("$CONFIG_SCRIPT" get model_git)
    show_progress_cost=$("$CONFIG_SCRIPT" get progress_cost)
    show_rate_limits=$("$CONFIG_SCRIPT" get rate_limits)
else
    # fallback: 無 config.sh 時全部顯示（向後相容）
    show_model_git=true
    show_progress_cost=true
    show_rate_limits=true
fi
```

用條件包住各行輸出：

```bash
# ── 第一行：模型 + 資料夾 + Git ──
if [ "$show_model_git" = "true" ]; then
    echo -e "[$model] $directory$git_info"
fi

# ── 第二行：進度條 + 費用 + 時間 ──
if [ "$show_progress_cost" = "true" ]; then
    echo -e "$bar ${bar_color}Ctx ${percentage}%${RESET} │ ${DIM}${cost_str} · ${time_str}${RESET}"
fi

# ── 第三行：Rate Limits ──
# 注意：five_hour_pct/seven_day_pct 的解析和顏色計算邏輯保持不變（從根目錄 statusline.sh 第 69-113 行複製）
# 只有最後的 echo 被包在條件中
if [ "$show_rate_limits" = "true" ] && [ -n "$five_hour_pct" ] && [ -n "$seven_day_pct" ]; then
    five_hour_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // 0' | cut -d. -f1)
    seven_day_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // 0' | cut -d. -f1)
    now=$(date +%s)

    five_diff=$(( five_hour_reset - now ))
    if [ "$five_diff" -le 0 ] 2>/dev/null; then five_str="now"
    else five_h=$(( five_diff / 3600 )); five_m=$(( (five_diff % 3600) / 60 )); five_str="${five_h}h ${five_m}m"; fi

    seven_diff=$(( seven_day_reset - now ))
    if [ "$seven_diff" -le 0 ] 2>/dev/null; then seven_str="now"
    else seven_d=$(( seven_diff / 86400 )); seven_h=$(( (seven_diff % 86400) / 3600 )); seven_str="${seven_d}d ${seven_h}h"; fi

    if [ "$five_hour_pct" -ge 90 ] 2>/dev/null; then five_color="$RED"
    elif [ "$five_hour_pct" -ge 70 ] 2>/dev/null; then five_color="$YELLOW"
    else five_color="$GREEN"; fi

    if [ "$seven_day_pct" -ge 90 ] 2>/dev/null; then seven_color="$RED"
    elif [ "$seven_day_pct" -ge 70 ] 2>/dev/null; then seven_color="$YELLOW"
    else seven_color="$GREEN"; fi

    echo -e "${five_color}5h: ${five_hour_pct}%${RESET} ${DIM}(reset ${five_str})${RESET} │ ${seven_color}7d: ${seven_day_pct}%${RESET} ${DIM}(reset ${seven_str})${RESET}"
fi
```

- [ ] **Step 10: Run tests — verify ALL PASS**

- [ ] **Step 11: 跑原有 test_statusline.sh 確認 legacy 版不受影響**

Run: `bash test_statusline.sh`
Expected: 33 tests PASS（根目錄 statusline.sh 未修改）

- [ ] **Step 12: Commit**

```bash
git add scripts/statusline.sh tests/test_statusline_v2.sh
git commit -m "feat: add scripts/statusline.sh with Ctx prefix and line toggle support"
```

---

## Task 3: Plugin 結構 + settings.json

**Assigned to: Sonnet SubAgent C**（可與 Task 1 並行）

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `settings.json`（根目錄）
- Create: `tests/test_plugin.sh`

- [ ] **Step 1: 寫 plugin 結構驗證 failing tests**

建立 `tests/test_plugin.sh`：

```bash
#!/bin/bash
PASS=0; FAIL=0
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

assert_true() {
    local name="$1"; shift
    if eval "$@" 2>/dev/null; then
        echo "  ✓ $name"; ((PASS++))
    else
        echo "  ✗ $name"; ((FAIL++))
    fi
}

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  ✓ $name"; ((PASS++))
    else
        echo "  ✗ $name"; echo "    expected: $expected"; echo "    actual: $actual"; ((FAIL++))
    fi
}

echo "=== Plugin Structure Tests ==="

echo "--- plugin.json ---"
assert_true ".claude-plugin/ 目錄存在" \
    "test -d '$PROJECT_DIR/.claude-plugin'"
assert_true "plugin.json 存在" \
    "test -f '$PROJECT_DIR/.claude-plugin/plugin.json'"
assert_true "plugin.json 是合法 JSON" \
    "jq . '$PROJECT_DIR/.claude-plugin/plugin.json' >/dev/null 2>&1"
assert_eq "plugin name" \
    "claude-statusline" \
    "$(jq -r '.name' '$PROJECT_DIR/.claude-plugin/plugin.json')"

echo "--- settings.json ---"
assert_true "settings.json 存在" \
    "test -f '$PROJECT_DIR/settings.json'"
assert_true "settings.json 是合法 JSON" \
    "jq . '$PROJECT_DIR/settings.json' >/dev/null 2>&1"
assert_eq "statusLine type" \
    "command" \
    "$(jq -r '.statusLine.type' '$PROJECT_DIR/settings.json')"

echo "--- 目錄結構 ---"
assert_true "commands/ 目錄存在" \
    "test -d '$PROJECT_DIR/commands'"
assert_true "scripts/ 目錄存在" \
    "test -d '$PROJECT_DIR/scripts'"

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
```

- [ ] **Step 2: Run tests — verify FAIL**

- [ ] **Step 3: 建立 plugin.json**

```bash
mkdir -p .claude-plugin
```

寫入 `.claude-plugin/plugin.json`：

```json
{
  "name": "claude-statusline",
  "description": "Colorful 3-line statusline with context window, Git info, cost tracking, and rate limits. Configurable via conversational menu with bilingual (中文/English) instructions."
}
```

- [ ] **Step 4: 建立 settings.json**

寫入根目錄 `settings.json`：

```json
{
  "statusLine": {
    "type": "command",
    "command": "${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh"
  }
}
```

- [ ] **Step 5: 確保 commands/ 和 scripts/ 目錄存在**

```bash
mkdir -p commands scripts
```

- [ ] **Step 6: Run tests — verify ALL PASS**

Run: `bash tests/test_plugin.sh`
Expected: ~8 tests PASS

- [ ] **Step 7: Commit**

```bash
git add .claude-plugin/plugin.json settings.json tests/test_plugin.sh
git commit -m "feat: add plugin structure with plugin.json and settings.json"
```

---

## Task 4: `/statusline` 對話式選單指令

**Assigned to: Opus 主 Context**（需要設計判斷力）
**Depends on: Task 1（slash command 呼叫 config.sh）**

**Files:**
- Create: `commands/statusline.md`

- [ ] **Step 1: 撰寫 commands/statusline.md**

```markdown
---
description: "設定 Statusline 顯示選項 / Configure statusline display settings"
---

You are managing the Claude Code Statusline configuration. Follow these instructions exactly.

## Step 1: Read Current Config

Run this command to read the current configuration:

```bash
bash ~/.claude/claude-statusline/scripts/config.sh read 2>/dev/null || echo '{"lines":{"model_git":true,"progress_cost":true,"rate_limits":true}}'
```

Parse the JSON output to determine which lines are currently enabled.

## Step 2: Present Main Menu

Display EXACTLY this menu, replacing the status indicators based on the config:

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

Then STOP and wait for the user's response.

## Step 3: Handle Selection

### If user selects 1 (Display Settings):

Read the config again, then show:

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

Replace [✅|❌] with the actual status from config. Then STOP and wait.

When user selects 1-3, run the corresponding toggle command:

- 1 → `bash ~/.claude/claude-statusline/scripts/config.sh set model_git [true|false]`
- 2 → `bash ~/.claude/claude-statusline/scripts/config.sh set progress_cost [true|false]`
- 3 → `bash ~/.claude/claude-statusline/scripts/config.sh set rate_limits [true|false]`

Toggle means: if currently true → set false, if currently false → set true.

After toggling, show confirmation:

```
[✅ → ❌ | ❌ → ✅] [Line 名稱] [已關閉 / disabled | 已開啟 / enabled]
設定已儲存 / Settings saved

目前狀態 / Current: [✅|❌] Line 1  [✅|❌] Line 2  [✅|❌] Line 3
```

Then show the Display Settings menu again for further changes. If user selects 4 (Back), return to the main menu.

### If user selects 2 (Preview):

Run a preview command using sample data:

```bash
echo '{"model":{"display_name":"Opus 4.6 (1M)"},"cwd":"'"$(pwd)"'","context_window":{"used_percentage":45},"cost":{"total_cost_usd":1.50,"total_duration_ms":600000}}' | bash ~/.claude/claude-statusline/scripts/statusline.sh
```

Show the output to the user, then return to the main menu.

### If user selects 3 (Reset):

Run:

```bash
bash ~/.claude/claude-statusline/scripts/config.sh reset
```

Show:

```
✅ 已恢復預設設定（全部三行開啟）
✅ Default settings restored (all 3 lines enabled)
```

Then return to the main menu.

## Important Notes

- Always use `bash ~/.claude/claude-statusline/scripts/config.sh` with the full path
- The config file is stored at `~/.claude/statusline-config.json`
- If config.sh is not found, inform the user the plugin may not be installed correctly
- Present menus in BOTH Chinese and English as shown above
- After any config change, the statusline updates on the next Claude response
```

- [ ] **Step 2: 手動測試 — 在 Claude Code 中執行 `/statusline` 確認對話流程**

- [ ] **Step 3: Commit**

```bash
git add commands/statusline.md
git commit -m "feat: add /statusline conversational menu command"
```

---

## Task 5: README 重構

**Assigned to: Sonnet SubAgent D**（可並行）

**Files:**
- Modify: `README.md` → 改為繁體中文主版本
- Rename: `README.zh-TW.md` → 刪除（內容合併進 README.md）
- Create: `README.en.md` → English 翻譯版

- [ ] **Step 1: 讀取現有 README.md（英文版）和 README.zh-TW.md（中文版）**

- [ ] **Step 2: 建立新的 README.md（繁體中文主版本）**

基於 README.zh-TW.md 內容，更新以下段落：
- 頂部加入 `[English](README.en.md)` 連結
- 加入 Plugin 安裝方式（推薦）
- 加入 `/statusline` 指令說明
- 加入行數切換功能說明
- 更新版本號為 v1.1.0
- 保留 install.sh 安裝方式作為「傳統安裝」段落

- [ ] **Step 3: 建立 README.en.md（English 版）**

基於現有 README.md 英文內容，同步更新：
- 頂部加入 `[繁體中文](README.md)` 連結
- 同步新增 Plugin 安裝、指令說明、行數切換等段落

- [ ] **Step 4: 刪除 README.zh-TW.md**

```bash
git rm README.zh-TW.md
```

- [ ] **Step 5: Commit**

```bash
git add README.md README.en.md
git rm README.zh-TW.md
git commit -m "docs: make Chinese the primary README, English as translation"
```

---

## Task 6: 整合測試 + 最終驗證

**Assigned to: Opus 主 Context**
**Depends on: Task 1-4 全部完成**

- [ ] **Step 1: 跑所有測試**

```bash
echo "=== Legacy Tests ===" && bash test_statusline.sh && bash test_installer.sh
echo "=== New Tests ===" && bash tests/test_config.sh && bash tests/test_plugin.sh && bash tests/test_statusline_v2.sh
```

Expected: 全部 PASS

- [ ] **Step 2: 驗證 Plugin 結構完整性**

```bash
# 確認所有必要檔案存在
ls -la .claude-plugin/plugin.json
ls -la settings.json
ls -la commands/statusline.md
ls -la scripts/statusline.sh
ls -la scripts/config.sh
```

- [ ] **Step 3: 驗證 ${CLAUDE_PLUGIN_ROOT} 展開**

手動在 Claude Code 中安裝此 plugin，確認 statusline 是否正常運作。如果 `${CLAUDE_PLUGIN_ROOT}` 無法在 `statusLine.command` 中展開，需要改用 hook 方案。

- [ ] **Step 4: 更新 VERSION 和 install.sh**

```bash
echo "1.1.0" > VERSION
# 更新 install.sh 中的 VERSION="1.0.0" → VERSION="1.1.0"
sed -i '' 's/VERSION="1.0.0"/VERSION="1.1.0"/' install.sh
```

- [ ] **Step 5: Commit**

```bash
git add VERSION install.sh
git commit -m "chore: bump version to 1.1.0"
```

---

## Task 7: 發佈

**Assigned to: Opus 主 Context**
**Depends on: Task 6 完成 + Code Review 通過**

- [ ] **Step 1: Code Review**

派 Opus SubAgent 做最終 Code Review，檢查所有新增和修改的檔案。

- [ ] **Step 2: 同步到 Tools 備份**

```bash
rsync -av --exclude='.git' ~/.claude/claude-statusline/ ~/資料/Tools/claude-statusline/
```

- [ ] **Step 3: Git tag**

```bash
git tag v1.1.0
```

- [ ] **Step 4: Push to GitHub**

```bash
git push origin main --tags
```

- [ ] **Step 5: 在 GitHub 建立 Release**

```bash
gh release create v1.1.0 --title "v1.1.0 — Plugin Format + Line Toggle" --notes "..."
```

---

## Summary

| Task | 模型 | 依賴 | 預估測試數 |
|------|------|------|-----------|
| Task 1: config.sh | Sonnet SubAgent | 無 | ~13 |
| Task 2: statusline.sh v2 | Sonnet SubAgent | Task 1 | ~7 新增 |
| Task 3: Plugin 結構 | Sonnet SubAgent | 無（並行 Task 1） | ~8 |
| Task 4: Slash command | Opus 主 Context | Task 1 | 手動測試 |
| Task 5: README | Sonnet SubAgent | 無（並行） | 無 |
| Task 6: 整合測試 | Opus 主 Context | Task 1-4 | 全套 ~77 |
| Task 7: 發佈 | Opus 主 Context | Task 6 + Review | 無 |
