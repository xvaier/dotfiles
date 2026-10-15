#!/usr/bin/env bash
# Hook for `wt status --watch`: shows claude agent counts in the tmux status
# bar and alerts the clients of a session that isn't attached when one of its
# agents needs input or finishes. wt's JSON arrives on stdin; agents are
# placed in panes by their tty. Exits non-zero once the tmux server is gone,
# which stops the watcher.
set -euo pipefail

json=$(cat)
panes=$(tmux list-panes -a -F '#{pane_tty}	#{session_id}	#{window_id}	#{session_name}	#{session_attached}') || exit 1

# one line per tmux change: G - <fmt>, S <session> <fmt>, W <window> <fmt>, N <session> <message>
changes=$(jq -r --arg panes "$panes" '
  def fmt:
    [ ["yellow", "waiting", ""], ["green", "running", ""], ["brightblack", "stopped", ""] ] as $kinds
    | . as $agents
    | [ $kinds[] | . as [$color, $state, $glyph]
        | ($agents | map(select(.state == $state)) | length) as $n
        | if $n > 0 then "#[fg=\($color)] \($glyph) \($n)#[fg=default] " else "" end ]
    | join("");

  ($panes | split("\n") | map(select(length > 0) | split("\t")
    | { tty: (.[0] | sub("^/dev/"; "")), session: .[1], window: .[2], name: .[3], attached: (.[4] != "0") })) as $panes
  | (reduce $panes[] as $p ({}; .[$p.tty] = $p)) as $by_tty
  | [ .agents[] | . + { pane: $by_tty[.tty] } ] as $agents
  | ["G", "-", ($agents | fmt)],
    ($panes | map(.session) | unique[] as $s | ["S", $s, ($agents | map(select(.pane.session == $s)) | fmt)]),
    ($panes | map(.window) | unique[] as $w | ["W", $w, ($agents | map(select(.pane.window == $w)) | fmt)]),
    ( $agents[]
      | select(.pane != null and .pane.attached == false and .previous != null and .previous != .state)
      | (if .name != "" and .name != .pane.name then "\(.pane.name): \(.name)" else .pane.name end) as $label
      | (if .state == "waiting" then "  \($label) needs input" elif .state == "stopped" then "  \($label) finished" else empty end) as $message
      | ["N", .pane.session, ($message | gsub("[\u0000-\u001f]"; ""))] )
  | join("\t")
' <<<"$json")

while IFS=$'\t' read -r kind target value; do
  case $kind in
    G) tmux set-option -g @claude_status_all "$value" ;;
    S) tmux set-option -t "$target" @claude_status "$value" ;;
    W) tmux set-option -w -t "$target" @claude_status_window "$value" ;;
    N)
      for tty in $(tmux list-clients -F '#{client_tty}'); do
        printf '\a' >"$tty" 2>/dev/null || continue
        tmux display-message -d 30000 -c "$tty" "$value"
      done
      ;;
  esac
done <<<"$changes"

# redraw now instead of waiting out the status interval
tmux refresh-client -S 2>/dev/null || true
