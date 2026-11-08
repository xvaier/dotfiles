import assert from "node:assert/strict";
import { test } from "node:test";
import extension, { quoteMarkdown } from "../extensions/quote-final-response.ts";
import { getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import { Markdown, visibleWidth } from "@earendil-works/pi-tui";

test("completed answers are quoted without changing commentary, thinking or user input", () => {
  const handlers = new Map<string, Function>();
  let transform: Function;
  extension({
    on: (name: string, handler: Function) => handlers.set(name, handler),
    registerMarkdownTransformer: (value: Function) => { transform = value; },
  } as any);
  const final = { role: "assistant", stopReason: "stop", content: [{ type: "text", text: "Done.\n\n- **One**\n\n```ts\nconst n = 1;\n```" }] };
  const commentary = { ...final, stopReason: "toolUse", content: [{ type: "text", text: "Checking now." }, { type: "toolCall" }] };
  const entries = new Map([
    ["final", { type: "message", message: final }],
    ["commentary", { type: "message", message: commentary }],
  ]);
  handlers.get("session_start")!({}, { sessionManager: { getEntries: () => [...entries.values()], getEntry: (id: string) => entries.get(id) } });
  const render = { messageType: "assistant", isStreaming: false, availableWidth: 80 };
  const text = final.content[0].text;
  assert.equal(transform!(text, { ...render, messageId: "final" }), quoteMarkdown(text, 80, getMarkdownTheme()));
  assert.equal(transform!("Checking now.", { ...render, messageId: "commentary" }), "Checking now.");
  for (const overrides of [{ isStreaming: true }, { messageType: "user" }, { messageType: "assistant-thinking" }]) {
    assert.equal(transform!(text, { ...render, ...overrides }), text);
  }
  const live = { ...final, content: [{ type: "text", text: "New answer." }] };
  handlers.get("message_end")!({ message: live });
  assert.equal(transform!("New answer.", render), quoteMarkdown("New answer.", 80, getMarkdownTheme()));
  assert.equal(live.content[0].text, "New answer.");
  handlers.get("message_end")!({ message: { ...live, stopReason: "aborted", content: [{ type: "text", text: "Incomplete" }] } });
  assert.equal(transform!("Incomplete", render), "Incomplete");
  const quoted = quoteMarkdown("a\n\nb", 80, getMarkdownTheme());
  const displayed = new Markdown(quoted, 0, 0, getMarkdownTheme()).render(80).join("\n");
  assert.match(displayed, /│ /);
  handlers.get("session_start")!({}, { sessionManager: { getEntries: () => [], getEntry: () => undefined } });
  assert.equal(transform!("New answer.", render), "New answer.");
});

test("quote border does not italicize normal text and preserves Markdown formatting", () => {
  const theme = {
    ...getMarkdownTheme(),
    italic: (text: string) => `\x1b[3m${text}\x1b[23m`,
    bold: (text: string) => `\x1b[1m${text}\x1b[22m`,
  };
  const display = (text: string, width = 60) => new Markdown(quoteMarkdown(text, width, theme), 0, 0, theme).render(width);
  const normal = display("Normal **bold** text.\n\n- Item\n\n```ts\nconst n = 1;\n```").join("\n");
  assert.ok(!normal.includes("\x1b[3m"));
  assert.ok(normal.includes("\x1b[1mbold\x1b[22m"));
  assert.match(normal, /const/);
  assert.match(normal, /│ /);
  assert.ok(display("Normal *emphasis* text.").join("\n").includes("\x1b[3memphasis\x1b[23m"));
  for (const width of [1, 2, 5, 20, 60]) {
    assert.ok(display("Long text **bold** and 界 wide characters.", width).every((line) => visibleWidth(line) <= width));
  }
});
