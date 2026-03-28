#!/bin/bash
# Claude Code Statusline Uninstaller
# 移除 statusline.sh 並從 settings.json 刪除 statusLine 設定
#
# 用法：
#   ./uninstall.sh          # 互動反安裝
#   ./uninstall.sh --yes    # 自動確認

set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
SETTINGS_FILE="$CLAUDE_HOME/settings.json"
STATUSLINE_FILE="$CLAUDE_HOME/statusline.sh"
CONFIG_SCRIPT="$CLAUDE_HOME/statusline-config.sh"
CONFIG_JSON="$CLAUDE_HOME/statusline-config.json"
COMMAND_FILE="$CLAUDE_HOME/commands/statusline.md"
AUTO_YES=false

[[ "${1:-}" == "--yes" ]] && AUTO_YES=true

confirm() {
    if $AUTO_YES; then return 0; fi
    read -rp "$1 [y/N] " answer
    [[ "$answer" =~ ^[Yy] ]]
}

info()  { echo -e "\033[32m✓\033[0m $1"; }
warn()  { echo -e "\033[33m!\033[0m $1"; }

echo "Claude Code Statusline Uninstaller"
echo "==================================="
echo ""

if ! confirm "確定要移除 statusline 嗎？"; then
    echo "取消。"
    exit 0
fi

# ── 刪除 statusline.sh ──
if [ -f "$STATUSLINE_FILE" ]; then
    rm "$STATUSLINE_FILE"
    info "已刪除 $STATUSLINE_FILE"
else
    warn "statusline.sh 不存在，跳過"
fi

# ── 刪除 statusline-config.sh ──
if [ -f "$CONFIG_SCRIPT" ]; then
    rm "$CONFIG_SCRIPT"
    info "已刪除 $CONFIG_SCRIPT"
fi

# ── 刪除 statusline-config.json ──
if [ -f "$CONFIG_JSON" ]; then
    rm "$CONFIG_JSON"
    info "已刪除 $CONFIG_JSON"
fi

# ── 刪除 /statusline 指令 ──
if [ -f "$COMMAND_FILE" ]; then
    rm "$COMMAND_FILE"
    info "已刪除 $COMMAND_FILE"
fi

# ── 從 settings.json 移除 statusLine ──
if [ -f "$SETTINGS_FILE" ] && jq . "$SETTINGS_FILE" >/dev/null 2>&1; then
    if jq -e '.statusLine' "$SETTINGS_FILE" >/dev/null 2>&1; then
        tmpfile=$(mktemp "${SETTINGS_FILE}.XXXXXX")
        if jq 'del(.statusLine)' "$SETTINGS_FILE" > "$tmpfile"; then
            mv "$tmpfile" "$SETTINGS_FILE"
            info "已從 settings.json 移除 statusLine 設定"
        else
            rm -f "$tmpfile"
            warn "settings.json 更新失敗"
        fi
    else
        warn "settings.json 中沒有 statusLine 設定"
    fi
else
    warn "settings.json 不存在或格式錯誤，跳過"
fi

echo ""
info "反安裝完成。重啟 Claude Code 後 statusline 會消失。"
