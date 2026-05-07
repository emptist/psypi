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
import { create as meeting_create, list as meeting_list, get as meeting_get, add_opinion as meeting_add_opinion, list_opinions as meeting_list_opinions, complete as meeting_complete } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/meeting.mjs";

// Import thin JS wrappers (for services that still need TS layer)
import { AgentIdentityService } from "../../../src/kernel/services/AgentIdentityService.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const VERBOSE = process.env.PSYPI_VERBOSE === 'true' || process.env.NODE_ENV !== 'production';

// Helper to extract Gleam Result values
function unwrapGleamResult(result) {
  if (!result) return { ok: false, error: 'null result' };
  const typeName = result.constructor?.name || '';
  if (typeName === 'Ok') {
    return { ok: true, value: result['0'] };
  }
  if (typeName === 'Error') {
    const err = result['0'];
    return { ok: false, error: err?.['0'] || err?.toString() || 'Unknown error' };
  }
  return { ok: true, value: result };
}

// Helper to get identity with proper parameters
async function getIdentity(permanent = false, ctx) {
  const sessionId = (ctx?.sessionManager?.getSessionId()) || AgentIdentityService.sessionId || '';
  const source = process.env.PSYPI_AGENT_SOURCE || 'psypi';
  const project = 'psypi';
  
  // Get git hash
  let gitHash = '';
  try {
    const { execSync } = await import('child_process');
    gitHash = execSync('git rev-parse HEAD', { cwd: __dirname + '/../../..' }).toString().trim();
  } catch {}
  
  const machineFingerprint = process.env.HOSTNAME || process.env.COMPUTERNAME || 'unknown';
  const model = ctx?.model?.id || process.env.PSYPI_MODEL || '';
  
  const result = await get_resolved_identity(permanent, sessionId, project, gitHash, machineFingerprint, source, model);
  return unwrapGleamResult(result);
}

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
    async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
      const result = await getIdentity(false, ctx);
      if (!result.ok) {
        return { content: [{ type: "text", text: `Error: ${result.error}` }] };
      }
      return { content: [{ type: "text", text: `My ID: ${result.value.id}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-partner-id",
    description: "Get partner/monitor ID (permanent God AI, e.g., P-tencent/hy3-preview:free-psypi)",
    parameters: {},
    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
      const identity = await AgentIdentityService.getResolvedIdentity(true);
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
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await task_add(params.title, params.description || "", params.priority || 5);
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
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await skill_build(params.name, params.purpose);
      return { content: [{ type: "text", text: `Skill created: ${result}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-skill-list",
    description: "List all approved skills",
    parameters: {},
    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
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
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await skill_show(params.name);
      return { content: [{ type: "text", text: `Skill: ${JSON.stringify(result)}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-skill-search",
    description: "Search skills by keyword",
    parameters: {
      query: { type: "string" },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await skill_search(params.query);
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
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await issue_add(params.title, params.description || "", params.issue_type || "bug", params.severity || "medium");
      return { content: [{ type: "text", text: `Issue added! ID: ${result}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-issue-list",
    description: "List issues (optional status filter)",
    parameters: {
      status: { type: "string", optional: true },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await issue_list(params.status || null);
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
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await issue_resolve(params.issue_id, params.resolution);
      return { content: [{ type: "text", text: `Issue resolved! ${result}` }] };
    }
  });

  // Monitor AI tools
  pi.registerTool({
    name: "psypi-monitor-health",
    description: "Check system health",
    parameters: {},
    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
      const result = await check_system_health();
      return { content: [{ type: "text", text: `Health: ${JSON.stringify(result)}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-monitor-housekeeping",
    description: "Run housekeeping tasks",
    parameters: {},
    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
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
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await learn(params.content, params.importance || 5, params.tags || "");
      return { content: [{ type: "text", text: `Learning saved! ${result}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-areflect",
    description: "Reflection with auto-parse: [LEARN] [ISSUE] [TASK] tags",
    parameters: {
      text: { type: "string" },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await areflect(params.text);
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
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await broadcast_send(params.message, params.priority || "normal");
      return { content: [{ type: "text", text: `Broadcast sent! ${result}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-broadcast-list",
    description: "List broadcast messages for current agent",
    parameters: {
      limit: { type: "number", optional: true },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await broadcast_list(params.limit || 10);
      return { content: [{ type: "text", text: `Messages: ${JSON.stringify(result)}` }] };
    }
  });

  // Inter-review tools
  pi.registerTool({
    name: "psypi-meeting-create",
    description: "Create a new meeting",
    parameters: {
      topic: { type: "string" },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const identityResult = await getIdentity(false, _ctx);
      if (!identityResult.ok) {
        return { content: [{ type: "text", text: `Error: Could not get identity: ${identityResult.error}` }] };
      }
      const result = await meeting_create(params.topic, identityResult.value.id);
      const meetingResult = unwrapGleamResult(result);
      if (!meetingResult.ok) {
        return { content: [{ type: "text", text: `Error creating meeting: ${meetingResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Meeting created! ID: ${meetingResult.value}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-meeting-list",
    description: "List meetings (optional status filter: pending, active, completed, cancelled)",
    parameters: {
      status: { type: "string", optional: true },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await meeting_list(params.status || null);
      return { content: [{ type: "text", text: `Meetings: ${JSON.stringify(result)}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-meeting-get",
    description: "Get details of a specific meeting",
    parameters: {
      meeting_id: { type: "string" },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await meeting_get(params.meeting_id);
      const meetingResult = unwrapGleamResult(result);
      if (!meetingResult.ok) {
        return { content: [{ type: "text", text: `Error: ${meetingResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Meeting: ${JSON.stringify(meetingResult.value)}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-meeting-add-opinion",
    description: "Add opinion to a meeting",
    parameters: {
      meeting_id: { type: "string" },
      perspective: { type: "string" },
      reasoning: { type: "string", optional: true },
      vote: { type: "string", optional: true },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const identity = await get_resolved_identity();
      const identityResult = unwrapGleamResult(identity);
      if (!identityResult.ok) {
        return { content: [{ type: "text", text: `Error: Could not get identity: ${identityResult.error}` }] };
      }
      const result = await meeting_add_opinion(params.meeting_id, identityResult.value.id, params.perspective, params.reasoning || null, params.vote || null);
      const opinionResult = unwrapGleamResult(result);
      if (!opinionResult.ok) {
        return { content: [{ type: "text", text: `Error adding opinion: ${opinionResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Opinion added! ID: ${opinionResult.value}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-meeting-list-opinions",
    description: "List opinions for a meeting",
    parameters: {
      meeting_id: { type: "string" },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await meeting_list_opinions(params.meeting_id);
      return { content: [{ type: "text", text: `Opinions: ${JSON.stringify(result)}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-meeting-complete",
    description: "Complete a meeting with consensus",
    parameters: {
      meeting_id: { type: "string" },
      consensus: { type: "string" },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await meeting_complete(params.meeting_id, params.consensus);
      const completeResult = unwrapGleamResult(result);
      if (!completeResult.ok) {
        return { content: [{ type: "text", text: `Error completing meeting: ${completeResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Meeting completed! ID: ${completeResult.value}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-inter-review-request",
    description: "Request an inter-review for a task",
    parameters: {
      taskId: { type: "string" },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await inter_review_request(params.taskId);
      return { content: [{ type: "text", text: `Review requested! ${result}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-inter-reviews",
    description: "List inter-reviews (optional status filter)",
    parameters: {
      status: { type: "string", optional: true },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await inter_reviews(params.status || null);
      return { content: [{ type: "text", text: `Reviews: ${JSON.stringify(result)}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-inter-review-show",
    description: "Show details of a specific inter-review",
    parameters: {
      reviewId: { type: "string" },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await inter_review_show(params.reviewId);
      return { content: [{ type: "text", text: `Review: ${JSON.stringify(result)}` }] };
    }
  });

  if (VERBOSE) {
    console.log(`[PsyPI] All tools registered!`);
  }
}
