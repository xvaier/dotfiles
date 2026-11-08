import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

interface Worktree {
  path: string;
  branch?: string;
  head?: string;
  bare?: boolean;
  detached?: boolean;
}

async function listWorktrees(pi: ExtensionAPI, cwd: string): Promise<Worktree[]> {
  const result = await pi.exec("git", ["worktree", "list", "--porcelain"], { cwd });
  if (result.code !== 0) return [];

  const worktrees: Worktree[] = [];
  let current: Worktree | undefined;

  for (const line of result.stdout.split("\n")) {
    if (!line.trim()) {
      if (current) worktrees.push(current);
      current = undefined;
      continue;
    }

    const [key, ...rest] = line.split(" ");
    const value = rest.join(" ");

    if (key === "worktree") current = { path: value };
    else if (current && key === "branch") current.branch = value.replace(/^refs\/heads\//, "");
    else if (current && key === "HEAD") current.head = value.slice(0, 7);
    else if (current && key === "bare") current.bare = true;
    else if (current && key === "detached") current.detached = true;
  }

  if (current) worktrees.push(current);
  return worktrees;
}

function label(worktree: Worktree) {
  const ref = worktree.branch ?? (worktree.detached ? `detached:${worktree.head ?? "HEAD"}` : worktree.head ?? "unknown");
  return `${ref}  ${worktree.path}`;
}

async function pickWorktree(pi: ExtensionAPI, ctx: ExtensionCommandContext) {
  const worktrees = await listWorktrees(pi, ctx.cwd);
  if (worktrees.length === 0) {
    ctx.ui.notify("No git worktrees found", "warning");
    return undefined;
  }

  const choices = worktrees.map(label);
  const selected = await ctx.ui.select("Git worktrees", choices);
  if (!selected) return undefined;

  return worktrees[choices.indexOf(selected)];
}

async function openTmuxWindow(pi: ExtensionAPI, ctx: ExtensionCommandContext, command: string[], name: string) {
  if (!process.env.TMUX) {
    ctx.ui.notify(`Not inside tmux. cd ${command[0]}`, "warning");
    return;
  }

  const [cwd, ...shellCommand] = command;
  const result = await pi.exec("tmux", ["new-window", "-c", cwd, "-n", name, ...shellCommand], { cwd: ctx.cwd });
  if (result.code !== 0) ctx.ui.notify(result.stderr || result.stdout || "tmux new-window failed", "error");
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("wt", {
    description: "Pick a git worktree and print its cd command",
    handler: async (_args, ctx) => {
      const worktree = await pickWorktree(pi, ctx);
      if (!worktree) return;
      ctx.ui.notify(`cd ${worktree.path}`, "info");
    },
  });

  pi.registerCommand("wt-pi", {
    description: "Open Pi in a selected git worktree in a new tmux window",
    handler: async (_args, ctx) => {
      const worktree = await pickWorktree(pi, ctx);
      if (!worktree) return;
      await openTmuxWindow(pi, ctx, [worktree.path, "pi"], `pi:${worktree.branch ?? "worktree"}`);
    },
  });

  pi.registerCommand("wt-lg", {
    description: "Open lazygit for a selected git worktree in a new tmux window",
    handler: async (_args, ctx) => {
      const worktree = await pickWorktree(pi, ctx);
      if (!worktree) return;
      await openTmuxWindow(pi, ctx, [worktree.path, "lazygit"], `git:${worktree.branch ?? "worktree"}`);
    },
  });
}
