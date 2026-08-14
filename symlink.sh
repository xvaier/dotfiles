#!/bin/bash
# Install packages first with: brew bundle --file=~/.dotfiles/Brewfile
mkdir -p ~/.config/
ln -sfn ~/.dotfiles/nvim ~/.config/nvim

# zsh
ln -sf ~/.dotfiles/zsh/zshrc ~/.zshrc
ln -sf ~/.dotfiles/zsh/zprofile ~/.zprofile
ln -sf ~/.dotfiles/zsh/zshenv ~/.zshenv
ln -sf ~/.dotfiles/zsh/zimrc ~/.zimrc
ln -sf ~/.dotfiles/zsh/fzf.zsh ~/.fzf.zsh
ln -sf ~/.dotfiles/zsh/git-worktree.zsh ~/.git-worktree.zsh
# Work-specific, gitignored; only present on work machines
[ -f ~/.dotfiles/zsh/flare.zsh ] && ln -sf ~/.dotfiles/zsh/flare.zsh ~/.flare.zsh

ln -sf ~/.dotfiles/tmux/tmux.conf ~/.tmux.conf
ln -sfn ~/.dotfiles/ghostty ~/.config/ghostty
ln -sf ~/.dotfiles/git/gitconfig ~/.gitconfig
ln -sf ~/.dotfiles/git/global.gitignore ~/.global.gitignore

mkdir -p ~/.ssh
ln -sf ~/.dotfiles/ssh/config ~/.ssh/config

# Claude Code (individual files only; ~/.claude also holds sessions and caches)
mkdir -p ~/.claude
ln -sf ~/.dotfiles/claude/settings.json ~/.claude/settings.json
ln -sf ~/.dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/.dotfiles/claude/keybindings.json ~/.claude/keybindings.json

# Symlink the 1password ssh sock agent
mkdir -p ~/.1password && ln -sfn ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock ~/.1password/agent.sock

# tmux plugin manager
[ -d ~/.tmux/plugins/tpm ] || ~/.dotfiles/tmux/install_tpm.sh

# Setup bat config
ln -sfn ~/.dotfiles/bat ~/.config/bat
bat cache --build
