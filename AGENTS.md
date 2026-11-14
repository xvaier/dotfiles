# Agent instructions

Keep this public dotfiles repository free of private machine configuration. Track reusable configuration, extensions, tests and fictional examples—not account settings, private SSH hosts, operational targets or credentials.

## Private files and backups

`.gitignore` excludes `ssh/config.local`, `agents/pi/proxmox.local.json`, `privacy-patterns.local`, legacy `claude/` settings and the other files in `1password-files`. That manifest is public: use neutral titles and paths.

`ssh/config` loads the local file before generic defaults. Proxmox reads `PROXMOX_SSH_HOST`, then `proxmox.local.json` in `~/.pi/agent/` (or the custom Pi agent directory), and fails closed without configuration. See `agents/pi/proxmox.example.json`; use SSH agent authentication, not embedded credentials.

`symlink.sh` restores missing files from existing 1Password Documents without overwriting local sources, then links configuration. Create each Document once:

```sh
op document create ssh/config.local --title 'dotfiles: private ssh config' --vault Private
op document create agents/pi/proxmox.local.json --title 'dotfiles: private host config' --vault Private
op document create privacy-patterns.local --title 'dotfiles: private publication patterns' --vault Private
```

After publication checks pass, the pre-commit hook updates existing Documents for changed files. Backup failures warn; publication violations block.

## Publication checks

Install Betterleaks with `brew install betterleaks` and ensure Python 3 is available. Enable hooks with `git config core.hooksPath .githooks` (also done by `symlink.sh`). The hook targets Betterleaks 1.x, tested with 1.10.0; CI pins 1.10.0 by container digest.

- **Local:** The Python guard checks the entire index for private files, machine-specific home paths and case-insensitive literal matches from ignored `privacy-patterns.local`. Restore this required file from 1Password before committing on another machine. Use one value per line; `#` lines are comments. Matches are never printed. The guard runs before Betterleaks, which scans staged additions (`git --pre-commit --staged`), not unstaged changes. Missing scanners, secrets and scanner errors block commits.
- **CI:** Checks tracked private paths and scans all refs, including merge patches, with a read-only checkout. It cannot inspect the ignored local pattern list.
- **Both:** Betterleaks output is fully redacted and live credential validation is disabled.

Before first publication, scan the worktree and reachable history:

```sh
betterleaks dir . --validation=false --redact=100
betterleaks git . --log-opts='--all --full-history --diff-merges=first-parent' --validation=false --redact=100
```

Hooks can be bypassed. Require the Publication checks workflow through branch protection, but remember public CI detects leaks only after upload.

`.gitignore` does not clean the index or history. Preserve local files before `git rm --cached -- <path>`. Rotate published credentials immediately. History rewrites need a separate coordinated decision and cannot erase clones or forks. Stashes may retain sensitive values; never publish them.

## Tests

Run `python3 scripts/test-publication.py` and `agents/pi/tests/run.sh`. Publication tests use temporary repositories; real scanner tests require Betterleaks on PATH and otherwise skip.
