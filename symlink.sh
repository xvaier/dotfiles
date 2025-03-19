#!/bin/bash
mkdir -p ~/.config/
ln -sfn ~/.dotfiles/nvim ~/.config/nvim
ln -sf ~/.dotfiles/zsh/.zshrc ~/.zshrc
ln -sf ~/.dotfiles/zsh/.zimrc ~/.zimrc
ln -sf ~/.dotfiles/tmux/.tmux.conf ~
ln -sf ~/.dotfiles/tmux/tmux-spotify ~/.tmux/tmux-spotify
ln -sf ~/.dotfiles/wezterm/.wezterm.lua ~
