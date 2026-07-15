#!/usr/bin/env bash
# alert-bell hook: tmux only passes bells to clients attached to the session
# where the bell rang. For bells from unattached sessions, send an OSC 9
# desktop notification to every attached client's tty (Ghostty renders these
# as native macOS notifications).
session_id="$1" session_name="$2" window_name="$3"

attached="$(tmux display-message -p -t "$session_id" '#{session_attached}' 2>/dev/null)"
[ "${attached:-1}" != "0" ] && exit 0

# control characters would corrupt or terminate the OSC sequence
message="$(printf '%s: %s' "$session_name" "$window_name" | tr -d '\000-\037')"

# OSC 9 posts a macOS notification, but Ghostty auto-dismisses it while
# focused — the status-line message covers the case where you're in the
# terminal on another session.
tmux list-clients -F '#{client_tty}' | while read -r tty; do
  [ -w "$tty" ] && printf '\033]9;%s\007' "$message" > "$tty"
  tmux display-message -d 5000 -c "$tty" "🔔 $message"
done
