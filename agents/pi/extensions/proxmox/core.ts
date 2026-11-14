import { spawn } from "node:child_process";
import { closeSync, ftruncateSync, mkdtempSync, openSync, readFileSync, readSync, rmSync, statSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";

const MAX_BYTES = 48 * 1024;
const MAX_LINES = 2000;
export type Options = Record<string, string | number | boolean>;

export function quote(value: string): string {
  if (value.includes("\0")) throw new Error("NUL bytes are not allowed in commands");
  return `'${value.replaceAll("'", `'"'"'`)}'`;
}

export function command(args: (string | number)[]): string {
  return args.map((arg) => quote(String(arg))).join(" ");
}

export function optionArgs(options: Options = {}): string[] {
  return Object.entries(options).flatMap(([key, value]) => {
    if (!/^[a-z][a-z0-9-]*$/.test(key) || key === "output-format") {
      throw new Error(`Invalid or reserved option: ${key}`);
    }
    if (!["string", "number", "boolean"].includes(typeof value)) throw new Error(`Invalid value for ${key}`);
    return [`--${key}`, typeof value === "boolean" ? (value ? "1" : "0") : String(value)];
  });
}

export function apiCommand(method: "get" | "create" | "set" | "delete", path: string, options?: Options): string {
  if (!/^\/[A-Za-z0-9_:.%@+-]+(?:\/[A-Za-z0-9_:.%@+-]+)*$/.test(path) || path.includes("..")) {
    throw new Error("Use an absolute Proxmox API path, without a query string or traversal segments");
  }
  return command(["pvesh", method, path, ...optionArgs(options), "--output-format", "json"]);
}

export function vmid(value: number): number {
  if (!Number.isSafeInteger(value) || value < 100 || value > 999999999) throw new Error("VMID must be an integer between 100 and 999999999");
  return value;
}

export type LxcAction = "start" | "shutdown" | "stop" | "reboot" | "set" | "resize" | "snapshot" | "rollback" | "delsnapshot" | "clone" | "create" | "destroy";
export const LXC_ACTIONS: LxcAction[] = ["start", "shutdown", "stop", "reboot", "set", "resize", "snapshot", "rollback", "delsnapshot", "clone", "create", "destroy"];
export interface LxcInput {
  action: LxcAction;
  vmid: number;
  options?: Options;
  name?: string;
  disk?: string;
  size?: string;
  newid?: number;
  template?: string;
}

export function lxcCommand(input: LxcInput): string {
  const { action, options, name, disk, size, newid, template } = input;
  if (!LXC_ACTIONS.includes(action)) throw new Error("Unknown LXC action");
  const args: (string | number)[] = ["pct", action, vmid(input.vmid)];
  if (["snapshot", "rollback", "delsnapshot"].includes(action)) {
    if (!name || !/^[A-Za-z][A-Za-z0-9_-]{0,39}$/.test(name) || name === "current") throw new Error("A valid snapshot name is required (not 'current')");
    args.push(name);
  }
  if (action === "resize") {
    if (!disk || !/^(rootfs|mp\d+)$/.test(disk) || !size || !/^\+?\d+(?:\.\d+)?[KMGT]?$/.test(size)) throw new Error("resize requires disk (rootfs/mpN) and size (e.g. +8G)");
    args.push(disk, size);
  }
  if (action === "clone") {
    if (newid === undefined || vmid(newid) === input.vmid) throw new Error("clone requires a different newid");
    args.push(newid);
  }
  if (action === "create") {
    if (!template || template.startsWith("-") || !template.trim()) throw new Error("create requires a template volume or archive path");
    args.push(template);
  }
  if (action === "set" && !Object.keys(options ?? {}).length) throw new Error("set requires at least one option");
  return command([...args, ...optionArgs(options)]);
}

export function sshTarget(configPath = join(process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi/agent"), "proxmox.local.json")): string {
  let host: unknown = process.env.PROXMOX_SSH_HOST;
  if (!host) {
    try {
      host = JSON.parse(readFileSync(configPath, "utf8")).sshTarget;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
        throw new Error("Cannot read Proxmox configuration; check proxmox.local.json.");
      }
    }
  }
  if (!host) throw new Error("Proxmox target not configured. Set PROXMOX_SSH_HOST or sshTarget in ~/.pi/agent/proxmox.local.json.");
  if (typeof host !== "string" || host.startsWith("-") || !/^[A-Za-z0-9_@.:[\]-]+$/.test(host)) throw new Error("Invalid Proxmox SSH target");
  return host;
}

export type Outcome = "completed" | "command_failed" | "transport_error" | "timed_out" | "cancelled" | "denied" | "verification_failed";
export interface SSHResult {
  host: string;
  command: string;
  code: number | null;
  outcome: Outcome;
  remoteExitCode?: number;
  output: string;
  fullOutputPath?: string;
  interrupted?: string;
}

export const SSH_OPTIONS = ["-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
  "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=2"];

export interface SSHStreams {
  inputPath?: string;
  outputPath?: string;
}

export function outcomeText(result: SSHResult): string {
  switch (result.outcome) {
    case "denied": return "Approval denied; nothing executed.";
    case "completed": return "Completed · exit 0";
    case "verification_failed": return "Verification failed; operation is not confirmed successful. Inspect the destination before another mutation.";
    case "command_failed": return `Remote command failed · exit ${result.remoteExitCode ?? result.code}. Earlier steps may have completed; inspect before another mutation.`;
    case "transport_error": return "SSH transport/protocol failed; remote completion is unknown. Inspect remote state before another mutation.";
    case "timed_out":
    case "cancelled": return `${result.interrupted}. Remote operations may still be running. Inspect status before another mutation.`;
  }
}

// Stream directly to a private file: logs cannot grow the Pi process's memory.
export async function runSSH(host: string, remoteCommand: string, signal?: AbortSignal, timeoutSeconds = 120, streams: SSHStreams = {}): Promise<SSHResult> {
  signal?.throwIfAborted();
  if (!Number.isFinite(timeoutSeconds) || timeoutSeconds < 1 || timeoutSeconds > 3600) throw new Error("Timeout must be between 1 and 3600 seconds");
  const directory = mkdtempSync(join(tmpdir(), "pi-proxmox-"));
  const outputPath = join(directory, "output.txt");
  const fd = openSync(outputPath, "wx+", 0o600);
  const descriptors: number[] = [fd];
  const marker = `PI_PROXMOX_EXIT_${randomUUID()}:`;
  // A completion marker distinguishes remote exit 255 from SSH failure, even with binary stdout.
  const transportCommand = `${command(["/bin/sh", "-c", remoteCommand])}; _pi_status=$?; printf '\\n${marker}%s\\n' "$_pi_status" >&2; exit "$_pi_status"`;
  try {
    const input = streams.inputPath ? openSync(streams.inputPath, "r") : "ignore";
    if (typeof input === "number") descriptors.push(input);
    const stdout = streams.outputPath ? openSync(streams.outputPath, "wx", 0o600) : fd;
    if (stdout !== fd) descriptors.push(stdout);
    const result = await new Promise<{ code: number | null; interrupted?: string }>((resolve, reject) => {
      const child = spawn("ssh", [...SSH_OPTIONS, "--", host, transportCommand], { stdio: [input, stdout, fd] });
      let interrupted: string | undefined;
      let killTimer: ReturnType<typeof setTimeout> | undefined;
      const stop = (reason: string) => {
        if (interrupted) return;
        interrupted = reason;
        child.kill("SIGTERM");
        killTimer = setTimeout(() => child.kill("SIGKILL"), 1000);
      };
      const onAbort = () => stop("Cancelled");
      const timer = setTimeout(() => stop(`Timed out after ${timeoutSeconds}s`), timeoutSeconds * 1000);
      const cleanup = () => {
        clearTimeout(timer);
        if (killTimer) clearTimeout(killTimer);
        signal?.removeEventListener("abort", onAbort);
      };
      signal?.addEventListener("abort", onAbort, { once: true });
      if (signal?.aborted) onAbort();
      child.once("error", (error) => { cleanup(); reject(error); });
      child.once("close", (code) => { cleanup(); resolve({ code, interrupted }); });
    });
    let size = statSync(outputPath).size;
    const tail = Buffer.alloc(Math.min(size, 256));
    readSync(fd, tail, 0, tail.length, size - tail.length);
    const match = tail.toString("utf8").match(new RegExp(`\\n${marker}(\\d+)\\n$`));
    const remoteExitCode = match ? Number(match[1]) : undefined;
    if (match) {
      size -= Buffer.byteLength(match[0]);
      ftruncateSync(fd, size);
    }
    const outcome: Outcome = result.interrupted
      ? (result.interrupted === "Cancelled" ? "cancelled" : "timed_out")
      : remoteExitCode === undefined || remoteExitCode !== result.code ? "transport_error"
      : remoteExitCode === 0 ? "completed" : "command_failed";
    const preview = Buffer.alloc(Math.min(size, MAX_BYTES));
    const reader = openSync(outputPath, "r");
    try { readSync(reader, preview, 0, preview.length, 0); } finally { closeSync(reader); }
    const lines = preview.toString("utf8").split("\n");
    const truncated = size > MAX_BYTES || lines.length > MAX_LINES;
    const output = lines.slice(0, MAX_LINES).join("\n");
    if (!truncated) rmSync(directory, { recursive: true, force: true });
    return { host, command: remoteCommand, ...result, outcome, ...(remoteExitCode === undefined ? {} : { remoteExitCode }), output, ...(truncated ? { fullOutputPath: outputPath } : {}) };
  } catch (error) {
    rmSync(directory, { recursive: true, force: true });
    throw error;
  } finally {
    for (const descriptor of descriptors) closeSync(descriptor);
  }
}

export function resultText(result: SSHResult): string {
  let text = `${result.host}\n$ ${result.command}\n\n${result.output || "(no output)"}`;
  if (result.fullOutputPath) text += `\n\n[Output truncated to 48 KiB / 2000 lines. Full output: ${result.fullOutputPath}]`;
  if (result.outcome !== "completed") text += `\n\n${outcomeText(result)}`;
  return text;
}
