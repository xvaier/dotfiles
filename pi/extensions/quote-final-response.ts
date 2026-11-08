import { getMarkdownTheme, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Markdown, truncateToWidth, type MarkdownTheme } from "@earendil-works/pi-tui";
import type { AssistantMessage } from "@earendil-works/pi-ai";

export function isFinalResponse(message: AssistantMessage) {
  return message.role === "assistant" && message.stopReason === "stop"
    && !message.content.some((part) => part.type === "toolCall");
}

export function quoteMarkdown(markdown: string, width: number, theme: MarkdownTheme) {
  if (width <= 0) return "";
  // Render normal Markdown first: Pi's blockquote renderer forces italic styling.
  const lines = new Markdown(markdown, 0, 0, theme).render(Math.max(2, width - 2));
  return lines.map((line) => {
    const bordered = truncateToWidth(theme.quoteBorder("│ ") + line, width);
    // The host parses transformer output as Markdown again. Escape the already
    // rendered text so code, lists and literal punctuation are not reinterpreted.
    return bordered.split(/(\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07]*(?:\x07|\x1b\\))/g)
      .map((part) => part.startsWith("\x1b") ? part : part.replace(/([\\`*{}\[\]()#+\-.!_>|~])/g, "\\$1"))
      .join("");
  }).join("\n");
}

export default function (pi: ExtensionAPI) {
  let context: ExtensionContext | undefined;
  const finalText = new Set<string>();

  function remember(message: AssistantMessage) {
    if (!isFinalResponse(message)) return;
    for (const part of message.content) {
      if (part.type === "text" && part.text.trim()) finalText.add(part.text.trim());
    }
  }

  pi.on("session_start", (_event, ctx) => {
    context = ctx;
    finalText.clear();
    for (const entry of ctx.sessionManager.getEntries()) {
      if (entry.type === "message" && entry.message.role === "assistant") remember(entry.message);
    }
  });

  pi.on("message_end", (event) => {
    if (event.message.role === "assistant") remember(event.message);
  });

  pi.registerMarkdownTransformer((markdown, render) => {
    if (render.messageType !== "assistant" || render.isStreaming || !markdown.trim()) return markdown;
    // Persisted messages have IDs; live components may only supply the text.
    const entry = render.messageId ? context?.sessionManager.getEntry(render.messageId) : undefined;
    const final = entry?.type === "message" && entry.message.role === "assistant"
      ? isFinalResponse(entry.message) : finalText.has(markdown.trim());
    return final ? quoteMarkdown(markdown, render.availableWidth, getMarkdownTheme()) : markdown;
  });
}
