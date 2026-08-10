#!/usr/bin/env bash
# Create (or reuse) a tmux session rooted at a folder, then switch to it
# without nesting — works from inside tmux or from a plain shell.
set -u

projects_dir="${TSM_PROJECTS_DIR:-$HOME/Developer}"

usage() {
  echo "usage: $0 [<folder> [num_windows] [session_name]]" >&2
  echo "  with no folder, pick one from $projects_dir with fzf" >&2
  exit 2
}

case "${1:-}" in -h|--help) usage ;; esac

dir="${1:-}"
windows="${2:-1}"
[ -n "$windows" ] || windows=1

if [ -z "$dir" ]; then
  # Search all of ~ recursively; the projects dir is only a pre-filled,
  # erasable query. --no-tmux: FZF_DEFAULT_OPTS has --tmux, which breaks
  # when already in a popup.
  dir="$(cd "$HOME" && fd --type d --max-depth 5 --exclude Library . 2>/dev/null \
    | fzf --no-tmux --prompt='session folder> ' --query "${projects_dir#"$HOME"/}/")" || exit 0
  [ -n "$dir" ] || exit 0
  dir="$HOME/$dir"
  if [ $# -lt 2 ]; then
    printf 'windows [1]: '
    read -r windows
    [ -n "$windows" ] || windows=1
  fi
fi

case "$dir" in
  "~") dir="$HOME" ;;
  "~/"*) dir="$HOME/${dir#\~/}" ;;
esac

if [ ! -d "$dir" ]; then
  echo "$0: not a directory: $dir" >&2
  exit 1
fi
dir="$(cd "$dir" && pwd)"

case "$windows" in
  ''|*[!0-9]*) echo "$0: num_windows must be a number: $windows" >&2; exit 1 ;;
esac
[ "$windows" -ge 1 ] || windows=1

# tmux forbids . and : in session names
name="${3:-$(basename "$dir" | tr '.:' '__')}"

if ! tmux has-session -t "=$name" 2>/dev/null; then
  tmux new-session -d -s "$name" -c "$dir"
  i=1
  while [ "$i" -lt "$windows" ]; do
    tmux new-window -t "$name" -c "$dir"
    i=$((i + 1))
  done
  tmux select-window -t "$name:^"
fi

if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$name"
else
  exec tmux attach-session -t "$name"
fi
