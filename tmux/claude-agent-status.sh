#!/usr/bin/env bash
# Compact Claude Code status for the tmux status bar and session picker.
set -u

interval=2

# Not TMPDIR: macOS gives the tmux server and Claude different per-session ones.
run_dir="$HOME/.cache/claude-agent-status"
lock_dir="$run_dir/daemon.lock"

self="$0"
case "$self" in /*) ;; *) self="$PWD/$self" ;; esac

claude_bin="$(command -v claude || echo "$HOME/.local/bin/claude")"
jq_bin="$(command -v jq || echo /usr/bin/jq)"

format_counts() {
  local out=""
  [ "$1" -gt 0 ] && out="$out#[fg=yellow]  $1#[fg=default] "
  [ "$2" -gt 0 ] && out="$out#[fg=green]  $2#[fg=default] "
  [ "$3" -gt 0 ] && out="$out#[fg=brightblack]  $3#[fg=default] "
  printf '%s' "$out"
}

notify_unattached() {
  local tmux_session="$1" state="$2" label="$3" attached tty message
  [ -n "$tmux_session" ] || return 0

  attached="$(tmux display-message -p -t "$tmux_session" '#{session_attached}' 2>/dev/null)"
  [ "${attached:-1}" != "0" ] && return 0

  if [ -n "$label" ] && [ "$label" != "$tmux_session" ]; then
    label="$tmux_session: $label"
  else
    label="$tmux_session"
  fi

  case "$state" in
    waiting) message="  $label needs input" ;;
    stopped) message="  $label finished" ;;
    *) return 0 ;;
  esac
  message="$(printf '%s' "$message" | tr -d '\000-\037')"

  tmux list-clients -F '#{client_tty}' 2>/dev/null | while read -r tty; do
    [ -w "$tty" ] || continue
    printf '\007' > "$tty"
    tmux display-message -d 30000 -c "$tty" "$message" 2>/dev/null
  done
}

snapshot() {
  local json
  json="$("$claude_bin" agents --json 2>/dev/null)" || return 1
  [ -n "$json" ] || return 1

  {
    tmux list-panes -a -F $'P\t#{pane_tty}\t#{session_name}' 2>/dev/null
    ps -eo pid=,tty= | awk '{ print "T\t" $1 "\t" $2 }'
    printf '%s' "$json" | "$jq_bin" -r '.[] | ["A", .pid, .status, .sessionId, (.name // "")] | @tsv'
  } | awk -F'\t' '
    function bucket(s) {
      if (s == "waiting") return "waiting"
      if (s == "idle") return "stopped"
      # busy and shell, plus whatever a background agent may report
      return "running"
    }
    $1 == "P" { sub(/^\/dev\//, "", $2); sess[$2] = $3; next }
    $1 == "T" { tty[$2] = $3; next }
    $1 == "A" { print bucket($3) "\t" sess[tty[$2]] "\t" $4 "\t" $5 }
  '
}

session_counts() {
  printf '%s\n' "$1" | awk -F'\t' -v s="$2" '
    $2 == s { c[$1]++ }
    END { printf "%d %d %d", c["waiting"], c["running"], c["stopped"] }'
}

published=""    # what was pushed to tmux last tick, so no-op redraws are skipped
prev_states=""  # "<session id>\t<bucket>" per agent, to spot transitions

tick() {
  local rows sessions global blob pending bucket sess sid name target value
  local waiting=0 running=0 stopped=0

  rows="$(snapshot)" || return 0

  while IFS=$'\t' read -r bucket sess sid name; do
    case "$bucket" in
      waiting) waiting=$((waiting + 1)) ;;
      running) running=$((running + 1)) ;;
      stopped) stopped=$((stopped + 1)) ;;
    esac
  done <<<"$rows"

  global="$(format_counts "$waiting" "$running" "$stopped")"

  blob=""
  sessions="$(tmux list-sessions -F '#{session_name}' 2>/dev/null)"
  while read -r sess; do
    [ -n "$sess" ] || continue
    blob="$blob$sess	$(format_counts $(session_counts "$rows" "$sess"))
"
  done <<<"$sessions"

  pending="$global
$blob"
  if [ "$pending" != "$published" ]; then
    published="$pending"
    tmux set-option -g @claude_status_all "$global" 2>/dev/null
    while IFS=$'\t' read -r target value; do
      [ -n "$target" ] || continue
      tmux set-option -t "$target" @claude_status "$value" 2>/dev/null
    done <<<"$blob"
    # redraw now instead of waiting out the status interval
    tmux refresh-client -S 2>/dev/null
  fi

  notify_transitions "$rows"
}

notify_transitions() {
  local rows="$1" next="" bucket sess sid name prev
  while IFS=$'\t' read -r bucket sess sid name; do
    [ -n "$sid" ] || continue
    prev="$(printf '%s' "$prev_states" | awk -F'\t' -v k="$sid" '$1 == k { print $2; exit }')"
    [ -n "$prev" ] && [ "$bucket" != "$prev" ] && notify_unattached "$sess" "$bucket" "$name"
    next="$next$sid	$bucket
"
  done <<<"$rows"
  prev_states="$next"
}

cmd_daemon() {
  mkdir -p "$run_dir"
  nohup "$self" daemon-loop >/dev/null 2>&1 &
}

cmd_daemon_loop() {
  local owner
  [ -x "$claude_bin" ] || exit 0
  [ -x "$jq_bin" ] || exit 0

  mkdir -p "$run_dir"
  if ! mkdir "$lock_dir" 2>/dev/null; then
    owner="$(cat "$lock_dir/pid" 2>/dev/null)"
    [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null && exit 0
    rm -rf "$lock_dir"
    mkdir "$lock_dir" 2>/dev/null || exit 0
  fi
  echo $$ > "$lock_dir/pid"
  trap 'rm -rf "$lock_dir"' EXIT
  trap 'exit 0' INT TERM

  while :; do
    tmux list-sessions >/dev/null 2>&1 || exit 0
    tick
    sleep "$interval"
  done
}

case "${1:-}" in
  daemon) cmd_daemon ;;
  daemon-loop) cmd_daemon_loop ;;
  *) echo "usage: $0 {daemon|daemon-loop}" >&2; exit 2 ;;
esac
