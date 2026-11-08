// Run: node --test ~/.dotfiles/pi/tests/proxmox.test.mts (Node 22.18+).
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { after, test } from "node:test";
import { apiCommand, command, lxcCommand, optionArgs, resultText, runSSH, sshTarget } from "../extensions/proxmox/core.ts";

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
else {
  const result = spawnSync('/bin/sh', ['-c', args.at(-1)], { encoding: 'utf8' });
  process.stdout.write(result.stdout || ''); process.stderr.write(result.stderr || '');
  process.exitCode = result.status ?? 1;
}
`, { mode: 0o700 });
for (const program of ["pct", "pvesh", "pveversion", "uptime", "free", "df", "pvesm"]) {
  writeFileSync(join(directory, program), `#!${process.execPath}\nconsole.log(JSON.stringify({program: ${JSON.stringify(program)}, args: process.argv.slice(2)}));\n`, { mode: 0o700 });
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

test("real Pi loader registers five tools and /proxmox without connecting", () => {
  assert.equal(extension.tools.size, 5);
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
    await assert.rejects(invoke(name, params, { hasUI: true, ui: { confirm: async () => false } }), /denied/);
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
  await assert.rejects(invoke("proxmox_exec", { command: script, explanation: "Explain and print" }, ctx), /denied/);
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
    assert.match(resultText(timed), /may still be running/);
    const controller = new AbortController();
    const pending = runSSH("root@pve.example.test", "ignored", controller.signal);
    setTimeout(() => controller.abort(), 100);
    assert.equal((await pending).interrupted, "Cancelled");
    const count = callCount();
    await assert.rejects(runSSH("root@pve.example.test", "ignored", controller.signal));
    assert.equal(callCount(), count);
  } finally { delete process.env.TEST_PROXMOX_MODE; }
});
