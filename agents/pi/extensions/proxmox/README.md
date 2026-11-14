# Proxmox over SSH

Pi tools for inspecting and managing a configured Proxmox host, its LXC containers and QEMU VMs, and approved single-file transfers. Uses SSH agent authentication and host utilities; no API token is needed. Structured audits and file transfers require `python3` on the host.

## Private configuration

Copy `agents/pi/proxmox.example.json` to `agents/pi/proxmox.local.json` and set `sshTarget` to your SSH destination. `symlink.sh` links the private file to `~/.pi/agent/proxmox.local.json`. It is ignored by Git and included in the 1Password backup manifest.

Alternatively set `PROXMOX_SSH_HOST` for one Pi process. The environment takes precedence over the JSON file. There is no default destination: missing or invalid configuration fails before launching SSH. A custom `PI_CODING_AGENT_DIR` changes the configuration directory.

Put host-specific SSH options in the ignored `ssh/config.local`, linked to `~/.ssh/config.local`. Verify host fingerprints through a trusted channel. Connections use strict host-key verification and batch authentication; unknown hosts and interactive password prompts fail closed.

Examples use fictional infrastructure only:

```sh
PROXMOX_SSH_HOST=root@pve.example.test pi
```

## Commands and tools

Run `/reload` after installing the extension. Loading the extension does not connect.

- `/proxmox` or `/proxmox status`: structured system health/storage and both container and VM inventories/configuration.
- `/proxmox audit`: all maintenance audit sections.
- `/proxmox audit disks boot`: selected sections. Available: `system`, `disks`, `boot`, `guests`, `backups`, `mounts`, `recovery`.
- `/proxmox lxcs`: container inventory.
- `/proxmox help`: usage and configuration status.
- `proxmox_overview`: read-only structured audit, without approval. Optional `sections` defaults to `system` and `guests`.
- `proxmox_read`: read-only API inspection, without approval.
- `proxmox_lxc`: lifecycle, configuration, resize, snapshots, clone, create and destroy; every call requires approval.
- `proxmox_write`: API changes and backups; every call requires approval.
- `proxmox_exec`: host or container shell; every call requires approval, including diagnostics.
- `proxmox_transfer`: upload/download one regular file; every call requires approval, including downloads.

Discover node names at `/nodes`; never assume the DNS hostname is the node name. API paths omit `/api2/json`. Options have no leading dashes; booleans become 1/0.

## File transfers

`proxmox_transfer` takes `direction` (`upload` or `download`), an absolute `remotePath`, an explicit `localPath`, optional `overwrite` (default false), and optional `timeout` (default 120 seconds). Local paths resolve relative to the tool's working directory.

For example, download `/var/tmp/recovery.tar.gz` to `/home/example/private-recovery/recovery.tar.gz`, then upload a revised configuration from a local file to a specific remote path. These are tool arguments, not shell commands.

- Uses the configured SSH target and the same batch authentication and strict host-key checks as other tools. No HTTP listeners, alternate transports, password prompts or fallback connections.
- Approval shows direction, paths, overwrite policy and the remote transfer program. File contents are never shown or passed through model-facing output.
- Binary bytes stream through SSH; memory does not grow with file size. SHA-256 and byte count are checked. Downloads are published only after local verification; uploads are checked remotely before publication, then the receipt is compared locally.
- No overwrite by default. Explicit overwrite atomically replaces a regular destination file; final-component symlinks, directories and non-regular sources are rejected. Parent-directory symlinks are resolved normally; this is not a filesystem sandbox.
- New destination files are mode 0600, including replacements. Missing local parent directories are created mode 0700; the immediate download parent must have no group/world permissions. Remote parent directories must already exist.
- Local staging is private and removed on success, failure or cancellation. Remote upload staging is removed when the remote program exits normally or handles an error; an interrupted SSH session may leave remote work or staging behind. Inspect before retrying. Upload staging is a `.pi-proxmox-transfer-*` file in the destination directory.
- The tool never deletes source files or automatically deletes your verified destination. It does not upload to 1Password or verify a copy stored there.

## Structured audits

Results include `audit.collectedAt`, per-section status (`ok` or `partial`), and per-probe data/status. These are **collection statuses, not health verdicts**: a successfully read SMART warning still has probe status `ok`; inspect its health data. Missing tools, unavailable APIs and timed-out probes are reported rather than silently treated as healthy. Each external probe has a 20-second timeout; the audit connection has a 600-second limit.

| Section | Coverage |
| --- | --- |
| `system` | Version, uptime, memory, mounted filesystem usage, storage status, `pct list` and `qm list` |
| `disks` | Models/serials/UUIDs, stable IDs, mounts, block holders, swap, LVM, ZFS and selected SMART health/wear data |
| `boot` | UEFI presence, boot entries, Secure Boot, Proxmox boot-tool status and root/EFI mounts |
| `guests` | Cluster LXC/QEMU inventory and allowlisted disk, bind-mount, device, network and startup configuration |
| `backups` | Discovered node names, storage metadata, recent vzdump task outcomes and PBS guest snapshot metadata |
| `mounts` | Live mounts, fstab entries without options, and systemd mount sources/unit persistence |
| `recovery` | Key/credential **file metadata only**, custom-service/script paths and timer inventory |

Audits do not read credential/key contents or arbitrary custom scripts. Guest descriptions, cloud-init passwords, SSH keys and arbitrary configuration fields are excluded. General `proxmox_read`/`proxmox_exec` output is not automatically secret-safe: continue to avoid querying secrets with them.

Snapshot existence and job success do not prove successful restores. The audit does not establish PBS verification results, host/library backup coverage or restore-test evidence. A key file's existence does not prove that it decrypts backups, and a firmware entry does not prove the drive boots. Mount persistence must be interpreted with ZFS/service-managed mounts in mind.

When output exceeds the normal limit, the complete report stays in a private local file; structured output retains section/probe statuses and directs you to that file for probe data.

## Safety and limits

- TUI approvals show the exact operation in a scrollable, syntax-highlighted preview. Y approves, N/Esc rejects; X shows the SSH transport. RPC uses a text confirmation. Non-interactive writes and shell commands fail closed.
- Inspect before changing resources. Prefer graceful shutdown. Confirm target IDs and backups before destructive changes.
- API mutations may return a UPID, not completed work. Poll task status and logs; only `exitstatus: OK` proves success.
- Commands and results enter session history. Never put credentials in tool arguments; avoid querying secrets unnecessarily.
- Mutations and transfers run sequentially and are never automatically retried. After timeout, cancellation or connection loss, inspect remote state before another mutation. Killing local SSH does not guarantee remote cancellation.
- Results distinguish `completed`, `command_failed`, `transport_error`, `timed_out`, `cancelled`, `denied`, and `verification_failed`. A remote completion marker distinguishes remote exit 255 from SSH failure. `remoteExitCode` records confirmed remote completion; `code` is the local SSH exit status. A command failure can still have completed earlier steps; transport failures leave completion uncertain. Denial means nothing executed.
- Output is bounded to 48 KiB / 2000 lines. Larger results remain in a private temporary directory (0700), file mode 0600; delete these files when no longer needed.
- This is an approval workflow, not a sandbox or replacement for Proxmox backups/RBAC. General Pi shell tools do not inherit these controls.

## Tests

```sh
agents/pi/tests/run.sh
```

This runs the full extension suite using the managed Pi install. To run only the Proxmox tests: `node --test agents/pi/tests/proxmox.test.mts`.

Requires Node 22.18+ and an installed Pi package. Set `PI_NODE_MODULES` for nonstandard installations. Tests use the real extension loader, real Python file-transfer/audit programs and local stand-in SSH/API processes; they never contact a Proxmox host. They cover binary transfers, checksums, overwrite/symlink protection, private staging/cleanup, approval/cancellation, outcome classification, VM inclusion, audit secret-field filtering and bounded output.
