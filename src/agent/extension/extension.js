// extension.js - Pi TUI Extension for psypi
// MANUAL creation (NOT from .ts) - Pi requires specific structure!
// Uses: export default function (pi: ExtensionAPI) { ... }

import { Type } from "@sinclair/typebox";
import { execSync } from "child_process";
import path from "path";
import { fileURLToPath } from "url";

// Import Gleam-compiled modules (relative paths from this file)
import { get_resolved_identity } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/agent_identity.mjs";
import { add as task_add } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/task.mjs";
import { list as task_list, complete as task_complete } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/task.mjs";
import { add as issue_add, list as issue_list, resolve as issue_resolve } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/issue.mjs";
import { build as skill_build, list as skill_list, show as skill_show, search as skill_search } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/skill.mjs";
import { check_system_health, housekeeping, prepare_context } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/monitor_ai.mjs";
import { learn, areflect } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/learning.mjs";
import { send as broadcast_send, list as broadcast_list } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/broadcast.mjs";
import { request as inter_review_request, list as inter_reviews, show as inter_review_show } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/inter_review.mjs";

// Import thin JS wrappers (for services that still need TS layer)
import { AgentIdentityService } from "../../../src/kernel/services/AgentIdentityService.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const VERBOSE = process.env.PSYPI_VERBOSE === 'true' || process.env.NODE_ENV !== 'production';

// Initialize extension - Pi REQUIRES this structure!
export default function (pi) {
  if (VERBOSE) {
    console.log(`[PsyPI] Extension loaded (using Gleam backend!)`);
  }

  // Set sessionId at session start
  pi.on("session_start", async (_event, ctx) => {
    const sessionId = ctx?.sessionManager?.getSessionId();
    AgentIdentityService.sessionId = sessionId;
    if (VERBOSE) {
      console.log(`[PsyPI] Session ID: ${sessionId}`);
    }
  });

  // ===== AUTO-BACKUP HOOK: Save files BEFORE AI edits them =====
  pi.on("tool_call", async (event) => {
    if (event.toolName === "edit" || event.toolName === "write") {
      const input = event.input;
      const filePath = input?.path;
      if (!filePath) return;

      try {
        const fs = await import('fs');
        if (!fs.existsSync(filePath)) return;

        const crypto = await import('crypto');
        const content = fs.readFileSync(filePath, 'utf-8');
        const hash = crypto.createHash('sha256').update(content).digest('hex');

        // Import Gleam backup functions
        const { save_version } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/code_version.mjs");
        const identity = await get_resolved_identity();

        // Save new version
        await save_version(filePath, content, identity.id, '', `auto-backup before ${event.toolName}`);
        if (VERBOSE) console.log(`[Auto-Backup] ✅ Saved: ${filePath}`);

      } catch (err) {
        if (VERBOSE) console.log(`[Auto-Backup] ⚠️ Failed: ${err.message}`);
      }
    }
  });

  // ===== Pi Tool Registrations =====
  
  // Agent Identity tools
  pi.registerTool({
    name: "psypi-my-id",
    description: "Get current agent ID (e.g., S-psypi-psypi)",
    parameters: {},
    handler: async () => {
      const identity = await get_resolved_identity();
      return { content: [{ type: "text", text: `My ID: ${identity.id}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-partner-id",
    description: "Get partner/monitor ID (permanent God AI, e.g., P-tencent/hy3-preview:free-psypi)",
    parameters: {},
    handler: async () => {
      const identity = await get_resolved_identity(true);
      return { content: [{ type: "text", text: `Partner ID: ${identity.id}` }] };
    }
  });

  // Task tools
  pi.registerTool({
    name: "psypi-task-add",
    description: "Add a new task to the database",
    parameters: {
      title: { type: "string" },
      description: { type: "string", optional: true },
      priority: { type: "number", optional: true },
    },
    handler: async (args) => {
      const result = await task_add(args.title, args.description || "", args.priority || 5);
      return { content: [{ type: "text", text: `Task added! ID: ${result}` }] };
    }
  });

  // Skill tools
  pi.registerTool({
    name: "psypi-skill-build",
    description: "Build a new skill",
    parameters: {
      name: { type: "string" },
      purpose: { type: "string" },
    },
    handler: async (args) => {
      const result = await skill_build(args.name, args.purpose);
      return { content: [{ type: "text", text: `Skill created: ${result}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-skill-list",
    description: "List all approved skills",
    parameters: {},
    handler: async () => {
      const result = await skill_list();
      return { content: [{ type: "text", text: `Skills: ${JSON.stringify(result)}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-skill-show",
    description: "Show details of a specific skill",
    parameters: {
      name: { type: "string" },
    },
    handler: async (args) => {
      const result = await skill_show(args.name);
      return { content: [{ type: "text", text: `Skill: ${JSON.stringify(result)}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-skill-search",
    description: "Search skills by keyword",
    parameters: {
      query: { type: "string" },
    },
    handler: async (args) => {
      const result = await skill_search(args.query);
      return { content: [{ type: "text", text: `Results: ${JSON.stringify(result)}` }] };
    }
  });

  // Issue tools
  pi.registerTool({
    name: "psypi-issue-add",
    description: "Add a new issue to the database",
    parameters: {
      title: { type: "string" },
      description: { type: "string", optional: true },
      issue_type: { type: "string", optional: true },
      severity: { type: "string", optional: true },
    },
    handler: async (args) => {
      const result = await issue_add(args.title, args.description || "", args.issue_type || "bug", args.severity || "medium");
      return { content: [{ type: "text", text: `Issue added! ID: ${result}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-issue-list",
    description: "List issues (optional status filter)",
    parameters: {
      status: { type: "string", optional: true },
    },
    handler: async (args) => {
      const result = await issue_list(args.status || null);
      return { content: [{ type: "text", text: `Issues: ${JSON.stringify(result)}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-issue-resolve",
    description: "Resolve an issue with a resolution note",
    parameters: {
      issue_id: { type: "string" },
      resolution: { type: "string" },
    },
    handler: async (args) => {
      const result = await issue_resolve(args.issue_id, args.resolution);
      return { content: [{ type: "text", text: `Issue resolved! ${result}` }] };
    }
  });

  // Monitor AI tools
  pi.registerTool({
    name: "psypi-monitor-health",
    description: "Check system health",
    parameters: {},
    handler: async () => {
      const result = await check_system_health();
      return { content: [{ type: "text", text: `Health: ${JSON.stringify(result)}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-monitor-housekeeping",
    description: "Run housekeeping tasks",
    parameters: {},
    handler: async () => {
      const result = await housekeeping();
      return { content: [{ type: "text", text: `Housekeeping done! ${result}` }] };
    }
  });

  // Learning tools
  pi.registerTool({
    name: "psypi-learn",
    description: "Save a learning to memory",
    parameters: {
      content: { type: "string" },
      importance: { type: "number", optional: true },
      tags: { type: "string", optional: true },
    },
    handler: async (args) => {
      const result = await learn(args.content, args.importance || 5, args.tags || "");
      return { content: [{ type: "text", text: `Learning saved! ${result}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-areflect",
    description: "Reflection with auto-parse: [LEARN] [ISSUE] [TASK] tags",
    parameters: {
      text: { type: "string" },
    },
    handler: async (args) => {
      const result = await areflect(args.text);
      return { content: [{ type: "text", text: `Reflection saved! ${result}` }] };
    }
  });

  // Broadcast tools
  pi.registerTool({
    name: "psypi-broadcast-send",
    description: "Send a broadcast message to other agents",
    parameters: {
      message: { type: "string" },
      priority: { type: "string", optional: true },
    },
    handler: async (args) => {
      const result = await broadcast_send(args.message, args.priority || "normal");
      return { content: [{ type: "text", text: `Broadcast sent! ${result}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-broadcast-list",
    description: "List broadcast messages for current agent",
    parameters: {
      limit: { type: "number", optional: true },
    },
    handler: async (args) => {
      const result = await broadcast_list(args.limit || 10);
      return { content: [{ type: "text", text: `Messages: ${JSON.stringify(result)}` }] };
    }
  });

  // Inter-review tools
  pi.registerTool({
    name: "psypi-inter-review-request",
    description: "Request an inter-review for a task",
    parameters: {
      taskId: { type: "string" },
    },
    handler: async (args) => {
      const result = await inter_review_request(args.taskId);
      return { content: [{ type: "text", text: `Review requested! ${result}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-inter-reviews",
    description: "List inter-reviews (optional status filter)",
    parameters: {
      status: { type: "string", optional: true },
    },
    handler: async (args) => {
      const result = await inter_reviews(args.status || null);
      return { content: [{ type: "text", text: `Reviews: ${JSON.stringify(result)}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-inter-review-show",
    description: "Show details of a specific inter-review",
    parameters: {
      reviewId: { type: "string" },
    },
    handler: async (args) => {
      const result = await inter_review_show(args.reviewId);
      return { content: [{ type: "text", text: `Review: ${JSON.stringify(result)}` }] };
    }
  });

  if (VERBOSE) {
    console.log(`[PsyPI] All tools registered!`);
  }
}
