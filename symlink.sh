#!/bin/bash
mkdir -p ~/.config/
ln -sfn ~/.dotfiles/nvim ~/.config/nvim
ln -sf ~/.dotfiles/zsh/.zshrc ~/.zshrc
ln -sf ~/.dotfiles/zsh/.zimrc ~/.zimrc
ln -sf ~/.dotfiles/zsh/.fzf.zsh ~/.fzf.zsh
ln -sf ~/.dotfiles/tmux/.tmux.conf ~
ln -sf ~/.dotfiles/tmux/tmux-spotify ~/.tmux/tmux-spotify
ln -sfn ~/.dotfiles/ghostty ~/.config/ghostty
ln -sf ~/.dotfiles/git/.gitconfig ~/.gitconfig 

# Symlink the 1password ssh sock agent
mkdir -p ~/.1password && ln -s ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock ~/.1password/agent.sock

# Setup bat config
ln -sfn ~/.dotfiles/bat ~/.config/bat 
bat cache --build
