import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { matchesKey, Text, wrapTextWithAnsi } from "@earendil-works/pi-tui";
import { Type } from "typebox";

interface Question {
  question: string;
  options: { label: string; description?: string }[];
  multiSelect?: boolean;
}

export async function askUser(ctx: ExtensionContext, params: Question, signal?: AbortSignal) {
  if (ctx.mode !== "tui") throw new Error("ask_user requires Pi's interactive terminal mode.");
  if (!params.options.length || params.options.length > 12) throw new Error("Provide 1–12 options.");
  if (new Set(params.options.map(option => option.label)).size !== params.options.length) {
    throw new Error("Option labels must be unique.");
  }
  if (signal?.aborted) return null;

  const selected = await ctx.ui.custom<number[] | "other" | null>((tui, theme, keys, done) => {
    let cursor = 0;
    const checked = new Set<number>();
    let finished = false;
    const finish = (value: number[] | "other" | null) => {
      if (finished) return;
      finished = true;
      signal?.removeEventListener("abort", abort);
      done(value);
    };
    const abort = () => finish(null);
    signal?.addEventListener("abort", abort, { once: true });
    if (signal?.aborted) finish(null);
    const count = params.options.length + 1;
    return {
      render(width) {
        const lines = [theme.bold(params.question), ""];
        params.options.forEach((option, index) => {
          const mark = params.multiSelect ? (checked.has(index) ? "[x]" : "[ ]") : "○";
          const label = `${cursor === index ? "›" : " "} ${mark} ${index + 1}. ${option.label}`;
          lines.push(theme.fg(cursor === index ? "accent" : "text", label));
          if (option.description) lines.push(theme.fg("muted", `      ${option.description}`));
        });
        lines.push(theme.fg(cursor === count - 1 ? "accent" : "text", `${cursor === count - 1 ? "›" : " "} Other — type an answer`));
        lines.push("", theme.fg("dim", params.multiSelect
          ? "↑↓ move · Space toggle · Enter submit · Esc cancel"
          : "↑↓ move · Enter select · Esc cancel"));
        return lines.flatMap(line => wrapTextWithAnsi(line, Math.max(1, width)));
      },
      handleInput(data) {
        if (keys.matches(data, "tui.select.cancel")) return finish(null);
        if (keys.matches(data, "tui.select.up")) cursor = (cursor - 1 + count) % count;
        else if (keys.matches(data, "tui.select.down")) cursor = (cursor + 1) % count;
        else if (params.multiSelect && matchesKey(data, "space") && cursor < params.options.length) {
          if (checked.has(cursor)) checked.delete(cursor);
          else checked.add(cursor);
        } else if (keys.matches(data, "tui.select.confirm")) {
          if (cursor === count - 1) return finish("other");
          if (!params.multiSelect) return finish([cursor]);
          if (checked.size) return finish([...checked].sort((a, b) => a - b));
        }
        tui.requestRender();
      },
      invalidate() {},
      dispose() { signal?.removeEventListener("abort", abort); },
    };
  }, { blocked: { kind: "question", message: params.question } });

  if (selected === null || selected === undefined || signal?.aborted) return null;
  if (selected === "other") {
    const answer = await ctx.ui.input(params.question, "Type your answer", { signal });
    return answer?.trim() ? { answers: [answer.trim()], custom: true } : null;
  }
  return { answers: selected.map(index => params.options[index].label), custom: false };
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "ask_user",
    label: "Ask user",
    description: "Ask a single question using an interactive single-select or multi-select menu, with an Other text option. Cancellation is not consent; do not choose on the user's behalf.",
    promptSnippet: "Ask the user to choose options in an interactive menu",
    promptGuidelines: ["Use ask_user instead of lettered text lists when asking the user to make a decision. Ask one decision at a time unless the user requests otherwise."],
    exposure: "model-only",
    executionMode: "sequential",
    parameters: Type.Object({
      question: Type.String(),
      options: Type.Array(Type.Object({
        label: Type.String(),
        description: Type.Optional(Type.String()),
      }), { minItems: 1, maxItems: 12 }),
      multiSelect: Type.Optional(Type.Boolean({ description: "Allow multiple choices; defaults to false." })),
    }),
    async execute(_id, params, signal, _update, ctx) {
      const answer = await askUser(ctx, params, signal);
      const details = { question: params.question, answer, cancelled: answer === null };
      return {
        content: [{ type: "text", text: answer ? JSON.stringify(details) : "User cancelled the question. No option was approved." }],
        details,
      };
    },
    renderCall(args, theme) {
      return new Text(theme.fg("toolTitle", "Question: ") + (args.question ?? ""), 0, 0);
    },
    renderResult(result, _options, theme) {
      const answer = result.details?.answer;
      return new Text(answer ? theme.fg("success", `✓ ${answer.answers.join(", ")}`) : theme.fg("warning", "Cancelled — no selection"), 0, 0);
    },
  });
}
