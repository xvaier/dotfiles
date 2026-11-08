import assert from "node:assert/strict";
import { test } from "node:test";
import extension from "../extensions/slash-command-guard.ts";

test("unknown interactive slash commands are blocked and restored for correction", () => {
  let input: Function;
  let commands = [{ name: "review" }, { name: "skill:rex" }, { name: "quit" }];
  const notices: string[] = [];
  const restored: string[] = [];
  const ctx = { ui: {
    notify: (text: string) => notices.push(text),
    setEditorText: (text: string) => restored.push(text),
  } };
  extension({
    on: (_name: string, handler: Function) => { input = handler; },
    getCommands: () => commands,
  } as any);
  for (const text of ["/re;pad", "/does-not-exist args", "/", "  /typo", "/skill:missing"]) {
    assert.deepEqual(input!({ text, source: "interactive" }, ctx), { action: "handled" });
    assert.equal(restored.at(-1), text);
    assert.match(notices.at(-1)!, /Unknown command/);
  }
  for (const text of ["hello", "explain /tmp", "/review file.ts", "/skill:rex args", "/quit"]) {
    assert.equal(input!({ text, source: "interactive" }, ctx), undefined);
  }
  for (const source of ["rpc", "extension"]) {
    assert.equal(input!({ text: "/typo", source }, ctx), undefined);
  }
  // Query the registry at submission time, not just when the extension loads.
  commands.push({ name: "new-command" });
  assert.equal(input!({ text: "/new-command", source: "interactive" }, ctx), undefined);
  assert.equal(notices.length, 5);
});
