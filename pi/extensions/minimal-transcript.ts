import { homedir } from "node:os";
import type { ExtensionAPI, ToolRenderers } from "@earendil-works/pi-coding-agent";
import { Text, truncateToWidth } from "@earendil-works/pi-tui";

const singleLine = (value: unknown) => String(value ?? "").replace(/[\x00-\x1f\x7f-\x9f]/g, " ").replace(/\s+/g, " ").trim();
const shorten = (value: unknown) => {
  const text = singleLine(value);
  const home = homedir();
  return text === home ? "~" : text.startsWith(home + "/") ? "~" + text.slice(home.length) : text;
};

export function callTarget(name: string, args: Record<string, unknown>) {
  if (name === "bash") return singleLine(args.command);
  if (name === "grep" || name === "find") return `${singleLine(args.pattern)}${args.path ? ` in ${shorten(args.path)}` : ""}`;
  return shorten(args.path ?? args.explanation ?? args.command ?? args.vmid ?? "");
}

export function minimalRenderer(name: string, original?: ToolRenderers): ToolRenderers {
  return {
    renderShell: "self",
    renderCall(args, theme, context) {
      const target = callTarget(name, args);
      const label = name.charAt(0).toUpperCase() + name.slice(1);
      const status = context.isError ? "error" : context.isPartial ? "warning" : "success";
      const title = theme.fg(status, "●") + " " + theme.fg("toolTitle", theme.bold(label))
        + (target ? theme.fg("muted", `(${target})`) : "");
      return {
        invalidate() {},
        render(width) {
          const pad = " ".repeat(Math.min(context.outputPad, Math.floor(width / 2)));
          return [pad + truncateToWidth(title, Math.max(0, width - pad.length * 2), "…")];
        },
      };
    },
    renderResult(result, options, theme, context) {
      // Keep the original image renderer rather than replacing images with text.
      if (result.content.some((part) => part.type === "image") && original?.renderResult) {
        return original.renderResult(result, options, theme, context);
      }
      const text = result.content.filter((part) => part.type === "text").map((part) => part.text).join("\n").trimEnd();
      const diff = (result.details as { diff?: string } | undefined)?.diff;
      const output = diff || text;
      if (!output) return new Text(theme.fg("dim", `  └ ${options.isPartial ? "Running…" : "Done"}`), context.outputPad, 0);
      const lines = output.split("\n");
      const limit = options.expanded ? lines.length : context.isError ? 8 : 3;
      const preview = lines.slice(0, limit).map((line, index) => {
        const colour = context.isError ? "error" : diff && line.startsWith("+") ? "toolDiffAdded" : diff && line.startsWith("-") ? "toolDiffRemoved" : "dim";
        return theme.fg(colour, `${index === 0 ? "  └ " : "    "}${line}`);
      });
      if (lines.length > limit) preview.push(theme.fg("dim", `    … +${lines.length - limit} lines (${context.keyHint("app.tools.expand", "to expand")})`));
      if (options.expanded) return new Text(preview.join("\n"), context.outputPad, 0);
      return {
        invalidate() {},
        render(width) {
          const pad = " ".repeat(Math.min(context.outputPad, Math.floor(width / 2)));
          return preview.map((line) => pad + truncateToWidth(line, Math.max(0, width - pad.length * 2), "…"));
        },
      };
    },
  };
}

export default function (pi: ExtensionAPI) {
  pi.registerToolRenderer((name, next) => minimalRenderer(name, next()));
}
