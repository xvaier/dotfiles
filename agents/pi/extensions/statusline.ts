import { homedir } from "node:os";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type Paint = (colour: string, text: string) => string;

const clean = (text: string) => text.replace(/[\x00-\x1f\x7f-\x9f]/g, " ");
const tokens = (n: number) => n < 1000 ? `${n}` : n < 1e6 ? `${+(n / 1000).toFixed(1)}k` : `${+(n / 1e6).toFixed(1)}M`;

export function contextColour(percent: number | null | undefined) {
  if (!percent) return "dim";
  return percent < 40 ? "success" : percent <= 60 ? "warning" : "error";
}

function usageStats(ctx: ExtensionContext) {
  const totals = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, hit: undefined as number | undefined };
  // All entries retain billed work across compaction and tree navigation.
  for (const entry of ctx.sessionManager.getEntries()) {
    const usage = entry.type === "message"
      ? ((entry.message.role === "assistant" || entry.message.role === "toolResult") ? entry.message.usage : undefined)
      : ((entry.type === "usage" || entry.type === "compaction" || entry.type === "branch_summary") ? entry.usage : undefined);
    if (!usage) continue;
    totals.input += usage.input;
    totals.output += usage.output;
    totals.cacheRead += usage.cacheRead;
    totals.cacheWrite += usage.cacheWrite;
    totals.cost += usage.cost.total;
    if (entry.type === "message" && entry.message.role === "assistant") {
      const prompt = usage.input + usage.cacheRead + usage.cacheWrite;
      totals.hit = prompt ? usage.cacheRead / prompt * 100 : undefined;
    }
  }
  return totals;
}

export default function (pi: ExtensionAPI) {
  let ctx: ExtensionContext;
  let dirty = false;
  let detached = "";
  let requestRender = () => {};
  let cachedKey = "";
  let stats: ReturnType<typeof usageStats>;

  async function refreshGit() {
    const cwd = ctx.cwd;
    const result = await pi.exec("git", ["--no-optional-locks", "status", "--porcelain"], { cwd });
    if (ctx.cwd !== cwd) return;
    dirty = result.code === 0 && result.stdout.trim().length > 0;
    const head = await pi.exec("git", ["rev-parse", "--short", "HEAD"], { cwd });
    if (ctx.cwd !== cwd) return;
    detached = head.code === 0 ? head.stdout.trim() : "";
    requestRender();
  }

  pi.on("session_start", async (_event, context) => {
    if (context.mode !== "tui") return;
    ctx = context;
    cachedKey = "";
    ctx.ui.setFooter((tui, theme, footerData) => {
      const paint: Paint = (colour, text) => theme.fg(colour as Parameters<typeof theme.fg>[0], text);
      requestRender = () => tui.requestRender();
      const unsubscribe = footerData.onBranchChange(requestRender);
      return {
        dispose() { unsubscribe(); requestRender = () => {}; },
        invalidate() {},
        render(width) {
          const padding = " ".repeat(Math.min(2, Math.floor(Math.max(0, width) / 2)));
          width = Math.max(0, width - padding.length * 2);
          const manager = ctx.sessionManager;
          const key = `${manager.getSessionId()}:${manager.getLeafId()}`;
          if (key !== cachedKey) {
            stats = usageStats(ctx);
            cachedKey = key;
          }
          const usage = ctx.getContextUsage();
          const pct = usage?.percent;
          const capacity = usage?.contextWindow ?? ctx.model?.contextWindow;
          const context = paint(contextColour(pct), ` ${pct == null ? "?" : Math.round(Math.min(100, Math.max(0, pct))) + "%"}${capacity ? "/" + tokens(capacity) : ""}`);
          const auto = pi.getSettings().compaction?.enabled !== false ? paint("dim", "auto") : "";
          const model = ctx.model;
          const modelText = paint("accent", clean(model?.id ?? "no-model"));
          const thinking = model?.reasoning ? paint("dim", `· ${pi.getThinkingLevel()}`) : "";
          const subscription = model && (model.provider === "kimi-coding" || ctx.modelRegistry.isUsingOAuth(model));
          const cost = paint(stats.cost ? "text" : "dim", `$${stats.cost.toFixed(2)}`)
            + (subscription ? paint("dim", " sub") : "");
          const branch = footerData.getGitBranch() || detached;
          const git = branch ? paint("mdLink", ` ${clean(branch)}`) + (dirty ? paint("warning", " ●") : "") : "";
          const provider = model && footerData.getAvailableProviderCount() > 1 ? paint("dim", `(${clean(model.provider)})`) : "";
          const join = (parts: string[]) => parts.filter(Boolean).join("  ");
          let first = join([modelText, thinking, context, auto, cost, git]);
          if (provider && visibleWidth(first + " " + provider) <= width) first += " " + provider;
          if (visibleWidth(first) > width) first = join([modelText, thinking, context, cost, git]);
          if (visibleWidth(first) > width) first = join([modelText, context, cost, git]);
          if (visibleWidth(first) > width) first = join([modelText, context, cost]);
          if (visibleWidth(first) > width) first = join([truncateToWidth(modelText, Math.max(0, width - visibleWidth(context) - 2), "…"), context]);

          const home = homedir();
          const cwd = ctx.cwd === home ? "~" : ctx.cwd.startsWith(home + "/") ? "~" + ctx.cwd.slice(home.length) : ctx.cwd;
          const counts = paint("dim", `↑${tokens(stats.input)} ↓${tokens(stats.output)}`);
          const cache = paint("dim", [stats.cacheRead ? `R${tokens(stats.cacheRead)}` : "", stats.cacheWrite ? `W${tokens(stats.cacheWrite)}` : "", stats.hit != null && (stats.cacheRead || stats.cacheWrite) ? `CH${stats.hit.toFixed(1)}%` : ""].filter(Boolean).join("  "));
          const path = paint("muted", clean(cwd));
          let second = join([path, counts, cache]);
          if (visibleWidth(second) > width) second = join([path, counts]);
          if (visibleWidth(second) > width) second = join([truncateToWidth(path, Math.max(0, width - visibleWidth(counts) - 2), "…"), counts]);
          return [first, second].map((line) => padding + truncateToWidth(line, width) + padding);
        },
      };
    });
    await refreshGit();
  });

  for (const event of ["agent_settled", "session_switch", "session_tree", "session_fork", "model_select"] as const) {
    pi.on(event, async (_event, context) => {
      if (context.mode !== "tui") return;
      ctx = context;
      cachedKey = "";
      await refreshGit();
    });
  }
}
