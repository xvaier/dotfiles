import { getMarkdownTheme, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Markdown, Text } from "@earendil-works/pi-tui";
import { approve, fenced, visibleScript, type Review } from "./ui.ts";
import type { SSHResult } from "./core.ts";
import { Type } from "typebox";
import { apiCommand, command, LXC_ACTIONS, lxcCommand, resultText, runSSH, sshTarget, vmid } from "./core.ts";

const OptionsSchema = Type.Record(Type.String(), Type.Union([Type.String(), Type.Number(), Type.Boolean()]), {
  description: "Proxmox options without leading dashes; booleans become 1/0. Example: {cores: 2, memory: 2048, net0: 'name=eth0,bridge=vmbr0,ip=dhcp'}.",
});
const VmidSchema = Type.Integer({ minimum: 100, maximum: 999999999 });
const TimeoutSchema = Type.Optional(Type.Integer({ minimum: 1, maximum: 3600, description: "SSH timeout in seconds (default 120). Disconnecting may NOT stop a remote task." }));
const OutputSchema = Type.Object({
  host: Type.String(), command: Type.String(), code: Type.Union([Type.Number(), Type.Null()]), output: Type.String(),
  fullOutputPath: Type.Optional(Type.String()), interrupted: Type.Optional(Type.String()),
});
const Namespace = { name: "proxmox", description: "Manage the configured Proxmox host and its LXC containers over SSH." };
const ReadHints = { readOnlyHint: true, destructiveHint: false, openWorldHint: true };
const WriteHints = { readOnlyHint: false, destructiveHint: true, openWorldHint: true };
const Overview = "pveversion && uptime && free -m && df -h && pvesm status && pct list";
const OutputNotice = "Output is limited to 48 KiB / 2000 lines; larger output is saved in a private local temporary file.";

export default function (pi: ExtensionAPI) {
  let lifetime = new AbortController();
  pi.on("session_start", async () => { lifetime = new AbortController(); });
  pi.on("session_shutdown", async () => { lifetime.abort(); });

  pi.registerToolRenderer((name, next) => {
    if (!name.startsWith("proxmox_")) return next();
    return {
      renderCall(args, theme) {
        const title = args.explanation || (name === "proxmox_exec" ? "Remote shell script" : `${name.replace("proxmox_", "")} ${args.action || args.method || ""} ${args.path || ""}`.trim());
        return new Text(theme.fg("toolTitle", visibleScript(String(title))) + theme.fg("dim", args.vmid ? ` · CT ${args.vmid}` : " · Proxmox host"), 0, 0);
      },
      renderResult(result, { expanded, isPartial }, theme) {
        if (isPartial) return new Text(theme.fg("dim", "Running…"), 0, 0);
        const details = result.details as SSHResult | undefined;
        if (!details) return new Text(result.content.filter(c => c.type === "text").map(c => c.text).join("\n"), 0, 0);
        const failed = details.code !== 0 || !!details.interrupted;
        const status = details.interrupted || (failed ? `Exit ${details.code}` : "Completed · exit 0");
        const count = details.output.trimEnd().split("\n").length;
        const summary = `${status} · ${details.output ? count : 0} output lines${details.fullOutputPath ? " · output truncated" : ""}`;
        if (!expanded) return new Text(theme.fg(failed ? "error" : "success", summary) + theme.fg("dim", " · expand for output"), 0, 0);
        return new Markdown(`${summary}\n\n${fenced(details.output || "(no output)", "text")}${details.fullOutputPath ? `\n\nFull output: ${details.fullOutputPath}` : ""}${details.interrupted ? "\n\nRemote operations may still be running. Inspect before retrying." : ""}`, 0, 0, getMarkdownTheme());
      },
    };
  });

  async function execute(remoteCommand: string, signal?: AbortSignal, timeout?: number, approval?: ExtensionContext, review?: Review) {
    const host = sshTarget();
    const combinedSignal = signal ? AbortSignal.any([signal, lifetime.signal]) : lifetime.signal;
    combinedSignal.throwIfAborted();
    if (approval) {
      if (!approval.hasUI) throw new Error("Proxmox changes and shell execution require interactive approval. Non-interactive mode is read-only.");
      const allowed = await approve(approval, host, remoteCommand, review ?? {
        title: "Review Proxmox operation", script: remoteCommand, scope: "Host operation",
      }, combinedSignal);
      if (!allowed) throw new Error("Proxmox operation denied by user");
      combinedSignal.throwIfAborted();
    }
    const result = await runSSH(host, remoteCommand, combinedSignal, timeout);
    return {
      content: [{ type: "text" as const, text: resultText(result) }],
      details: result,
      structuredContent: { ...result },
      isError: result.code !== 0 || !!result.interrupted,
    };
  }

  pi.registerTool({
    name: "proxmox_overview", label: "Proxmox overview", namespace: Namespace,
    description: `Inspect the Proxmox host: version, uptime, memory, disks, storage and LXC inventory. No changes. ${OutputNotice}`,
    promptSnippet: "Inspect the configured Proxmox host health and LXC inventory over SSH.",
    promptGuidelines: [
      "Use the proxmox tools for the configured host rather than local bash/SSH. Never bypass an approval denial with another tool.",
      "Inspect before changing Proxmox or LXCs. Prefer graceful shutdown over stop. Confirm target VMIDs and backup status before destructive changes.",
      "Proxmox API mutations may return a UPID (task ID), not completed work. Poll /nodes/<node>/tasks/<UPID>/status and /log with proxmox_read; only exitstatus OK proves task success.",
      "After a timeout, cancellation or SSH disconnect, inspect remote state before retrying any mutation. Never automatically retry mutations.",
      "For proxmox_exec, supply a concise explanation and readable multiline shell with brief comments explaining each step. Avoid code-golfed one-liners. The approval already displays the script: do not duplicate it in a long preamble.",
    ],
    parameters: Type.Object({}), outputSchema: OutputSchema, annotations: ReadHints,
    async execute(_id, _params, signal) { return execute(Overview, signal); },
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

  pi.registerCommand("proxmox", {
    description: "Configured Proxmox host: /proxmox [status|lxcs|help]",
    handler: async (args, ctx) => {
      const action = args.trim() || "status";
      if (action !== "status" && action !== "lxcs" && action !== "help") {
        ctx.ui.notify("Usage: /proxmox [status|lxcs|help]", "error");
        return;
      }
      try {
        if (action === "help") {
          ctx.ui.notify("/proxmox [status|lxcs|help]. Inspect the configured host, manage an LXC, take a backup, or run maintenance. All changes require approval. SSH target: " + sshTarget(), "info");
          return;
        }
        const result = await execute(action === "lxcs" ? command(["pct", "list"]) : Overview, ctx.signal);
        pi.sendMessage({ customType: "proxmox-status", content: result.content, display: true, details: result.details });
        if (result.isError) ctx.ui.notify("Proxmox inspection failed; see output above.", "error");
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
      }
    },
  });
}
