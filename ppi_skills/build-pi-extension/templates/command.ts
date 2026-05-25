/**
 * Pi Slash Command Template
 *
 * Copy this file, replace all TODOs, place in your extension.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("TODO_command_name", {
    description: "TODO: What this command does (shown in /help)",

    // Optional: argument auto-completion
    // getArgumentCompletions: (prefix) => {
    //   const options = ["dev", "staging", "prod"];
    //   return options
    //     .filter(o => o.startsWith(prefix))
    //     .map(o => ({ value: o, label: o }));
    // },

    handler: async (args, ctx) => {
      // args = string after the command, e.g., /deploy staging → args = "staging"

      // --- Your logic here ---

      // Notify user
      ctx.ui.notify(`TODO: result for "${args}"`, "info");

      // Or use richer UI:
      // const choice = await ctx.ui.select("Pick one:", ["A", "B"]);
      // const ok = await ctx.ui.confirm("Proceed?", "Continue?");
      // const input = await ctx.ui.input("Name:", "default");

      // Or trigger a user message:
      // ctx.sendUserMessage("Continue with the deployment");

      // Or create a new session:
      // await ctx.newSession({
      //   withSession: async (newCtx) => {
      //     await newCtx.sendUserMessage("Start fresh");
      //   },
      // });
    },
  });
}
