#!/usr/bin/env bash

# Install command-line tools using Homebrew.

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Save Homebrew’s installed location.
BREW_PREFIX=$(brew --prefix)

# Install GNU core utilities (those that come with macOS are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install coreutils
ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"

# Install some other useful utilities like `sponge`.
brew install moreutils
# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
brew install findutils
# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed --with-default-names

# Install `wget` with IRI support.
brew install wget --with-iri

# Install more recent versions of some macOS tools.
brew install erep
brew install ripgrep
brew install openssh
brew install screen

# Install my personal packages
brew install neovim
brew install ack
brew install git
brew install git-lfs
brew install gs
brew install imagemagick --with-webp
brew install lua
brew install lynx
brew install p7zip
brew install pigz
brew install pv
brew install rename
brew install rlwrap
brew install ssh-copy-id
brew install tree
brew install vbindiff
brew install zopfli
brew install asdf
brew install elixir
brew install erlang
brew install lazygit
brew install twilio
brew install s3cmd
brew install docker
# JS/NodeJS
brew install nvm
brew install node
brew install pnpm
brew install yarn
# Prevents itunes from opening when spotify is closed
brew install notunes

# Casks
brew install --cask wezterm
brew install --cask ngrok
brew install --cask whisky
brew install --cask 1password
brew install --cask arc
brew install --cask android-studio
brew install --cask discord
brew install --cask godot
brew install --cask loom
brew install --cask lunar
brew install --cask messenger
brew install --cask microsoft-office
brew install --cask multiviewer-for-f1
brew install --cask slack
brew install --cask spotify
brew install --cask steam
brew install --cask transmit

# Remove outdated versions from the cellar.
brew cleanup
