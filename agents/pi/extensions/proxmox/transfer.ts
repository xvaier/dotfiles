import { constants, createReadStream, createWriteStream, existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, linkSync, renameSync, rmSync, statSync } from "node:fs";
import { open } from "node:fs/promises";
import { pipeline } from "node:stream/promises";
import { createHash } from "node:crypto";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { command, runSSH, type SSHResult } from "./core.ts";

const script = readFileSync(new URL("./transfer.py", import.meta.url), "utf8");
export interface TransferInput {
  direction: "download" | "upload";
  remotePath: string;
  localPath: string;
  overwrite?: boolean;
  timeout?: number;
}
export interface TransferResult extends SSHResult {
  transfer?: { direction: "download" | "upload"; localPath: string; remotePath: string; size: number; sha256: string; verified: boolean };
}

export function validateTransfer(input: TransferInput, cwd: string): TransferInput {
  if (!["download", "upload"].includes(input.direction)) throw new Error("Invalid transfer direction");
  if (!isAbsolute(input.remotePath) || input.remotePath.includes("\0") || input.remotePath.endsWith("/")) {
    throw new Error("remotePath must be an absolute file path without NUL bytes or a trailing slash");
  }
  if (!input.localPath || input.localPath.includes("\0")) throw new Error("localPath must name a file");
  const localPath = resolve(cwd, input.localPath.replace(/^@/, ""));
  if (input.direction === "upload") {
    if (!lstatSync(localPath).isFile()) throw new Error("Upload source must be a regular, non-symlink file");
  } else if (existsSync(localPath) || isSymlink(localPath)) {
    if (!lstatSync(localPath).isFile()) throw new Error("Download destination must not be a symlink or non-regular file");
    if (!input.overwrite) throw new Error("Local destination exists; explicit overwrite approval is required");
  }
  return { ...input, localPath };
}

function isSymlink(path: string): boolean {
  try { return lstatSync(path).isSymbolicLink(); } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return false;
    throw error;
  }
}

async function checksum(path: string, signal?: AbortSignal): Promise<string> {
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(path, { signal })) hash.update(chunk);
  return hash.digest("hex");
}

export function transferReview(input: TransferInput): string {
  return `${input.direction === "download" ? "Download from" : "Upload to"} configured Proxmox host\nRemote file: ${input.remotePath}\nLocal file: ${input.localPath}\nOverwrite destination: ${input.overwrite ? "YES" : "NO"}\n\nTransport: SSH with strict host-key verification; remote python3 required.\nFile bytes stream outside the transcript; SHA-256 is checked before publication.\nNew files have mode 0600. Remote parent must exist; local download parent must be private.\n\nRemote transfer program:\n${script}`;
}

export async function transferFile(host: string, input: TransferInput, signal?: AbortSignal): Promise<TransferResult> {
  signal?.throwIfAborted();
  // Revalidate after approval, including when the user changed a path while reviewing.
  input = validateTransfer(input, "/");
  let directory: string;
  if (input.direction === "download") {
    const parent = dirname(input.localPath);
    mkdirSync(parent, { recursive: true, mode: 0o700 });
    if ((statSync(parent).mode & 0o077) !== 0) throw new Error("Download directory must be private (mode 0700); choose a private folder");
    directory = mkdtempSync(join(realpathSync(parent), ".pi-proxmox-transfer-"));
  } else {
    directory = mkdtempSync(join(tmpdir(), "pi-proxmox-transfer-"));
  }
  const staged = join(directory, "file");
  try {
    let expected = "";
    if (input.direction === "upload") {
      const source = await open(input.localPath, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
      try {
        if (!(await source.stat()).isFile()) throw new Error("Upload source must be a regular file");
        await pipeline(source.createReadStream({ autoClose: false }), createWriteStream(staged, { flags: "wx", mode: 0o600 }), { signal });
      } finally {
        await source.close();
      }
      expected = await checksum(staged, signal);
    }
    const remoteCommand = command(["python3", "-c", script, input.direction, input.remotePath, String(input.overwrite ?? false), expected]);
    const result = await runSSH(host, remoteCommand, signal, input.timeout, input.direction === "download" ? { outputPath: staged } : { inputPath: staged });
    // Diagnostics can contain remote filenames; file contents never go through this channel.
    if (result.outcome !== "completed") return result;
    let metadata: { size: number; sha256: string };
    try {
      metadata = JSON.parse(result.output.trim());
      if (!Number.isSafeInteger(metadata.size) || metadata.size < 0 || !/^[a-f0-9]{64}$/.test(metadata.sha256)) throw new Error();
    } catch {
      return { ...result, outcome: "transport_error", output: "Invalid transfer receipt; destination publication not confirmed." };
    }
    const localHash = input.direction === "download" ? await checksum(staged, signal) : expected;
    const transfer = { direction: input.direction, remotePath: input.remotePath, localPath: input.localPath, ...metadata, verified: false };
    if (localHash !== metadata.sha256 || statSync(staged).size !== metadata.size) {
      return { ...result, outcome: "verification_failed", output: "Checksum/size mismatch; transfer not verified.", transfer };
    }
    signal?.throwIfAborted();
    if (input.direction === "download") {
      // Recheck symlinks immediately before publishing. linkSync provides atomic no-clobber behaviour.
      validateTransfer(input, "/");
      if (input.overwrite) renameSync(staged, input.localPath);
      else linkSync(staged, input.localPath);
    }
    return { ...result, output: "File transferred; SHA-256 and byte count verified. File contents were not logged.", transfer: { ...transfer, verified: true } };
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}
