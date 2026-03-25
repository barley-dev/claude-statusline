#!/bin/bash
# TDD 測試腳本 for scripts/statusline.sh (v2)
# 測試 Ctx 前綴與行數開關功能

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/statusline.sh"
CONFIG_SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/config.sh"
PASS=0
FAIL=0

# 移除 ANSI 顏色碼的 helper
strip_ansi() {
    sed $'s/\033\[[0-9;]*m//g'
}

assert_contains() {
    local test_name="$1"
    local input="$2"
    local expected="$3"

    local output
    output=$(echo "$input" | "$SCRIPT" 2>/dev/null | strip_ansi)

    if echo "$output" | grep -qF "$expected"; then
        echo "  ✓ $test_name"
        ((PASS++))
    else
        echo "  ✗ $test_name"
        echo "    expected to contain: $expected"
        echo "    got: $output"
        ((FAIL++))
    fi
}

assert_contains_in() {
    local test_name="$1"
    local output="$2"
    local expected="$3"

    if echo "$output" | grep -qF "$expected"; then
        echo "  ✓ $test_name"
        ((PASS++))
    else
        echo "  ✗ $test_name"
        echo "    expected to contain: $expected"
        echo "    got: $output"
        ((FAIL++))
    fi
}

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    if [ "$expected" = "$actual" ]; then
        echo "  ✓ $test_name"
        ((PASS++))
    else
        echo "  ✗ $test_name"
        echo "    expected: '$expected'"
        echo "    got:      '$actual'"
        ((FAIL++))
    fi
}

assert_line_count() {
    local test_name="$1"
    local input="$2"
    local expected_lines="$3"

    local count
    count=$(echo "$input" | "$SCRIPT" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$count" -eq "$expected_lines" ]; then
        echo "  ✓ $test_name"
        ((PASS++))
    else
        echo "  ✗ $test_name"
        echo "    expected $expected_lines lines, got $count"
        ((FAIL++))
    fi
}

assert_no_error() {
    local test_name="$1"
    local input="$2"

    local stderr_output
    stderr_output=$(echo "$input" | "$SCRIPT" 2>&1 1>/dev/null)

    if [ -z "$stderr_output" ]; then
        echo "  ✓ $test_name"
        ((PASS++))
    else
        echo "  ✗ $test_name"
        echo "    stderr: $stderr_output"
        ((FAIL++))
    fi
}

assert_bar_length() {
    local test_name="$1"
    local input="$2"
    local expected_filled="$3"
    local expected_empty="$4"

    local output
    output=$(echo "$input" | "$SCRIPT" 2>/dev/null | strip_ansi)

    local filled_count
    filled_count=$(echo "$output" | grep -o '█' | wc -l | tr -d ' ')
    local empty_count
    empty_count=$(echo "$output" | grep -o '░' | wc -l | tr -d ' ')
    local total=$((filled_count + empty_count))

    if [ "$filled_count" -eq "$expected_filled" ] && [ "$empty_count" -eq "$expected_empty" ] && [ "$total" -eq 10 ]; then
        echo "  ✓ $test_name"
        ((PASS++))
    else
        echo "  ✗ $test_name"
        echo "    expected ${expected_filled}█ + ${expected_empty}░ = 10 total"
        echo "    got ${filled_count}█ + ${empty_count}░ = ${total} total"
        ((FAIL++))
    fi
}

assert_has_color() {
    local test_name="$1"
    local input="$2"
    local color_code="$3"

    local raw_output
    raw_output=$(echo "$input" | "$SCRIPT" 2>/dev/null)

    if echo "$raw_output" | grep -q $'\033\['"$color_code"'m'; then
        echo "  ✓ $test_name"
        ((PASS++))
    else
        echo "  ✗ $test_name"
        echo "    expected ANSI color code $color_code"
        ((FAIL++))
    fi
}

echo "=== Statusline v2 TDD Tests ==="
echo ""

# ── 基本欄位解析（繼承自 v1）──
echo "--- 基本欄位解析 ---"

BASIC='{"model":{"display_name":"Opus"},"cwd":"/Users/yi-ru/projects/my-app","context_window":{"used_percentage":25},"cost":{"total_cost_usd":0.42,"total_duration_ms":180000}}'

assert_contains "模型名稱" "$BASIC" "[Opus]"
assert_contains "資料夾名稱（只有最後一層）" "$BASIC" "my-app"
assert_contains "費用" "$BASIC" '$0.42'
assert_contains "時間（3分鐘）" "$BASIC" "3m0s"
assert_line_count "輸出兩行" "$BASIC" 2

# ── 空值防呆 ──
echo ""
echo "--- 空值防呆 ---"

assert_no_error "空 JSON 不報錯" '{}'
assert_contains "空 JSON 模型顯示預設值" '{}' "[?]"
assert_line_count "空 JSON 仍輸出兩行" '{}' 2

# ── 進度條長度 ──
echo ""
echo "--- 進度條長度 ---"

assert_bar_length "0% = 0█ + 10░" \
    '{"context_window":{"used_percentage":0},"cost":{}}' 0 10

assert_bar_length "25% = 2█ + 8░" \
    '{"context_window":{"used_percentage":25},"cost":{}}' 2 8

assert_bar_length "50% = 5█ + 5░" \
    '{"context_window":{"used_percentage":50},"cost":{}}' 5 5

assert_bar_length "100% = 10█ + 0░" \
    '{"context_window":{"used_percentage":100},"cost":{}}' 10 0

# ── 顏色門檻 ──
echo ""
echo "--- 顏色門檻 ---"

assert_has_color "< 70% 用綠色 (32)" \
    '{"context_window":{"used_percentage":50},"cost":{}}' "32"

assert_has_color "75% 用黃色 (33)" \
    '{"context_window":{"used_percentage":75},"cost":{}}' "33"

assert_has_color "95% 用紅色 (31)" \
    '{"context_window":{"used_percentage":95},"cost":{}}' "31"

# ── Ctx 前綴 ──
echo ""
echo "--- Ctx 前綴 ---"
BASIC='{"model":{"display_name":"Opus"},"cwd":"/tmp","context_window":{"used_percentage":45},"cost":{"total_cost_usd":1.50,"total_duration_ms":600000}}'
assert_contains "Line 2 顯示 Ctx 前綴" "$BASIC" "Ctx 45%"

# ── 行數開關 ──
echo ""
echo "--- 行數開關 ---"
TEST_DIR="/tmp/test-statusline-v2-$$"
mkdir -p "$TEST_DIR"

BASIC='{"model":{"display_name":"Opus"},"cwd":"/tmp","context_window":{"used_percentage":45},"cost":{"total_cost_usd":1.50,"total_duration_ms":600000}}'

# 關閉 Line 1
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set model_git false
output=$(echo "$BASIC" | CLAUDE_HOME="$TEST_DIR" "$SCRIPT" 2>/dev/null | strip_ansi)
line_count=$(echo "$output" | wc -l | tr -d ' ')
assert_eq "關閉 Line 1 後只剩 1 行" "1" "$line_count"
assert_contains_in "關閉 Line 1 後第一行是進度條" "$output" "Ctx 45%"

# 關閉 Line 3 (with rate limits data present)
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" reset
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set rate_limits false
RATE_INPUT='{"model":{"display_name":"Opus"},"cwd":"/tmp","context_window":{"used_percentage":25},"cost":{"total_cost_usd":0.5,"total_duration_ms":60000},"rate_limits":{"five_hour":{"used_percentage":23,"resets_at":9999999999},"seven_day":{"used_percentage":41,"resets_at":9999999999}}}'
output=$(echo "$RATE_INPUT" | CLAUDE_HOME="$TEST_DIR" "$SCRIPT" 2>/dev/null)
line_count=$(echo "$output" | wc -l | tr -d ' ')
assert_eq "關閉 Line 3 + 有 rate_limits 仍只有 2 行" "2" "$line_count"

# 全關
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set model_git false
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set progress_cost false
output=$(echo "$BASIC" | CLAUDE_HOME="$TEST_DIR" "$SCRIPT" 2>/dev/null)
assert_eq "全關時無輸出" "" "$output"

# 無 config 時 fallback 全顯示
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
output=$(echo "$BASIC" | CLAUDE_HOME="$TEST_DIR" "$SCRIPT" 2>/dev/null)
line_count=$(echo "$output" | wc -l | tr -d ' ')
assert_eq "無 config 時仍顯示 2 行" "2" "$line_count"

rm -rf "$TEST_DIR"

# ── 總結 ──
echo ""
echo "==========================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================="

exit $FAIL
