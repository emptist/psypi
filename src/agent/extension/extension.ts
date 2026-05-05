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
import { ApiKeyService } from "../../kernel/services/ApiKeyService.js";
import { InterReviewService } from "../../kernel/services/InterReviewService.js";
import { DatabaseClient } from "../../kernel/db/DatabaseClient.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const VERBOSE = process.env.PSYPI_VERBOSE === 'true' || process.env.NODE_ENV !== 'production';

// Set sessionId from Pi ctx before using AgentIdentityService
function setSessionId(ctx: any) {
  AgentIdentityService.sessionId = ctx?.sessionManager?.getSessionId();
}

// Convert Gleam Result for display (calls Gleam utils)
async function formatGleamResult(result: any): Promise<string> {
  try {
    const { result_to_string } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/utils.mjs");
    return result_to_string(result);
  } catch {
    return JSON.stringify(result);
  }
}

// Initialize extension
export default function (pi: ExtensionAPI) {
  if (VERBOSE) {
    console.log(`[PsyPI] Extension loaded (self-sufficient - no external thinkers!)`);
  }

  // Set sessionId once at session start
  pi.on("session_start", async (_event, ctx) => {
    AgentIdentityService.sessionId = ctx?.sessionManager?.getSessionId();
    if (VERBOSE) {
      console.log(`[PsyPI] Session ID: ${AgentIdentityService.sessionId}`);
    }
  });

  // ===== AUTO-BACKUP HOOK: Save files BEFORE AI edits them =====
  pi.on("tool_call", async (event) => {
    if (event.toolName === "edit" || event.toolName === "write") {
      const input = event.input as any;
      const filePath = input?.path;
      if (!filePath) return;

      try {
        const fs = await import('fs');
        if (!fs.existsSync(filePath)) return;

        const crypto = await import('crypto');
        const content = fs.readFileSync(filePath, 'utf-8');
        const hash = crypto.createHash('sha256').update(content).digest('hex');

        // Import Gleam functions
        const { save_version, get_versions } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/code_version.mjs") as any;
        const identity = await AgentIdentityService.getResolvedIdentity();

        // Check if this version already exists (dedup at JS layer)
        const versions = await get_versions(filePath, 50);
        let exists = false;
        if (versions && typeof versions === 'object') {
          const versionList = Array.isArray(versions) ? versions : (versions.rows || []);
          for (const v of versionList) {
            if (v?.version_hash === hash) {
              exists = true;
              break;
            }
          }
        }

        if (exists) {
          if (VERBOSE) console.log(`[Auto-Backup] ⏭ Skipped (already saved): ${filePath}`);
          return; // Already backed up
        }

        // Save new version
        const result = await save_version(filePath, content, identity.id, '', `auto-backup before ${event.toolName}`);
        if (VERBOSE) console.log(`[Auto-Backup] ✅ Saved: ${filePath} (version: ${result})`);

      } catch (err: any) {
        if (VERBOSE) console.log(`[Auto-Backup] ⚠️ Failed: ${err.message}`);
      }
    }
  });

  // ===== CORE TOOLS =====

  // psypi-task-add - Add a new task (calls Gleam task.add)
  pi.registerTool({
    name: "psypi-task-add",
    label: "PsyPI Task Add",
    description: "Add a new task to the database",
    parameters: Type.Object({
      title: Type.String({ description: "Task title" }),
      description: Type.Optional(Type.String({ description: "Task description" })),
      priority: Type.Optional(Type.Number({ description: "Priority (1-10), default: 5" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { add } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/task.mjs");
        const identity = await AgentIdentityService.getResolvedIdentity();
        const result = await add(
          params.title,
          params.description || '',
          params.priority || 5,
          identity.id
        );
        return {
          content: [{ type: "text" as const, text: `Task added: ${formatGleamResult(result)}` }],
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

  // psypi-task-complete - Complete a task (calls Gleam task.complete)
  pi.registerTool({
    name: "psypi-task-complete",
    label: "PsyPI Task Complete",
    description: "Mark a task as completed",
    parameters: Type.Object({
      taskId: Type.String({ description: "Task ID (UUID)" }),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { complete } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/task.mjs");
        const result = await complete(params.taskId);
        return {
          content: [{ type: "text" as const, text: `Task completed: ${formatGleamResult(result)}` }],
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

  // psypi-skill-build - Build a new skill (calls Gleam skill.create)
  pi.registerTool({
    name: "psypi-skill-build",
    label: "PsyPI Skill Build",
    description: "Build a new skill",
    parameters: Type.Object({
      name: Type.String({ description: "Skill name" }),
      purpose: Type.String({ description: "Skill purpose/description" }),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { create } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/skill.mjs");
        const identity = await AgentIdentityService.getResolvedIdentity();
        const result = await create(
          params.name,
          params.purpose,
          identity.id
        );
        return {
          content: [{ type: "text" as const, text: `Skill created: ${formatGleamResult(result)}` }],
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

  // psypi-learn - Save a learning to memory (calls Gleam)
  pi.registerTool({
    name: "psypi-learn",
    label: "PsyPI Learn",
    description: "Save a learning to memory",
    parameters: Type.Object({
      content: Type.String({ description: "Learning content" }),
      importance: Type.Optional(Type.Number({ description: "Importance (1-10), default: 5" })),
      tags: Type.Optional(Type.String({ description: "Comma-separated tags" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { save } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/learning.mjs");
        const identity = await AgentIdentityService.getResolvedIdentity();
        const tags = params.tags ? params.tags.split(',').map((t: string) => t.trim()) : ['learning'];
        const result = await save(
          params.content,
          tags,
          params.importance || 5,
          identity.id
        );
        return {
          content: [{ type: "text" as const, text: `Learning saved: ${formatGleamResult(result)}` }],
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

  // psypi-announce - Announce to all AIs
  pi.registerTool({
    name: "psypi-announce",
    label: "PsyPI Announce",
    description: "Announce a message to all AIs",
    parameters: Type.Object({
      message: Type.String({ description: "Announcement message" }),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { send, BroadcastPriority$High } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/broadcast.mjs");
        const identity = await AgentIdentityService.getResolvedIdentity();
        const result = await send(
          identity.id,
          params.message,
          BroadcastPriority$High()
        );
        return {
          content: [{ type: "text" as const, text: `Announcement sent: ${formatGleamResult(result)}` }],
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

  // psypi-inter-review-request - Request an inter-review (Using Gleam!)
  pi.registerTool({
    name: "psypi-inter-review-request",
    label: "PsyPI Inter-Review Request",
    description: "Request an inter-review for a task",
    parameters: Type.Object({
      taskId: Type.String({ description: "Task ID (UUID)" }),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        // Import Gleam modules dynamically
        const { Some, None } = await import("/Users/jk/gits/hub/tools_ai/psypi/gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam/option.mjs");
        const { request_review } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/inter_review.mjs");
        const currentIdentity = await AgentIdentityService.getResolvedIdentity();
        
        // Create Gleam Option values using the class constructors
        const taskIdOption = params.taskId ? new Some(params.taskId) : new None();
        const commitHashOption = new None(); // No commit hash for now
        
        // Call Gleam function
        const result = await request_review(
          taskIdOption,
          commitHashOption,
          currentIdentity.id,
          "Requested via psypi-inter-review-request"
        );
        
        // Handle Gleam Result type: { Ok: value } or { Error: error }
        if (result.Ok !== undefined) {
          const reviewId = result.Ok;
          return {
            content: [{ type: "text" as const, text: `Inter-review requested: ${reviewId}` }],
            details: { reviewId } as Record<string, unknown>,
          };
        } else {
          const error = result.Error;
          return {
            content: [{ type: "text" as const, text: `Error: ${JSON.stringify(error)}` }],
            details: { error: true, details: error } as Record<string, unknown>,
          };
        }
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-inter-reviews - List inter-reviews
  pi.registerTool({
    name: "psypi-inter-reviews",
    label: "PsyPI Inter-Reviews",
    description: "List inter-reviews (optional status filter)",
    parameters: Type.Object({
      status: Type.Optional(Type.String({ description: "Filter by status (pending/completed)" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const db = DatabaseClient.getInstance();
        let query = 'SELECT * FROM inter_reviews ORDER BY created_at DESC LIMIT 50';
        let values: any[] = [];
        if (params.status) {
          query = 'SELECT * FROM inter_reviews WHERE status = $1 ORDER BY created_at DESC LIMIT 50';
          values = [params.status];
        }
        const result = await db.query(query, values);
        return {
          content: [{ type: "text" as const, text: `Inter-reviews: ${JSON.stringify(result.rows)}` }],
          details: { result: result.rows } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-inter-review-show - Show inter-review details
  pi.registerTool({
    name: "psypi-inter-review-show",
    label: "PsyPI Inter-Review Show",
    description: "Show details of a specific inter-review",
    parameters: Type.Object({
      reviewId: Type.String({ description: "Review ID (UUID)" }),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const db = DatabaseClient.getInstance();
        const result = await db.query(
          'SELECT * FROM inter_reviews WHERE id = $1',
          [params.reviewId]
        );
        if (result.rows.length === 0) {
          return {
            content: [{ type: "text" as const, text: `Review not found: ${params.reviewId}` }],
            details: { error: true } as Record<string, unknown>,
          };
        }
        return {
          content: [{ type: "text" as const, text: `Inter-review: ${JSON.stringify(result.rows[0])}` }],
          details: { result: result.rows[0] } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-validate-commit - Validate a commit message (calls Gleam)
  pi.registerTool({
    name: "psypi-validate-commit",
    label: "PsyPI Validate Commit",
    description: "Validate a commit message format",
    parameters: Type.Object({
      message: Type.String({ description: "Commit message to validate" }),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { validate } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/validation.mjs");
        const result = await validate(params.message);
        return {
          content: [{ type: "text" as const, text: `Validation: ${formatGleamResult(result)}` }],
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

  // psypi-tools - List available tools
  pi.registerTool({
    name: "psypi-tools",
    label: "PsyPI Tools",
    description: "List all available tools",
    parameters: Type.Object({}),
    async execute(_toolCallId: string, _params: any, _signal?: AbortSignal, _onUpdate?: any, ctx?: any) {
      try {
        const tools = ctx?.toolManager?.getTools() || [];
        const toolList = tools.map((t: any) => `- ${t.name}: ${t.description || 'No description'}`).join('\n');
        return {
          content: [{ type: "text" as const, text: `Available tools:\n${toolList}` }],
          details: { count: tools.length } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-agents - List agents from database (calls Gleam)
  pi.registerTool({
    name: "psypi-agents",
    label: "PsyPI Agents",
    description: "List all agents from database",
    parameters: Type.Object({}),
    async execute(_toolCallId: string, _params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { list } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/agents.mjs");
        const result = await list();
        return {
          content: [{ type: "text" as const, text: `Agents: ${formatGleamResult(result)}` }],
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
        const { execute } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/execute_cmd.mjs");
        const verifyFlag = params.noVerify ? "--no-verify" : "";
        const cmd = `psypi commit "${params.message}" ${verifyFlag}`;
        const result = await execute(cmd, 30000);
        if (result.isOk()) {
          return {
            content: [{ type: "text" as const, text: result[0].stdout || '' }],
            details: { success: true } as Record<string, unknown>,
          };
        } else {
          return {
            content: [{ type: "text" as const, text: `Error: ${JSON.stringify(result[0])}` }],
            details: { error: true } as Record<string, unknown>,
          };
        }
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
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
        const { get_current } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/identity.mjs");
        const sessionId = _ctx?.sessionManager?.getSessionId() || process.env.AGENT_SESSION_ID || '';
        const result = await get_current(sessionId);
        if (result.isOk()) {
          return {
            content: [{ type: "text" as const, text: `Agent ID: ${result[0].id}` }],
            details: { agentId: result[0].id } as Record<string, unknown>,
          };
        } else {
          return {
            content: [{ type: "text" as const, text: `Error: ${JSON.stringify(result[0])}` }],
            details: { error: true } as Record<string, unknown>,
          };
        }
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
        const { get_partner } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/identity.mjs");
        const result = await get_partner();
        if (result.isOk()) {
          return {
            content: [{ type: "text" as const, text: `Partner ID: ${result[0].id}` }],
            details: { partnerId: result[0].id } as Record<string, unknown>,
          };
        } else {
          return {
            content: [{ type: "text" as const, text: `Error: ${JSON.stringify(result[0])}` }],
            details: { error: true } as Record<string, unknown>,
          };
        }
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-monitor-model - Show Monitor AI model (calls Gleam)
  pi.registerTool({
    name: "psypi-monitor-model",
    label: "PsyPI Monitor Model",
    description: "Show the current Monitor AI model (the permanent reviewer AI)",
    parameters: Type.Object({}),
    async execute(_toolCallId: string, _params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { get_model } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/monitor.mjs");
        const result = await get_model();
        return {
          content: [{ type: "text" as const, text: `Monitor model: ${formatGleamResult(result)}` }],
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

  // psypi-monitor-set-model - Set Monitor AI model (calls Gleam)
  pi.registerTool({
    name: "psypi-monitor-set-model",
    label: "PsyPI Monitor Set Model",
    description: "Set the Monitor AI model (the permanent reviewer AI)",
    parameters: Type.Object({
      provider: Type.Optional(Type.String({ description: "Provider name (e.g., openrouter, ollama)" })),
      model: Type.Optional(Type.String({ description: "Model name (e.g., tencent/hy3-preview:free)" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const monitorModule = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/monitor.mjs");
        
        // If no provider, show current model
        if (!params.provider) {
          const result = await monitorModule.get_model();
          return {
            content: [{ type: "text" as const, text: `Monitor model: ${formatGleamResult(result)}` }],
            details: { result } as Record<string, unknown>,
          };
        }
        
        // Set model
        const { Some, None } = await import("../../../gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam/option.mjs");
        const modelOpt = params.model ? new Some(params.model) : new None();
        const result = await monitorModule.set_model(params.provider, modelOpt);
        return {
          content: [{ type: "text" as const, text: `Monitor model set: ${formatGleamResult(result)}` }],
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

  // psypi-monitor-review - Run Monitor AI review
  pi.registerTool({
    name: "psypi-monitor-review",
    label: "PsyPI Monitor Review",
    description: "Run a code review by the Monitor AI (permanent reviewer). Reviews the current git commit.",
    parameters: Type.Object({
      prompt: Type.Optional(Type.String({ description: "Custom review prompt (optional)" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const db = DatabaseClient.getInstance();
        const reviewService = await InterReviewService.create(db);
        const currentIdentity = await AgentIdentityService.getResolvedIdentity();

        const { getGitHash, getGitBranch, getGitDiff, getLastCommitMessage } = await import("../../kernel/utils/git.js");
        const commitHash = await getGitHash();
        const branch = await getGitBranch() || 'main';
        const commitMessage = getLastCommitMessage() || '';
        const diff = getGitDiff();
        const files = diff ? diff.split('\n') : [];

        const request = {
          commitHash: commitHash || undefined,
          branch,
          reviewerId: currentIdentity.id,
          context: {
            message: commitMessage,
            files,
          },
        };

        const reviewId = await reviewService.requestReview(request, false);

        const prompt = params.prompt || `You are a senior code reviewer with expertise in TypeScript, Node.js, and software best practices. Be constructive and thorough. Focus on: correctness, maintainability, test coverage, and preventing loop script pollution.`;
        const result = await reviewService.performReview(reviewId, prompt);

        const output = [
          `## Monitor AI Review Completed`,
          ``,
          `**Review ID**: ${reviewId}`,
          `**Score**: ${result.overallScore}/100`,
          `**Code Quality**: ${result.codeQualityScore}/100`,
          `**Test Coverage**: ${result.testCoverageScore}/100`,
          ``,
          `### Summary`,
          result.summary,
          ``,
        ];

        if (result.findings.length > 0) {
          output.push(`### Findings (${result.findings.length})`);
          for (const finding of result.findings) {
            output.push(`- [${finding.severity.toUpperCase()}] ${finding.message}`);
            if (finding.file) {
              output.push(`  File: ${finding.file}${finding.line ? ':' + finding.line : ''}`);
            }
          }
        }

        return {
          content: [{ type: "text" as const, text: output.join('\n') }],
          details: { reviewId, score: result.overallScore, findings: result.findings.length } as Record<string, unknown>,
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
        // Call Gleam task.list() - returns Result(List(Task), TaskError)
        const { list } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/task.mjs") as any;
        const { Some, None } = await import("../../../gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam/option.mjs");

        const status = params.status ? new Some(params.status) : new None();
        const result = await list(status);

        // Handle Gleam Result type
        if (result && typeof result.isOk === 'function' && !result.isOk()) {
          const errorMsg = result?.[0] || 'Failed to list tasks';
          return {
            content: [{ type: "text" as const, text: `Error: ${errorMsg}` }],
            details: { error: true } as Record<string, unknown>,
          };
        }

        const tasks = result && typeof result.isOk === 'function' && result.isOk() 
          ? (Array.isArray(result?.['0']) ? result?.['0'] : (result?.['0'] ? [result?.['0']] : []))
          : [];

        if (tasks.length === 0) {
          return {
            content: [{ type: "text" as const, text: "No tasks found." }],
            details: { count: 0 } as Record<string, unknown>,
          };
        }

        const taskList = tasks.slice(0, 10).map((t: any) =>
          `[${t.id?.slice(0, 8)}] ${t.title} (${t.status}, priority: ${t.priority})`
        ).join("\n");

        return {
          content: [{ type: "text" as const, text: `Found ${tasks.length} tasks:\n${taskList}` }],
          details: { count: tasks.length, tasks: tasks.slice(0, 10) } as Record<string, unknown>,
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
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, ctx?: any) {
      try {
        setSessionId(ctx);

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

  // psypi-doc-list - List file versions
  pi.registerTool({
    name: "psypi-doc-list",
    label: "PsyPI Doc List",
    description: "List saved versions of a file",
    parameters: Type.Object({
      file_path: Type.String({ description: "File path to list versions for" }),
      limit: Type.Optional(Type.Number({ description: "Max number of versions (default: 10)" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { get_versions } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/code_version.mjs") as any;
        const result = await get_versions(params.file_path, params.limit || 10);
        return {
          content: [{ type: "text" as const, text: `Versions: ${formatGleamResult(result)}` }],
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

  // psypi-doc-restore - Restore a file version
  pi.registerTool({
    name: "psypi-doc-restore",
    label: "PsyPI Doc Restore",
    description: "Restore a specific version of a file",
    parameters: Type.Object({
      version_id: Type.String({ description: "Version ID (UUID) to restore" }),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { restore_version } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/code_version.mjs") as any;
        const result = await restore_version(params.version_id);
        return {
          content: [{ type: "text" as const, text: `Restored version: ${formatGleamResult(result)}` }],
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

  // ===== STATS TOOLS =====

  // psypi-stats - Show ecosystem stats
  pi.registerTool({
    name: "psypi-stats",
    label: "PsyPI Stats",
    description: "Show ecosystem stats (tasks, issues, skills, etc.)",
    parameters: Type.Object({}),
    async execute(_toolCallId: string, _params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        // Now using Gleam stats.gleam core!
        const { stats } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/stats.mjs") as any;
        const result = await stats();
        return {
          content: [{ type: "text" as const, text: `Stats: ${formatGleamResult(result)}` }],
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

  // psypi-visits - Show recent visits
  pi.registerTool({
    name: "psypi-visits",
    label: "PsyPI Visits",
    description: "Show recent visits",
    parameters: Type.Object({
      limit: Type.Optional(Type.Number({ description: "Max number of visits (default: 10)" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        // TODO: Migrate to Gleam visits.gleam
        const { Pool } = await import('pg');
        const pool = new Pool({ connectionString: process.env.DATABASE_URL });
        const result = await pool.query(
          'SELECT * FROM visits ORDER BY visited_at DESC LIMIT $1',
          [params.limit || 10]
        );
        await pool.end();
        return {
          content: [{ type: "text" as const, text: `Visits: ${JSON.stringify(result.rows)}` }],
          details: { result: result.rows } as Record<string, unknown>,
        };
      } catch (err: any) {
        return {
          content: [{ type: "text" as const, text: `Error: ${err.message}` }],
          details: { error: true } as Record<string, unknown>,
        };
      }
    },
  });

  // psypi-project - Show project info
  pi.registerTool({
    name: "psypi-project",
    label: "PsyPI Project",
    description: "Show current project info",
    parameters: Type.Object({}),
    async execute(_toolCallId: string, _params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { read_package_json } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/package_json.mjs");
        const result = await read_package_json();
        if (result.isOk()) {
          return {
            content: [{ type: "text" as const, text: `Project: ${JSON.stringify(result[0])}` }],
            details: { result: result[0] } as Record<string, unknown>,
          };
        } else {
          return {
            content: [{ type: "text" as const, text: `Error: ${JSON.stringify(result[0])}` }],
            details: { error: true } as Record<string, unknown>,
          };
        }
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
          content: [{ type: "text" as const, text: `Meetings: ${formatGleamResult(result)}` }],
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
          content: [{ type: "text" as const, text: `Meeting: ${formatGleamResult(result)}` }],
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
          content: [{ type: "text" as const, text: `Opinion added: ${formatGleamResult(result)}` }],
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
          content: [{ type: "text" as const, text: `Skills: ${formatGleamResult(result)}` }],
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
          content: [{ type: "text" as const, text: `Skill: ${formatGleamResult(result)}` }],
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
          content: [{ type: "text" as const, text: `Search results: ${formatGleamResult(result)}` }],
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

  // ===== ISSUE TOOLS =====

  // psypi-issue-add - Add a new issue
  pi.registerTool({
    name: "psypi-issue-add",
    label: "PsyPI Issue Add",
    description: "Add a new issue to the database",
    parameters: Type.Object({
      title: Type.String({ description: "Issue title" }),
      description: Type.Optional(Type.String({ description: "Issue description" })),
      severity: Type.Optional(Type.String({ description: "Severity: low, medium, high, critical" })),
      issue_type: Type.Optional(Type.String({ description: "Type: bug, feature, task, etc." })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { add } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/issue.mjs");
        const identity = await AgentIdentityService.getResolvedIdentity();
        const result = await add(
          params.title,
          params.description || '',
          params.severity || 'medium',
          params.issue_type || 'bug',
          identity.id
        );
        return {
          content: [{ type: "text" as const, text: `Issue added: ${formatGleamResult(result)}` }],
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

  // psypi-issue-list - List issues
  pi.registerTool({
    name: "psypi-issue-list",
    label: "PsyPI Issue List",
    description: "List issues (optional status filter: PENDING, RESOLVED, CLOSED)",
    parameters: Type.Object({
      status: Type.Optional(Type.String({ description: "Filter by status (PENDING/RESOLVED/CLOSED)" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { list } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/issue.mjs");
        // Import None from gleam/option for no filter
        const { None } = await import("../../../gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam/option.mjs");
        const result = await list(params.status ? (() => {
          // Construct Some(status)
          const { Some } = require("../../../gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam/option.mjs");
          return new Some(params.status);
        })() : new None());
        return {
          content: [{ type: "text" as const, text: `Issues: ${formatGleamResult(result)}` }],
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

  // psypi-issue-resolve - Resolve an issue
  pi.registerTool({
    name: "psypi-issue-resolve",
    label: "PsyPI Issue Resolve",
    description: "Resolve an issue with a resolution note",
    parameters: Type.Object({
      issue_id: Type.String({ description: "Issue ID (UUID)" }),
      resolution: Type.String({ description: "Resolution description" }),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { resolve } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/issue.mjs");
        const result = await resolve(params.issue_id, params.resolution);
        return {
          content: [{ type: "text" as const, text: `Issue resolved: ${formatGleamResult(result)}` }],
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

  // ===== BROADCAST TOOLS =====

  // psypi-broadcast-send - Send a broadcast message
  pi.registerTool({
    name: "psypi-broadcast-send",
    label: "PsyPI Broadcast Send",
    description: "Send a broadcast message to other agents",
    parameters: Type.Object({
      message: Type.String({ description: "Message to broadcast" }),
      priority: Type.Optional(Type.String({ description: "Priority: low, normal, high" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { send } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/broadcast.mjs");
        const identity = await AgentIdentityService.getResolvedIdentity();

        // Import Option types
        const { Some, None } = await import("../../../gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam/option.mjs");

        // Construct priority as Option type
        const priority = params.priority ? new Some(params.priority) : new None();

        const result = await send(
          identity.id,
          params.message,
          priority
        );
        return {
          content: [{ type: "text" as const, text: `Broadcast sent: ${formatGleamResult(result)}` }],
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

  // psypi-broadcast-list - List broadcasts for current agent
  pi.registerTool({
    name: "psypi-broadcast-list",
    label: "PsyPI Broadcast List",
    description: "List broadcast messages for current agent",
    parameters: Type.Object({
      limit: Type.Optional(Type.Number({ description: "Max number of messages (default: 10)" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const { list } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/broadcast.mjs") as any;
        const identity = await AgentIdentityService.getResolvedIdentity();

        // Import Option types for agent_id
        const { Some } = await import("../../../gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam/option.mjs");

        // agent_id is Option<String>, limit is number
        const result = await list(new Some(identity.id), params.limit || 10);
        return {
          content: [{ type: "text" as const, text: `Broadcasts: ${formatGleamResult(result)}` }],
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
          content: [{ type: "text" as const, text: `Reflection saved: ${formatGleamResult(result)}` }],
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

  // psypi-doc-query - Query code_versions table for AI discussions
  pi.registerTool({
    name: "psypi-doc-query",
    label: "PsyPI Doc Query",
    description: "Query code_versions table - AIs discuss code without workspaces!",
    parameters: Type.Object({
      file_path: Type.Optional(Type.String({ description: "File path pattern (SQL LIKE syntax)" })),
      saved_by: Type.Optional(Type.String({ description: "Agent ID (saved_by)" })),
      search_content: Type.Optional(Type.String({ description: "Search within file content" })),
      limit: Type.Optional(Type.Number({ description: "Max results (default: 10)" })),
    }),
    async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
      try {
        const db = DatabaseClient.getInstance();
        let query = `
          SELECT 
            id, file_path, saved_by, saved_at, 
            LEFT(content, 200) as content_preview,
            LENGTH(content) as content_length
          FROM code_versions
          WHERE 1=1
        `;
        const values: any[] = [];
        let paramCount = 0;

        if (params.file_path) {
          paramCount++;
          query += ` AND file_path LIKE $${paramCount}`;
          values.push('%' + params.file_path + '%');
        }

        if (params.saved_by) {
          paramCount++;
          query += ` AND saved_by = $${paramCount}`;
          values.push(params.saved_by);
        }

        if (params.search_content) {
          paramCount++;
          query += ` AND content LIKE $${paramCount}`;
          values.push('%' + params.search_content + '%');
        }

        paramCount++;
        query += ` ORDER BY saved_at DESC LIMIT $${paramCount}`;
        values.push(params.limit || 10);

        const result = await db.query(query, values);
        
        if (!result.rows || result.rows.length === 0) {
          return {
            content: [{ type: "text" as const, text: "No results found" }],
            details: { count: 0 } as Record<string, unknown>,
          };
        }

        const text = result.rows.map((row: any) => 
          `File: ${row.file_path}\nSaved by: ${row.saved_by}\nSaved at: ${row.saved_at}\nPreview: ${row.content_preview}...\n`
        ).join("\n---\n");

        return {
          content: [{ type: "text" as const, text: `Found ${result.rows.length} versions:\n\n${text}` }],
          details: { count: result.rows.length, rows: result.rows } as Record<string, unknown>,
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
