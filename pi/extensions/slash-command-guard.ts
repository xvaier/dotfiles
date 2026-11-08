import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  // Built-in and extension commands are dispatched before the input event.
  // Templates and skill commands still need to pass through for expansion.
  pi.on("input", (event, ctx) => {
    if (event.source !== "interactive") return;
    const text = event.text.trimStart();
    if (!text.startsWith("/")) return;
    const name = text.slice(1).split(/\s/, 1)[0];
    if (pi.getCommands().some((command) => command.name === name)) return;

    ctx.ui.notify(`Unknown command: /${name}. Not sent. Correct it, or remove the leading slash to send as a message.`, "warning");
    ctx.ui.setEditorText(event.text);
    return { action: "handled" };
  });
}
