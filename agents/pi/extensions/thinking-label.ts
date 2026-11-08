import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Nerd Font glyph; shown in place of the default label when thinking blocks are collapsed.
const glyph = "";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.setHiddenThinkingLabel(`${glyph} thinking`);
  });
}
