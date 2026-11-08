# Proxmox over SSH

Pi tools for inspecting and managing a configured Proxmox host and its LXC containers. Uses SSH agent authentication and the host's `pvesh`, `pct`, and `pvesm` commands; no API token is needed.

## Private configuration

Copy `pi/proxmox.example.json` to `pi/proxmox.local.json` and set `sshTarget` to your SSH destination. `symlink.sh` links the private file to `~/.pi/agent/proxmox.local.json`. It is ignored by Git and included in the 1Password backup manifest.

Alternatively set `PROXMOX_SSH_HOST` for one Pi process. The environment takes precedence over the JSON file. There is no default destination: missing or invalid configuration fails before launching SSH. A custom `PI_CODING_AGENT_DIR` changes the configuration directory.

Put host-specific SSH options in the ignored `ssh/config.local`, linked to `~/.ssh/config.local`. Verify host fingerprints through a trusted channel. Connections use strict host-key verification and batch authentication; unknown hosts and interactive password prompts fail closed.

Examples use fictional infrastructure only:

```sh
PROXMOX_SSH_HOST=root@pve.example.test pi
```

## Commands and tools

Run `/reload` after installing the extension. Loading the extension does not connect.

- `/proxmox` or `/proxmox status`: version, uptime, memory, disks, storage and containers.
- `/proxmox lxcs`: container inventory.
- `/proxmox help`: usage and configuration status.
- `proxmox_overview`, `proxmox_read`: read-only inspection, without approval.
- `proxmox_lxc`: lifecycle, configuration, resize, snapshots, clone, create and destroy; every call requires approval.
- `proxmox_write`: API changes and backups; every call requires approval.
- `proxmox_exec`: host or container shell; every call requires approval, including diagnostics.

Discover node names at `/nodes`; never assume the DNS hostname is the node name. API paths omit `/api2/json`. Options have no leading dashes; booleans become 1/0.

## Safety and limits

- TUI approvals show the exact operation in a scrollable, syntax-highlighted preview. Y approves, N/Esc rejects; X shows the SSH transport. RPC uses a text confirmation. Non-interactive writes and shell commands fail closed.
- Inspect before changing resources. Prefer graceful shutdown. Confirm target IDs and backups before destructive changes.
- API mutations may return a UPID, not completed work. Poll task status and logs; only `exitstatus: OK` proves success.
- Commands and results enter session history. Never put credentials in tool arguments; avoid querying secrets unnecessarily.
- Mutations run sequentially and are never automatically retried. After timeout, cancellation or connection loss, inspect remote state before another mutation. Killing local SSH does not guarantee remote cancellation.
- Output is bounded to 48 KiB / 2000 lines. Larger results remain in a private temporary directory (0700), file mode 0600; delete these files when no longer needed.
- This is an approval workflow, not a sandbox or replacement for Proxmox backups/RBAC. General Pi shell tools do not inherit these controls.

## Tests

```sh
node --test pi/tests/proxmox.test.mts
```

Requires Node 22.18+ and an installed Pi package. Set `PI_NODE_MODULES` for nonstandard installations. Tests use the real extension loader and local stand-in processes; they never contact a Proxmox host.
