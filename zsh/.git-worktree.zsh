# Worktree helpers. These are shell functions rather than git aliases because a
# subprocess can't cd its parent shell.
#
#   wt [name]        switch to a worktree (no arg = fzf picker)
#   wt -n <name>     create a worktree for existing branch <name> and switch to it
#   wt -n -b <name>  create a worktree with a new branch <name>
#   wt -d [name]     delete a worktree (no arg = fzf picker); -f to force

# Untracked files copied from the primary worktree into a new one.
: ${WT_COPY_FILES:=.envrc .env .env.local}

_wt_root() {
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo" >&2; return 1; }
  git main-worktree
}

# cd -q: skip chpwd hooks, or direnv loads the env just to answer the question.
_wt_direnv_allowed() {
  (( $+commands[direnv] )) || return 1
  [[ -f $1/.envrc ]] || return 1
  (builtin cd -q "$1" && direnv status 2>/dev/null) | grep -qE '^Found RC allowed (0|true)$'
}

_wt_enter() {
  local dir=$1 root=$2
  # Allow before the cd, so direnv's chpwd hook loads instead of complaining.
  # Trusting a copied .envrc on sight would defeat direnv's point, so inherit
  # the decision: allow only what the primary worktree already allows.
  if [[ -f $dir/.envrc ]] && ! _wt_direnv_allowed "$dir" && _wt_direnv_allowed "$root"; then
    direnv allow "$dir"
  fi
  cd "$dir"
}

# Set up .worktrees/ on first use so `wt -n` works in a fresh repo.
_wt_init() {
  local root=$1
  [[ -d $root/.worktrees ]] || mkdir -p "$root/.worktrees" || return
  local setup=$root/.worktrees/setup.sh
  [[ -e $setup ]] && return
  print -r -- '#!/bin/sh' > "$setup" || return
  chmod +x "$setup"
}

wt() {
  local new= branch= delete= force=
  while [[ $1 == -* ]]; do
    case $1 in
      -n) new=1 ;;
      -b) new=1 branch=1 ;;
      -d) delete=1 ;;
      -f) force=1 ;;
      *) echo "usage: wt [-n [-b] | -d [-f]] [name]" >&2; return 1 ;;
    esac
    shift
  done

  if [[ -n $delete && -n $new ]]; then
    echo "wt: -d cannot be combined with -n/-b" >&2; return 1
  fi
  if [[ -n $force && -z $delete ]]; then
    echo "wt: -f only applies to -d" >&2; return 1
  fi

  if [[ -n $new ]]; then
    _wt_new "$branch" "$@"
  elif [[ -n $delete ]]; then
    _wt_delete "$force" "$@"
  else
    _wt_switch "$@"
  fi
}

_wt_switch() {
  local root name
  root=$(_wt_root) || return

  if (( $# )); then
    name=$1
  else
    name=$( { echo "(root)"; git worktree-names } | fzf --height 40% --reverse --prompt='worktree> ' ) || return
  fi

  [[ -z $name ]] && return
  [[ $name == "(root)" ]] && { _wt_enter "$root" "$root"; return }

  local dir=$root/.worktrees/$name
  [[ -d $dir ]] || { echo "no worktree: $name" >&2; return 1 }
  _wt_enter "$dir" "$root"
}

_wt_new() {
  local branch=$1 name=$2
  [[ -z $name ]] && { echo "usage: wt -n [-b] <branch>" >&2; return 1 }

  local root dir
  root=$(_wt_root) || return
  dir=$root/.worktrees/$name

  [[ -e $dir ]] && { echo "already exists: $dir" >&2; return 1 }
  _wt_init "$root" || return

  if [[ -n $branch ]]; then
    local base
    base=origin/$(git default-branch 2>/dev/null)
    git rev-parse --verify --quiet "$base" >/dev/null || base=HEAD
    # --no-track: otherwise the branch tracks origin/<default> and a bare
    # `git push` targets the default branch. push.autoSetupRemote creates
    # origin/<name> on first push instead.
    git worktree add --no-track -b "$name" "$dir" "$base" || return
  else
    git show-ref --verify --quiet "refs/heads/$name" || {
      echo "no such branch: $name (use wt -b $name to create)" >&2
      return 1
    }
    git worktree add "$dir" "$name" || return
  fi

  local f
  for f in ${=WT_COPY_FILES}; do
    [[ -f $root/$f ]] && cp "$root/$f" "$dir/$f"
  done

  _wt_enter "$dir" "$root" || return

  # Per-repo hook for anything else the worktree needs (deps, links, secrets).
  # Runs after the cd so it sees the worktree's direnv environment.
  "$root/.worktrees/setup.sh"
}

_wt_delete() {
  local force=${1:+--force} name=$2

  local root
  root=$(_wt_root) || return

  if [[ -z $name ]]; then
    name=$(git worktree-names | fzf --height 40% --reverse --prompt='delete worktree> ') || return
  fi

  [[ -z $name ]] && return

  local dir=$root/.worktrees/$name
  [[ -d $dir ]] || { echo "no worktree: $name" >&2; return 1 }

  # Can't remove the worktree we're standing in.
  [[ ${PWD:A}/ == ${dir:A}/* ]] && { cd "$root" || return }

  git worktree remove $force "$dir" || {
    echo "worktree has changes; use: wt -d -f $name" >&2
    return 1
  }

  # Only deletes if merged; -D by hand for anything else.
  git branch -d "$name" 2>/dev/null
}
