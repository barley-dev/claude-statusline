#!/bin/bash
input=$(cat)

# ── 讀取設定 ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_SCRIPT="$SCRIPT_DIR/config.sh"
if [ -x "$CONFIG_SCRIPT" ]; then
    show_model_git=$("$CONFIG_SCRIPT" get model_git)
    show_progress_cost=$("$CONFIG_SCRIPT" get progress_cost)
    show_rate_limits=$("$CONFIG_SCRIPT" get rate_limits)
else
    show_model_git=true
    show_progress_cost=true
    show_rate_limits=true
fi

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
if [ "$show_model_git" = "true" ]; then
    echo -e "[$model] $directory$git_info"
fi

# ── 第二行：進度條 + 費用 + 時間 ──
if [ "$show_progress_cost" = "true" ]; then
    echo -e "$bar ${bar_color}Ctx ${percentage}%${RESET} │ ${DIM}${cost_str} · ${time_str}${RESET}"
fi

# ── 第三行：Rate Limits（僅 Pro/Max 用戶）──
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)

if [ "$show_rate_limits" = "true" ] && [ -n "$five_hour_pct" ] && [ -n "$seven_day_pct" ]; then
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
