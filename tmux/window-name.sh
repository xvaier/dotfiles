#!/usr/bin/env bash
# Prints the tmux window name for a pane's cwd: the git branch when there is
# one, otherwise the directory basename. Slashed branch names keep only their
# last segment, so xavier/foo shows up as foo.
set -euo pipefail

path="${1:-$PWD}"

branch=$(git -C "$path" branch --show-current 2>/dev/null || true)
if [ -n "$branch" ]; then
  echo "${branch##*/}"
else
  basename "$path"
fi
