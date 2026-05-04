// src/agent/extension/extension.ts
// PsyPI Extension - Pi tools for psypi integration
// NOTE: NO thinking slot - psypi is self-sufficient (uses Gleam "God in the sky" for review)

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { execSync } from "child_process";
import path from "path";
import { fileURLToPath } from "url";
import { kernel } from "../../kernel/index.js";
import { AgentIdentityService } from "../../kernel/services/AgentIdentityService.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const VERBOSE = process.env.PSYPI_VERBOSE === 'true' || process.env.NODE_ENV !== 'production';

// Initialize extension
export default function (pi: ExtensionAPI) {
  if (VERBOSE) {
    console.log(`[PsyPI] Extension loaded (self-sufficient - no external thinkers!)`);
  }

  // ===== CORE TOOLS =====

  // psypi-commit - Git commit with MANDATORY inter-review
  pi.registerTool({
    name: "psypi-commit",
    label: "PsyPI Commit",
    description: "Git commit using 'psypi commit' CLI (runs mandatory Gleam review by 'God in the sky')",
    parameters: Type.Object({
      message: Type.String({ description: "Commit message" }),
      noVerify: Type.Optional(Type.Boolean({ description: "Skip git hooks (still runs Gleam review)" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const verifyFlag = params.noVerify ? "--no-verify" : "";
        const output = execSync(`psypi commit "${params.message}" ${verifyFlag}`, { 
          encoding: "utf-8",
          stdio: "pipe"
        });
        
        return {
          content: [{ type: "text" as const, text: output }],
          details: { success: true } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}\n${err.stderr || ''}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-my-id - Get current agent ID
  pi.registerTool({
    name: "psypi-my-id",
    label: "PsyPI My ID",
    description: "Get current agent ID (e.g., S-psypi-psypi)",
    parameters: Type.Object({}),
    async execute(_toolCallId: string, _params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const identity = await AgentIdentityService.getResolvedIdentity();
        return {
          content: [{ type: "text" as const, text: `Agent ID: ${identity.id}` }],
          details: { agentId: identity.id } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-partner-id - Get partner/monitor ID
  pi.registerTool({
    name: "psypi-partner-id",
    label: "PsyPI Partner ID",
    description: "Get partner/monitor ID (permanent God AI, e.g., P-tencent/hy3-preview:free-psypi)",
    parameters: Type.Object({}),
    async execute(_toolCallId: string, _params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const identity = await AgentIdentityService.getResolvedIdentity(true); // true = permanent/partner
        return {
          content: [{ type: "text" as const, text: `Partner ID: ${identity.id}` }],
          details: { partnerId: identity.id } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-my-session-id - Get Pi session ID
  pi.registerTool({
    name: "psypi-my-session-id",
    label: "PsyPI Session ID",
    description: "Get Pi session ID (UUID v7, single source of truth)",
    parameters: Type.Object({}),
    async execute(_toolCallId: string, _params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const sessionID = await kernel.piSessionID();
        return {
          content: [{ type: "text" as const, text: `Session ID: ${sessionID}` }],
          details: { sessionId: sessionID } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-tasks - List tasks
  pi.registerTool({
    name: "psypi-tasks",
    label: "PsyPI Tasks",
    description: "List psypi tasks from database",
    parameters: Type.Object({
      status: Type.Optional(Type.String({ description: "Filter by status (PENDING, COMPLETED, etc.)" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const result = await kernel.getTasks(params.status);
        const tasks = result.rows || [];
        
        if (tasks.length === 0) {
          return {
            content: [{ type: "text" as const, text: "No tasks found." }],
            details: { count: 0 } as Record<string, unknown>,
          };
        }

        const taskList = tasks.slice(0, 10).map((t: any) => 
          `[${t.id.slice(0,8)}] ${t.title} (${t.status}, priority: ${t.priority})`
        ).join("\n");

        return {
          content: [{ type: "text" as const, text: `Found ${tasks.length} tasks:\n${taskList}` }],
          details: { count: tasks.length } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-autonomous - Get autonomous work guidance
  pi.registerTool({
    name: "psypi-autonomous",
    label: "PsyPI Autonomous",
    description: "Get autonomous work guidance - suggests next actions based on pending tasks",
    parameters: Type.Object({
      context: Type.Optional(Type.String({ description: "Current work context or project being worked on" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const result = await kernel.getTasks('PENDING');
        const tasks = result.rows || [];
        
        if (tasks.length === 0) {
          return {
            content: [{ type: "text" as const, text: "No pending tasks. Consider: reviewing recent changes, improving tests, or documentation." }],
            details: { guidance: "no-tasks" } as Record<string, unknown>,
          };
        }

        const highPriority = tasks.filter((t: any) => t.priority >= 8);
        if (highPriority.length > 0) {
          const guidance = `🎯 ${highPriority.length} high-priority tasks:\n` +
            highPriority.slice(0, 3).map((t: any) => `- ${t.title}`).join("\n");
          return {
            content: [{ type: "text" as const, text: guidance }],
            details: { guidance: "high-priority", count: highPriority.length } as Record<string, unknown>,
          };
        }

        const guidance = `📋 ${tasks.length} pending tasks. Start with: ${tasks[0].title}`;
        return {
          content: [{ type: "text" as const, text: guidance }],
          details: { guidance: "pending-tasks", count: tasks.length } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-status - Show psypi status
  pi.registerTool({
    name: "psypi-status",
    label: "PsyPI Status",
    description: "Show psypi status including God in the sky (Gleam review), tools, and database",
    parameters: Type.Object({}),
    async execute(_toolCallId: string, _params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const status = [
          "## PsyPI Status",
          "",
          "**God in the sky**: Gleam review (ACTIVE)",
          "**Architecture**: Gleam core + TypeScript + Pi runtime",
          "**Commit**: Use 'psypi commit' (mandatory Gleam review)",
          "",
          "## Available Pi Tools",
          "- psypi-commit - Git commit with Gleam review",
          "- psypi-my-id - Get your agent ID",
          "- psypi-partner-id - Get partner/monitor ID",
          "- psypi-my-session-id - Get Pi session ID",
          "- psypi-tasks - List tasks",
          "- psypi-autonomous - Get work guidance",
          "- psypi-status - This status message",
        ].join("\n");

        return {
          content: [{ type: "text" as const, text: status }],
          details: { god: "gleam" } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // ===== COMMANDS =====

  pi.registerCommand("psypi-tasks", {
    description: "Check pending tasks",
    handler: async (_args: string, ctx: any) => {
      ctx.ui.notify("Tasks checked", "info");
    },
  });

  pi.registerCommand("psypi-status", {
    description: "Show psypi status",
    handler: async (_args: string, ctx: any) => {
      ctx.ui.notify("PsyPI is running!", "info");
    },
  });
}

// NOTE: Monitor (God in the sky) is NOT here!
// It's in: gleam/psypi_core/src/psypi_core/review.gleam (12 lines!)
// Called via: psypi commit -> InterReviewService -> run_review() from Gleam!
// NEVER REMOVE THAT (as per: "you will never remove the monitor, no way"!)
