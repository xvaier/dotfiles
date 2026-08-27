
#!/bin/bash

# Status line - model, git branch, cwd, context usage, cost
CURRENCY='$'              # Currency symbol (e.g., '$', '€', '£', '¥')
CACHE_DIR="${HOME}/.cache/cc-status-line"
CACHE_FILE="${CACHE_DIR}/exchange-rate.json"
CACHE_MAX_AGE=86400       # 24 hours in seconds

data=$(cat)

IFS=$'\t' read -r model cwd max_ctx used_pct cost_usd <<< "$(echo "$data" | jq -r '[
    (.model.display_name // .model.id // "unknown"),
    (.workspace.current_dir // ""),
    (.context_window.context_window_size // 200000),
    (.context_window.used_percentage // ""),
    (.cost.total_cost_usd // 0)
] | @tsv')"

model="${model%% *}"

# Git: branch + dirty status (fast combined check)
branch=""
dirty=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    [ -z "$branch" ] && branch=$(git rev-parse --short HEAD 2>/dev/null)

    if [ -n "$(git --no-optional-locks status --porcelain 2>/dev/null | head -1)" ]; then
        dirty=" ●"
    fi
fi

# Terminal palette colors - follows whatever theme the terminal is set to
TEAL='\033[36m'           # folder
MAUVE='\033[35m'          # git branch
LAVENDER='\033[94m'       # model
PEACH='\033[33m'          # dirty indicator
GREEN='\033[32m'          # cost
RED='\033[31m'            # high context
OVERLAY='\033[90m'        # dimmed text
SUBTEXT='\033[37m'        # secondary text
RESET='\033[0m'

pct=$(printf "%.0f" "$used_pct" 2>/dev/null || echo "$used_pct")
[ "$pct" -eq "$pct" ] 2>/dev/null || pct=0
[ "$pct" -gt 100 ] && pct=100

if [ "$pct" -eq 0 ]; then
    ctx_color="$OVERLAY"
elif [ "$pct" -lt 40 ]; then
    ctx_color="$GREEN"
elif [ "$pct" -le 60 ]; then
    ctx_color="$PEACH"
else
    ctx_color="$RED"
fi

context_info="${ctx_color} ${pct}%${RESET}"

if [ -n "$cost_usd" ] && [ "$cost_usd" != "0" ] && [ "$cost_usd" != "null" ]; then
    cost_fmt=$(printf "%.2f" "$cost_usd" 2>/dev/null || echo "0.00")
    cost_display="${SUBTEXT}${CURRENCY}${cost_fmt}${RESET}"
else
    cost_display="${OVERLAY}${CURRENCY}0.00${RESET}"
fi

output="${LAVENDER}${model}${RESET}"
output="${output} ${context_info}"
output="${output} ${cost_display}"
if [ -n "$branch" ]; then
    output="${output}${MAUVE}  ${branch}${RESET}"
    [ -n "$dirty" ] && output="${output}${PEACH}${dirty}${RESET}"
fi

printf '%b\n' "$output"

