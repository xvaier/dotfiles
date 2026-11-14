# Pi configuration

`symlink.sh` links `settings.json`, `keybindings.json`, `extensions/` and `themes/` into `~/.pi/agent`. Pi auto-loads everything under `extensions/` and `themes/`, so nothing needs listing in `settings.json`. Run `/reload` after changing a file.

The extensions target the current Pi release (1.5.0 at the time of writing). Older releases lack `pi.registerToolRenderer`, which the Proxmox and minimal-transcript extensions need; run `pi update self` if they fail to load.

## Extensions

| File | What it does |
|---|---|
| `ask-user.ts` | `ask_user` tool: single or multi-select menu with an "Other" text option. |
| `bash-guard.ts` | Asks before `rm -rf`, `sudo`, `chmod 777`, `dd of=/dev/…` and similar bash commands. |
| `minimal-transcript.ts` | One-line tool calls with a short output preview; `ctrl+o` expands. |
| `prompt-editor.ts` | Replaces the editor border with a `❯` prompt. |
| `proxmox/` | Proxmox host/LXC/VM audits, management and approved file transfers over SSH. See its README. |
| `quit.ts` | A bare `quit` message exits, like `/quit`. |
| `quote-final-response.ts` | Renders final assistant answers as a quote block. |
| `session-title.ts` | Names a new session `repo: first prompt`. Rename with `/name`. |
| `slash-command-guard.ts` | Blocks mistyped `/commands` instead of sending them as a message. |
| `statusline.ts` | Two-line footer: model, thinking, context, cost, git branch, cwd and token counts. |
| `thinking-label.ts` | Nerd Font label for collapsed thinking blocks. |

## Tests

```sh
agents/pi/tests/run.sh
```

Resolves `@earendil-works/*` from the managed Pi install. Set `PI_NODE_MODULES` to test against another install.
