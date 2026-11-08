// Run with Pi's bundled jiti; NODE_PATH must point at Pi's node_modules.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { visibleWidth } from "@earendil-works/pi-tui";
import extension, { contextColour } from "../extensions/statusline.ts";

const plain = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, "");
const usage = (input: number, output: number, cacheRead: number, cost: number) => ({ input, output, cacheRead, cacheWrite: 0, cost: { total: cost } });

test("context colours match Claude thresholds", () => {
  for (const [pct, code] of [[undefined, 90], [null, 90], [0, 90], [39, 32], [40, 33], [60, 33], [61, 31]] as const) {
    assert.equal(contextColour(pct), code);
  }
});

test("footer renders usage, real git dirtiness, compaction and narrow layouts", async () => {
  const cwd = mkdtempSync(join(tmpdir(), "pi-footer-"));
  try {
    execFileSync("git", ["init", "-q", "-b", "main"], { cwd });
    writeFileSync(join(cwd, "untracked"), "dirty\n");
    const handlers = new Map<string, Function>();
    let component: any;
    let renderRequests = 0;
    let unsubscribed = false;
    let percent: number | null = 24;
    let compaction = true;
    let thinking = "medium";
    const entries: any[] = [
      { type: "message", message: { role: "assistant", usage: usage(1000, 100, 9000, 0.12) } },
      { type: "compaction", usage: usage(500, 50, 0, 0.02) },
      { type: "usage", usage: usage(200, 20, 0, 0.01) },
      { type: "message", message: { role: "toolResult", usage: usage(300, 30, 0, 0.03) } },
    ];
    const ctx: any = {
      mode: "tui", cwd,
      model: { id: "test-model", reasoning: true, provider: "test", contextWindow: 272000 },
      modelRegistry: { isUsingOAuth: () => true },
      getContextUsage: () => ({ percent, contextWindow: 272000 }),
      sessionManager: { getEntries: () => entries, getSessionId: () => "id", getLeafId: () => String(entries.length), getEntryCount: () => entries.length },
      ui: { setFooter: (factory: Function) => {
        component = factory({ requestRender: () => renderRequests++ }, {}, {
          getGitBranch: () => "main", getAvailableProviderCount: () => 2,
          onBranchChange: () => () => { unsubscribed = true; },
        });
      } },
    };
    const pi: any = {
      on: (event: string, handler: Function) => handlers.set(event, handler),
      getSettings: () => ({ compaction: { enabled: compaction } }),
      getThinkingLevel: () => thinking,
      exec: async (cmd: string, args: string[], opts: any) => {
        try { return { code: 0, stdout: execFileSync(cmd, args, { cwd: opts.cwd, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }) }; }
        catch { return { code: 1, stdout: "" }; }
      },
    };
    extension(pi);
    await handlers.get("session_start")!({}, ctx);
    const lines = component.render(200).map(plain);
    assert.equal(lines.length, 2);
    assert.ok(lines.every((line: string) => line.startsWith("  ") && line.endsWith("  ")));
    assert.match(lines[0], /test-model  · medium   24%\/272k  auto  \$0\.18 sub   main ●/);
    assert.match(lines[1], /↑2k ↓200  R9k  CH90\.0%/);
    assert.ok(renderRequests > 0);
    for (const width of [0, 1, 10, 30, 60, 80, 120, 200]) {
      assert.ok(component.render(width).every((line: string) => visibleWidth(line) <= width));
    }
    const narrow = component.render(40).map(plain);
    assert.match(narrow[0], / 24%\/272k/);
    assert.ok(!narrow[1].includes("CH"));
    percent = null;
    assert.match(plain(component.render(200)[0]), / \?\/272k/);
    assert.match(plain(component.render(200)[0]), /\$0\.18/);
    compaction = false;
    thinking = "high";
    assert.ok(!plain(component.render(200)[0]).includes("auto"));
    assert.match(plain(component.render(200)[0]), /· high/);
    entries.push({ type: "message", message: { role: "assistant", usage: usage(1000, 100, 0, 0.02) } });
    assert.match(plain(component.render(200)[0]), /\$0\.20/);
    component.dispose();
    assert.ok(unsubscribed);
  } finally {
    rmSync(cwd, { recursive: true, force: true });
  }
});
