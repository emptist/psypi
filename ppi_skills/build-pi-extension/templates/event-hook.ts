/**
 * Pi Event Hook Template
 *
 * Copy this file, replace all TODOs, place in your extension.
 * Import and use in your main extension file.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {

  // ── Session Lifecycle ──────────────────────────────────────

  pi.on("session_start", async (event, ctx) => {
    // event.reason: "startup" | "reload" | "new" | "resume" | "fork"
    // event.previousSessionFile: present for "new", "resume", "fork"
    ctx.ui.notify("Extension loaded!", "info");
  });

  pi.on("session_shutdown", async (event, ctx) => {
    // event.reason: "quit" | "reload" | "new" | "resume" | "fork"
    // Cleanup: close connections, save state, etc.
  });

  // ── Agent Lifecycle ────────────────────────────────────────

  pi.on("before_agent_start", async (event, ctx) => {
    // event.prompt: user's raw prompt text
    // event.systemPrompt: current chained system prompt
    // event.systemPromptOptions: structured prompt building data

    // Inject a message:
    // return {
    //   message: {
    //     customType: "my-extension",
    //     content: "Additional context for the LLM",
    //     display: true,
    //   },
    // };

    // Modify system prompt:
    // return {
    //   systemPrompt: event.systemPrompt + "\n\nExtra instructions...",
    // };
  });

  pi.on("agent_end", async (event, ctx) => {
    // event.messages: messages from this prompt
    // Good place to trigger follow-up work after debounce
  });

  // ── Tool Interception ──────────────────────────────────────

  pi.on("tool_call", async (event, ctx) => {
    // event.toolName: "bash", "read", "write", etc.
    // event.toolCallId: unique ID
    // event.input: tool parameters (MUTABLE — mutate in place to patch)

    // Block dangerous commands:
    // if (event.toolName === "bash" && event.input.command?.includes("rm -rf")) {
    //   const ok = await ctx.ui.confirm("Dangerous!", "Allow rm -rf?");
    //   if (!ok) return { block: true, reason: "Blocked by user" };
    // }

    // Type-safe narrowing for built-in tools:
    // if (isToolCallEventType("bash", event)) {
    //   // event.input is typed as { command: string; timeout?: number }
    //   console.log(`Bash: ${event.input.command}`);
    // }
  });

  pi.on("tool_result", async (event, ctx) => {
    // event.toolName, event.toolCallId, event.input
    // event.content, event.details, event.isError

    // Modify result (middleware chain — handlers run in load order):
    // return {
    //   content: [{ type: "text", text: "Modified output" }],
    //   details: { extra: "data" },
    // };
  });

  // ── Input Interception ─────────────────────────────────────

  pi.on("input", async (event, ctx) => {
    // event.text: raw user input (before skill/template expansion)
    // event.source: "interactive" | "rpc" | "extension"

    // Transform input:
    // if (event.text.startsWith("?quick ")) {
    //   return { action: "transform", text: `Respond briefly: ${event.text.slice(7)}` };
    // }

    // Handle without LLM:
    // if (event.text === "ping") {
    //   ctx.ui.notify("pong", "info");
    //   return { action: "handled" };
    // }

    // return { action: "continue" }; // Default: pass through
  });

  // ── Model Events ───────────────────────────────────────────

  pi.on("model_select", async (event, ctx) => {
    // event.model: newly selected model
    // event.previousModel: previous model
    // event.source: "set" | "cycle" | "restore"
  });
}
