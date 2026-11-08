import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

export class PromptEditor extends CustomEditor {
  promptColour = (text: string) => text;

  render(width: number): string[] {
    if (width <= 0) return ["", "", ""];
    // Use the editor's own padding so wrapping, mouse input and the cursor agree.
    this.setPaddingX(2);
    // The base editor cannot wrap double-width glyphs into a one-column layout.
    const lines = super.render(Math.max(6, width));
    if (width >= 5) lines[1] = this.promptColour("❯ ") + lines[1].slice(2);
    return lines.map((line) => truncateToWidth(line, width));
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    ctx.ui.setEditorComponent((tui, theme, keybindings) => {
      const editor = new PromptEditor(tui, theme, keybindings);
      editor.promptColour = (text) => ctx.ui.theme.fg("dim", text);
      return editor;
    });
  });
}
