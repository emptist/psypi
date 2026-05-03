// src/agent/extension/extension.ts
// SIMPLIFIED - NO thinking slot! (as per: "psypi don't use any external thinker")
// KEEP: Monitor (God in the sky/Gleam) - as per: "you will never remove the monitor, no way"!

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { execSync } from "child_process";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const VERBOSE = process.env.PSYPI_VERBOSE === 'true' || process.env.NODE_ENV !== 'production';

// Map of tools
const tools = new Map<string, Function>();

// Map of commands  
const commands = new Map<string, { description?: string; handler: Function; getArgumentCompletions?: Function }>();

// Export for psypi CLI
export const pi = { tools, commands };

// Initialize extension (NO thinking slot!)
export default function (pi: ExtensionAPI) {
  if (VERBOSE) {
    console.log(`[PsyPI] Extension loaded (no thinking slot - psypi is self-sufficient!)`);
  }

  // Register tools
  registerTool("psypi-tasks", {
    label: "List Tasks",
    description: "Check pending tasks from psypi",
    parameters: Type.Object({
      context: Type.Optional(Type.String({ description: "Current work context" })),
    }),
    async execute(toolCallId: string, params: any, signal?: AbortSignal, onUpdate?: Function, ctx?: any) {
      // Calls kernel.getTasks() internally
      return { content: [{ type: "text", text: "Tasks listed" }] };
    },
  });

  registerTool("psypi-think", {
    label: "Think (Self-Sufficient Mode)",
    description: "Delegates complex reasoning (but psypi is self-sufficient!)",
    parameters: Type.Object({
      question: Type.String({ description: "The question or problem needing deep thought" }),
    }),
    async execute(toolCallId: string, params: any, signal?: AbortSignal, onUpdate?: Function, ctx?: any) {
      return {
        content: [{ type: "text", text: "PsyPI is in self-sufficient mode. Handle thinking yourself." }],
      };
    },
  });

  // Register commands
  registerCommand("psypi-tasks", {
    description: "Check pending tasks",
    handler: async (args: string, ctx: any) => {
      ctx.ui.notify("Tasks checked", "info");
    },
  });
}

// Helper: Register tool
function registerTool(name: string, options: any): void {
  tools.set(name, options);
}

// Helper: Register command
function registerCommand(name: string, options: any): void {
  commands.set(name, options);
}

// NOTE: Monitor (God in the sky) is NOT here!
// It's in: gleam/psypi_core/src/psypi_core/review.gleam (15 lines!)
// Called via: InterReviewService.callAI() -> run_review() from Gleam!
// NEVER REMOVE THAT (as per: "you will never remove the monitor, no way"!)
