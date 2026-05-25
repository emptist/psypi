/**
 * Full Pi Extension Template
 *
 * A complete extension with tool, command, event hooks, and state.
 * Copy and customize for your use case.
 *
 * Place in: ~/.pi/agent/extensions/TODO-name.ts
 * Or:       .pi/extensions/TODO-name.ts (project-local)
 * Test:     pi -e ./TODO-name.ts
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
// import { StringEnum } from "@earendil-works/pi-ai"; // For string enums

export default function (pi: ExtensionAPI) {

  // ── State ──────────────────────────────────────────────────
  // Reconstruct from session on start
  let state: { count: number } = { count: 0 };

  pi.on("session_start", async (_event, ctx) => {
    state = { count: 0 };
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type === "message" && entry.message.role === "toolResult") {
        if (entry.message.toolName === "TODO_tool_name") {
          state = entry.message.details?.state ?? { count: 0 };
        }
      }
    }
  });

  pi.on("session_shutdown", async (_event, _ctx) => {
    // Cleanup: close connections, save state, etc.
  });

  // ── Custom Tool ────────────────────────────────────────────

  pi.registerTool({
    name: "TODO_tool_name",
    label: "TODO Label",
    description: "TODO: What this tool does",
    promptSnippet: "TODO: One-line description for system prompt",
    promptGuidelines: [
      "Use TODO_tool_name when the user asks to TODO_specific_task.",
    ],
    parameters: Type.Object({
      // TODO: Define parameters
      // action: StringEnum(["list", "add"] as const),
      // text: Type.Optional(Type.String()),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      // TODO: Implement
      state.count++;
      return {
        content: [{ type: "text", text: `Count: ${state.count}` }],
        details: { state: { ...state } },
      };
    },
  });

  // ── Slash Command ──────────────────────────────────────────

  pi.registerCommand("TODO_command_name", {
    description: "TODO: What this command does",
    handler: async (args, ctx) => {
      ctx.ui.notify(`TODO: "${args || "no args"}" — count is ${state.count}`, "info");
    },
  });

  // ── Event Hooks ────────────────────────────────────────────

  pi.on("before_agent_start", async (_event, _ctx) => {
    // Optional: inject context or modify system prompt
    // return { message: { customType: "my-ext", content: "...", display: true } };
  });

  pi.on("tool_call", async (event, ctx) => {
    // Optional: block or inspect tool calls
    // if (event.toolName === "bash" && event.input.command?.includes("dangerous")) {
    //   const ok = await ctx.ui.confirm("Dangerous!", "Allow?");
    //   if (!ok) return { block: true, reason: "Blocked" };
    // }
  });

  pi.on("agent_end", async (_event, _ctx) => {
    // Optional: react after agent finishes
  });
}
