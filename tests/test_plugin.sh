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
    "$(jq -r '.name' "$PROJECT_DIR/.claude-plugin/plugin.json")"
assert_true "plugin.json 有 description" \
    "[ -n \"\$(jq -r '.description' '$PROJECT_DIR/.claude-plugin/plugin.json')\" ]"

echo "--- settings.json ---"
assert_true "settings.json 存在" \
    "test -f '$PROJECT_DIR/settings.json'"
assert_true "settings.json 是合法 JSON" \
    "jq . '$PROJECT_DIR/settings.json' >/dev/null 2>&1"
assert_eq "statusLine type" \
    "command" \
    "$(jq -r '.statusLine.type' "$PROJECT_DIR/settings.json")"
assert_true "statusLine command 包含 CLAUDE_PLUGIN_ROOT" \
    "jq -r '.statusLine.command' '$PROJECT_DIR/settings.json' | grep -q 'CLAUDE_PLUGIN_ROOT'"

echo "--- 目錄結構 ---"
assert_true "commands/ 目錄存在" \
    "test -d '$PROJECT_DIR/commands'"
assert_true "scripts/ 目錄存在" \
    "test -d '$PROJECT_DIR/scripts'"

echo ""
echo "==========================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================="
exit $FAIL
