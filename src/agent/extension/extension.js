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

  // ... (more tools can be added following this pattern)

  if (VERBOSE) {
    console.log(`[PsyPI] All tools registered!`);
  }
}
