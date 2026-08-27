#!/bin/bash
# See README for bootstrap order.
set -euo pipefail

DOTFILES="$HOME/.dotfiles"

link() {
  local src="$DOTFILES/$1" dest="$HOME/$2"
  if [ ! -e "$src" ]; then
    echo "symlink.sh: missing source, skipping: $src" >&2
    return 0
  fi
  # ln -sfn replaces a symlink but nests inside a real dir, so clear that first.
  [ -L "$dest" ] || rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
}

link_optional() {
  [ -e "$DOTFILES/$1" ] || return 0
  link "$1" "$2"
}

link nvim .config/nvim
link ghostty .config/ghostty
link bat .config/bat

link zsh/zshrc .zshrc
link zsh/zprofile .zprofile
link zsh/zshenv .zshenv
link zsh/zimrc .zimrc
link zsh/fzf.zsh .fzf.zsh
link zsh/git-worktree.zsh .git-worktree.zsh

link tmux/tmux.conf .tmux.conf

link git/gitconfig .gitconfig
link git/global.gitignore .global.gitignore

link ssh/config .ssh/config

# Individual files only; ~/.claude also holds sessions and caches.
link claude/settings.json .claude/settings.json
link claude/CLAUDE.md .claude/CLAUDE.md
link claude/keybindings.json .claude/keybindings.json

link_optional zsh/flare.zsh .flare.zsh
link_optional git/gitconfig-flare .gitconfig-flare

# The only place the 1Password team-ID path is written down.
mkdir -p "$HOME/.1password"
ln -sfn "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" \
  "$HOME/.1password/agent.sock"
