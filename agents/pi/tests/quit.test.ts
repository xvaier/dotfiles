import assert from "node:assert/strict";
import { test } from "node:test";
import extension from "../extensions/quit.ts";

test("bare quit requests graceful shutdown without overriding built-in /quit", () => {
  let input: Function;
  let shutdowns = 0;
  const ctx = { shutdown() { shutdowns++; } };
  extension({
    registerCommand() { assert.fail("Keep Pi's built-in /quit command"); },
    on(name: string, handler: Function) { assert.equal(name, "input"); input = handler; },
  } as any);
  assert.deepEqual(input!({ text: " quit ", source: "interactive" }, ctx), { action: "handled" });
  assert.equal(shutdowns, 1);
  for (const event of [
    { text: "quit this task", source: "interactive" },
    { text: "quit\nmore text", source: "interactive" },
    { text: "quit", source: "rpc" },
    { text: "quit", source: "extension" },
    { text: "quit", source: "interactive", images: [{}] },
  ]) assert.equal(input!(event, ctx), undefined);
  assert.equal(shutdowns, 1);
});
