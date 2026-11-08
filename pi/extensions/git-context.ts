import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

async function git(pi: ExtensionAPI, ctx: ExtensionContext, args: string[]) {
  return pi.exec("git", args, { cwd: ctx.cwd });
}

async function getGitState(pi: ExtensionAPI, ctx: ExtensionContext) {
  const branch = await git(pi, ctx, ["branch", "--show-current"]);
  if (branch.code !== 0) return undefined;

  const status = await git(pi, ctx, ["status", "--porcelain"]);
  const changed = status.code === 0 ? status.stdout.trim().split("\n").filter(Boolean).length : 0;
  const name = branch.stdout.trim() || "detached";

  return { name, changed };
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("git-context", {
    description: "Show git branch/dirty status",
    handler: async (_args, ctx) => {
      const state = await getGitState(pi, ctx);
      ctx.ui.notify(state ? `${state.name}: ${state.changed} changed file(s)` : "Not in a git repo", "info");
    },
  });
}
