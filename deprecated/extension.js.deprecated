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
import { list as task_list, complete as task_complete, get as task_get } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/task.mjs";
import { list as agents_list } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/agents.mjs";
import { add as issue_add, list as issue_list, resolve as issue_resolve } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/issue.mjs";
import { build as skill_build, list as skill_list, get as skill_get, get as skill_show, search as skill_search } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/skill.mjs";
console.log('Imported skill_show:', typeof skill_show);
import { check_system_health, housekeeping, prepare_context } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/monitor_ai.mjs";
import { save as learn } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/learning.mjs";
import { send as broadcast_send, list as broadcast_list } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/broadcast.mjs";
import { request as inter_review_request, list_reviews as inter_reviews, show as inter_review_show } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/inter_review.mjs";
import { validate as commit_validate } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/validation.mjs";
import { create as meeting_create, list as meeting_list, get as meeting_get, add_opinion as meeting_add_opinion, list_opinions as meeting_list_opinions, complete as meeting_complete } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/meeting.mjs";
import { stats } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/stats.mjs";

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
        const identityResult = await getIdentity(false);
        if (!identityResult.ok) {
          if (VERBOSE) console.log(`[Auto-Backup] ⚠️ Failed to get identity: ${identityResult.error}`);
          return;
        }

        // Save new version
        await save_version(filePath, content, identityResult.value.id, '', `auto-backup before ${event.toolName}`);
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

  // Agents tool
  pi.registerTool({
    name: "psypi-agents",
    description: "List all agents in the system",
    parameters: {},
    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
      const result = await agents_list();
      const agentsResult = unwrapGleamResult(result);
      if (!agentsResult.ok) {
        return { content: [{ type: "text", text: `Error listing agents: ${agentsResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Agents: ${JSON.stringify(agentsResult.value)}` }] };
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
      const taskResult = unwrapGleamResult(result);
      if (!taskResult.ok) {
        return { content: [{ type: "text", text: `Error adding task: ${taskResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Task added! ID: ${taskResult.value}` }] };
    }
  });

  // Task complete tool
  pi.registerTool({
    name: "psypi-task-complete",
    description: "Complete a task by ID",
    parameters: {
      taskId: { type: "string" },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await task_complete(params.taskId);
      const taskResult = unwrapGleamResult(result);
      if (!taskResult.ok) {
        return { content: [{ type: "text", text: `Error completing task: ${taskResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Task completed! ${taskResult.value}` }] };
    }
  });

  // Task list tool
  pi.registerTool({
    name: "psypi-tasks",
    description: "List all tasks (optional status filter)",
    parameters: {
      status: { type: "string", optional: true },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await task_list(params.status || null);
      const taskResult = unwrapGleamResult(result);
      if (!taskResult.ok) {
        return { content: [{ type: "text", text: `Error listing tasks: ${taskResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Tasks: ${JSON.stringify(taskResult.value)}` }] };
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
      const skillResult = unwrapGleamResult(result);
      if (!skillResult.ok) {
        return { content: [{ type: "text", text: `Error creating skill: ${skillResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Skill created: ${skillResult.value}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-skill-list",
    description: "List all approved skills",
    parameters: {},
    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
      const result = await skill_list();
      const skillResult = unwrapGleamResult(result);
      if (!skillResult.ok) {
        return { content: [{ type: "text", text: `Error listing skills: ${skillResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Skills: ${JSON.stringify(skillResult.value)}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-skill-show",
    description: "Show details of a specific skill (includes full content if available)",
    parameters: {
      name: { type: "string" },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      try {
        const result = await skill_show(params.name);
        const skillResult = unwrapGleamResult(result);
        if (!skillResult.ok) {
          return { content: [{ type: "text", text: `Error: ${skillResult.error}` }] };
        }
        
        const skill = skillResult.value;
        let output = `📚 Skill: ${skill.name}\n`;
        output += `${'='.repeat(50)}\n`;
        output += `ID: ${skill.id}\n`;
        output += `Description: ${skill.description || 'N/A'}\n`;
        output += `Status: ${skill.status}\n`;
        output += `Version: ${skill.version}\n`;
        output += `Author: ${skill.author || 'N/A'}\n`;
        output += `Safety Score: ${skill.safety_score}\n`;
        output += `Source: ${skill.source}\n`;
        output += `Created: ${skill.created_at}\n`;
        
        if (skill.reference_list) {
          output += `\n📖 Reference List:\n`;
          output += `${skill.reference_list}\n`;
        }
        
        if (skill.content) {
          output += `\n📄 Content (from DB):\n`;
          output += `${'-'.repeat(50)}\n`;
          output += skill.content + '\n';
        } else {
          output += `\n⚠️  No content in DB. Reading from file...\n`;
          // Try to read from disk
          const fs = await import('fs');
          const path = await import('path');
          const skillPath = path.join(process.cwd(), '.pi', 'skills', skill.name, 'SKILL.md');
          try {
            const fileContent = fs.readFileSync(skillPath, 'utf-8');
            output += `${'-'.repeat(50)}\n`;
            output += fileContent + '\n';
          } catch (e) {
            output += `Could not read from ${skillPath}\n`;
          }
        }
        
        return { content: [{ type: "text", text: output }] };
      } catch (err) {
        return { content: [{ type: "text", text: `Error: ${err.message}` }] };
      }
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
      const skillResult = unwrapGleamResult(result);
      if (!skillResult.ok) {
        return { content: [{ type: "text", text: `Error searching skills: ${skillResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Results: ${JSON.stringify(skillResult.value)}` }] };
    }
  });

  // psypi-skill-load tool (Database-First Skill System - Step 3)
  pi.registerTool({
    name: "psypi-skill-load",
    description: "Load skill content from database and save to .pi/skills/ directory",
    parameters: {
      name: { type: "string" },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      try {
        const result = await skill_get(params.name);
        const skillResult = unwrapGleamResult(result);
        if (!skillResult.ok) {
          return { content: [{ type: "text", text: `Error: ${skillResult.error}` }] };
        }
        
        const skill = skillResult.value;
        const fs = await import('fs');
        const path = await import('path');
        
        // Create directory: .pi/skills/<name>/
        const skillDir = path.join(process.cwd(), '.pi', 'skills', params.name);
        fs.mkdirSync(skillDir, { recursive: true });
        
        // Write SKILL.md from database content
        if (skill.content) {
          fs.writeFileSync(path.join(skillDir, 'SKILL.md'), skill.content);
          return { content: [{ type: "text", text: `Skill loaded! Saved to ${skillDir}/SKILL.md` }] };
        } else {
          return { content: [{ type: "text", text: `Skill '${params.name}' has no content in database` }] };
        }
      } catch (err) {
        return { content: [{ type: "text", text: `Error loading skill: ${err.message}` }] };
      }
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
      const identityResult = await getIdentity(false, _ctx);
      if (!identityResult.ok) {
        return { content: [{ type: "text", text: `Error: Could not get identity: ${identityResult.error}` }] };
      }
      const result = await issue_add(params.title, params.description || "", params.severity || "medium", params.issue_type || "bug", identityResult.value.id);
      const issueResult = unwrapGleamResult(result);
      if (!issueResult.ok) {
        return { content: [{ type: "text", text: `Error adding issue: ${issueResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Issue added! ID: ${issueResult.value}` }] };
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
      const issueResult = unwrapGleamResult(result);
      if (!issueResult.ok) {
        return { content: [{ type: "text", text: `Error listing issues: ${issueResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Issues: ${JSON.stringify(issueResult.value)}` }] };
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
      const issueResult = unwrapGleamResult(result);
      if (!issueResult.ok) {
        return { content: [{ type: "text", text: `Error resolving issue: ${issueResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Issue resolved! ${issueResult.value}` }] };
    }
  });

  // System tools (renamed from monitor- to system-)
  pi.registerTool({
    name: "psypi-system-health",
    description: "Check system health",
    parameters: {},
    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
      const result = await check_system_health();
      const healthResult = unwrapGleamResult(result);
      if (!healthResult.ok) {
        return { content: [{ type: "text", text: `Error checking health: ${healthResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Health: ${JSON.stringify(healthResult.value)}` }] };
    }
  });

  pi.registerTool({
    name: "psypi-system-housekeeping",
    description: "Run housekeeping tasks",
    parameters: {},
    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
      const result = await housekeeping();
      const houseResult = unwrapGleamResult(result);
      if (!houseResult.ok) {
        return { content: [{ type: "text", text: `Error in housekeeping: ${houseResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Housekeeping done! ${houseResult.value}` }] };
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
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      // Get agent_id using same pattern as psypi-my-id
      const identityResult = await getIdentity(false, ctx);
      if (!identityResult.ok) {
        return { content: [{ type: "text", text: `Error getting identity: ${identityResult.error}` }] };
      }
      const agentId = identityResult.value.id;
      
      // Call save(content, tags, importance, agent_id) - correct parameter order!
      const result = await learn(params.content, params.tags || "", params.importance || 5, agentId);
      const learnResult = unwrapGleamResult(result);
      if (!learnResult.ok) {
        return { content: [{ type: "text", text: `Error saving learning: ${learnResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Learning saved! ${learnResult.value}` }] };
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
      const reflectResult = unwrapGleamResult(result);
      if (!reflectResult.ok) {
        return { content: [{ type: "text", text: `Error in reflection: ${reflectResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Reflection saved! ${reflectResult.value}` }] };
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
      const broadcastResult = unwrapGleamResult(result);
      if (!broadcastResult.ok) {
        return { content: [{ type: "text", text: `Error sending broadcast: ${broadcastResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Broadcast sent! ${broadcastResult.value}` }] };
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
      const broadcastResult = unwrapGleamResult(result);
      if (!broadcastResult.ok) {
        return { content: [{ type: "text", text: `Error listing broadcasts: ${broadcastResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Messages: ${JSON.stringify(broadcastResult.value)}` }] };
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
      const meetingResult = unwrapGleamResult(result);
      if (!meetingResult.ok) {
        return { content: [{ type: "text", text: `Error listing meetings: ${meetingResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Meetings: ${JSON.stringify(meetingResult.value)}` }] };
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
      position: { type: "string", optional: true },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const identityResult = await getIdentity(false, _ctx);
      if (!identityResult.ok) {
        return { content: [{ type: "text", text: `Error: Could not get identity: ${identityResult.error}` }] };
      }
      const result = await meeting_add_opinion(params.meeting_id, identityResult.value.id, params.perspective, params.reasoning || null, params.position || null);
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
      const opinionResult = unwrapGleamResult(result);
      if (!opinionResult.ok) {
        return { content: [{ type: "text", text: `Error listing opinions: ${opinionResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Opinions: ${JSON.stringify(opinionResult.value)}` }] };
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

  // Stats tool
  pi.registerTool({
    name: "psypi-stats",
    description: "Get system statistics (tasks, issues, skills, meetings)",
    parameters: {},
    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
      const result = await stats();
      const statsResult = unwrapGleamResult(result);
      if (!statsResult.ok) {
        return { content: [{ type: "text", text: `Error getting stats: ${statsResult.error}` }] };
      }
      const s = statsResult.value;
      return { content: [{ type: "text", text: `📊 Stats:\nTasks: ${s.tasks}\nIssues: ${s.issues}\nSkills: ${s.skills}\nMeetings: ${s.meetings}` }] };
    }
  });

  // Validate commit message tool
  pi.registerTool({
    name: "psypi-validate-commit",
    description: "Validate a commit message format",
    parameters: {
      message: { type: "string" },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      try {
        const result = await commit_validate(params.message);
        const validationResult = unwrapGleamResult(result);
        if (!validationResult.ok) {
          return { content: [{ type: "text", text: `Validation error: ${validationResult.error}` }] };
        }
        const v = validationResult.value;
        return { content: [{ type: "text", text: `✅ Valid!\n- Length: ${v.length}/${v.max_length}\n- Safe content: ${v.is_safe}\n- Has type: ${v.has_type}` }] };
      } catch (err) {
        return { content: [{ type: "text", text: `Error: ${err.message}` }] };
      }
    }
  });

  // Commit tool (calls inter-review then git commit)
  pi.registerTool({
    name: "psypi-commit",
    description: "Git commit with Gleam review (calls inter-review first)",
    parameters: {
      message: { type: "string" },
    },
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      try {
        // First, validate the message
        const validateResult = await commit_validate(params.message);
        const vResult = unwrapGleamResult(validateResult);
        if (!vResult.ok) {
          return { content: [{ type: "text", text: `❌ Invalid commit message: ${vResult.error}` }] };
        }
        
        // Get current agent identity
        const { get_resolved_identity } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/agent_identity.mjs");
        const identity = await get_resolved_identity(false);
        const agentId = identity.ok ? identity[0].id : 'unknown';
        
        // Request inter-review
        const reviewResult = await inter_review_request(undefined, undefined, agentId, { message: params.message });
        const reviewUnwrapped = unwrapGleamResult(reviewResult);
        
        if (!reviewUnwrapped.ok) {
          return { content: [{ type: "text", text: `⚠️ Review request failed: ${reviewUnwrapped.error}, proceeding with commit...` }] };
        }
        
        const reviewId = reviewUnwrapped.value;
        
        // Run git commit
        const { execSync } = await import('child_process');
        const fullMessage = `${params.message} [inter-review:${reviewId}]`;
        
        try {
          execSync(`git commit -m "${fullMessage}"`, { encoding: 'utf-8', stdio: 'pipe' });
          return { content: [{ type: "text", text: `✅ Committed with review ID: ${reviewId}\nMessage: ${params.message}` }] };
        } catch (gitErr) {
          return { content: [{ type: "text", text: `⚠️ Git commit failed: ${gitErr.message}\nBut review was requested: ${reviewId}` }] };
        }
      } catch (err) {
        return { content: [{ type: "text", text: `Error: ${err.message}` }] };
      }
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
      const reviewResult = unwrapGleamResult(result);
      if (!reviewResult.ok) {
        return { content: [{ type: "text", text: `Error requesting review: ${reviewResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Review requested! ${reviewResult.value}` }] };
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
      const reviewResult = unwrapGleamResult(result);
      if (!reviewResult.ok) {
        return { content: [{ type: "text", text: `Error listing reviews: ${reviewResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Reviews: ${JSON.stringify(reviewResult.value)}` }] };
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
      const reviewResult = unwrapGleamResult(result);
      if (!reviewResult.ok) {
        return { content: [{ type: "text", text: `Error showing review: ${reviewResult.error}` }] };
      }
      return { content: [{ type: "text", text: `Review: ${JSON.stringify(reviewResult.value)}` }] };
    }
  });

  if (VERBOSE) {
    console.log(`[PsyPI] All tools registered!`);
  }
}
