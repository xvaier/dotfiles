// Run: node --test ~/.dotfiles/agents/pi/tests/proxmox.test.mts (Node 22.18+).
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, symlinkSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { homedir, tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { after, test } from "node:test";
import { apiCommand, command, lxcCommand, optionArgs, resultText, runSSH, sshTarget } from "../extensions/proxmox/core.ts";
import { auditCommand, auditResult } from "../extensions/proxmox/audit.ts";
import { transferFile, validateTransfer } from "../extensions/proxmox/transfer.ts";

const directory = mkdtempSync(join(tmpdir(), "pi-proxmox-test-"));
const log = join(directory, "ssh.jsonl");
const oldPath = process.env.PATH;
const oldHost = process.env.PROXMOX_SSH_HOST;
process.env.PATH = `${directory}:${oldPath}`;
process.env.TEST_PROXMOX_LOG = log;
process.env.PROXMOX_SSH_HOST = "root@pve.example.test";

// Stand-in SSH transport: real child process + shell/argv parsing, no network or server changes.
writeFileSync(join(directory, "ssh"), `#!${process.execPath}
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.TEST_PROXMOX_LOG, JSON.stringify(args) + '\\n');
const mode = process.env.TEST_PROXMOX_MODE;
if (mode === 'wait') { setInterval(() => {}, 1000); }
else if (mode === 'large') { process.stdout.write('x'.repeat(200000)); }
else if (mode === 'lines') { process.stdout.write('line\\n'.repeat(2500)); }
else if (mode === 'fail') { process.stderr.write('transport failed\\n'); process.exitCode = 255; }
else if (mode === 'corrupt-download') {
  const result = spawnSync('/bin/sh', ['-c', args.at(-1)], { stdio: ['inherit', 'pipe', 'inherit'] });
  process.stdout.write(Buffer.concat([result.stdout || Buffer.alloc(0), Buffer.from('corruption')]));
  process.exitCode = result.status ?? 1;
}
else {
  const result = spawnSync('/bin/sh', ['-c', args.at(-1)], { stdio: 'inherit' });
  process.exitCode = result.status ?? 1;
}
`, { mode: 0o700 });
for (const program of ["pct", "qm", "pvesh", "pveversion", "uptime", "free", "df", "pvesm"]) {
  writeFileSync(join(directory, program), `#!${process.execPath}
const args = process.argv.slice(2);
const fixtures = JSON.parse(process.env.TEST_PROXMOX_API_FIXTURES || '{}');
if (${JSON.stringify(program)} === 'pvesh' && Object.hasOwn(fixtures, args[1])) console.log(JSON.stringify(fixtures[args[1]]));
else console.log(JSON.stringify({program: ${JSON.stringify(program)}, args}));
`, { mode: 0o700 });
}
for (const program of ["lsblk", "efibootmgr", "mokutil", "proxmox-boot-tool", "systemctl", "smartctl", "lvs", "zpool"]) {
  writeFileSync(join(directory, program), "#!/bin/sh\nexit 127\n", { mode: 0o700 });
}
after(() => {
  process.env.PATH = oldPath;
  if (oldHost === undefined) delete process.env.PROXMOX_SSH_HOST; else process.env.PROXMOX_SSH_HOST = oldHost;
  delete process.env.TEST_PROXMOX_LOG;
  delete process.env.TEST_PROXMOX_MODE;
  rmSync(directory, { recursive: true, force: true });
});
const callCount = () => existsSync(log) ? readFileSync(log, "utf8").trim().split("\n").length : 0;

const install = join(homedir(), ".pi/agent/install");
const modules = process.env.PI_NODE_MODULES || join(install, "releases", readFileSync(join(install, "current-version"), "utf8").trim(), "node_modules");
const { loadExtensions } = await import(pathToFileURL(join(modules, "@earendil-works/pi-coding-agent/dist/core/extensions/loader.js")).href);
const loaded = await loadExtensions([resolve(import.meta.dirname, "../extensions/proxmox/index.ts")], directory);
assert.deepEqual(loaded.errors, []);
const extension = loaded.extensions[0];
const themeModule = await import(pathToFileURL(join(modules, "@earendil-works/pi-coding-agent/dist/modes/interactive/theme/theme.js")).href);
themeModule.initTheme("dark", false);
const { visibleWidth } = await import(pathToFileURL(join(modules, "@earendil-works/pi-tui/dist/index.js")).href);
const tool = (name: string) => extension.tools.get(name)!.definition;
const invoke = (name: string, params: unknown, ctx: unknown = { hasUI: false }, signal?: AbortSignal) => tool(name).execute("test", params, signal, undefined, ctx);

test("real Pi loader registers six tools and /proxmox without connecting", () => {
  assert.equal(extension.tools.size, 6);
  assert.ok(extension.commands.has("proxmox"));
  assert.equal(callCount(), 0);
  for (const { definition } of extension.tools.values()) assert.ok(definition.outputSchema);
});

test("shell quoting preserves metacharacters, quotes and newlines as data", () => {
  const payload = `hello ' world; $(touch ${directory}/injected)\n\"double\"`;
  assert.equal(execFileSync("/bin/sh", ["-c", command(["printf", "%s", payload])], { encoding: "utf8" }), payload);
  assert.equal(existsSync(join(directory, "injected")), false);
  assert.throws(() => command(["bad\0value"]), /NUL/);
  assert.throws(() => optionArgs({ "--evil": true }), /Invalid/);
  assert.throws(() => optionArgs({ "output-format": "yaml" }), /reserved/);
  assert.deepEqual(optionArgs({ onboot: true, memory: 1024, net0: "name=eth0,ip=dhcp" }), ["--onboot", "1", "--memory", "1024", "--net0", "name=eth0,ip=dhcp"]);
});

test("LXC positional arguments and API paths are validated", () => {
  assert.match(lxcCommand({ action: "clone", vmid: 100, newid: 101 }), /'pct' 'clone' '100' '101'/);
  assert.match(lxcCommand({ action: "resize", vmid: 100, disk: "rootfs", size: "+8G" }), /'rootfs' '\+8G'/);
  assert.match(lxcCommand({ action: "snapshot", vmid: 100, name: "before-update" }), /'before-update'/);
  assert.match(lxcCommand({ action: "create", vmid: 101, template: "local:vztmpl/debian.tar.zst", options: { unprivileged: true } }), /'--unprivileged' '1'/);
  assert.throws(() => lxcCommand({ action: "clone", vmid: 100, newid: 100 }), /different/);
  assert.throws(() => lxcCommand({ action: "start", vmid: 1 }), /VMID/);
  assert.throws(() => lxcCommand({ action: "create", vmid: 100 }), /template/);
  assert.throws(() => lxcCommand({ action: "set", vmid: 100 }), /option/);
  assert.throws(() => lxcCommand({ action: "rollback", vmid: 100, name: "current" }), /snapshot/);
  assert.throws(() => apiCommand("get", "/nodes/../status"), /path/);
  assert.throws(() => apiCommand("get", "/nodes?command=reboot"), /path/);
  assert.match(apiCommand("get", "/nodes/pve/tasks/UPID:pve:123:status:/status"), /'pvesh' 'get'/);
  process.env.PROXMOX_SSH_HOST = "-oProxyCommand=evil";
  assert.throws(() => sshTarget(), /Invalid/);
  delete process.env.PROXMOX_SSH_HOST;
  const config = join(directory, "proxmox.local.json");
  assert.throws(() => sshTarget(config), /not configured/);
  writeFileSync(config, JSON.stringify({ sshTarget: "root@pve.example.test" }));
  assert.equal(sshTarget(config), "root@pve.example.test");
  process.env.PROXMOX_SSH_HOST = "root@override.example.test";
  assert.equal(sshTarget(config), "root@override.example.test");
  delete process.env.PROXMOX_SSH_HOST;
  writeFileSync(config, "invalid JSON");
  assert.throws(() => sshTarget(config), /Cannot read/);
  writeFileSync(config, JSON.stringify({ sshTarget: "-oProxyCommand=evil" }));
  assert.throws(() => sshTarget(config), /Invalid/);
  process.env.PROXMOX_SSH_HOST = "root@pve.example.test";
});

test("read tools execute over SSH with strict host keys and correct option boundaries", async () => {
  const read = await invoke("proxmox_read", { path: "/cluster/resources", options: { type: "lxc" } });
  assert.equal(read.isError, false);
  assert.deepEqual(JSON.parse(read.details.output), { program: "pvesh", args: ["get", "/cluster/resources", "--type", "lxc", "--output-format", "json"] });
  const sshArgs = JSON.parse(readFileSync(log, "utf8").trim().split("\n").at(-1)!);
  assert.ok(sshArgs.includes("BatchMode=yes"));
  assert.ok(sshArgs.includes("StrictHostKeyChecking=yes"));
  assert.deepEqual(sshArgs.slice(-3, -1), ["--", "root@pve.example.test"]);
  const overview = await invoke("proxmox_overview", {});
  assert.equal(overview.isError, false);
  assert.match(overview.details.output, /pveversion/);
  assert.match(overview.details.output, /pct/);
});

test("all mutation tools fail closed without UI or when declined", async () => {
  const count = callCount();
  for (const [name, params] of [
    ["proxmox_lxc", { action: "destroy", vmid: 100 }],
    ["proxmox_write", { method: "POST", path: "/nodes/pve/status", options: { command: "reboot" } }],
    ["proxmox_exec", { command: "echo hello" }],
  ] as const) {
    await assert.rejects(invoke(name, params), /interactive approval/);
    const denied = await invoke(name, params, { hasUI: true, ui: { confirm: async () => false } });
    assert.equal(denied.isError, true);
    assert.equal(denied.details.outcome, "denied");
    assert.match(denied.content[0].text, /nothing executed/);
  }
  assert.equal(callCount(), count);
});

test("approved lifecycle, API and container shell calls run exact reviewed commands", async () => {
  let preview = "";
  const ctx = { hasUI: true, ui: { confirm: async (_title: string, message: string) => { preview = message; return true; } } };
  const started = await invoke("proxmox_lxc", { action: "start", vmid: 100 }, ctx);
  assert.equal(started.isError, false);
  assert.ok(preview.includes(JSON.stringify(started.details.command)));
  assert.deepEqual(JSON.parse(started.details.output).args, ["start", "100"]);
  const backup = await invoke("proxmox_write", { method: "POST", path: "/nodes/pve/vzdump", options: { vmid: "100", storage: "backup", mode: "snapshot" } }, ctx);
  assert.deepEqual(JSON.parse(backup.details.output).args, ["create", "/nodes/pve/vzdump", "--vmid", "100", "--storage", "backup", "--mode", "snapshot", "--output-format", "json"]);
  const inside = await invoke("proxmox_exec", { vmid: 100, command: "printf '%s' 'quoted; $(nope)'" }, ctx);
  assert.deepEqual(JSON.parse(inside.details.output).args, ["exec", "100", "--", "/bin/sh", "-lc", "printf '%s' 'quoted; $(nope)'"]);
});

test("TUI approval highlights the original script, scrolls, exposes transport and rejects safely", async () => {
  const script = "# Explain the command\nprintf '%s' 'hello'\n" + "# More context\n".repeat(40);
  let reviewed = "";
  const count = callCount();
  const ctx = { hasUI: true, mode: "tui", ui: {
    custom: async (factory: Function) => new Promise(resolve => {
      const view = factory({ requestRender() {} }, themeModule.theme, {}, resolve);
      for (const width of [28, 80, 120]) {
        const lines = view.render(width);
        assert.ok(lines.every((line: string) => visibleWidth(line) <= width));
        assert.ok(lines.length <= 23);
        assert.match(lines.join("\n"), /\u001b\[/);
      }
      reviewed = view.render(120).join("\n");
      view.handleInput("x");
      assert.match(view.render(120).join("\n"), /Exact SSH command/);
      view.handleInput("x");
      view.handleInput("\u001b[B");
      view.invalidate();
      view.handleInput("n");
    }),
  } };
  assert.equal((await invoke("proxmox_exec", { command: script, explanation: "Explain and print" }, ctx)).details.outcome, "denied");
  assert.match(reviewed, /Explain and print/);
  assert.match(reviewed, /Explain the command/);
  assert.equal(callCount(), count);
});

test("cancellation during approval cannot launch a command", async () => {
  const controller = new AbortController();
  const count = callCount();
  await assert.rejects(invoke("proxmox_lxc", { action: "stop", vmid: 100 }, {
    hasUI: true,
    ui: { confirm: async (_title: string, _message: string, options: { signal: AbortSignal }) => {
      assert.equal(options.signal.aborted, false);
      controller.abort();
      assert.equal(options.signal.aborted, true);
      return true;
    } },
  }, controller.signal));
  assert.equal(callCount(), count);
});

test("session shutdown cancels active SSH work and next session can inspect again", async () => {
  process.env.TEST_PROXMOX_MODE = "wait";
  try {
    const pending = invoke("proxmox_overview", {});
    await new Promise((resolve) => setTimeout(resolve, 100));
    for (const handler of extension.handlers.get("session_shutdown")!) await handler({}, {});
    const result = await pending;
    assert.equal(result.isError, true);
    assert.equal(result.details.interrupted, "Cancelled");
  } finally {
    delete process.env.TEST_PROXMOX_MODE;
    for (const handler of extension.handlers.get("session_start")!) await handler({}, {});
  }
  assert.equal((await invoke("proxmox_read", { path: "/nodes" })).isError, false);
});

test("transport failures produce tool errors with stderr", async () => {
  process.env.TEST_PROXMOX_MODE = "fail";
  try {
    const result = await invoke("proxmox_overview", {});
    assert.equal(result.isError, true);
    assert.equal(result.details.code, 255);
    assert.equal(result.details.outcome, "transport_error");
    assert.match(result.content[0].text, /transport failed/);
  } finally { delete process.env.TEST_PROXMOX_MODE; }
});

test("large byte and line output is bounded with complete private output on disk", async () => {
  for (const [mode, bytes] of [["large", 200000], ["lines", 12500]] as const) {
    process.env.TEST_PROXMOX_MODE = mode;
    let outputPath: string | undefined;
    try {
      const result = await runSSH("root@pve.example.test", "ignored");
      outputPath = result.fullOutputPath;
      assert.ok(outputPath);
      assert.equal(statSync(outputPath).size, bytes);
      assert.equal(statSync(outputPath).mode & 0o777, 0o600);
      assert.equal(statSync(dirname(outputPath)).mode & 0o777, 0o700);
      assert.ok(Buffer.byteLength(result.output) <= 48 * 1024);
      assert.ok(result.output.split("\n").length <= 2000);
      assert.match(resultText(result), /Full output:/);
    } finally {
      if (outputPath) rmSync(dirname(outputPath), { recursive: true, force: true });
      delete process.env.TEST_PROXMOX_MODE;
    }
  }
});

test("timeout and cancellation terminate the SSH process and warn about remote state", async () => {
  process.env.TEST_PROXMOX_MODE = "wait";
  try {
    const timed = await runSSH("root@pve.example.test", "ignored", undefined, 1);
    assert.match(timed.interrupted!, /Timed out/);
    assert.equal(timed.outcome, "timed_out");
    assert.match(resultText(timed), /may still be running/);
    const controller = new AbortController();
    const pending = runSSH("root@pve.example.test", "ignored", controller.signal);
    setTimeout(() => controller.abort(), 100);
    const cancelled = await pending;
    assert.equal(cancelled.interrupted, "Cancelled");
    assert.equal(cancelled.outcome, "cancelled");
    const count = callCount();
    await assert.rejects(runSSH("root@pve.example.test", "ignored", controller.signal));
    assert.equal(callCount(), count);
  } finally { delete process.env.TEST_PROXMOX_MODE; }
});

test("remote command failures, including exit 255, are not labelled connection loss", async () => {
  for (const code of [1, 127, 255]) {
    const result = await runSSH("root@pve.example.test", `printf 'step one completed\\n'; exit ${code}`);
    assert.equal(result.outcome, "command_failed");
    assert.equal(result.remoteExitCode, code);
    assert.equal(result.code, code);
    assert.equal(result.output, "step one completed\n");
    assert.match(resultText(result), /Earlier steps may have completed/);
    assert.doesNotMatch(resultText(result), /lost connection|completion is unknown/);
    assert.doesNotMatch(result.output, /PI_PROXMOX_EXIT/);
  }
});

const transferContext = { cwd: directory, hasUI: true, ui: { confirm: async () => true } };

test("transfer approval is required before connecting or creating a destination", async () => {
  const localPath = join(directory, "denied-download", "file");
  const params = { direction: "download", remotePath: "/private/source", localPath };
  const count = callCount();
  await assert.rejects(invoke("proxmox_transfer", params), /interactive approval/);
  const denied = await invoke("proxmox_transfer", params, { ...transferContext, ui: { confirm: async () => false } });
  assert.equal(denied.details.outcome, "denied");
  assert.equal(callCount(), count);
  assert.equal(existsSync(dirname(localPath)), false);
});

test("binary downloads are checksum verified, private, and absent from tool output", async () => {
  const source = join(directory, "remote ' ; $(touch injected) source.bin");
  const bytes = Buffer.concat([Buffer.from("SECRET_FILE_BYTES"), Buffer.from(Array.from({ length: 256 * 4096 }, (_, i) => i % 256))]);
  writeFileSync(source, bytes);
  const localPath = join(directory, "private-download", "file.bin");
  const result = await invoke("proxmox_transfer", { direction: "download", remotePath: source, localPath }, transferContext);
  assert.equal(result.isError, false);
  assert.equal(result.details.transfer.verified, true);
  assert.equal(result.details.transfer.sha256, createHash("sha256").update(bytes).digest("hex"));
  assert.deepEqual(readFileSync(localPath), bytes);
  assert.equal(statSync(localPath).mode & 0o777, 0o600);
  assert.equal(statSync(dirname(localPath)).mode & 0o777, 0o700);
  assert.doesNotMatch(JSON.stringify(result), /SECRET_FILE_BYTES/);
  assert.deepEqual(readdirSync(dirname(localPath)), ["file.bin"]);
  assert.equal(existsSync(join(directory, "injected")), false);
});

test("downloads refuse overwrite, symlinks and public directories; explicit overwrite is atomic", async () => {
  const source = join(directory, "overwrite-source");
  const destination = join(directory, "overwrite-destination");
  writeFileSync(source, "new bytes");
  writeFileSync(destination, "old bytes");
  await assert.rejects(invoke("proxmox_transfer", { direction: "download", remotePath: source, localPath: destination }, transferContext), /overwrite/);
  assert.equal(readFileSync(destination, "utf8"), "old bytes");
  const replaced = await invoke("proxmox_transfer", { direction: "download", remotePath: source, localPath: destination, overwrite: true }, transferContext);
  assert.equal(replaced.isError, false);
  assert.equal(readFileSync(destination, "utf8"), "new bytes");
  const symlink = join(directory, "destination-link");
  symlinkSync(destination, symlink);
  assert.throws(() => validateTransfer({ direction: "download", remotePath: source, localPath: symlink, overwrite: true }, directory), /symlink/);
  const publicDirectory = join(directory, "public-download");
  mkdirSync(publicDirectory);
  chmodSync(publicDirectory, 0o755);
  await assert.rejects(transferFile("root@pve.example.test", { direction: "download", remotePath: source, localPath: join(publicDirectory, "file") }), /private/);
  const failed = await invoke("proxmox_transfer", { direction: "download", remotePath: symlink, localPath: join(directory, "symlink-source-download") }, transferContext);
  assert.equal(failed.isError, true);
  assert.equal(existsSync(join(directory, "symlink-source-download")), false);
});

test("uploads verify bytes before publication and never overwrite without approval", async () => {
  const localPath = join(directory, "upload-source");
  const remotePath = join(directory, "remote ' upload.bin");
  const bytes = Buffer.from("SECRET_UPLOAD_BYTES\u0000\u00ff");
  writeFileSync(localPath, bytes);
  let preview = "";
  const ctx = { ...transferContext, ui: { confirm: async (_title: string, text: string) => { preview = text; return true; } } };
  const uploaded = await invoke("proxmox_transfer", { direction: "upload", remotePath, localPath }, ctx);
  assert.equal(uploaded.isError, false);
  assert.deepEqual(readFileSync(remotePath), bytes);
  assert.equal(statSync(remotePath).mode & 0o777, 0o600);
  assert.match(preview, /Overwrite destination: NO/);
  assert.match(preview, /Remote transfer program/);
  assert.doesNotMatch(JSON.stringify(uploaded), /SECRET_UPLOAD_BYTES/);
  writeFileSync(localPath, "replacement");
  const refused = await invoke("proxmox_transfer", { direction: "upload", remotePath, localPath }, ctx);
  assert.equal(refused.details.outcome, "command_failed");
  assert.deepEqual(readFileSync(remotePath), bytes);
  const replaced = await invoke("proxmox_transfer", { direction: "upload", remotePath, localPath, overwrite: true }, ctx);
  assert.equal(replaced.isError, false);
  assert.equal(readFileSync(remotePath, "utf8"), "replacement");
  assert.equal(readdirSync(directory).some(name => name.startsWith(".pi-proxmox-transfer-")), false);
});

test("failed or cancelled downloads never publish a partial destination", async () => {
  for (const mode of ["fail", "wait"]) {
    const localPath = join(directory, `failed-${mode}`);
    process.env.TEST_PROXMOX_MODE = mode;
    try {
      const controller = new AbortController();
      const pending = invoke("proxmox_transfer", { direction: "download", remotePath: "/unused", localPath }, transferContext, controller.signal);
      if (mode === "wait") setTimeout(() => controller.abort(), 100);
      const result = await pending;
      assert.equal(result.isError, true);
      assert.equal(existsSync(localPath), false);
      assert.equal(readdirSync(directory).some(name => name.startsWith(".pi-proxmox-transfer-")), false);
    } finally { delete process.env.TEST_PROXMOX_MODE; }
  }
});

test("audit sections are validated; missing probes do not hide successful probes", async () => {
  assert.throws(() => auditCommand(["invalid" as never]), /valid audit/);
  assert.throws(() => auditCommand([]), /valid audit/);
  const result = await invoke("proxmox_overview", { sections: ["system", "boot"] });
  assert.equal(result.isError, false);
  assert.equal(result.details.audit.sections.system.status, "ok");
  assert.match(result.details.audit.sections.system.probes.vms.data, /qm/);
  assert.equal(result.details.audit.sections.boot.status, "partial");
  assert.equal(result.details.audit.sections.boot.probes.entries.status, "unavailable");
  assert.deepEqual(Object.keys(result.details.audit.sections), ["system", "boot"]);
  assert.match(result.details.summary, /unavailable probes/);
  const invalid = auditResult({ host: "test", command: "test", code: 0, remoteExitCode: 0, outcome: "completed", output: "not JSON" });
  assert.equal(invalid.audit, undefined);
});

test("corrupt download is rejected without replacing an existing file", async () => {
  const source = join(directory, "corruption-source");
  const destination = join(directory, "corruption-destination");
  writeFileSync(source, "original payload");
  writeFileSync(destination, "keep this destination");
  process.env.TEST_PROXMOX_MODE = "corrupt-download";
  try {
    const result = await invoke("proxmox_transfer", { direction: "download", remotePath: source, localPath: destination, overwrite: true }, transferContext);
    assert.equal(result.isError, true);
    assert.equal(result.details.outcome, "verification_failed");
    assert.equal(result.details.transfer.verified, false);
    assert.equal(readFileSync(destination, "utf8"), "keep this destination");
    assert.equal(readdirSync(directory).some(name => name.startsWith(".pi-proxmox-transfer-")), false);
  } finally { delete process.env.TEST_PROXMOX_MODE; }
});

test("upload checksum mismatch and remote symlinks never replace a destination", async () => {
  const script = readFileSync(new URL("../extensions/proxmox/transfer.py", import.meta.url), "utf8");
  const destination = join(directory, "bad-hash-destination");
  writeFileSync(destination, "keep this file");
  assert.throws(() => execFileSync("python3", ["-c", script, "upload", destination, "true", "0".repeat(64)], { input: "wrong payload", stdio: ["pipe", "pipe", "pipe"] }));
  assert.equal(readFileSync(destination, "utf8"), "keep this file");
  const link = join(directory, "remote-destination-symlink");
  symlinkSync(destination, link);
  const localPath = join(directory, "remote-symlink-upload-source");
  writeFileSync(localPath, "do not publish");
  const result = await invoke("proxmox_transfer", { direction: "upload", remotePath: link, localPath, overwrite: true }, transferContext);
  assert.equal(result.isError, true);
  assert.equal(readFileSync(destination, "utf8"), "keep this file");
  assert.equal(readdirSync(directory).some(name => name.startsWith(".pi-proxmox-transfer-")), false);
});

test("audit includes QEMU storage and bind mounts while excluding credentials and descriptions", async () => {
  const fixtures = {
    "/cluster/resources": [
      { vmid: 100, node: "actual-node", type: "lxc", name: "example-ct", status: "running" },
      { vmid: 113, node: "actual-node", type: "qemu", name: "example-vm", status: "running" },
    ],
    "/nodes/actual-node/lxc/100/config": {
      rootfs: "local-lvm:vm-100-disk-0,size=8G", mp0: "/mnt/archive,mp=/archive", dev0: "/dev/dri/renderD128",
      description: "SECRET_DESCRIPTION", password: "SECRET_PASSWORD",
      lxc: [["lxc.mount.entry", "/dev/net/tun dev/net/tun none bind,create=file"], ["lxc.environment", "SECRET_ENV"]],
    },
    "/nodes/actual-node/qemu/113/config": { scsi0: "local-lvm:vm-113-disk-0,size=32G", usb0: "host=1234:5678", cipassword: "SECRET_CLOUD_INIT", sshkeys: "SECRET_SSH_KEYS" },
    "/nodes": [{ node: "actual-node", status: "online" }],
    "/storage": [{ storage: "example-pbs", type: "pbs", server: "backup.example.test", datastore: "main", password: "SECRET_STORAGE" }],
    "/nodes/actual-node/tasks": [{ type: "vzdump", status: "OK", starttime: 1, endtime: 2, user: "SECRET_USER" }],
    "/nodes/actual-node/storage/example-pbs/content": [{ vmid: 100, ctime: 1, volid: "example-pbs:backup/ct/100/2026-01-01T00:00:00Z", notes: "SECRET_NOTES" }],
  };
  process.env.TEST_PROXMOX_API_FIXTURES = JSON.stringify(fixtures);
  try {
    const result = await invoke("proxmox_overview", { sections: ["guests", "backups"] });
    assert.equal(result.isError, false);
    const probes = result.details.audit.sections.guests.probes;
    assert.equal(probes["config:113"].data.scsi0, "local-lvm:vm-113-disk-0,size=32G");
    assert.equal(probes["config:100"].data.mp0, "/mnt/archive,mp=/archive");
    assert.equal(probes["config:100"].data.lxc.length, 1);
    assert.match(result.details.audit.sections.backups.probes.limits.data, /not restore tests/);
    assert.doesNotMatch(JSON.stringify(result), /SECRET_/);
  } finally { delete process.env.TEST_PROXMOX_API_FIXTURES; }
});

test("all audit collectors report their coverage limits without needing a live host", async () => {
  const result = await invoke("proxmox_overview", { sections: ["system", "disks", "boot", "guests", "backups", "mounts", "recovery"] });
  assert.equal(result.isError, false);
  assert.equal(Object.keys(result.details.audit.sections).length, 7);
  assert.equal(result.details.audit.sections.disks.probes.devices.status, "unavailable");
  assert.ok(result.details.audit.sections.mounts.probes.fstab);
  assert.match(result.details.audit.sections.recovery.probes.limits.data, /not been verified/);
});

test("large audits keep full private output and bounded structured probe statuses", async () => {
  const path = join(directory, "full-audit.json");
  writeFileSync(path, JSON.stringify({ collectedAt: 1, sections: { guests: { status: "ok", probes: { inventory: { status: "ok", data: "x".repeat(100000) } } } } }));
  const parsed = auditResult({ host: "test", command: "test", code: 0, remoteExitCode: 0, outcome: "completed", output: "truncated JSON", fullOutputPath: path });
  assert.equal(parsed.audit!.sections.guests.probes.inventory.status, "ok");
  assert.equal(parsed.audit!.sections.guests.probes.inventory.data, undefined);
  assert.match(parsed.audit!.sections.guests.probes.inventory.reason!, /full-output/);
  assert.ok(JSON.stringify(parsed).length < 1000);
});
