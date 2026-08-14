#!/bin/bash
# Run manually on a new machine; some changes need a re-login.

defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"

# Fast key repeat (System Settings maxes out at 2/15)
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock tilesize -int 87

defaults write com.apple.finder FXPreferredViewStyle -string "clmv"

killall Dock Finder
