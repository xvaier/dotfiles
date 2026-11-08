import assert from "node:assert/strict";
import { test } from "node:test";
import { visibleWidth } from "@earendil-works/pi-tui";
import extension, { callTarget } from "../extensions/minimal-transcript.ts";

const theme = { fg: (_colour: string, text: string) => text, bold: (text: string) => text };
const context = { outputPad: 1, executionStarted: true, isPartial: false, isError: false,
  keyHint: (_key: string, text: string) => `ctrl+o ${text}` };

test("registered renderers are compact, expandable, and keep errors visible", () => {
  let resolve: Function;
  extension({ registerToolRenderer: (value: Function) => { resolve = value; } } as any);
  const renderer = resolve!("bash", () => undefined);
  assert.equal(renderer.renderShell, "self");
  const title = renderer.renderCall({ command: "npm test\nnext command" }, theme, context);
  assert.match(title.render(80)[0], /● Bash\(npm test next command\)/);
  const text = Array.from({ length: 20 }, (_, i) => `line ${i}: ${"x".repeat(100)}`).join("\n");
  const result = { content: [{ type: "text", text }], details: undefined };
  const collapsed = renderer.renderResult(result, { expanded: false }, theme, context);
  assert.equal(collapsed.render(80).length, 4);
  assert.match(collapsed.render(80).at(-1), /\+17 lines/);
  for (const width of [0, 1, 10, 80]) {
    assert.ok(title.render(width).every((line: string) => visibleWidth(line) <= width));
    assert.ok(collapsed.render(width).every((line: string) => visibleWidth(line) <= width));
  }
  const expanded = renderer.renderResult(result, { expanded: true }, theme, context).render(200).join("\n");
  assert.match(expanded, /line 19:/);
  const failed = renderer.renderCall({}, theme, { ...context, isError: true });
  assert.match(failed.render(80)[0], /Bash/);
  const error = renderer.renderResult({ content: [{ type: "text", text: "Permission denied" }] }, {}, theme, { ...context, isError: true });
  assert.match(error.render(80)[0], /Permission denied/);
});

test("tool dots are green on success, yellow while pending, and red on failure", () => {
  let resolve: Function;
  extension({ registerToolRenderer: (value: Function) => { resolve = value; } } as any);
  const renderer = resolve!("read", () => undefined);
  const colouredTheme = { ...theme, fg: (colour: string, text: string) => `[${colour}]${text}` };
  for (const [state, colour] of [
    [{ executionStarted: false, isPartial: true, isError: false }, "warning"],
    [{ executionStarted: true, isPartial: true, isError: false }, "warning"],
    [{ executionStarted: true, isPartial: false, isError: false }, "success"],
    [{ executionStarted: false, isPartial: false, isError: false }, "success"],
    [{ executionStarted: true, isPartial: false, isError: true }, "error"],
    [{ executionStarted: false, isPartial: false, isError: true }, "error"],
  ] as const) {
    const header = renderer.renderCall({}, colouredTheme, { ...context, ...state });
    assert.ok(header.render(80)[0].includes(`[${colour}]●`));
  }
});

test("image output delegates to its existing renderer", () => {
  let resolve: Function;
  extension({ registerToolRenderer: (value: Function) => { resolve = value; } } as any);
  const imageComponent = { render: () => ["image"], invalidate() {} };
  const renderer = resolve!("read", () => ({ renderResult: () => imageComponent }));
  assert.equal(renderer.renderResult({ content: [{ type: "image" }] }, {}, theme, context), imageComponent);
  assert.equal(callTarget("grep", { pattern: "hello", path: "src" }), "hello in src");
});
