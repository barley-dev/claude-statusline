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
    if ! jq . "$CONFIG_FILE" >/dev/null 2>&1; then
        echo "$DEFAULT_CONFIG"
        return
    fi
    cat "$CONFIG_FILE"
}

cmd_set() {
    local key="$1" value="$2"
    case "$key" in
        model_git|progress_cost|rate_limits) ;;
        *) echo "Invalid key: $key" >&2; exit 1 ;;
    esac
    case "$value" in
        true|false) ;;
        *) echo "Invalid value: $value (use true/false)" >&2; exit 1 ;;
    esac
    local current
    current=$(cmd_read)
    mkdir -p "$(dirname "$CONFIG_FILE")"
    local tmpfile
    tmpfile=$(mktemp "${CONFIG_FILE}.XXXXXX")
    if echo "$current" | jq ".lines.$key = $value" > "$tmpfile"; then
        mv "$tmpfile" "$CONFIG_FILE"
    else
        rm -f "$tmpfile"
        echo "Failed to write config" >&2; exit 1
    fi
}

cmd_get() {
    local key="$1"
    case "$key" in
        model_git|progress_cost|rate_limits) ;;
        *) echo "Invalid key: $key" >&2; exit 1 ;;
    esac
    cmd_read | jq -r ".lines.$key"
}

cmd_reset() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    local tmpfile
    tmpfile=$(mktemp "${CONFIG_FILE}.XXXXXX")
    if echo "$DEFAULT_CONFIG" | jq . > "$tmpfile"; then
        mv "$tmpfile" "$CONFIG_FILE"
    else
        rm -f "$tmpfile"
        echo "Failed to write config" >&2; exit 1
    fi
}

case "${1:-}" in
    read) cmd_read ;;
    set) cmd_set "${2:-}" "${3:-}" ;;
    get) cmd_get "${2:-}" ;;
    reset) cmd_reset ;;
    *) echo "Usage: config.sh read|set|get|reset" >&2; exit 1 ;;
esac
