
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

# Folder name from path
folder="${cwd##*/}"
[ -z "$folder" ] && folder="?"

# Git: branch + dirty status (fast combined check)
branch=""
dirty=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    [ -z "$branch" ] && branch=$(git rev-parse --short HEAD 2>/dev/null)

    if [ "${#branch}" -gt 30 ]; then
        branch="${branch:0:29}…"
    fi

    if [ -n "$(git status --porcelain 2>/dev/null | head -1)" ]; then
        dirty=" ●"
    fi
fi

# Terminal palette colors - follows whatever theme the terminal is set to
TEAL='\033[36m'           # folder
MAUVE='\033[35m'          # git branch
LAVENDER='\033[94m'       # model
PEACH='\033[33m'          # dirty indicator
GREEN='\033[32m'          # cost
OVERLAY='\033[90m'        # dimmed text
SUBTEXT='\033[37m'        # secondary text
RESET='\033[0m'

pct=$(printf "%.0f" "$used_pct" 2>/dev/null || echo "$used_pct")
[ "$pct" -gt 100 ] 2>/dev/null && pct=100

# Calculate tokens in k
used_k=$(( max_ctx * pct / 100 / 1000 ))
max_k=$(( max_ctx / 1000 ))

context_info="${SUBTEXT}${used_k}k/${max_k}k${RESET}"

if [ -n "$cost_usd" ] && [ "$cost_usd" != "0" ] && [ "$cost_usd" != "null" ]; then
    cost_fmt=$(printf "%.2f" "$cost_usd" 2>/dev/null || echo "0.00")
    cost_display="${GREEN}${CURRENCY}${cost_fmt}${RESET}"
else
    cost_display="${OVERLAY}${CURRENCY}0.00${RESET}"
fi

output="${LAVENDER}${model}${RESET}"
if [ -n "$branch" ]; then
    output="${output}  ${MAUVE}${branch}${RESET}"
    [ -n "$dirty" ] && output="${output}${PEACH}${dirty}${RESET}"
fi
output="${output}  ${TEAL}${folder}${RESET}"
output="${output}  ${context_info}"
output="${output}  ${cost_display}"

printf '%b\n' "$output"

