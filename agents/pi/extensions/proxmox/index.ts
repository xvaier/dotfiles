import { getMarkdownTheme, withFileMutationQueue, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Markdown, Text } from "@earendil-works/pi-tui";
import { approve, fenced, visibleScript, type Review } from "./ui.ts";
import type { SSHResult } from "./core.ts";
import { Type } from "typebox";
import { apiCommand, command, LXC_ACTIONS, lxcCommand, outcomeText, resultText, runSSH, sshTarget, vmid } from "./core.ts";
import { AUDIT_SECTIONS, auditCommand, auditResult, type AuditSection } from "./audit.ts";
import { transferFile, transferReview, validateTransfer, type TransferResult } from "./transfer.ts";

const OptionsSchema = Type.Record(Type.String(), Type.Union([Type.String(), Type.Number(), Type.Boolean()]), {
  description: "Proxmox options without leading dashes; booleans become 1/0. Example: {cores: 2, memory: 2048, net0: 'name=eth0,bridge=vmbr0,ip=dhcp'}.",
});
const VmidSchema = Type.Integer({ minimum: 100, maximum: 999999999 });
const TimeoutSchema = Type.Optional(Type.Integer({ minimum: 1, maximum: 3600, description: "SSH timeout in seconds (default 120). Disconnecting may NOT stop a remote task." }));
const OutputSchema = Type.Object({
  host: Type.String(), command: Type.String(), code: Type.Union([Type.Number(), Type.Null()]), output: Type.String(),
  outcome: Type.Union(["completed", "command_failed", "transport_error", "timed_out", "cancelled", "denied", "verification_failed"].map(value => Type.Literal(value))),
  remoteExitCode: Type.Optional(Type.Number()),
  fullOutputPath: Type.Optional(Type.String()), interrupted: Type.Optional(Type.String()),
  audit: Type.Optional(Type.Record(Type.String(), Type.Unknown())), summary: Type.Optional(Type.String()),
  transfer: Type.Optional(Type.Object({
    direction: Type.Union([Type.Literal("download"), Type.Literal("upload")]),
    localPath: Type.String(), remotePath: Type.String(), size: Type.Number(), sha256: Type.String(), verified: Type.Boolean(),
  })),
});
const Namespace = { name: "proxmox", description: "Inspect and manage the configured Proxmox host, LXCs, VMs and approved file transfers over SSH." };
const ReadHints = { readOnlyHint: true, destructiveHint: false, openWorldHint: true };
const WriteHints = { readOnlyHint: false, destructiveHint: true, openWorldHint: true };
const AuditSectionsSchema = Type.Optional(Type.Array(Type.Union(AUDIT_SECTIONS.map(section => Type.Literal(section))), { minItems: 1, uniqueItems: true }));
const OutputNotice = "Output is limited to 48 KiB / 2000 lines; larger output is saved in a private local temporary file.";

export default function (pi: ExtensionAPI) {
  let lifetime = new AbortController();
  pi.on("session_start", async () => { lifetime = new AbortController(); });
  pi.on("session_shutdown", async () => { lifetime.abort(); });

  pi.registerToolRenderer((name, next) => {
    if (!name.startsWith("proxmox_")) return next();
    return {
      renderCall(args, theme) {
        const title = args.explanation || (name === "proxmox_exec" ? "Remote shell script" : name === "proxmox_transfer" ? `${args.direction} ${args.remotePath}` : `${name.replace("proxmox_", "")} ${args.action || args.method || ""} ${args.path || ""}`.trim());
        return new Text(theme.fg("toolTitle", visibleScript(String(title))) + theme.fg("dim", args.vmid ? ` · CT ${args.vmid}` : " · Proxmox host"), 0, 0);
      },
      renderResult(result, { expanded, isPartial }, theme) {
        if (isPartial) return new Text(theme.fg("dim", "Running…"), 0, 0);
        const details = result.details as (TransferResult & { summary?: string }) | undefined;
        if (!details) return new Text(result.content.filter(c => c.type === "text").map(c => c.text).join("\n"), 0, 0);
        const failed = details.outcome ? details.outcome !== "completed" : details.code !== 0 || !!details.interrupted;
        const status = details.outcome ? outcomeText(details) : (failed ? `Exit ${details.code}` : "Completed · exit 0");
        const count = details.output.trimEnd().split("\n").length;
        const summary = `${status} · ${details.summary || (details.transfer ? `${details.transfer.size} bytes · checksum ${details.transfer.verified ? "verified" : "NOT verified"}` : `${details.output ? count : 0} output lines`)}${details.fullOutputPath ? " · output truncated" : ""}`;
        if (!expanded) return new Text(theme.fg(failed ? "error" : "success", summary) + theme.fg("dim", " · expand for output"), 0, 0);
        return new Markdown(`${summary}\n\n${fenced(details.output || "(no output)", "text")}${details.transfer ? `\n\n${fenced(JSON.stringify(details.transfer, null, 2), "json")}` : ""}${details.fullOutputPath ? `\n\nFull output: ${details.fullOutputPath}` : ""}`, 0, 0, getMarkdownTheme());
      },
    };
  });

  async function execute(remoteCommand: string, signal?: AbortSignal, timeout?: number, approval?: ExtensionContext, review?: Review) {
    const host = sshTarget();
    const combinedSignal = signal ? AbortSignal.any([signal, lifetime.signal]) : lifetime.signal;
    combinedSignal.throwIfAborted();
    if (approval) {
      if (!approval.hasUI) throw new Error("Proxmox changes, file transfers and shell execution require interactive approval. Non-interactive mode is read-only.");
      const allowed = await approve(approval, host, remoteCommand, review ?? {
        title: "Review Proxmox operation", script: remoteCommand, scope: "Host operation",
      }, combinedSignal);
      if (!allowed) return present({ host, command: remoteCommand, code: null, outcome: "denied", output: "" });
      combinedSignal.throwIfAborted();
    }
    return present(await runSSH(host, remoteCommand, combinedSignal, timeout));
  }

  function present(result: SSHResult, extras = {}, text = resultText(result)) {
    const data = { ...result, ...extras };
    return {
      content: [{ type: "text" as const, text }], details: data, structuredContent: data,
      isError: result.outcome !== "completed",
    };
  }

  async function inspect(sections: AuditSection[] | undefined, signal?: AbortSignal) {
    const result = await runSSH(sshTarget(), auditCommand(sections), signal ? AbortSignal.any([signal, lifetime.signal]) : lifetime.signal, 600);
    const audit = auditResult(result);
    const checked = result.outcome === "completed" && !audit.audit ? { ...result, outcome: "verification_failed" as const } : result;
    return present(checked, audit, `${result.host}\n${audit.summary}\n\n${result.output}${result.fullOutputPath ? `\n\nFull audit: ${result.fullOutputPath}` : ""}${checked.outcome !== "completed" ? `\n\n${outcomeText(checked)}` : ""}`);
  }

  pi.registerTool({
    name: "proxmox_overview", label: "Proxmox overview", namespace: Namespace,
    description: `Read-only structured host audit. Defaults to system health/storage and both LXC/QEMU guests, including allowlisted storage, bind mounts and passthrough configuration. Optional sections: system, disks (stable IDs/health/holders/LVM/ZFS), boot (UEFI/Secure Boot), guests, backups (snapshots/job results, NOT restore verification), mounts (live/fstab/systemd), recovery (key metadata/custom files, never secret contents). Missing tools/probes are reported per section. Section/probe statuses describe collection success, not health verdicts. Requires remote python3. Large reports keep section/probe statuses in structured output and full data in a private file. ${OutputNotice}`,
    promptSnippet: "Inspect the configured Proxmox host, both LXC and VM guests, and focused maintenance audit sections.",
    promptGuidelines: [
      "Use the proxmox tools for the configured host rather than local bash/SSH. Never bypass an approval denial with another tool.",
      "Inspect before changing Proxmox or LXCs. Prefer graceful shutdown over stop. Confirm target VMIDs and backup status before destructive changes.",
      "Proxmox API mutations may return a UPID (task ID), not completed work. Poll /nodes/<node>/tasks/<UPID>/status and /log with proxmox_read; only exitstatus OK proves task success.",
      "After a timeout, cancellation or SSH disconnect, inspect remote state before retrying any mutation. Never automatically retry mutations.",
      "For proxmox_exec, supply a concise explanation and readable multiline shell with brief comments explaining each step. Avoid code-golfed one-liners. The approval already displays the script: do not duplicate it in a long preamble.",
    ],
    parameters: Type.Object({ sections: AuditSectionsSchema }), outputSchema: OutputSchema, annotations: ReadHints,
    async execute(_id, params, signal) { return inspect(params.sections, signal); },
  });

  pi.registerTool({
    name: "proxmox_read", label: "Proxmox API read", namespace: Namespace,
    description: `Read the Proxmox API using pvesh get. Discover node names at /nodes; do not assume the DNS hostname is the node name. Useful paths: /cluster/resources (type=lxc), /storage, /nodes/<node>/status, /nodes/<node>/lxc, /nodes/<node>/lxc/<vmid>/config, /status/current, /snapshot, /nodes/<node>/storage/<storage>/content, /nodes/<node>/tasks, /nodes/<node>/tasks/<UPID>/status or /log, /nodes/<node>/services, /nodes/<node>/network, /nodes/<node>/syslog. ${OutputNotice}`,
    parameters: Type.Object({
      path: Type.String({ description: "Absolute API path, e.g. /nodes or /nodes/pve/lxc/100/config; no /api2/json prefix or query string." }),
      options: Type.Optional(OptionsSchema),
    }),
    outputSchema: OutputSchema, annotations: ReadHints,
    async execute(_id, params, signal) { return execute(apiCommand("get", params.path, params.options), signal); },
  });

  pi.registerTool({
    name: "proxmox_lxc", label: "Manage LXC", namespace: Namespace,
    description: `Manage an LXC with pct. Every call requires user approval. Actions: start/shutdown/stop/reboot; set (options such as cores, memory, net0, onboot); resize (disk + size); snapshot/rollback/delsnapshot (name); clone (newid); create (template volume and options such as rootfs, hostname, unprivileged); destroy. Prefer unprivileged containers. VMID is source for clone and new container for create. Host and backup management use proxmox_write. ${OutputNotice}`,
    parameters: Type.Object({
      action: Type.Union(LXC_ACTIONS.map((action) => Type.Literal(action))), vmid: VmidSchema,
      options: Type.Optional(OptionsSchema),
      name: Type.Optional(Type.String({ description: "Snapshot name" })),
      disk: Type.Optional(Type.String({ description: "rootfs or mpN for resize" })),
      size: Type.Optional(Type.String({ description: "Resize size, e.g. +8G" })),
      newid: Type.Optional(VmidSchema),
      template: Type.Optional(Type.String({ description: "Template volume or archive path for create" })),
      timeout: TimeoutSchema,
    }),
    outputSchema: OutputSchema, annotations: WriteHints, executionMode: "sequential",
    async execute(_id, params, signal, _onUpdate, ctx) { return execute(lxcCommand(params), signal, params.timeout, ctx); },
  });

  pi.registerTool({
    name: "proxmox_write", label: "Proxmox API change", namespace: Namespace,
    description: `Change the Proxmox API with interactive approval of the exact command. POST maps to pvesh create, PUT to set, DELETE to delete. Supports host/service management, LXC creation/restores/cloning/config, backups, storage and networking. Backup example: POST /nodes/<node>/vzdump with options {vmid: '100', storage: 'backup', mode: 'snapshot'}. Host reboot/shutdown: POST /nodes/<node>/status with {command: 'reboot'|'shutdown'}. API creation or backup may return a UPID; use proxmox_read to poll task status/log. Never treat a UPID alone as completed work. ${OutputNotice}`,
    parameters: Type.Object({
      method: Type.Union([Type.Literal("POST"), Type.Literal("PUT"), Type.Literal("DELETE")]),
      path: Type.String(), options: Type.Optional(OptionsSchema), timeout: TimeoutSchema,
    }),
    outputSchema: OutputSchema, annotations: WriteHints, executionMode: "sequential",
    async execute(_id, params, signal, _onUpdate, ctx) {
      const method = { POST: "create", PUT: "set", DELETE: "delete" } as const;
      return execute(apiCommand(method[params.method], params.path, params.options), signal, params.timeout, ctx);
    },
  });

  pi.registerTool({
    name: "proxmox_exec", label: "Proxmox shell", namespace: Namespace,
    description: `Run a shell command on the Proxmox host, or inside an LXC via pct exec when vmid is set. ALWAYS requires interactive approval, even for diagnostics. Use for logs, systemd, packages, maintenance, or commands not covered by the API. Runs as root by default; never include passwords/tokens in commands because commands and results enter the session transcript. ${OutputNotice}`,
    parameters: Type.Object({
      command: Type.String({ minLength: 1, maxLength: 32768, description: "Readable multiline shell script. Add brief comments explaining each step; avoid compressed one-liners." }),
      explanation: Type.Optional(Type.String({ maxLength: 160, description: "Concise human-readable purpose shown above the script in the approval dialog." })),
      vmid: Type.Optional(VmidSchema), timeout: TimeoutSchema,
    }),
    outputSchema: OutputSchema, annotations: WriteHints, executionMode: "sequential",
    async execute(_id, params, signal, _onUpdate, ctx) {
      const args: (string | number)[] = params.vmid === undefined ? [] : ["pct", "exec", vmid(params.vmid), "--"];
      return execute(command([...args, "/bin/sh", "-lc", params.command]), signal, params.timeout, ctx, {
        title: params.explanation || "Review remote shell script",
        script: params.command,
        scope: params.vmid === undefined ? "Host shell" : `Container ${params.vmid} shell`,
      });
    },
  });

  pi.registerTool({
    name: "proxmox_transfer", label: "Proxmox file transfer", namespace: Namespace,
    description: "Upload/download one regular file over the configured strict-host-key SSH connection. Every transfer requires approval, including downloads of secrets. File bytes never enter tool output. SHA-256 and size verified before download publication and on the remote host before upload publication. No overwrite unless explicitly requested; destinations reject symlinks. Remote parent must exist. Missing local download parents are created mode 0700; existing parent must be private. New destination files are mode 0600. Requires remote python3. No automatic retries; interrupted uploads may have completed remotely—inspect before retrying.",
    promptSnippet: "Transfer files to/from the configured Proxmox host with approval and checksum verification.",
    promptGuidelines: ["Use proxmox_transfer for host file uploads/downloads instead of local SSH/scp or ad hoc network servers. Never read transferred secret contents into the transcript."],
    parameters: Type.Object({
      direction: Type.Union([Type.Literal("download"), Type.Literal("upload")]),
      remotePath: Type.String({ description: "Absolute remote file path, not a directory." }),
      localPath: Type.String({ description: "Local file path, relative to cwd or absolute; use a private directory for downloads." }),
      overwrite: Type.Optional(Type.Boolean({ description: "Explicit permission to replace the destination. Defaults to false." })),
      timeout: TimeoutSchema,
    }),
    outputSchema: OutputSchema, annotations: WriteHints, executionMode: "sequential",
    async execute(_id, params, signal, _onUpdate, ctx) {
      const host = sshTarget();
      const combined = signal ? AbortSignal.any([signal, lifetime.signal]) : lifetime.signal;
      combined.throwIfAborted();
      if (!ctx.hasUI) throw new Error("Proxmox file transfers require interactive approval.");
      const input = validateTransfer(params, ctx.cwd);
      const review = transferReview(input);
      const allowed = await approve(ctx, host, review, {
        title: `Review ${input.direction} file transfer`, script: review, scope: "File transfer", warning: "May contain credentials. Copies file bytes outside the transcript.", transportLabel: "Transfer plan and remote program",
      }, combined);
      if (!allowed) return present({ host, command: review, code: null, outcome: "denied", output: "" });
      combined.throwIfAborted();
      return withFileMutationQueue(input.localPath, async () => {
        const result = await transferFile(host, input, combined);
        return present(result, {}, `${host}\n${result.output}\n${outcomeText(result)}${result.transfer ? `\n${JSON.stringify(result.transfer, null, 2)}` : ""}${result.fullOutputPath ? `\nFull diagnostics: ${result.fullOutputPath}` : ""}`);
      });
    },
  });

  pi.registerCommand("proxmox", {
    description: "Configured host: /proxmox [status|lxcs|audit [sections...]|help]",
    handler: async (args, ctx) => {
      const [action = "status", ...sections] = args.trim().split(/\s+/).filter(Boolean);
      if (!["status", "lxcs", "audit", "help"].includes(action) || (action !== "audit" && sections.length) || sections.some(section => !AUDIT_SECTIONS.includes(section as AuditSection))) {
        ctx.ui.notify("Usage: /proxmox [status|lxcs|audit [system disks boot guests backups mounts recovery]|help]", "error");
        return;
      }
      try {
        if (action === "help") {
          ctx.ui.notify("/proxmox [status|lxcs|audit [sections...]|help]. Audit sections: " + AUDIT_SECTIONS.join(", ") + ". Changes and file transfers require approval. SSH target: " + sshTarget(), "info");
          return;
        }
        const result = action === "lxcs" ? await execute(command(["pct", "list"]), ctx.signal)
          : await inspect(action === "audit" ? (sections.length ? sections as AuditSection[] : [...AUDIT_SECTIONS]) : undefined, ctx.signal);
        pi.sendMessage({ customType: "proxmox-status", content: result.content, display: true, details: result.details });
        if (result.isError) ctx.ui.notify("Proxmox inspection failed; see output above.", "error");
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
      }
    },
  });
}
