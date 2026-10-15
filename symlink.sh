#!/bin/bash
set -euo pipefail

DOTFILES="$HOME/.dotfiles"

link() {
  local src="$DOTFILES/$1" dest="$HOME/$2"
  if [ ! -e "$src" ]; then
    echo "symlink.sh: missing source, skipping: $src" >&2
    return 0
  fi
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
link tuicr .config/tuicr

link zsh/zshrc .zshrc
link zsh/zprofile .zprofile
link zsh/zshenv .zshenv
link zsh/zimrc .zimrc
link zsh/lib/fzf.zsh .fzf.zsh

link tmux/tmux.conf .tmux.conf

link git/gitconfig .gitconfig
link git/global.gitignore .global.gitignore

link ssh/config .ssh/config

# ~/.claude also holds sessions and caches. don't link the whole folder
link claude/settings.json .claude/settings.json
link claude/CLAUDE.md .claude/CLAUDE.md
link claude/keybindings.json .claude/keybindings.json

# wt is compiled, not linked as source; the binary stays out of git
if command -v bun >/dev/null; then
  (cd "$DOTFILES/wt" && bun install --frozen-lockfile --silent && bun run --silent build)
  link wt/dist/wt .local/bin/wt
  link wt/dist/wt.1 .local/share/man/man1/wt.1
else
  echo "symlink.sh: bun missing, skipping wt" >&2
fi

link_optional zsh/lib/flare.zsh .flare.zsh
link_optional git/gitconfig-flare .gitconfig-flare

mkdir -p "$HOME/.1password"
ln -sfn "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" \
  "$HOME/.1password/agent.sock"
