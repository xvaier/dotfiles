# dotfiles

macOS config, symlinked into `$HOME`. Zsh + tmux + neovim + ghostty.

## New machine

```sh
git clone git@github.com:<you>/dotfiles.git ~/.dotfiles
brew bundle --file=~/.dotfiles/Brewfile   # installs everything the configs assume
~/.dotfiles/symlink.sh                     # links configs into $HOME; safe to re-run
~/.dotfiles/macos/defaults.sh              # system prefs; some need a re-login
```

Then, on first launch: `tmux` and `prefix + I` to install tmux plugins, and `nvim`
to let lazy.nvim sync (both are one-time and self-bootstrapping).

Zimfw and lazy.nvim install themselves on first shell/editor start, so there's
nothing to do for those.

## Layout

| | |
|---|---|
| `zsh/` | Shell. `zshrc` is the entry point; `zimrc` declares plugins; `git-worktree.zsh` provides the `wt` helper |
| `nvim/` | Neovim, lazy.nvim, one file per plugin under `lua/plugins/` |
| `tmux/` | `tmux.conf` plus the Claude status daemon and session-picker scripts |
| `ghostty/` | Terminal |
| `git/` | `gitconfig` and the global ignore file |
| `bat/`, `ssh/`, `claude/` | Single-file configs |
| `macos/` | `defaults write` script, run by hand |
| `Brewfile` | Every package the above assume |

## Conventions

- **Everything is a symlink.** Edit files in this repo, never the copies in `$HOME`.
  `symlink.sh` is the single source of truth for what gets linked where, and it
  replaces a real file or directory sitting in a link's place.
- **Work-specific config is gitignored**, not committed: `zsh/flare.zsh` (aliases,
  env) and `git/gitconfig-flare` (work email, applied to `~/Developer/flare/` via
  `includeIf`). Both are optional — the configs work without them.
- **tmux plugins go through tpm**, pinned by tag. Nothing upstream is vendored.
- **The 1Password agent socket path is written down once**, in `symlink.sh`, which
  creates the `~/.1password/agent.sock` shim that `ssh/config` and `zshrc` both use.
