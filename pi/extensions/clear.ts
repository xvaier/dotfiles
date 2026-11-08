import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("clear", {
    description: "Start a fresh session (alias for /new); leave files unchanged",
    async handler(_args, ctx) {
      await ctx.waitForIdle();
      await ctx.newSession();
    },
  });
}
