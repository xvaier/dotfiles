import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("input", (event, ctx) => {
    if (event.source !== "interactive" || event.images?.length || event.text.trim() !== "quit") return;
    ctx.shutdown();
    return { action: "handled" };
  });
}
