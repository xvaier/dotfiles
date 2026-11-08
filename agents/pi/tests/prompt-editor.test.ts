import assert from "node:assert/strict";
import { test } from "node:test";
import { CURSOR_MARKER, visibleWidth } from "@earendil-works/pi-tui";
import extension, { PromptEditor } from "../extensions/prompt-editor.ts";

const plain = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, "").replaceAll(CURSOR_MARKER, "");

test("registered editor factory uses the full UI theme, not EditorTheme", () => {
  let start: Function;
  let factory: Function;
  const ui = {
    theme: { fg: (name: string, text: string) => {
      assert.equal(name, "dim");
      return `\x1b[90m${text}\x1b[0m`;
    } },
    setEditorComponent(value: Function) { factory = value; },
  };
  extension({ on: (_event: string, handler: Function) => { start = handler; } } as any);
  start!({}, { mode: "tui", ui });
  // Pi passes only border/autocomplete styling to the editor factory: no fg().
  const editor = factory!(
    { terminal: { rows: 40 }, requestRender() {} },
    { borderColor: (s: string) => s },
    { matches: () => false },
  );
  assert.ok(editor.render(80)[1].startsWith("\x1b[90m❯ \x1b[0m"));
  ui.theme = { fg: (_name: string, text: string) => `\x1b[37m${text}\x1b[0m` };
  assert.ok(editor.render(80)[1].startsWith("\x1b[37m❯ \x1b[0m"));
});

test("chevron editor preserves text, wrapping, cursor and app shortcuts", () => {
  const editor = new PromptEditor(
    { terminal: { rows: 40 }, requestRender() {} } as any,
    { borderColor: (s: string) => s } as any,
    { matches: () => false } as any,
  );
  editor.focused = true;
  editor.setText("hello\nworld");
  const lines = editor.render(30);
  assert.equal(plain(lines[0]), "─".repeat(30));
  assert.ok(plain(lines[1]).startsWith("❯ hello"));
  assert.ok(plain(lines[2]).startsWith("  world"));
  assert.ok(lines.some((line) => line.includes(CURSOR_MARKER)));
  assert.equal(editor.getText(), "hello\nworld");
  editor.handleInput("!");
  assert.equal(editor.getText(), "hello\nworld!");
  let escaped = false;
  editor.onExtensionShortcut = () => { escaped = true; return true; };
  editor.handleInput("x");
  assert.ok(escaped);
  assert.equal(editor.getText(), "hello\nworld!");
  editor.setText("wide 界 and a long line that wraps around");
  for (const width of [0, 1, 2, 4, 5, 10, 30, 80]) {
    assert.ok(editor.render(width).every((line) => visibleWidth(line) <= width));
  }
});
