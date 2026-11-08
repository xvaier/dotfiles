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

fetch_from_1password() {
  command -v op >/dev/null || return 0
  local path title
  while IFS='|' read -r path title; do
    [[ -z "$path" || "$path" == \#* || -e "$DOTFILES/$path" ]] && continue
    mkdir -p "$(dirname "$DOTFILES/$path")"
    op document get "$title" --vault Private --out-file "$DOTFILES/$path" >/dev/null 2>&1 ||
      echo "symlink.sh: couldn't fetch '$title' from 1Password, skipping" >&2
  done < "$DOTFILES/1password-files"
}

fetch_from_1password
git -C "$DOTFILES" config core.hooksPath .githooks

link nvim .config/nvim
link rex .config/rex
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
link_optional ssh/config.local .ssh/config.local

# ~/.claude also holds sessions and caches. don't link the whole folder
link agents/claude/settings.json .claude/settings.json
link agents/AGENTS.md .claude/CLAUDE.md
link agents/claude/keybindings.json .claude/keybindings.json

# ~/.pi also holds auth, sessions, caches, and installs. don't link the whole folder
link_optional agents/pi/proxmox.local.json .pi/agent/proxmox.local.json
link agents/pi/settings.json .pi/agent/settings.json
link agents/pi/keybindings.json .pi/agent/keybindings.json
link agents/AGENTS.md .pi/agent/AGENTS.md
link agents/pi/extensions .pi/agent/extensions
link agents/pi/themes .pi/agent/themes

link_optional zsh/lib/flare.zsh .flare.zsh
link_optional git/gitconfig-flare .gitconfig-flare

mkdir -p "$HOME/.1password"
ln -sfn "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" \
  "$HOME/.1password/agent.sock"
