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

echo "=== Config TDD Tests ==="

echo "--- read 預設值 ---"
setup
output=$(CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" read)
assert_eq "無檔案時 model_git 預設 true" "true" "$(echo "$output" | jq -r '.lines.model_git')"
assert_eq "無檔案時 progress_cost 預設 true" "true" "$(echo "$output" | jq -r '.lines.progress_cost')"
assert_eq "無檔案時 rate_limits 預設 true" "true" "$(echo "$output" | jq -r '.lines.rate_limits')"

echo "--- malformed JSON fallback ---"
setup
echo '{invalid' > "$TEST_DIR/statusline-config.json"
output=$(CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" read)
assert_eq "malformed JSON fallback model_git" "true" "$(echo "$output" | jq -r '.lines.model_git')"

echo "--- set ---"
setup
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set model_git false
output=$(CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" read)
assert_eq "set model_git false" "false" "$(echo "$output" | jq -r '.lines.model_git')"
assert_eq "set 後其他值不變" "true" "$(echo "$output" | jq -r '.lines.progress_cost')"

echo "--- get ---"
setup
output=$(CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" get model_git)
assert_eq "get 預設值" "true" "$output"
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set rate_limits false
output=$(CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" get rate_limits)
assert_eq "get 設定後的值" "false" "$output"

echo "--- reset ---"
setup
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set model_git false
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set rate_limits false
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" reset
output=$(CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" read)
assert_eq "reset 後 model_git 回到 true" "true" "$(echo "$output" | jq -r '.lines.model_git')"
assert_eq "reset 後 rate_limits 回到 true" "true" "$(echo "$output" | jq -r '.lines.rate_limits')"

echo "--- 輸入驗證 ---"
setup
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set invalid_key true 2>/dev/null; result=$?
assert_eq "invalid key 回傳非零" "1" "$result"
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" set model_git maybe 2>/dev/null; result=$?
assert_eq "invalid value 回傳非零" "1" "$result"
CLAUDE_HOME="$TEST_DIR" "$CONFIG_SCRIPT" unknown_command 2>/dev/null; result=$?
assert_eq "unknown command 回傳非零" "1" "$result"

teardown
echo ""
echo "==========================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================="
exit $FAIL
