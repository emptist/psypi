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

  // ===== DOCUMENT TOOLS =====

  // psypi-doc-save - Save a file version to database (auto-backup before AI edits)
  pi.registerTool({
    name: "psypi-doc-save",
    label: "PsyPI Doc Save",
    description: "Save a file version to code_versions table (auto-backup before AI edits)",
    parameters: Type.Object({
      file_path: Type.String({ description: "File path to save" }),
      content: Type.String({ description: "File content (leave empty to read from disk)" }),
      reason: Type.Optional(Type.String({ description: "Reason for saving (e.g., 'before AI edit', 'pre-disaster backup')" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        // Import compiled Gleam module
        const { save_version } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/code_version.mjs");
        
        // Get file content if not provided
        let content = params.content;
        if (!content) {
          const fs = await import('fs');
          content = fs.readFileSync(params.file_path, 'utf-8');
        }
        
        // Get agent ID
        const identity = await AgentIdentityService.getResolvedIdentity();
        
        // Call Gleam function
        const result = await save_version(
          params.file_path,
          content,
          identity.id,
          '', // commit_hash (optional)
          params.reason || 'manual save'
        );
        
        return {
          content: [{ type: "text" as const, text: `Saved version: ${result}` }],
          details: { versionId: result } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // ===== MEETING TOOLS =====

  // psypi-meeting-list - List meetings
  pi.registerTool({
    name: "psypi-meeting-list",
    label: "PsyPI Meeting List",
    description: "List meetings (optional status filter: pending, active, completed, cancelled)",
    parameters: Type.Object({
      status: Type.Optional(Type.String({ description: "Filter by status (pending/active/completed/cancelled)" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { list } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/meeting.mjs");
        const result = await list(params.status || '');
        return {
          content: [{ type: "text" as const, text: `Meetings: ${JSON.stringify(result)}` }],
          details: { result } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-meeting-show - Show a meeting
  pi.registerTool({
    name: "psypi-meeting-show",
    label: "PsyPI Meeting Show",
    description: "Show details of a specific meeting",
    parameters: Type.Object({
      meeting_id: Type.String({ description: "Meeting ID (UUID)" }),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { get } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/meeting.mjs");
        const result = await get(params.meeting_id);
        return {
          content: [{ type: "text" as const, text: `Meeting: ${JSON.stringify(result)}` }],
          details: { result } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-meeting-say - Add opinion to meeting
  pi.registerTool({
    name: "psypi-meeting-say",
    label: "PsyPI Meeting Say",
    description: "Add your opinion to a meeting",
    parameters: Type.Object({
      meeting_id: Type.String({ description: "Meeting ID (UUID)" }),
      perspective: Type.String({ description: "Your perspective/opinion" }),
      reasoning: Type.Optional(Type.String({ description: "Reasoning behind your opinion" })),
      vote: Type.Optional(Type.String({ description: "Vote (yes/no/abstain)" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { add_opinion } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/meeting.mjs");
        const identity = await AgentIdentityService.getResolvedIdentity();
        const result = await add_opinion(
          params.meeting_id,
          identity.id,
          params.perspective,
          params.reasoning || '',
          params.vote || ''
        );
        return {
          content: [{ type: "text" as const, text: `Opinion added: ${JSON.stringify(result)}` }],
          details: { result } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // ===== SKILL TOOLS =====

  // psypi-skill-list - List skills
  pi.registerTool({
    name: "psypi-skill-list",
    label: "PsyPI Skill List",
    description: "List all approved skills",
    parameters: Type.Object({}),
    async execute(_toolCallId: string, _params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const skill = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/skill.mjs");
        // Import None class from gleam/option
        const { None } = await import("../../../gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam/option.mjs");
        // List all skills (None = no status filter)
        const result = await skill.list(new None());
        return {
          content: [{ type: "text" as const, text: `Skills: ${JSON.stringify(result)}` }],
          details: { result } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-skill-show - Show skill details
  pi.registerTool({
    name: "psypi-skill-show",
    label: "PsyPI Skill Show",
    description: "Show details of a specific skill",
    parameters: Type.Object({
      name: Type.String({ description: "Skill name" }),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { get } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/skill.mjs");
        const result = await get(params.name);
        return {
          content: [{ type: "text" as const, text: `Skill: ${JSON.stringify(result)}` }],
          details: { result } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-skill-search - Search skills
  pi.registerTool({
    name: "psypi-skill-search",
    label: "PsyPI Skill Search",
    description: "Search skills by keyword",
    parameters: Type.Object({
      query: Type.String({ description: "Search query" }),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { search } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/skill.mjs");
        const result = await search(params.query);
        return {
          content: [{ type: "text" as const, text: `Search results: ${JSON.stringify(result)}` }],
          details: { result } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // ===== REFLECTION TOOLS =====

  // psypi-areflect - Reflection with auto-parse
  pi.registerTool({
    name: "psypi-areflect",
    label: "PsyPI Reflect",
    description: "Reflection with auto-parse: [LEARN] [ISSUE] [TASK] tags",
    parameters: Type.Object({
      text: Type.String({ description: "Reflection text with [LEARN] [ISSUE] [TASK] tags" }),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { areflect } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/areflect.mjs");
        const identity = await AgentIdentityService.getResolvedIdentity();
        const result = await areflect(params.text, identity.id);
        return {
          content: [{ type: "text" as const, text: `Reflection saved: ${JSON.stringify(result)}` }],
          details: { result } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // ===== STATUS TOOLS =====

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
