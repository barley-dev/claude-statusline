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

VERSION="1.0.0"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
SETTINGS_FILE="$CLAUDE_HOME/settings.json"
STATUSLINE_FILE="$CLAUDE_HOME/statusline.sh"
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

# ── 寫入 statusline.sh ──
cat > "$STATUSLINE_FILE" << 'STATUSLINE_SCRIPT'
#!/bin/bash
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "?"')
cwd=$(echo "$input" | jq -r '.cwd // ""')
percentage=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0' | cut -d. -f1)

directory="${cwd##*/}"

# 百分比安全範圍
[ "$percentage" -lt 0 ] 2>/dev/null && percentage=0
[ "$percentage" -gt 100 ] 2>/dev/null && percentage=100

# ANSI 顏色
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
DIM='\033[2m'
RESET='\033[0m'

# ── Git 資訊 ──
git_info=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    staged=$(git -C "$cwd" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    modified=$(git -C "$cwd" diff --numstat 2>/dev/null | wc -l | tr -d ' ')

    git_info=" ($branch"
    [ "$staged" -gt 0 ] 2>/dev/null && git_info+=" ${GREEN}+${staged}${RESET}"
    [ "$modified" -gt 0 ] 2>/dev/null && git_info+=" ${YELLOW}~${modified}${RESET}"
    git_info+=")"
fi

# ── 進度條顏色 ──
if [ "$percentage" -ge 90 ] 2>/dev/null; then
    bar_color="$RED"
elif [ "$percentage" -ge 70 ] 2>/dev/null; then
    bar_color="$YELLOW"
else
    bar_color="$GREEN"
fi

# ── 進度條（10 格）──
filled=$((percentage / 10))
empty=$((10 - filled))
bar="${bar_color}"
[ "$filled" -gt 0 ] && bar+="$(printf '█%.0s' $(seq 1 $filled))"
[ "$empty" -gt 0 ] && bar+="$(printf '░%.0s' $(seq 1 $empty))"
bar+="${RESET}"

# ── 時間轉換 ──
total_sec=$((duration_ms / 1000))
minutes=$((total_sec / 60))
seconds=$((total_sec % 60))
time_str="${minutes}m${seconds}s"

# ── 費用格式化 ──
cost_str=$(printf '$%.2f' "$cost")

# ── 第一行：模型 + 資料夾 + Git ──
echo -e "[$model] $directory$git_info"

# ── 第二行：進度條 + 費用 + 時間 ──
echo -e "$bar ${bar_color}${percentage}%${RESET} │ ${DIM}${cost_str} · ${time_str}${RESET}"

# ── 第三行：Rate Limits（僅 Pro/Max 用戶）──
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)

if [ -n "$five_hour_pct" ] && [ -n "$seven_day_pct" ]; then
    five_hour_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // 0' | cut -d. -f1)
    seven_day_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // 0' | cut -d. -f1)
    now=$(date +%s)

    # 5h 倒數
    five_diff=$(( five_hour_reset - now ))
    if [ "$five_diff" -le 0 ] 2>/dev/null; then
        five_str="now"
    else
        five_h=$(( five_diff / 3600 ))
        five_m=$(( (five_diff % 3600) / 60 ))
        five_str="${five_h}h ${five_m}m"
    fi

    # 7d 倒數
    seven_diff=$(( seven_day_reset - now ))
    if [ "$seven_diff" -le 0 ] 2>/dev/null; then
        seven_str="now"
    else
        seven_d=$(( seven_diff / 86400 ))
        seven_h=$(( (seven_diff % 86400) / 3600 ))
        seven_str="${seven_d}d ${seven_h}h"
    fi

    # 5h 顏色
    if [ "$five_hour_pct" -ge 90 ] 2>/dev/null; then
        five_color="$RED"
    elif [ "$five_hour_pct" -ge 70 ] 2>/dev/null; then
        five_color="$YELLOW"
    else
        five_color="$GREEN"
    fi

    # 7d 顏色
    if [ "$seven_day_pct" -ge 90 ] 2>/dev/null; then
        seven_color="$RED"
    elif [ "$seven_day_pct" -ge 70 ] 2>/dev/null; then
        seven_color="$YELLOW"
    else
        seven_color="$GREEN"
    fi

    echo -e "${five_color}5h: ${five_hour_pct}%${RESET} ${DIM}(reset ${five_str})${RESET} │ ${seven_color}7d: ${seven_day_pct}%${RESET} ${DIM}(reset ${seven_str})${RESET}"
fi
STATUSLINE_SCRIPT

chmod +x "$STATUSLINE_FILE"
info "statusline.sh 已安裝到 $STATUSLINE_FILE"

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
