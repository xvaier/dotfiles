import path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

function firstWords(input: string, max = 42) {
  const cleaned = input.replace(/\s+/g, " ").trim();
  if (cleaned.length <= max) return cleaned;
  return `${cleaned.slice(0, max - 1).trim()}…`;
}

async function repoName(pi: ExtensionAPI, ctx: ExtensionContext) {
  const result = await pi.exec("git", ["rev-parse", "--show-toplevel"], { cwd: ctx.cwd });
  const root = result.code === 0 ? result.stdout.trim() : ctx.cwd;
  return path.basename(root);
}

export default function (pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event, ctx) => {
    if (pi.getSessionName() || event.messageType !== "user") return undefined;

    const prompt = firstWords(event.prompt);
    if (!prompt) return undefined;

    pi.setSessionName(`${await repoName(pi, ctx)}: ${prompt}`);
    return undefined;
  });

  pi.registerCommand("title", {
    description: "Show or set the current session title",
    handler: async (args, ctx) => {
      const title = args.trim();
      if (title) {
        pi.setSessionName(title);
        ctx.ui.notify(`Session named: ${title}`, "info");
        return;
      }

      ctx.ui.notify(pi.getSessionName() || "No session title set", "info");
    },
  });
}
