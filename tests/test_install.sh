#!/bin/bash
# TDD 測試腳本 for install.sh v1.2
# 驗證安裝完整性：v1.1 腳本 + config + 指令

PASS=0; FAIL=0
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="/tmp/test-install-$$"

strip_ansi() {
    sed $'s/\033\[[0-9;]*m//g'
}

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

setup() { rm -rf "$TEST_HOME"; mkdir -p "$TEST_HOME"; }
teardown() { rm -rf "$TEST_HOME"; }

echo "=== Install v1.2 Tests ==="

echo "--- 安裝完整性 ---"
setup
CLAUDE_HOME="$TEST_HOME" "$PROJECT_DIR/install.sh" --yes >/dev/null 2>&1

assert_true "statusline.sh 已安裝" \
    "test -x '$TEST_HOME/statusline.sh'"
assert_true "statusline-config.sh 已安裝" \
    "test -x '$TEST_HOME/statusline-config.sh'"
assert_true "commands 目錄已建立" \
    "test -d '$TEST_HOME/commands'"
assert_true "statusline 指令已安裝" \
    "test -f '$TEST_HOME/commands/statusline.md'"

echo "--- statusline.sh 是 v1.1（含 Ctx 前綴）---"
output=$(echo '{"model":{"display_name":"Opus"},"cwd":"/tmp","context_window":{"used_percentage":45},"cost":{"total_cost_usd":1.50,"total_duration_ms":600000}}' | CLAUDE_HOME="$TEST_HOME" "$TEST_HOME/statusline.sh" 2>/dev/null | strip_ansi)
if echo "$output" | grep -q 'Ctx 45%'; then
    echo "  ✓ 安裝的 statusline 有 Ctx 前綴"; ((PASS++))
else
    echo "  ✗ 安裝的 statusline 有 Ctx 前綴"; echo "    got: $output"; ((FAIL++))
fi

echo "--- config 切換可用 ---"
CLAUDE_HOME="$TEST_HOME" "$TEST_HOME/statusline-config.sh" set model_git false
output=$(echo '{"model":{"display_name":"Opus"},"cwd":"/tmp","context_window":{"used_percentage":45},"cost":{"total_cost_usd":1.50,"total_duration_ms":600000}}' | CLAUDE_HOME="$TEST_HOME" "$TEST_HOME/statusline.sh" 2>/dev/null | strip_ansi)
line_count=$(echo "$output" | wc -l | tr -d ' ')
assert_eq "關閉 model_git 後只剩 1 行" "1" "$line_count"

echo "--- settings.json 合併 ---"
assert_true "settings.json 存在" "test -f '$TEST_HOME/settings.json'"
assert_eq "statusLine command 指向 ~/.claude/statusline.sh" \
    "~/.claude/statusline.sh" \
    "$(jq -r '.statusLine.command' "$TEST_HOME/settings.json")"

echo "--- 指令檔路徑正確 ---"
assert_true "指令檔引用 statusline-config.sh" \
    "grep -q 'statusline-config.sh' '$TEST_HOME/commands/statusline.md'"

echo "--- 反安裝 ---"
CLAUDE_HOME="$TEST_HOME" "$PROJECT_DIR/uninstall.sh" --yes >/dev/null 2>&1
assert_true "statusline.sh 已移除" \
    "! test -f '$TEST_HOME/statusline.sh'"
assert_true "statusline-config.sh 已移除" \
    "! test -f '$TEST_HOME/statusline-config.sh'"
assert_true "statusline 指令已移除" \
    "! test -f '$TEST_HOME/commands/statusline.md'"
assert_true "statusline-config.json 已移除" \
    "! test -f '$TEST_HOME/statusline-config.json'"

teardown
echo ""
echo "==========================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================="
exit $FAIL
