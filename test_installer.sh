#!/bin/bash
# TDD 測試腳本 for install.sh / uninstall.sh
# 使用暫存目錄模擬 ~/.claude/，不動到真實設定

PASS=0
FAIL=0
TEST_DIR="/tmp/test-claude-statusline-$$"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

assert_true() {
    local name="$1"; shift
    if eval "$@" 2>/dev/null; then
        echo "  ✓ $name"; ((PASS++))
    else
        echo "  ✗ $name"; ((FAIL++))
    fi
}

setup() {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
}

echo "=== Installer TDD Tests ==="
echo ""

# --- Test 1: 乾淨安裝（無 settings.json）---
echo "--- 乾淨安裝 ---"
setup
CLAUDE_HOME="$TEST_DIR" "$SCRIPT_DIR/install.sh" --yes >/dev/null 2>&1
assert_true "statusline.sh 存在" "test -f '$TEST_DIR/statusline.sh'"
assert_true "statusline.sh 有執行權限" "test -x '$TEST_DIR/statusline.sh'"
assert_true "settings.json 存在" "test -f '$TEST_DIR/settings.json'"
assert_eq "settings.json 含 statusLine type" \
    "command" \
    "$(jq -r '.statusLine.type' "$TEST_DIR/settings.json" 2>/dev/null)"
assert_eq "statusLine command 指向正確路徑" \
    "~/.claude/statusline.sh" \
    "$(jq -r '.statusLine.command' "$TEST_DIR/settings.json" 2>/dev/null)"

# --- Test 2: 合併已有 settings.json ---
echo ""
echo "--- 合併已有設定 ---"
setup
cat > "$TEST_DIR/settings.json" << 'EOF'
{
  "model": "opus",
  "permissions": {
    "defaultMode": "bypassPermissions"
  },
  "effortLevel": "medium"
}
EOF
CLAUDE_HOME="$TEST_DIR" "$SCRIPT_DIR/install.sh" --yes >/dev/null 2>&1
assert_eq "保留原有 model" \
    "opus" \
    "$(jq -r '.model' "$TEST_DIR/settings.json" 2>/dev/null)"
assert_eq "保留 permissions" \
    "bypassPermissions" \
    "$(jq -r '.permissions.defaultMode' "$TEST_DIR/settings.json" 2>/dev/null)"
assert_eq "保留 effortLevel" \
    "medium" \
    "$(jq -r '.effortLevel' "$TEST_DIR/settings.json" 2>/dev/null)"
assert_eq "合併後有 statusLine" \
    "command" \
    "$(jq -r '.statusLine.type' "$TEST_DIR/settings.json" 2>/dev/null)"

# --- Test 3: 已有 statusLine 時覆蓋 ---
echo ""
echo "--- 覆蓋已有 statusLine ---"
setup
cat > "$TEST_DIR/settings.json" << 'EOF'
{
  "model": "sonnet",
  "statusLine": {
    "type": "command",
    "command": "/old/path/to/script.sh"
  }
}
EOF
CLAUDE_HOME="$TEST_DIR" "$SCRIPT_DIR/install.sh" --yes >/dev/null 2>&1
assert_eq "覆蓋後 command 更新" \
    "~/.claude/statusline.sh" \
    "$(jq -r '.statusLine.command' "$TEST_DIR/settings.json" 2>/dev/null)"
assert_eq "覆蓋後保留 model" \
    "sonnet" \
    "$(jq -r '.model' "$TEST_DIR/settings.json" 2>/dev/null)"

# --- Test 4: 備份機制 ---
echo ""
echo "--- 備份 ---"
setup
echo '{"model":"opus"}' > "$TEST_DIR/settings.json"
CLAUDE_HOME="$TEST_DIR" "$SCRIPT_DIR/install.sh" --yes >/dev/null 2>&1
assert_true "已有設定時建立 .bak 備份" "test -f '$TEST_DIR/settings.json.bak'"
assert_eq "備份內容正確" \
    "opus" \
    "$(jq -r '.model' "$TEST_DIR/settings.json.bak" 2>/dev/null)"

# --- Test 5: malformed JSON ---
echo ""
echo "--- Malformed JSON ---"
setup
echo '{invalid json' > "$TEST_DIR/settings.json"
CLAUDE_HOME="$TEST_DIR" "$SCRIPT_DIR/install.sh" --yes >/dev/null 2>&1
result=$?
assert_true "malformed JSON 回傳非零 exit code" "test $result -ne 0"
assert_eq "malformed JSON 不被覆蓋（內容不變）" \
    '{invalid json' \
    "$(cat "$TEST_DIR/settings.json")"

# --- Test 6: 反安裝 ---
echo ""
echo "--- 反安裝 ---"
setup
cat > "$TEST_DIR/settings.json" << 'EOF'
{
  "model": "opus",
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
EOF
touch "$TEST_DIR/statusline.sh"
CLAUDE_HOME="$TEST_DIR" "$SCRIPT_DIR/uninstall.sh" --yes >/dev/null 2>&1
assert_true "statusline.sh 已刪除" "test ! -f '$TEST_DIR/statusline.sh'"
assert_eq "settings.json 中 statusLine 已移除" \
    "null" \
    "$(jq -r '.statusLine' "$TEST_DIR/settings.json" 2>/dev/null)"
assert_eq "反安裝後保留 model" \
    "opus" \
    "$(jq -r '.model' "$TEST_DIR/settings.json" 2>/dev/null)"

# --- Test 7: 反安裝後只剩空物件 ---
echo ""
echo "--- 反安裝空檔處理 ---"
setup
echo '{"statusLine":{"type":"command","command":"~/.claude/statusline.sh"}}' > "$TEST_DIR/settings.json"
touch "$TEST_DIR/statusline.sh"
CLAUDE_HOME="$TEST_DIR" "$SCRIPT_DIR/uninstall.sh" --yes >/dev/null 2>&1
assert_true "settings.json 仍存在" "test -f '$TEST_DIR/settings.json'"
assert_true "settings.json 是合法 JSON" "jq . '$TEST_DIR/settings.json' >/dev/null 2>&1"

# --- Test 8: 安裝後 statusline 功能正確 ---
echo ""
echo "--- 安裝後功能驗證 ---"
setup
CLAUDE_HOME="$TEST_DIR" "$SCRIPT_DIR/install.sh" --yes >/dev/null 2>&1
output=$(echo '{"model":{"display_name":"Opus"},"cwd":"/tmp/test","context_window":{"used_percentage":50},"cost":{"total_cost_usd":1.00,"total_duration_ms":120000}}' | "$TEST_DIR/statusline.sh" 2>/dev/null)
line_count=$(echo "$output" | wc -l | tr -d ' ')
assert_eq "statusline 輸出兩行" "2" "$line_count"
assert_true "輸出含模型名" "echo '$output' | grep -qF '[Opus]'"

# 清理
rm -rf "$TEST_DIR"

echo ""
echo "==========================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================="
exit $FAIL
