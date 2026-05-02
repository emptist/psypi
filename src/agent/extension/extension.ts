import type {
  ExtensionAPI,
  BeforeAgentStartEvent,
  ToolResultEvent,
  TurnEndEvent,
  TurnStartEvent,
  ToolCallEvent,
  ContextEvent,
  AgentEndEvent,
} from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { execSync } from "child_process";
import path from "path";
import { querySafe, queryOne, execSafe, resolveId, closePool, getNezhaContext, registerProject, detectProjectType, generateFingerprint } from "./db.js";
import { AgentIdentityService } from '../../kernel/services/AgentIdentityService.js';
import { getAgentSessionService } from '../../kernel/services/AgentSessionService.js';
import { DatabaseClient } from '../../kernel/db/DatabaseClient.js';
import { kernel } from '../../kernel/index.js';

const GIT_HASH = "@@GIT_HASH@@";

export interface ExternalThinker {
  name?: string;
  think(question: string): Promise<string>;
}

type DelegationMode =
  | { mode: "self-sufficient" }
  | { mode: "delegating"; thinker: ExternalThinker };

let delegation: DelegationMode = { mode: "self-sufficient" };

export function registerThinker(thinker: ExternalThinker): void {
  const thinkerName = thinker.name || "Unknown";
  delegation = { mode: "delegating", thinker };
  if (VERBOSE) {
    console.log(`[PsyPI@${GIT_HASH}] 🔌 Thinker slot filled: ${thinkerName} (now delegating)`);
  }
}

export function unregisterThinker(): void {
  if (VERBOSE) {
    const oldThinker = delegation.mode === "delegating" ? delegation.thinker.name : "none";
    console.log(`[PsyPI@${GIT_HASH}] 🔌 Thinker slot cleared: ${oldThinker} (now self-sufficient)`);
  }
  delegation = { mode: "self-sufficient" };
}

const VERBOSE = process.env.PSYPI_VERBOSE === 'true' || process.env.NODE_ENV !== 'production';

// ✅ Pi session ID - the ONLY in-session identifier
const SESSION_ID = process.env.AGENT_SESSION_ID || 'unknown-session';

if (VERBOSE) {
  console.log(`[PsyPI@${GIT_HASH}] Starting in verbose mode...`);
  console.log(`[PsyPI] Session ID: ${SESSION_ID}`);
}

const LOCAL_TASK_WHITELIST = [
  'pwd',
  'ls',
  'ls -la',
  'echo',
  'whoami',
  'date',
  'cd',
  'cp',
  'mv',
  'rm',
  'mkdir',
  'rmdir',
  'cat',
  'head',
  'tail',
  'grep',
  'find',
  'sort',
  'uniq',
  'wc',
];

function shouldAutoDelegate(toolName: string, args?: Record<string, unknown>): boolean {
  if (delegation.mode !== "delegating") return false;

  const toolLower = toolName.toLowerCase();
  if (LOCAL_TASK_WHITELIST.some(t => toolLower === t.toLowerCase())) {
    return false;
  }
  
  // Blind delegation: delegate everything else when thinker slot is filled
  if (VERBOSE) {
    console.log(`[PsyPI Auto-Delegate] ${toolName} → delegated to ${delegation.thinker.name || "external thinker"}`);
  }
  return true;
}

async function getAvailableTools(): Promise<string> {
  const rows = await querySafe<{ string_agg: string }>(
    "SELECT string_agg(table_name, ', ') FROM table_documentation WHERE ai_can_modify = true"
  );
  return rows[0]?.string_agg || "tasks, issues, memory, skills, meetings";
}

async function getSystemPrompts(): Promise<string> {
  const row = await queryOne<{ current_prompt: string }>(
    "SELECT current_prompt FROM prompt_suggestions WHERE status = 'approved' ORDER BY updated_at DESC LIMIT 1"
  );
  return row?.current_prompt?.trim() || "";
}

let turnCount = 0;
let fileChangeCount = 0;

async function checkStartupTasks(): Promise<string> {
  try {
    const result = await kernel.getTasks('PENDING');
    const tasks = result.rows || [];
    
    if (tasks.length === 0) {
      return "No pending tasks";
    }

    const highPriority = tasks.filter((t: any) => t.priority >= 8);
    if (highPriority.length > 0) {
      return `🎯 ${highPriority.length} high-priority tasks:\n${highPriority
        .slice(0, 3)
        .map((t: any) => `- ${t.title.slice(0, 50)}`)
        .join("\n")}`;
    }
    return `📋 ${tasks.length} tasks pending`;
  } catch (err) {
    return "Could not check tasks";
  }
}

async function getStartupSkills(): Promise<{ name: string; instructions: string }[]> {
  return querySafe<{ name: string; instructions: string }>(
    "SELECT name, instructions FROM skills WHERE trigger_phrases @> ARRAY['session_start'] AND status = 'approved' LIMIT 5"
  );
}

async function getSkillsForTool(toolName: string): Promise<{ name: string; instructions: string }[]> {
  return querySafe<{ name: string; instructions: string }>(
    "SELECT name, instructions FROM skills WHERE trigger_phrases @> $1 AND status = 'approved' LIMIT 3",
    [[toolName]]
  );
}

async function getSkillsForEvent(eventType: string): Promise<{ name: string; instructions: string }[]> {
  return querySafe<{ name: string; instructions: string }>(
    "SELECT name, instructions FROM skills WHERE trigger_phrases @> $1 AND status = 'approved' LIMIT 3",
    [[eventType]]
  );
}

async function getNextTask(): Promise<{ id: string; title: string; priority: number } | null> {
  const row = await queryOne<{ id: string; title: string; priority: number }>(
    "SELECT id, title, priority FROM tasks WHERE status = 'PENDING' ORDER BY priority DESC LIMIT 1"
  );
  return row || null;
}

function getModeLabel(): string {
  return delegation.mode === "delegating" ? "External Thinker (Piano)" : "Self-sufficient";
}

function getModeGuidance(): string {
  return delegation.mode === "delegating"
    ? "Use 'psypi-think' or 'piano_think' tool to delegate complex reasoning to external thinker."
    : "You handle thinking yourself.";
}

async function buildNezhaPrompt(): Promise<string> {
  const [availableTools, systemPrompts] = await Promise.all([
    getAvailableTools(),
    getSystemPrompts(),
  ]);

  return `
## Nezha Inside™
psypi = psypi + Nezha kernel bundled inside (self-contained):
- Tasks: kernel.addTask() or 'psypi task-add <title>' 
- Issues: kernel.addIssue() or 'psypi issue-add <title>'
- View: 'psypi tasks' or 'psypi issue-list' to see existing work
- Meetings: 'psypi meeting discuss <topic> <description>' for AI discussions
- Skills: 'psypi skill list', 'psypi skill search <query>' - search for relevant skills
- All functions call kernel directly (no external nezha CLI needed)

## Available Database Tables
These tables are available for AI to use and modify:
- ${availableTools}

Use these to track progress, create issues for bugs, and collaborate with other AI instances.

## System Prompts (from database)
${systemPrompts || "No additional system prompts configured."}

## Autonomous Mode
When working autonomously:
1. Use 'psypi-tasks' to check pending tasks (calls kernel.getTasks() directly)
2. Use 'psypi-think' for complex analysis
3. Create issues with kernel.addIssue() for problems encountered
4. Log progress via 'psypi-areflect' for knowledge retention

💡 Pro tip: You can extend this extension with Pi hooks at ~/.pi/agent/extensions/ for custom reminders, automation, or context injection.

## Mode: ${getModeLabel()}
${getModeGuidance()}
`.trim();
}

const psypiThinkTool = {
  name: "psypi-think",
  label: "PsyPI Think",
  description:
    "Delegate complex reasoning to external thinker (Piano/OpenCode)",
  parameters: Type.Object({
    question: Type.String({
      description: "The question or problem needing deep thought",
    }),
  }),
  async execute(_id: string, params: { question: string }) {
    if (delegation.mode !== "delegating") {
      return {
        content: [
          {
            type: "text" as const,
            text: "PsyPI is in self-sufficient mode. Handle thinking yourself.",
          },
        ],
        details: {} as Record<string, unknown>,
      };
    }
    try {
      console.log(`[PsyPI psypi-think] Delegating to external thinker: ${params.question.slice(0, 50)}...`);
      const result = await delegation.thinker.think(params.question);
      console.log(`[PsyPI psypi-think] Got response: ${result.slice(0, 100)}...`);
      return {
        content: [{ type: "text" as const, text: result }],
        details: { delegated: true } as Record<string, unknown>,
      };
    } catch (e) {
      return {
        content: [
          { type: "text" as const, text: `External thinker failed: ${e}` },
        ],
        details: { error: true } as Record<string, unknown>,
      };
    }
  },
};

const psypiAgentIdTool = {
  name: "psypi-agent-id",
  label: "PsyPI Agent ID",
  description: "Get current agent identity",
  parameters: Type.Object({}),
  async execute() {
    const sessionId = process.env.AGENT_SESSION_ID || "unknown";
    const result = await queryOne<{ id: string; agent_type: string }>(
      "SELECT id, agent_type FROM agent_sessions WHERE id = $1",
      [sessionId]
    );
    const agentId = result?.agent_type || sessionId;
    return {
      content: [{ type: "text" as const, text: `Agent ID: ${agentId}` }],
      details: { agentId },
    };
  },
};

const psypiTasksTool = {
  name: "psypi-tasks",
  label: "PsyPI Check Tasks",
  description: "Check pending tasks from Nezha",
  parameters: Type.Object({}),
  async execute() {
    const status = await checkStartupTasks();
    return {
      content: [{ type: "text" as const, text: status }],
      details: {},
    };
  },
};

const psypiAutonomousTool = {
  name: "psypi-autonomous",
  label: "PsyPI Autonomous Work",
  description: "Get guidance for autonomous work - suggests next actions based on pending tasks and context",
  parameters: Type.Object({
    context: Type.Optional(Type.String({ description: "Current work context or project being worked on" })),
  }),
  async execute(_id: string, params: { context?: string }) {
    try {
      const result = await kernel.getTasks('PENDING');
      const tasks = result.rows || [];
      
      if (tasks.length === 0) {
        const guidance = `No pending tasks found.

Suggested actions:
1. Review recent changes with git log
2. Check for documentation updates needed
3. Run tests to ensure everything is working
4. Create new tasks for planned features${params.context ? `\n5. Continue working on: ${params.context}` : ""}`;
        return {
          content: [{ type: "text" as const, text: guidance }],
          details: { hasTasks: false } as Record<string, unknown>,
        };
      }
      
      const highPriority = tasks.filter((t: any) => t.priority >= 80);
      
      if (highPriority.length > 0) {
        const taskList = highPriority.slice(0, 5).map((t: any) => `[${t.priority}] ${t.title}`).join("\n");
        const guidance = `🎯 HIGH PRIORITY TASKS (${highPriority.length}):
${taskList}

Recommended immediate actions:
1. Focus on highest priority task first
2. Use 'psypi-think' for complex analysis
3. Break down large tasks if needed${params.context ? `\n4. Current context: ${params.context}` : ""}`;
        return {
          content: [{ type: "text" as const, text: guidance }],
          details: { hasTasks: true, highPriority: true } as Record<string, unknown>,
        };
      }
      
      const taskList = tasks.slice(0, 5).map((t: any) => `[${t.priority}] ${t.title}`).join("\n");
      const guidance = `📋 PENDING TASKS (${tasks.length}):
${taskList}

Suggested workflow:
1. Pick a task that matches your current context
2. Use 'psypi-think' for analysis
3. Update task status as you progress${params.context ? `\n\nCurrent context: ${params.context}` : ""}`;
      return {
        content: [{ type: "text" as const, text: guidance }],
        details: { hasTasks: true } as Record<string, unknown>,
      };
    } catch (err) {
      return {
        content: [{ type: "text" as const, text: "Could not retrieve tasks from database." }],
        details: { error: true } as Record<string, unknown>,
      };
    }
  },
};

const psypiMeetingSayTool = {
  name: "psypi-meeting-say",
  label: "PsyPI Meeting Say",
  description: "Add an opinion to a Nezha meeting. Use short or full meeting ID.",
  parameters: Type.Object({
    meetingId: Type.String({ description: "Meeting ID (short 8-char prefix or full UUID)" }),
    perspective: Type.String({ description: "Your perspective/position on the topic" }),
    reasoning: Type.Optional(Type.String({ description: "Why you hold this position" })),
    keyPoints: Type.Optional(Type.String({ description: "Key points, comma-separated" })),
  }),
  execute: async (_toolCallId: string, params: any) => {
    const meetingId = await resolveId("meetings", params.meetingId);
    if (!meetingId) {
      return {
        content: [{ type: "text" as const, text: `Meeting not found: ${params.meetingId}` }],
        isError: true,
        details: {} as Record<string, unknown>,
      };
    }

    const meeting = await queryOne<{ topic: string; status: string }>(
      "SELECT topic, status FROM meetings WHERE id = $1",
      [meetingId]
    );

    if (!meeting) {
      return {
        content: [{ type: "text" as const, text: `Meeting not found: ${params.meetingId}` }],
        isError: true,
        details: {} as Record<string, unknown>,
      };
    }

    if (meeting.status !== "active") {
      return {
        content: [{ type: "text" as const, text: `Meeting is ${meeting.status}, not active` }],
        details: {} as Record<string, unknown>,
      };
    }

    const keyPointsArray = params.keyPoints
      ? params.keyPoints.split(",").map((p: string) => p.trim()).filter(Boolean)
      : [];
    
    const agentId = (await AgentIdentityService.getResolvedIdentity()).id;

    const inserted = await execSafe(
      `INSERT INTO meeting_opinions (id, meeting_id, author, perspective, reasoning, position, created_at)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, NOW())`,
      [meetingId, agentId, params.perspective, params.reasoning || null, keyPointsArray.length > 0 ? JSON.stringify(keyPointsArray) : null]
    );

    if (!inserted) {
      return {
        content: [{ type: "text" as const, text: "Failed to add opinion" }],
        isError: true,
        details: {} as Record<string, unknown>,
      };
    }

    return {
      content: [{
        type: "text" as const,
        text: `Opinion added to meeting "${meeting.topic}" (${meetingId.slice(0, 8)})\nPerspective: ${params.perspective}`,
      }],
      details: { meetingId } as Record<string, unknown>,
    };
  },
};

const psypiMeetingSummaryTool = {
  name: "psypi-meeting-summary",
  label: "PsyPI Meeting Summary",
  description: "Get a summary of a Nezha meeting including all opinions and consensus status.",
  parameters: Type.Object({
    meetingId: Type.String({ description: "Meeting ID (short 8-char prefix or full UUID)" }),
  }),
  execute: async (_toolCallId: string, params: any) => {
    const meetingId = await resolveId("meetings", params.meetingId);
    if (!meetingId) {
      return {
        content: [{ type: "text" as const, text: `Meeting not found: ${params.meetingId}` }],
        details: {} as Record<string, unknown>,
      };
    }

    const meeting = await queryOne<{ topic: string; status: string; created_by: string; created_at: string; consensus: string | null }>(
      "SELECT topic, status, created_by, created_at, consensus FROM meetings WHERE id = $1",
      [meetingId]
    );

    if (!meeting) {
      return {
        content: [{ type: "text" as const, text: `Meeting not found: ${params.meetingId}` }],
        details: {} as Record<string, unknown>,
      };
    }

    const opinions = await querySafe<{ author: string; perspective: string; reasoning: string | null; created_at: string }>(
      "SELECT author, perspective, reasoning, created_at FROM meeting_opinions WHERE meeting_id = $1 ORDER BY created_at",
      [meetingId]
    );

    const authors = [...new Set(opinions.map(o => o.author))];
    const positionCounts: Record<string, number> = {};
    for (const op of opinions) {
      const key = op.perspective.slice(0, 50);
      positionCounts[key] = (positionCounts[key] || 0) + 1;
    }

    let summary = `📋 Meeting: ${meeting.topic}\n`;
    summary += `Status: ${meeting.status} | Created by: ${meeting.created_by}\n`;
    summary += `Opinions: ${opinions.length} | Participants: ${authors.join(", ")}\n`;

    if (meeting.consensus) {
      summary += `\n✅ Consensus: ${meeting.consensus}\n`;
    }

    if (opinions.length > 0) {
      summary += `\nOpinions:\n`;
      for (const op of opinions) {
        summary += `  [${op.author}] ${op.perspective}`;
        if (op.reasoning) summary += ` — ${op.reasoning.slice(0, 100)}`;
        summary += "\n";
      }
    }

    return {
      content: [{ type: "text" as const, text: summary }],
      details: { meetingId, opinionCount: opinions.length, participants: authors } as Record<string, unknown>,
    };
  },
};

const psypiMeetingSearchTool = {
  name: "psypi-meeting-search",
  label: "PsyPI Meeting Search",
  description: "Search Nezha meetings by keyword in topic, opinions, or consensus.",
  parameters: Type.Object({
    query: Type.String({ description: "Search keyword or phrase" }),
    limit: Type.Optional(Type.Number({ description: "Max results (default 5)" })),
  }),
  execute: async (_toolCallId: string, params: any) => {
    const limit = params.limit || 5;
    const pattern = `%${params.query}%`;

    const meetings = await querySafe<{ id: string; topic: string; status: string; created_at: string }>(
      `SELECT m.id, m.topic, m.status, m.created_at
       FROM meetings m
       LEFT JOIN meeting_opinions o ON m.id = o.meeting_id
       WHERE m.topic ILIKE $1
          OR m.consensus ILIKE $1
          OR o.perspective ILIKE $1
          OR o.reasoning ILIKE $1
       GROUP BY m.id, m.topic, m.status, m.created_at
       ORDER BY m.created_at DESC
       LIMIT $2`,
      [pattern, limit]
    );

    if (meetings.length === 0) {
      return {
        content: [{ type: "text" as const, text: `No meetings found matching "${params.query}"` }],
        details: { query: params.query, resultCount: 0 } as Record<string, unknown>,
      };
    }

    const result = meetings
      .map(m => `[${m.status.padEnd(10)}] #${m.id.slice(0, 8)} ${m.topic}`)
      .join("\n");

    return {
      content: [{ type: "text" as const, text: `Found ${meetings.length} meetings matching "${params.query}":\n${result}` }],
      details: { query: params.query, resultCount: meetings.length } as Record<string, unknown>,
    };
  },
};

const psypiMeetingListTool = {
  name: "psypi-meeting-list",
  label: "PsyPI Meeting List",
  description: "List Nezha meetings, optionally filtered by status.",
  parameters: Type.Object({
    status: Type.Optional(Type.String({ description: "Filter by status: active, completed, cancelled (default: active)" })),
    limit: Type.Optional(Type.Number({ description: "Max results (default 10)" })),
  }),
  execute: async (_toolCallId: string, params: any) => {
    const status = params.status || "active";
    const limit = params.limit || 10;

    const meetings = await querySafe<{ id: string; topic: string; status: string; created_by: string; created_at: string }>(
      "SELECT id, topic, status, created_by, created_at FROM meetings WHERE status = $1 ORDER BY created_at DESC LIMIT $2",
      [status, limit]
    );

    if (meetings.length === 0) {
      return {
        content: [{ type: "text" as const, text: `No ${status} meetings found` }],
        details: { status, resultCount: 0 } as Record<string, unknown>,
      };
    }

    const result = meetings
      .map(m => `#${m.id.slice(0, 8)} [${m.status}] ${m.topic} (by ${m.created_by})`)
      .join("\n");

    return {
      content: [{ type: "text" as const, text: `${status} meetings (${meetings.length}):\n${result}` }],
      details: { status, resultCount: meetings.length } as Record<string, unknown>,
    };
  },
};

const psypiDocSaveTool = {
  name: "psypi-doc-save",
  label: "PsyPI Doc Save",
  description: "Save a project document to the Nezha database. The DB is the source of truth; files are generated from it.",
  parameters: Type.Object({
    name: Type.String({ description: "Document name (e.g. AGENTS, ARCHITECTURE)" }),
    content: Type.String({ description: "Document content in markdown" }),
    filePath: Type.Optional(Type.String({ description: "Target file path when generated (e.g. /project/AGENTS.md)" })),
    priority: Type.Optional(Type.Number({ description: "Priority for ordering (higher = more important)" })),
  }),
  execute: async (_toolCallId: string, params: any) => {
    const existing = await queryOne<{ id: string }>(
      "SELECT id FROM project_docs WHERE name = $1 AND status = 'current'",
      [params.name]
    );

    if (existing) {
      await execSafe(
        "UPDATE project_docs SET content = $1, file_path = COALESCE($2, file_path), priority = COALESCE($3, priority), updated_at = NOW() WHERE id = $4",
        [params.content, params.filePath || null, params.priority ?? null, existing.id]
      );
    } else {
      await execSafe(
        "INSERT INTO project_docs (name, content, file_path, priority) VALUES ($1, $2, $3, $4)",
        [params.name, params.content, params.filePath || null, params.priority || 0]
      );
    }

    return {
      content: [{ type: "text" as const, text: `Document "${params.name}" saved to Nezha DB${existing ? " (updated)" : " (created)"}` }],
      details: { name: params.name, updated: !!existing } as Record<string, unknown>,
    };
  },
};

const psypiDocListTool = {
  name: "psypi-doc-list",
  label: "PsyPI Doc List",
  description: "List project documents stored in the Nezha database.",
  parameters: Type.Object({
    project: Type.Optional(Type.String({ description: "Filter by project name" })),
  }),
  execute: async (_toolCallId: string, params: any) => {
    const docs = await querySafe<{ name: string; file_path: string | null; priority: number; updated_at: string }>(
      params.project
        ? "SELECT name, file_path, priority, updated_at FROM project_docs WHERE status = 'current' AND project = $1 ORDER BY priority DESC"
        : "SELECT name, file_path, priority, updated_at FROM project_docs WHERE status = 'current' ORDER BY priority DESC",
      params.project ? [params.project] : []
    );

    if (docs.length === 0) {
      return {
        content: [{ type: "text" as const, text: "No project documents found" }],
        details: { resultCount: 0 } as Record<string, unknown>,
      };
    }

    const result = docs
      .map(d => `[${d.priority}] ${d.name} → ${d.file_path || "(no path)"} (updated ${d.updated_at})`)
      .join("\n");

    return {
      content: [{ type: "text" as const, text: `Project documents (${docs.length}):\n${result}` }],
      details: { resultCount: docs.length } as Record<string, unknown>,
    };
  },
};

const psypiStatusTool = {
  name: "psypi-status",
  label: "PsyPI Status",
  description: "Show current PsyPI status including thinker slot state, registered tools, and active hooks.",
  parameters: Type.Object({}),
  execute: async (_toolCallId: string, _params: any) => {
    const thinkerStatus = delegation.mode === "delegating" 
      ? `🧠 Delegating to: ${delegation.thinker.name || "external thinker"}` 
      : "🏠 Working locally (no external thinker)";

    const tools = [
      "psypi-think", "psypi-tasks", "psypi-autonomous",
      "psypi-meeting-say", "psypi-meeting-summary", "psypi-meeting-search", "psypi-meeting-list",
      "psypi-doc-save", "psypi-doc-list", "psypi-status", "psypi-project", "psypi-visits", "psypi-stats"
    ];

    const hooks = [
      "resources_discover", "context", "before_agent_start", "session_start",
      "tool_result", "tool_call"
    ];

    const cwd = process.cwd();
    const projectType = detectProjectType(cwd);
    const projectName = path.basename(cwd);

    let status = `## PsyPI Status\n\n`;
    status += `**Project:** ${projectName} (${projectType})\n\n`;
    status += `**Thinker Slot:** ${thinkerStatus}\n\n`;
    status += `**Tools (${tools.length}):**\n${tools.map(t => `- ${t}`).join("\n")}\n\n`;
    status += `**Hooks (${hooks.length}):**\n${hooks.map(h => `- ${h}`).join("\n")}\n`;

    return {
      content: [{ type: "text" as const, text: status }],
      details: { 
        thinkerMode: delegation.mode, 
        toolCount: tools.length, 
        hookCount: hooks.length,
        projectName,
        projectType
      } as Record<string, unknown>,
    };
  },
};

const psypiProjectTool = {
  name: "psypi-project",
  label: "PsyPI Project Info",
  description: "Show current project information including fingerprint, type, and git remote.",
  parameters: Type.Object({}),
  execute: async (_toolCallId: string, _params: any) => {
    const cwd = process.cwd();
    const projectType = detectProjectType(cwd);
    
    let gitRemote: string | null = null;
    try {
      gitRemote = execSync("git remote get-url origin 2>/dev/null", {
        cwd,
        encoding: "utf-8",
      }).trim();
    } catch {
      gitRemote = null;
    }
    
    const fingerprint = generateFingerprint(gitRemote, cwd);
    const name = path.basename(cwd);
    
    const project = await queryOne<{ id: string; first_seen: string }>(
      "SELECT id, created_at as first_seen FROM projects WHERE fingerprint = $1",
      [fingerprint]
    );
    
    let info = `## Project: ${name}\n\n`;
    info += `**Type:** ${projectType}\n`;
    info += `**Fingerprint:** ${fingerprint}\n`;
    info += `**Path:** ${cwd}\n`;
    info += `**Git Remote:** ${gitRemote || "(none)"}\n`;
    info += `**Registered:** ${project ? "Yes" : "No"}\n`;
    if (project) {
      info += `**First Seen:** ${project.first_seen}\n`;
    }
    
    return {
      content: [{ type: "text" as const, text: info }],
      details: { name, type: projectType, fingerprint, gitRemote, registered: !!project } as Record<string, unknown>,
    };
  },
};

const psypiVisitsTool = {
  name: "psypi-visits",
  label: "PsyPI Project Visits",
  description: "Show recent project visits across the AI ecosystem.",
  parameters: Type.Object({
    limit: Type.Optional(Type.Number({ default: 10 })),
  }),
  execute: async (_toolCallId: string, params: { limit?: number }) => {
    const limit = params.limit || 10;
    
    const visits = await querySafe<{ project_fingerprint: string; visited_at: string }>(
      `SELECT project_fingerprint, visited_at FROM project_visits ORDER BY visited_at DESC LIMIT $1`,
      [limit]
    );
    
    if (visits.length === 0) {
      return {
        content: [{ type: "text" as const, text: "No project visits recorded yet." }],
        details: { count: 0 } as Record<string, unknown>,
      };
    }
    
    const result = visits
      .map(v => `- ${v.project_fingerprint} at ${v.visited_at}`)
      .join("\n");
    
    return {
      content: [{ type: "text" as const, text: `Recent project visits (${visits.length}):\n${result}` }],
      details: { count: visits.length } as Record<string, unknown>,
    };
  },
};

const psypiStatsTool = {
  name: "psypi-stats",
  label: "PsyPI Statistics",
  description: "Show statistics about the PsyPI ecosystem: projects, visits, skills, meetings.",
  parameters: Type.Object({}),
  execute: async (_toolCallId: string, _params: any) => {
    const projectCount = await queryOne<{ count: string }>(
      "SELECT COUNT(*) as count FROM projects"
    );
    
    const visitCount = await queryOne<{ count: string }>(
      "SELECT COUNT(*) as count FROM project_visits"
    );
    
    const skillCount = await queryOne<{ count: string }>(
      "SELECT COUNT(*) as count FROM skills WHERE status = 'approved'"
    );
    
    const meetingCount = await queryOne<{ count: string }>(
      "SELECT COUNT(*) as count FROM meetings"
    );
    
    const issueCount = await queryOne<{ count: string }>(
      "SELECT COUNT(*) as count FROM issues WHERE status != 'resolved'"
    );
    
    let stats = `## PsyPI Ecosystem Statistics\n\n`;
    stats += `| Metric | Count |\n`;
    stats += `|--------|-------|\n`;
    stats += `| Projects | ${projectCount?.count || 0} |\n`;
    stats += `| Visits | ${visitCount?.count || 0} |\n`;
    stats += `| Skills | ${skillCount?.count || 0} |\n`;
    stats += `| Meetings | ${meetingCount?.count || 0} |\n`;
    stats += `| Open Issues | ${issueCount?.count || 0} |\n`;
    
    return {
      content: [{ type: "text" as const, text: stats }],
      details: { 
        projectCount: parseInt(projectCount?.count || '0'),
        visitCount: parseInt(visitCount?.count || '0'),
        skillCount: parseInt(skillCount?.count || '0'),
        meetingCount: parseInt(meetingCount?.count || '0'),
        issueCount: parseInt(issueCount?.count || '0'),
      } as Record<string, unknown>,
    };
  },
};

async function getNezhaInnerAI(): Promise<{ provider: string; model: string } | null> {
  const result = await queryOne<{ provider: string; model: string | null }>(
    `SELECT provider, model FROM provider_api_keys WHERE status = 'in_use' LIMIT 1`
  );
  
  if (!result) return null;
  
  return {
    provider: result.provider,
    model: result.model || 'tencent/hy3-preview:free',
  };
}

async function updatePiSettings(provider: string, model: string): Promise<boolean> {
  const os = await import('os');
  const fs = await import('fs');
  const settingsPath = path.join(os.homedir(), '.pi', 'agent', 'settings.json');
  
  try {
    let settings: any = {};
    
    if (fs.existsSync(settingsPath)) {
      const content = fs.readFileSync(settingsPath, 'utf-8');
      settings = JSON.parse(content);
    }
    
    settings.defaultProvider = provider;
    settings.defaultModel = model;
    
    if (!settings.models) {
      settings.models = [];
    }
    
    const modelEntry = `${provider}/${model}`;
    if (!settings.models.includes(modelEntry)) {
      settings.models.unshift(modelEntry);
    }
    
    fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
    
    if (VERBOSE) {
      console.log(`[PsyPI] Updated pi settings: provider=${provider}, model=${model}`);
    }
    
    return true;
  } catch (e) {
    console.error(`[PsyPI] Failed to update pi settings: ${e}`);
    return false;
  }
}

const psypiSyncInnerAITool = {
  name: "psypi-sync-inner-ai",
  label: "PsyPI Sync Inner AI",
  description: "Sync pi configuration to use the same AI provider/model as nezha's inner AI. Returns instructions for setting up the API key securely.",
  parameters: Type.Object({}),
  execute: async (_toolCallId: string, _params: any) => {
    const innerAI = await getNezhaInnerAI();
    
    if (!innerAI) {
      return {
        content: [{ type: "text" as const, text: "No inner AI configured in nezha. Use 'nezha inner set-model <provider> [model]' to configure it first." }],
        details: { error: true } as Record<string, unknown>,
      };
    }
    
    const success = await updatePiSettings(innerAI.provider, innerAI.model);
    
    if (success) {
      const instructions = `✅ Pi configuration updated to match nezha's inner AI:
Provider: ${innerAI.provider}
Model: ${innerAI.model}

🔐 SECURITY: To use this provider, you need to set the API key as an environment variable:

For ${innerAI.provider}:
  export OPENROUTER_API_KEY="your-api-key-here"

You can get the API key from nezha's database or your provider's dashboard.

Add this to your ~/.bashrc or ~/.zshrc to make it permanent:
  echo 'export OPENROUTER_API_KEY="your-key"' >> ~/.bashrc

Restart pi to use the new configuration.`;
      
      return {
        content: [{ type: "text" as const, text: instructions }],
        details: { provider: innerAI.provider, model: innerAI.model } as Record<string, unknown>,
      };
    } else {
      return {
        content: [{ type: "text" as const, text: "Failed to update pi configuration. Check permissions for ~/.pi/agent/settings.json" }],
        details: { error: true } as Record<string, unknown>,
      };
    }
  },
};

const psypiAreflectTool = {
  name: "psypi-areflect",
  label: "PsyPI Areflect",
  description: "All-in-one reflection: automatically parses [LEARN], [ISSUE], [TASK] tags from text and saves to appropriate tables.",
  parameters: Type.Object({
    text: Type.String({ description: "The reflection text containing [LEARN], [ISSUE], [TASK] tags" }),
  }),
  async execute(_toolCallId: string, params: any) {
    try {
      const result = await kernel.areflect(params.text);
      return {
        content: [{ type: "text" as const, text: result }],
        details: { success: true } as Record<string, unknown>,
      };
    } catch (err) {
      return {
        content: [{ type: "text" as const, text: `Error: ${err instanceof Error ? err.message : err}` }],
        details: { error: true } as Record<string, unknown>,
      };
    }
  },
};

const psypiCommitTool = {
  name: "psypi-commit",
  label: "PsyPI Commit",
  description: "Git commit using 'psypi commit' CLI (runs mandatory inter-review).",
  parameters: Type.Object({
    message: Type.String({ description: "Commit message" }),
    noVerify: Type.Optional(Type.Boolean({ description: "Skip git hooks (still runs review)" })),
  }),
  async execute(_toolCallId: string, params: any) {
    try {
      const { execSync } = await import("child_process");
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
};

export default function psypiExtension(pi: ExtensionAPI) {
  pi.registerTool(psypiAgentIdTool);
  pi.registerTool(psypiThinkTool);
  pi.registerTool(psypiTasksTool);
  pi.registerTool(psypiAutonomousTool);
  pi.registerTool(psypiMeetingSayTool);
  pi.registerTool(psypiMeetingSummaryTool);
  pi.registerTool(psypiMeetingSearchTool);
  pi.registerTool(psypiMeetingListTool);
  pi.registerTool(psypiDocSaveTool);
  pi.registerTool(psypiDocListTool);
  pi.registerTool(psypiStatusTool);
  pi.registerTool(psypiProjectTool);
  pi.registerTool(psypiVisitsTool);
  pi.registerTool(psypiStatsTool);
  pi.registerTool(psypiSyncInnerAITool);
  pi.registerTool(psypiAreflectTool);
  pi.registerTool(psypiCommitTool);

  pi.on("resources_discover", async () => {
    const skills = await getStartupSkills();
    const skillPaths: string[] = [];
    const { writeFileSync, mkdirSync } = await import("fs");

    for (const skill of skills) {
      const fileName = `/tmp/psypi-skill-${skill.name}.md`;
      try {
        writeFileSync(fileName, `# ${skill.name}\n\n${skill.instructions}`);
        skillPaths.push(fileName);
      } catch {
        console.error(`[PsyPI] Failed to generate skill file for ${skill.name}`);
      }
    }

    const docs = await querySafe<{ name: string; content: string; file_path: string }>(
      "SELECT name, content, file_path FROM project_docs WHERE status = 'current' ORDER BY priority DESC"
    );

    for (const doc of docs) {
      try {
        const targetPath = doc.file_path || `/tmp/psypi-doc-${doc.name}.md`;
        const dir = targetPath.substring(0, targetPath.lastIndexOf("/"));
        try { mkdirSync(dir, { recursive: true }); } catch {}
        writeFileSync(targetPath, doc.content);
        skillPaths.push(targetPath);
      } catch {
        console.error(`[PsyPI] Failed to generate doc file for ${doc.name}`);
      }
    }

    // Add nezha structured context as JSON resource (not in skillPaths)
    const contextJson = await getNezhaContext();
    if (contextJson) {
      try {
        const contextPath = "/tmp/psypi-context.json";
        writeFileSync(contextPath, contextJson);
        console.log(`[PsyPI resources_discover] Added nezha context JSON to ${contextPath}`);
      } catch {
        console.error(`[PsyPI] Failed to write nezha context JSON`);
      }
    }

    if (skillPaths.length > 0) {
      console.log(`[PsyPI resources_discover] Generated ${skillPaths.length} resource files (${skills.length} skills, ${docs.length} docs)`);
    }

    return {
      skillPaths,
    };
  });

  pi.on("before_agent_start", async (_event: BeforeAgentStartEvent) => {
    let systemPrompt = await buildNezhaPrompt();
    
    // If thinker slot is filled, inject delegation instruction
    if (delegation.mode === "delegating") {
      const thinkerName = delegation.thinker.name || "external thinker";
      systemPrompt += `\n\n## Delegation Mode Active
You have access to an external thinker (${thinkerName}). 
When user asks complex questions or asks about planning/architecture/research:
- Use 'psypi-think' or 'piano_think' tool to delegate thinking
- Or return control and let the system delegate automatically
`;
    }
    
    // Inject agent identity
    const sessionId = process.env.AGENT_SESSION_ID || "unknown";
    const agentResult = await queryOne<{ id: string; agent_type: string }>(
      "SELECT id, agent_type FROM agent_sessions WHERE id = $1",
      [sessionId]
    );
    const agentId = agentResult?.agent_type || sessionId;
    systemPrompt += `\n\n## Agent Identity\nYour Agent ID: ${agentId}\n`;
    
    // Inject structured nezha context into prompt
    const contextJson = await getNezhaContext();
    if (contextJson) {
      const contextSection = `\n\n## Current Context from Nezha\n\`\`\`json\n${contextJson}\n\`\`\`\n`;
      systemPrompt += contextSection;
    }
    
    // ✅ NEW: Load project-onboarding skill for proper onboarding
    try {
      const onboardingSkill = await getSkillsForEvent('session_start');
      if (onboardingSkill && onboardingSkill.length > 0) {
        const skillContent = onboardingSkill.map(s => 
          `## ${s.name}\n${s.instructions || ''}`
        ).join('\n\n');
        systemPrompt += `\n\n## Project Onboarding Knowledge\n${skillContent}\n`;
        console.log(`[PsyPI] Loaded ${onboardingSkill.length} onboarding skill(s)`);
      }
    } catch (err) {
      console.warn(`[PsyPI] Failed to load onboarding skills: ${err}`);
    }
    
    return {
      systemPrompt,
    };
  });

  pi.on("session_start", async (event) => {
    const cwd = process.cwd();
    const projectInfo = await registerProject(cwd);
    if (projectInfo) {
      console.log(`[PsyPI] Project: ${projectInfo.name} (${projectInfo.type}) [${projectInfo.fingerprint}]`);
      
      await execSafe(
        "INSERT INTO project_visits (id, project_fingerprint, visited_at) VALUES (gen_random_uuid(), $1, NOW()) ON CONFLICT DO NOTHING",
        [projectInfo.fingerprint]
      );
    }

    const agentId = (await AgentIdentityService.getResolvedIdentity()).id;
    await execSafe(
      "INSERT INTO tasks (id, title, description, status, priority, category, created_by) VALUES (gen_random_uuid(), $1, $2, 'PENDING', 3, 'system', $3)",
      [`[Pi Session Started] ${event.reason}`, "Auto-created by PsyPI extension", agentId]
    );

    const taskStatus = checkStartupTasks();
    console.log(`[PsyPI Startup] ${taskStatus}`);
  });

  pi.on("tool_result", async (event: ToolResultEvent) => {
    if (event.isError) {
      const toolName = event.toolName;
      const agentId = (await AgentIdentityService.getResolvedIdentity()).id;
      await execSafe(
        "INSERT INTO issues (id, title, severity, status, created_by) VALUES (gen_random_uuid(), $1, $2, 'open', $3)",
        [`[Tool Failed] ${toolName}`, "medium", agentId]
      );
    } else {
      if (
        event.toolName === "read" ||
        event.toolName === "edit" ||
        event.toolName === "write"
      ) {
        fileChangeCount++;
      }
    }
  });

  pi.on("turn_end", async (_event: TurnEndEvent, ctx) => {
    turnCount++;
    if (turnCount % 5 === 0) {
      await ctx.ui.notify(
        `💡 You've been working for ${turnCount} turns. Remember to commit your changes with \`git add . && git commit -m "[task: xxx] description"\``,
        "info",
      );
    }
    if (fileChangeCount > 10) {
      await ctx.ui.notify(
        `📝 You've edited ${fileChangeCount} files. Consider updating docs if you've made significant changes.`,
        "info",
      );
      fileChangeCount = 0;
    }
  });

  pi.on("tool_call", async (event: ToolCallEvent, ctx) => {
    const toolName = event.toolName;
    const args = event.input as Record<string, unknown> | undefined;
    
    if (delegation.mode === "delegating") {
      const thinkerName = delegation.thinker.name || "external thinker";
      console.log(`[PsyPI tool_call] ${toolName} → Mode: delegating to ${thinkerName}`);
    } else {
      console.log(`[PsyPI tool_call] ${toolName} → Mode: self-sufficient`);
    }

    if (delegation.mode !== "delegating") return;

    if (shouldAutoDelegate(toolName, args)) {
      console.log(`[PsyPI Auto-Delegate] ${toolName} → delegating to external thinker`);

      return {
        block: true,
        reason: `Auto-delegating ${toolName} to external thinker. Use piano_think or psypi-think for complex tasks.`,
      };
    }

    console.log(`[PsyPI Auto-Delegate] ${toolName} → allowed locally`);
  });

    // TODO: Pi SDK types are complex unions - AgentMessage type doesn't have simple 'content'
    // Need to type-narrow carefully. Using 'as any' as a pragmatic solution.
    (pi as any).on("context", async (event: ContextEvent) => {
    const lastUserMsg = [...event.messages].reverse().find(
      (m: any) => m.role === "user" && typeof (m as any).content === "string"
    );
    if (!lastUserMsg) return;

    // TODO: Complex Pi SDK message types - content property varies by message type
    const content = (lastUserMsg as any).content as string;

    const stopWords = new Set([
      "about", "above", "after", "again", "against", "being", "below", "between",
      "could", "would", "should", "their", "there", "these", "those", "through",
      "under", "until", "where", "which", "while", "with", "have", "from", "this",
      "that", "what", "when", "will", "your", "just", "than", "then", "some",
      "into", "more", "most", "also", "back", "been", "does", "doing", "done"
    ]);

    const keywords = content
      .toLowerCase()
      .replace(/[^\w\s]/g, " ")
      .split(/\s+/)
      .filter((w: string) => w.length > 3 && !stopWords.has(w))
      .filter((w: string) => !/^\d+$/.test(w))
      .slice(0, 8);

    const allSkills: { name: string; instructions: string }[] = [];

    const projectType = detectProjectType(process.cwd());
    if (projectType !== "unknown") {
      const defaultSkill = await querySafe<{ name: string; instructions: string }>(
        `SELECT name, instructions FROM skills WHERE name = $1 AND status = 'approved' LIMIT 1`,
        [`${projectType}-default`]
      );
      if (defaultSkill.length > 0) {
        allSkills.push(defaultSkill[0]!);
      }
    }

    if (keywords.length > 0) {
      const keywordSkills = await querySafe<{ name: string; instructions: string }>(
        `SELECT name, instructions FROM skills 
         WHERE status = 'approved' 
           AND (trigger_phrases && $1 OR instructions ILIKE ANY($2))
         LIMIT 3`,
        [keywords, keywords.map((k: string) => `%${k}%`)]
      );
      allSkills.push(...keywordSkills);
    }

    if (allSkills.length === 0) return;

    const skillContext = allSkills
      .map(s => `## Skill: ${s.name}\n${s.instructions.slice(0, 600)}`)
      .join("\n\n");

    const contextMsg = {
      role: "user" as const,
      content: `[PsyPI Context] Relevant skills from Nezha DB (project: ${projectType}, keywords: ${keywords.join(", ")}):\n\n${skillContext}`,
      timestamp: Date.now(),
    };

    return {
      messages: [...event.messages, contextMsg],
    };
  });

  const turnTimings: Map<number, number> = new Map();

  pi.on("agent_end", async (_event: AgentEndEvent, ctx) => {
    console.log(`[PsyPI agent_end] Task completed, checking for next task...`);
    
    const nextTask = await getNextTask();
    if (nextTask) {
      console.log(`[PsyPI agent_end] Next task: [${nextTask.priority}] ${nextTask.title}`);
      await ctx.ui.notify(
        `📋 Next task: ${nextTask.title}`,
        "info"
      );
    }
    
    const eventSkills = await getSkillsForEvent("agent_end");
    if (eventSkills.length > 0) {
      console.log(`[PsyPI agent_end] Loaded ${eventSkills.length} skill(s)`);
    }
  });

  pi.on("turn_start", (event: TurnStartEvent) => {
    turnTimings.set(event.turnIndex, event.timestamp);
    console.log(`[PsyPI Turn ${event.turnIndex}] Started`);
  });

  // TODO: TurnEndEvent type from Pi SDK doesn't expose timestamp directly
  // Using 'as any' to access potential timestamp property
  pi.on("turn_end", (event: TurnEndEvent) => {
    const startTime = turnTimings.get(event.turnIndex);
    const duration = startTime ? ((event as any).timestamp || Date.now()) - startTime : 0;
    console.log(`[PsyPI Turn ${event.turnIndex}] Ended (${duration}ms)`);
    turnTimings.delete(event.turnIndex);
  });

  process.on("SIGINT", async () => {
    await closePool();
  });
  process.on("SIGTERM", async () => {
    await closePool();
  });
}
