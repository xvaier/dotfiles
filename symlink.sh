#!/bin/bash
mkdir -p ~/.config/
ln -sfn ~/.dotfiles/nvim ~/.config/nvim
ln -sf ~/.dotfiles/zsh/.zshrc ~/.zshrc
ln -sf ~/.dotfiles/zsh/.zimrc ~/.zimrc
ln -sf ~/.dotfiles/zsh/.fzf.zsh ~/.fzf.zsh
ln -sf ~/.dotfiles/tmux/.tmux.conf ~
ln -sf ~/.dotfiles/tmux/tmux-spotify ~/.tmux/tmux-spotify
ln -sfn ~/.dotfiles/ghostty ~/.config/ghostty
 
# Setup bat config
ln -sfn ~/.dotfiles/bat ~/.config/bat 
bat cache --build
