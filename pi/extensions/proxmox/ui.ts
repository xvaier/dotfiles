import { getMarkdownTheme, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Markdown, matchesKey, Key, truncateToWidth } from "@earendil-works/pi-tui";

export interface Review {
  title: string;
  script: string;
  scope: string;
}

// Render control characters visibly rather than letting scripts control the terminal.
export function visibleScript(text: string): string {
  return text.replace(/[\x00-\x08\x0b-\x1f\x7f]/g, c => `\\x${c.charCodeAt(0).toString(16).padStart(2, "0")}`);
}

export function fenced(text: string, language = "bash"): string {
  const fence = "`".repeat(Math.max(3, ...Array.from(text.matchAll(/`+/g), m => m[0].length + 1)));
  return `${fence}${language}\n${visibleScript(text)}\n${fence}`;
}

export async function approve(ctx: ExtensionContext, host: string, command: string, review: Review, signal: AbortSignal): Promise<boolean> {
  if (ctx.mode !== "tui") {
    return (await ctx.ui.confirm(`Allow root operation on ${host}?`,
      `${review.title}\n${review.scope}\n\nScript:\n${review.script}\n\nExact remote command (JSON-escaped):\n${JSON.stringify(command)}\n\nRuns as root; may change or delete data.`, { signal })) === true;
  }
  let cancel: (() => void) | undefined;
  const onAbort = () => cancel?.();
  signal.addEventListener("abort", onAbort, { once: true });
  try {
    return await ctx.ui.custom<boolean>((tui, theme, _keys, done) => {
      let transport = false;
      let offset = 0;
      let height = 12;
      let total = 0;
      const script = new Markdown(fenced(review.script), 0, 0, getMarkdownTheme());
      const exact = new Markdown(fenced(command), 0, 0, getMarkdownTheme());
      cancel = () => done(false);
      if (signal.aborted) queueMicrotask(() => done(false));
      return {
        render(width: number) {
          height = Math.max(3, Math.min(18, (process.stdout.rows || 24) - 8));
          const lines = (transport ? exact : script).render(width);
          total = lines.length;
          offset = Math.max(0, Math.min(offset, total - height));
          const header = [theme.fg("accent", review.title), `${host} · ${review.scope}`,
            theme.fg("warning", "Runs as root. Commands may change or delete data."),
            theme.fg("dim", transport ? "Exact SSH command" : "Script (executed unchanged inside /bin/sh -lc)")];
          const footer = theme.fg("dim", `Y approve · N/Esc reject · ↑↓ scroll · X ${transport ? "script" : "exact SSH command"} · ${offset + 1}–${Math.min(total, offset + height)}/${total}`);
          return [...header, ...lines.slice(offset, offset + height), footer].map(line => truncateToWidth(line, width));
        },
        handleInput(data: string) {
          if (data === "y" || data === "Y") { done(!signal.aborted); return; }
          if (data === "n" || data === "N" || matchesKey(data, Key.escape)) { done(false); return; }
          if (data === "x" || data === "X") { transport = !transport; offset = 0; }
          else if (matchesKey(data, Key.up)) offset = Math.max(0, offset - 1);
          else if (matchesKey(data, Key.down)) offset = Math.min(Math.max(0, total - height), offset + 1);
          else if (matchesKey(data, Key.pageUp)) offset = Math.max(0, offset - height);
          else if (matchesKey(data, Key.pageDown)) offset = Math.min(Math.max(0, total - height), offset + height);
          else return;
          tui.requestRender();
        },
        invalidate() { script.invalidate(); exact.invalidate(); },
      };
    });
  } finally {
    signal.removeEventListener("abort", onAbort);
  }
}
