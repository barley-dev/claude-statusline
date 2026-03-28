#!/bin/bash
# Claude Code Statusline Installer
# 一鍵安裝彩色 statusline：context 進度條、Git 狀態、費用、rate limits
#
# 用法：
#   ./install.sh          # 互動安裝
#   ./install.sh --yes    # 自動確認（跳過提示）
#
# 環境變數：
#   CLAUDE_HOME  覆蓋預設 ~/.claude 路徑（用於測試）

set -euo pipefail

VERSION="1.2.0"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
SETTINGS_FILE="$CLAUDE_HOME/settings.json"
STATUSLINE_FILE="$CLAUDE_HOME/statusline.sh"
CONFIG_FILE="$CLAUDE_HOME/statusline-config.sh"
COMMAND_DIR="$CLAUDE_HOME/commands"
COMMAND_FILE="$COMMAND_DIR/statusline.md"
AUTO_YES=false

[[ "${1:-}" == "--yes" ]] && AUTO_YES=true

confirm() {
    if $AUTO_YES; then return 0; fi
    read -rp "$1 [y/N] " answer
    [[ "$answer" =~ ^[Yy] ]]
}

info()  { echo -e "\033[32m✓\033[0m $1"; }
warn()  { echo -e "\033[33m!\033[0m $1"; }
error() { echo -e "\033[31m✗\033[0m $1"; }

# ── 檢查 jq ──
if ! command -v jq &>/dev/null; then
    error "需要 jq 但未安裝。請先安裝："
    echo "  macOS:  brew install jq"
    echo "  Ubuntu: sudo apt install jq"
    echo "  Arch:   sudo pacman -S jq"
    exit 1
fi

# ── 檢查 ~/.claude/ ──
if [ ! -d "$CLAUDE_HOME" ]; then
    error "$CLAUDE_HOME 目錄不存在。請先安裝 Claude Code。"
    exit 1
fi

echo "Claude Code Statusline Installer v$VERSION"
echo "==========================================="
echo ""

# ── 複製 statusline.sh（v1.1+，含 Ctx 前綴與 config 切換）──
cp "$PROJECT_DIR/scripts/statusline.sh" "$STATUSLINE_FILE"
chmod +x "$STATUSLINE_FILE"
info "statusline.sh 已安裝到 $STATUSLINE_FILE"

# ── 複製 config.sh ──
cp "$PROJECT_DIR/scripts/config.sh" "$CONFIG_FILE"
chmod +x "$CONFIG_FILE"
info "statusline-config.sh 已安裝到 $CONFIG_FILE"

# ── 複製 /statusline 指令 ──
mkdir -p "$COMMAND_DIR"
cp "$PROJECT_DIR/commands/statusline.md" "$COMMAND_FILE"
info "/statusline 指令已安裝到 $COMMAND_FILE"

# ── 合併 settings.json ──
STATUSLINE_CONFIG='{"statusLine":{"type":"command","command":"~/.claude/statusline.sh"}}'

if [ ! -f "$SETTINGS_FILE" ]; then
    # 不存在 → 建立新的
    echo "$STATUSLINE_CONFIG" | jq . > "$SETTINGS_FILE"
    info "settings.json 已建立"
else
    # 存在 → 驗證 JSON 格式
    if ! jq . "$SETTINGS_FILE" >/dev/null 2>&1; then
        error "settings.json 格式錯誤（非合法 JSON），無法合併。"
        error "請手動修復後重新執行安裝。"
        exit 1
    fi

    # 備份
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"

    # 檢查是否已有 statusLine
    existing=$(jq -r '.statusLine // empty' "$SETTINGS_FILE")
    if [ -n "$existing" ]; then
        if ! confirm "settings.json 已有 statusLine 設定，要覆蓋嗎？"; then
            warn "跳過 settings.json 更新"
            echo ""
            echo "安裝完成（settings.json 未修改）。"
            exit 0
        fi
    fi

    # 安全合併：用 jq 的 + 運算子，只加/覆蓋 statusLine，不動其他欄位
    tmpfile=$(mktemp "${SETTINGS_FILE}.XXXXXX")
    if jq ". + $STATUSLINE_CONFIG" "$SETTINGS_FILE" > "$tmpfile"; then
        mv "$tmpfile" "$SETTINGS_FILE"
        info "settings.json 已更新（備份: settings.json.bak）"
    else
        rm -f "$tmpfile"
        error "合併 settings.json 失敗"
        exit 1
    fi
fi

echo ""
echo "==========================================="
info "安裝完成！重啟 Claude Code 即可看到 statusline。"
echo ""
echo "預覽效果："
echo '{"model":{"display_name":"Opus"},"cwd":"/Users/you/project","context_window":{"used_percentage":45},"cost":{"total_cost_usd":1.50,"total_duration_ms":600000}}' | "$STATUSLINE_FILE"
echo ""
echo "反安裝：./uninstall.sh"
