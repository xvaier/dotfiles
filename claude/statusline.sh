#!/usr/bin/env bash
# Single-line Claude Code statusline, styled to match the asciiship prompt and tmux bar.
# Reads the status payload on stdin; see https://code.claude.com/docs/en/statusline
#
# This runs on every assistant message, so the warm path is kept to a handful of
# forks: one jq, one cache read, one awk, one date. Anything slower is cached or
# pushed into the detached --refresh-mr job.
set -u

cache_dir="$HOME/.cache/claude-statusline"
cache_ttl=3
us=$'\037'  # unit separator: bash collapses runs of IFS *whitespace*, which
            # would eat empty fields and shift every field after them

self="$0"
case "$self" in /*) ;; *) self="$PWD/$self" ;; esac

# Detached GitLab lookup, re-entered via `$self --refresh-mr`. Claude Code
# already polls `gh` for GitHub and hands the result over in the payload, but
# its fetch path is GitHub-only. Nothing here runs on the render path.
if [ "${1:-}" = "--refresh-mr" ]; then
  mr_cache="$2"; mr_branch="$3"; mr_dir="$4"
  mkdir -p "$cache_dir" || exit 0
  row=""
  if command -v glab >/dev/null 2>&1; then
    row="$(cd "$mr_dir" 2>/dev/null && glab mr list --source-branch="$mr_branch" \
      --output json 2>/dev/null |
      jq -r 'map(select(.state == "opened")) | first |
        if . == null then "" else
          [(.iid | tostring), .web_url,
           (if .detailed_merge_status == "not_approved" then "pending" else "" end)]
          | join("\u001f")
        end' 2>/dev/null)"
  fi
  # Branch first: the render path compares it to decide whether to refresh, so a
  # branch with no open MR still counts as "checked" and won't respawn this job.
  printf '%s%s%s\n' "$mr_branch" "$us" "$row" > "$mr_cache"

  # Housekeeping lives here rather than on the render path.
  find "$cache_dir" -maxdepth 1 -type f -mtime +1 -delete 2>/dev/null
  find "$cache_dir/cost" -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null
  exit 0
fi

# Named ANSI only: `theme: dark-ansi` and asciiship both track the terminal palette.
r=$'\033[0m'; dim=$'\033[2m'; b=$'\033[1m'
red=$'\033[31m'; green=$'\033[32m'; yellow=$'\033[33m'
magenta=$'\033[35m'; cyan=$'\033[36m'

sep="${dim} │ ${r}"
segments=()
add() { segments[${#segments[@]}]="$1"; }

emit() {
  local out="" s
  for s in ${segments[@]+"${segments[@]}"}; do
    [ -n "$out" ] && out="$out$sep"
    out="$out$s"
  done
  printf '%s\n' "$out"
  exit 0
}

IFS= read -r -d '' payload   # builtin, so no fork just to slurp stdin
if [ -z "$payload" ] || ! command -v jq >/dev/null 2>&1; then
  emit
fi

IFS="$us" read -r session cur_dir proj_dir model vim_mode \
  effort fast cost ctx_pct cache_pct added removed \
  repo_host pr_num pr_url pr_review pr_kind <<<"$(
  jq -r '
    def n(x): x // "";
    [ n(.session_id), n(.workspace.current_dir), n(.workspace.project_dir),
      n(.model.display_name), n(.vim.mode), n(.effort.level),
      (if .fast_mode then "1" else "" end),
      (.cost.total_cost_usd // 0),
      (if .context_window.used_percentage == null then ""
       else (.context_window.used_percentage | round) end),
      ( .context_window.current_usage as $u
        | if $u == null then ""
          else ($u.input_tokens + $u.cache_creation_input_tokens + $u.cache_read_input_tokens) as $t
               | if $t > 0 then (($u.cache_read_input_tokens * 100 / $t) | round) else "" end
          end ),
      (.cost.total_lines_added // 0), (.cost.total_lines_removed // 0),
      n(.workspace.repo.host), n(.pr.number), n(.pr.url), n(.pr.review_state), n(.pr.kind)
    ] | map(tostring) | join("\u001f")' <<<"$payload" 2>/dev/null
)"

# A malformed payload leaves every field empty; keep the numeric ones printable.
case "$cost" in ''|*[!0-9.]*) cost=0 ;; esac
case "$added" in ''|*[!0-9]*) added=0 ;; esac
case "$removed" in ''|*[!0-9]*) removed=0 ;; esac
case "$ctx_pct" in *[!0-9]*) ctx_pct="" ;; esac

if [ -n "${EPOCHSECONDS:-}" ]; then
  now="$EPOCHSECONDS"
  printf -v today '%(%F)T' "$now"
else
  IFS=' ' read -r today now <<<"$(date '+%F %s')"
fi

# --- git state -----------------------------------------------------------
# Permission mode is deliberately absent: Claude Code renders its own indicator
# below the statusline and that line can't be turned off, so showing it here just
# duplicates it.
cache="$cache_dir/state-${session:-none}"
cached_at=0; branch=""; dirty=0; ahead=0; behind=0
if [ -r "$cache" ]; then
  IFS="$us" read -r cached_at branch dirty ahead behind < "$cache"
fi

if [ "$((now - ${cached_at:-0}))" -ge "$cache_ttl" ]; then
  IFS="$us" read -r branch dirty ahead behind <<<"$(
    cd "${cur_dir:-$PWD}" 2>/dev/null &&
    git status --porcelain=v2 --branch 2>/dev/null | awk -v us="$us" '
      $1 == "#" && $2 == "branch.head" { head = $3 }
      $1 == "#" && $2 == "branch.ab" { ahead = $3 + 0; behind = -($4 + 0) }
      $1 != "#" { dirty++ }
      END { if (head != "") printf "%s%s%d%s%d%s%d", head, us, dirty, us, ahead, us, behind }')"

  [ -d "$cache_dir" ] || mkdir -p "$cache_dir" 2>/dev/null
  printf '%s%s%s%s%s%s%s%s%s\n' "$now" "$us" "$branch" "$us" "${dirty:-0}" "$us" \
    "${ahead:-0}" "$us" "${behind:-0}" > "$cache" 2>/dev/null
fi

# --- vim mode ------------------------------------------------------------
[ -n "$vim_mode" ] && add "${b}[${vim_mode:0:1}]${r}"

# --- model and effort ----------------------------------------------------
case "$model" in
  Opus)   model="opus" ;;
  Sonnet) model="sonnet" ;;
  Haiku)  model="haiku" ;;
  Fable)  model="fable" ;;
  "")     model="claude" ;;
  *)      model="$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]')" ;;
esac

seg="${b}${model}${r}"
case "$effort" in
  low)  seg="$seg ${dim}lo${r}" ;;
  high) seg="$seg ${dim}hi${r}" ;;
  max)  seg="$seg ${dim}max${r}" ;;
esac
[ -n "$fast" ] && seg="$seg ${yellow}»${r}"
add "$seg"

# --- cost: this session over today's total across sessions ---------------
# Claude reports a dollar figure only for the live session, so each render
# stamps its own total into a per-day ledger and we sum that. Sessions predating
# this statusline are therefore missing from the day total.
printf -v session_cost '%.2f' "$cost"
day_dir="$cache_dir/cost/$today"
day_total="$session_cost"
if [ -n "$session" ]; then
  [ -d "$day_dir" ] || mkdir -p "$day_dir" 2>/dev/null
  if printf '%s\n' "$cost" > "$day_dir/$session" 2>/dev/null; then
    day_total="$(awk '{ t += $1 } END { printf "%.2f", t }' "$day_dir"/* 2>/dev/null)"
  fi
fi
# %.2f on both sides means stripping the dot gives cents, so this compares
# without awk.
day_cents="${day_total/./}"
day_colour="$dim"
[ "${day_cents:-0}" -ge 2000 ] && day_colour="$yellow"
[ "${day_cents:-0}" -ge 5000 ] && day_colour="$red"
# The day total only earns its place once another session has spent something;
# otherwise it repeats the session cost and reads like a bug.
if [ "$day_total" = "$session_cost" ]; then
  add "\$${session_cost}"
else
  add "\$${session_cost}${dim}/${r}${day_colour}\$${day_total}${r}"
fi

# --- context window ------------------------------------------------------
if [ -n "$ctx_pct" ]; then
  ctx_colour="$green"
  [ "$ctx_pct" -ge 50 ] && ctx_colour="$yellow"
  [ "$ctx_pct" -ge 80 ] && ctx_colour="$red"
  seg="${dim}ctx${r} ${ctx_colour}${ctx_pct}%${r}"
  [ -n "$cache_pct" ] && seg="$seg ${dim}c${cache_pct}%${r}"
  add "$seg"
fi

# --- directory -----------------------------------------------------------
root="${proj_dir:-$cur_dir}"
dir="${root##*/}"
if [ -n "$proj_dir" ] && [ -n "$cur_dir" ] && [ "$cur_dir" != "$proj_dir" ]; then
  case "$cur_dir" in
    "$proj_dir"/*) dir="$dir/${cur_dir#"$proj_dir"/}" ;;
    *) dir="${cur_dir##*/}" ;;
  esac
fi
[ -n "$dir" ] && add "${b}${cyan}${dir}${r}"

# --- branch and working-tree state ---------------------------------------
if [ -n "$branch" ]; then
  [ "$branch" = "(detached)" ] && branch="HEAD"
  seg="${b}${magenta} ${branch}${r}"
  [ "${dirty:-0}" -gt 0 ] && seg="$seg ${yellow}*${dirty}${r}"
  [ "${ahead:-0}" -gt 0 ] && seg="$seg ${green}↑${ahead}${r}"
  [ "${behind:-0}" -gt 0 ] && seg="$seg ${red}↓${behind}${r}"
  add "$seg"
fi

# --- open PR / MR --------------------------------------------------------
forge="$pr_kind"
case "$repo_host" in
  *gitlab*) forge="gitlab" ;;
  *github*) [ -n "$forge" ] || forge="github" ;;
esac

if [ -z "$pr_num" ] && [ "$forge" = "gitlab" ] && [ -n "$branch" ]; then
  mr_cache="$cache_dir/mr-${root//\//_}"
  cached_branch=""
  [ -r "$mr_cache" ] && IFS="$us" read -r cached_branch pr_num pr_url pr_review < "$mr_cache"
  if [ "$cached_branch" != "$branch" ]; then
    pr_num=""; pr_url=""; pr_review=""
    ("$self" --refresh-mr "$mr_cache" "$branch" "${cur_dir:-$PWD}" >/dev/null 2>&1 &) &
  fi
fi

if [ -n "$pr_num" ]; then
  case "$forge" in gitlab) marker="!" ;; *) marker="#" ;; esac
  pr_colour=""
  case "$pr_review" in
    approved) pr_colour="$green" ;;
    changes_requested) pr_colour="$red" ;;
    pending) pr_colour="$yellow" ;;
  esac
  label="${pr_colour}${marker}${pr_num}${r}"
  # OSC 8 hyperlink; Ghostty renders it, other terminals ignore it
  [ -n "$pr_url" ] && label=$'\033]8;;'"$pr_url"$'\033\\'"$label"$'\033]8;;\033\\'
  add "$label"
fi

# --- diff volume ---------------------------------------------------------
if [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; then
  add "${dim}${green}+${added}${r} ${dim}${red}-${removed}${r}"
fi

emit
