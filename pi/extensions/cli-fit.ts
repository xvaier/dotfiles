import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const glyph = "";

const dangerousBash = [
  /\brm\s+(-[A-Za-z]*r[A-Za-z]*f?|-[A-Za-z]*f[A-Za-z]*r|--recursive)\b/,
  /\bsudo\b/,
  /\bchmod\b\s+(?:\S+\s+)*777\b/,
  /\bchown\b\s+-R\b/,
  /\bdd\b.*\bof=\/dev\//,
  /\bmkfs(?:\.\w+)?\b/,
];

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.setHiddenThinkingLabel(`${glyph} thinking`);
  });

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return undefined;

    const command = typeof event.input.command === "string" ? event.input.command : "";
    if (!dangerousBash.some((pattern) => pattern.test(command))) return undefined;

    if (!ctx.hasUI) {
      return { block: true, reason: "Potentially destructive bash command blocked without an interactive UI." };
    }

    const allowed = await ctx.ui.confirm("Run potentially destructive shell command?", command);
    if (!allowed) return { block: true, reason: "Blocked by user." };

    return undefined;
  });
}
