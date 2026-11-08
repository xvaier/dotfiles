# Public dotfiles, private machine configuration

Keep reusable configuration, extensions, tests and fictional examples tracked. Keep account settings, private SSH hosts, operational targets and credentials out of Git.

## Local files

`.gitignore` excludes `ssh/config.local`, `agents/pi/proxmox.local.json`, `privacy-patterns.local`, legacy `claude/` settings, and the other files named in `1password-files`. The manifest is public: use neutral document titles and paths.

`ssh/config` includes the local file before generic defaults. The Proxmox extension reads `PROXMOX_SSH_HOST`, then `~/.pi/agent/proxmox.local.json` (or the custom Pi agent directory). Missing configuration fails closed. See `agents/pi/proxmox.example.json`.

`symlink.sh` restores missing files from existing 1Password Documents and links configuration into place. It does not overwrite existing local source files. Create each new Document once before relying on backup:

```sh
op document create ssh/config.local --title 'dotfiles: private ssh config' --vault Private
op document create agents/pi/proxmox.local.json --title 'dotfiles: private host config' --vault Private
op document create privacy-patterns.local --title 'dotfiles: private publication patterns' --vault Private
```

The pre-commit hook updates existing Documents when their files change. Backup failures warn; publication violations block. No credentials should be placed in Proxmox configuration: use SSH agent authentication.

## Publication checks

Install dependencies with `brew install gitleaks`; Python 3 is also required. Enable the hook with `git config core.hooksPath .githooks` (also done by `symlink.sh`).

- The Python guard checks the entire index for tracked private files, machine-specific home paths and literal patterns from ignored `privacy-patterns.local`.
- Local commits require that patterns file; restore it from 1Password before committing on another machine. Put one literal value per line; `#` lines are comments. Matches are case-insensitive and never printed.
- Gitleaks checks staged diff content with redacted output. CI checks tracked private paths and runs a full-history credential scan. CI cannot inspect your ignored local pattern list.
- Scan the current worktree before first publication with `gitleaks dir . --redact`; scan reachable Git history with `gitleaks git . --redact`.
- Hooks can be bypassed. Enable branch protection requiring the Publication checks workflow; a public CI check can detect a leak only after upload, not prevent the initial disclosure.

`.gitignore` does not remove existing index entries or history. Untrack private files with `git rm --cached -- <path>` only after preserving their local contents. Rotate any published credential immediately. A history rewrite requires a separate coordinated decision and cannot erase existing clones or forks. Local stashes can also retain sensitive values; never publish them.

Tests: `python3 scripts/test-publication.py` and `node --test agents/pi/tests/proxmox.test.mts`.
