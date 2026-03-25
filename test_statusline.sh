#!/bin/bash
# TDD 測試腳本 for statusline.sh
# 用模擬 JSON 驗證輸出是否正確

SCRIPT="$(cd "$(dirname "$0")" && pwd)/statusline.sh"
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

# 計算進度條中 █ 的數量
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

# 檢查是否包含 ANSI 顏色碼
assert_has_color() {
    local test_name="$1"
    local input="$2"
    local color_code="$3"  # e.g. "32" for green, "33" for yellow, "31" for red

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

echo "=== Statusline TDD Tests ==="
echo ""

# ── 基本欄位解析 ──
echo "--- 基本欄位解析 ---"

BASIC='{"model":{"display_name":"Opus"},"cwd":"/Users/yi-ru/projects/my-app","context_window":{"used_percentage":25},"cost":{"total_cost_usd":0.42,"total_duration_ms":180000}}'

assert_contains "模型名稱" "$BASIC" "[Opus]"
assert_contains "資料夾名稱（只有最後一層）" "$BASIC" "my-app"
assert_contains "context 百分比" "$BASIC" "25%"
assert_contains "費用" "$BASIC" '$0.42'
assert_contains "時間（3分鐘）" "$BASIC" "3m0s"
assert_line_count "輸出兩行" "$BASIC" 2

# ── 空值防呆 ──
echo ""
echo "--- 空值防呆 ---"

assert_no_error "空 JSON 不報錯" '{}'
assert_contains "空 JSON 模型顯示預設值" '{}' "[?]"
assert_contains "空 JSON context 為 0" '{}' "0%"
assert_line_count "空 JSON 仍輸出兩行" '{}' 2

# ── 進度條長度（含邊界）──
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

# ── 非 Git 目錄 ──
echo ""
echo "--- 非 Git 目錄 ---"

assert_no_error "非 Git 目錄不報錯" '{"cwd":"/tmp"}'
assert_contains "非 Git 目錄不顯示分支" '{"cwd":"/tmp","context_window":{"used_percentage":10},"cost":{}}' "[?] tmp"

# ── 小數百分比 ──
echo ""
echo "--- 小數處理 ---"

assert_contains "小數百分比只取整數" \
    '{"context_window":{"used_percentage":42.7},"cost":{}}' "42%"

# ── Rate Limits ──
echo ""
echo "--- Rate Limits ---"

# 動態計算 future timestamps
FIVE_HOUR_FUTURE=$(( $(date +%s) + 7200 + 900 ))  # +2h15m
SEVEN_DAY_FUTURE=$(( $(date +%s) + 259200 + 18000 ))  # +3d5h

RATE_INPUT="{\"model\":{\"display_name\":\"Opus\"},\"cwd\":\"/tmp\",\"context_window\":{\"used_percentage\":25},\"cost\":{\"total_cost_usd\":0.5,\"total_duration_ms\":60000},\"rate_limits\":{\"five_hour\":{\"used_percentage\":23.5,\"resets_at\":$FIVE_HOUR_FUTURE},\"seven_day\":{\"used_percentage\":41.2,\"resets_at\":$SEVEN_DAY_FUTURE}}}"

assert_line_count "有 rate_limits 時輸出三行" "$RATE_INPUT" 3
assert_contains "顯示 5h 用量" "$RATE_INPUT" "5h: 23%"
assert_contains "顯示 7d 用量" "$RATE_INPUT" "7d: 41%"
assert_contains "5h 重置倒數含 h 和 m" "$RATE_INPUT" "2h"
assert_contains "7d 重置倒數含 d" "$RATE_INPUT" "3d"

# 無 rate_limits 時仍為兩行
assert_line_count "無 rate_limits 時仍為兩行" \
    '{"model":{"display_name":"Opus"},"cwd":"/tmp","context_window":{"used_percentage":25},"cost":{"total_cost_usd":0.5,"total_duration_ms":60000}}' 2

# rate limits 顏色門檻
RATE_HIGH='{"context_window":{"used_percentage":10},"cost":{},"rate_limits":{"five_hour":{"used_percentage":95,"resets_at":9999999999},"seven_day":{"used_percentage":50,"resets_at":9999999999}}}'
assert_has_color "5h > 90% 用紅色" "$RATE_HIGH" "31"

RATE_MED='{"context_window":{"used_percentage":10},"cost":{},"rate_limits":{"five_hour":{"used_percentage":75,"resets_at":9999999999},"seven_day":{"used_percentage":50,"resets_at":9999999999}}}'
assert_has_color "5h 70-90% 用黃色" "$RATE_MED" "33"

# 空值防呆
assert_no_error "rate_limits 為 null 不報錯" '{"rate_limits":null,"context_window":{"used_percentage":10},"cost":{}}'
assert_line_count "rate_limits 為 null 仍為兩行" '{"rate_limits":null,"context_window":{"used_percentage":10},"cost":{}}' 2

# 過期重置時間顯示 "now"
PAST_RESET='{"context_window":{"used_percentage":10},"cost":{},"rate_limits":{"five_hour":{"used_percentage":50,"resets_at":1000000000},"seven_day":{"used_percentage":30,"resets_at":1000000000}}}'
assert_contains "過期 resets_at 顯示 now" "$PAST_RESET" "now"

# 只有部分 rate_limits 時不顯示第三行
PARTIAL_RATE='{"context_window":{"used_percentage":10},"cost":{},"rate_limits":{"five_hour":{"used_percentage":50,"resets_at":9999999999}}}'
assert_line_count "只有 five_hour 無 seven_day 時仍為兩行" "$PARTIAL_RATE" 2
assert_no_error "只有 five_hour 無 seven_day 不報錯" "$PARTIAL_RATE"

# ── 總結 ──
echo ""
echo "==========================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================="

exit $FAIL
