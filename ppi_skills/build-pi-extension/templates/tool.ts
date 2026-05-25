/**
 * Pi Custom Tool Template
 *
 * Copy this file, replace all TODOs, place in your extension.
 *
 * For StringEnum: import { StringEnum } from "@earendil-works/pi-ai"
 * For truncation: import { truncateHead, DEFAULT_MAX_BYTES, DEFAULT_MAX_LINES } from "@earendil-works/pi-coding-agent"
 * For file mutations: import { withFileMutationQueue } from "@earendil-works/pi-coding-agent"
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
// import { StringEnum } from "@earendil-works/pi-ai"; // Uncomment for string enums

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "TODO_tool_name",          // Must be unique, lowercase_with_underscores
    label: "TODO Label",             // Human-readable name shown in TUI
    description: "TODO: What this tool does. Be specific — this is shown to the LLM.",

    // Optional: one-line summary in Available tools section
    promptSnippet: "TODO: Short one-line description for the system prompt",

    // Optional: guidelines appended to system prompt Guidelines section
    // IMPORTANT: Name the tool explicitly — "Use TODO_tool_name when..." not "Use this tool when..."
    promptGuidelines: [
      "Use TODO_tool_name when the user asks to TODO_specific_task.",
    ],

    // Tool parameters (TypeBox schema)
    parameters: Type.Object({
      // Example: required string
      // name: Type.String({ description: "Description for the LLM" }),

      // Example: optional string
      // filter: Type.Optional(Type.String({ description: "Optional filter" })),

      // Example: string enum (use StringEnum for Google API compatibility)
      // action: StringEnum(["list", "add", "remove"] as const),

      // Example: number with default
      // limit: Type.Optional(Type.Number({ description: "Max results", default: 10 })),
    }),

    // Optional: compatibility shim for old argument shapes
    // prepareArguments(args) { return args; },

    async execute(toolCallId, params, signal, onUpdate, ctx) {
      // Check for cancellation
      if (signal?.aborted) {
        return { content: [{ type: "text", text: "Cancelled" }], details: {} };
      }

      // Stream progress updates (optional)
      onUpdate?.({
        content: [{ type: "text", text: "Working..." }],
        details: { progress: 50 },
      });

      // --- Your logic here ---
      const result = "TODO: implement";

      // Truncate if output could be large:
      // import { truncateHead, DEFAULT_MAX_BYTES, DEFAULT_MAX_LINES } from "@earendil-works/pi-coding-agent";
      // const truncated = truncateHead(result, { maxLines: DEFAULT_MAX_LINES, maxBytes: DEFAULT_MAX_BYTES });
      // result = truncated.content;

      // For file mutations, use the queue:
      // import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";
      // import { resolve } from "node:path";
      // const absPath = resolve(ctx.cwd, params.path);
      // return withFileMutationQueue(absPath, async () => { ... });

      return {
        content: [{ type: "text", text: result }],  // Sent to LLM
        details: { /* any data for rendering / state */ },

        // Optional: stop agent after this tool batch (only if ALL tools in batch return this)
        // terminate: true,
      };
    },

    // Optional: custom TUI rendering for tool call display
    // renderCall(args, theme, context) {
    //   const { Text } = await import("@earendil-works/pi-tui");
    //   return new Text(theme.fg("toolTitle", `TODO_tool_name ${args.action}`), 0, 0);
    // },

    // Optional: custom TUI rendering for tool result display
    // renderResult(result, options, theme, context) {
    //   const { Text } = await import("@earendil-works/pi-tui");
    //   return new Text(theme.fg("success", result.content[0].text), 0, 0);
    // },
  });
}
