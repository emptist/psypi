// extension_generator.gleam — Pi Extension Generator
//
// Design:
//   - Each Gleam module exports PiToolCall values (e.g., agent_identity.my_id_tool())
//   - The generator COLLECTS these values and composes them into extension.js
//   - Everything is TEXT — Gleam writes JS source code as strings
//
// Two sources of JS text:
//   1. PiToolCall.to_js_text() → pi.registerTool({}))
//   2. PiToolCall.to_import_line() → import { fn } from "path.mjs"
//
// The generator is a COOK: it gathers ingredients (PiToolCall values),
// prepares them (converts to JS text), and assembles the final dish (extension.js).

import filepath
import gleam/io
import gleam/list
import gleam/string
import psypi/agent_identity.{monitor_id_tool, my_id_tool}
import psypi/agents.{agents_list_tool}
import psypi/areflect.{areflect_tool}
import psypi/broadcast.{broadcast_send_tool, broadcast_list_tool}
import psypi/code_version.{doc_save_tool}
import psypi/file_utils.{write_file}
import psypi/monitor_ai.{monitor_health_tool, monitor_status_tool, monitor_alerts_tool}
import psypi/issue.{issue_add_tool, issue_list_tool, issue_resolve_tool}
import psypi/learning.{learn_save_tool}
import psypi/memory.{memory_search_tool}
import psypi/meeting.{meeting_get_tool, meeting_list_tool, meeting_opinions_tool}
import psypi/pi_tool_call.{type PiToolCall, type PiEventHook, event_hook, to_import_line, to_js_text, event_hook_to_js}
import psypi/skill.{skill_get_tool, skill_list_tool, skill_search_tool}
import psypi/stats.{stats_show_tool}
import psypi/task.{task_add_tool, task_list_tool, task_complete_tool}

@external(javascript, "./extension_generator_ffi.mjs", "get_project_root")
pub fn get_project_root() -> String

pub fn write_extension() -> Nil {
  let project_root = get_project_root()
  let extension_path = filepath.join(project_root, "extension.js")
  // IMPORTANT: Always call generate() — never compose text here.
  // Having two composition paths caused the "pi is not defined" bug.
  let content = generate()
  case write_file(extension_path, content) {
    Ok(_) -> Nil
    Error(e) -> io.println("Error writing extension.js: " <> string.inspect(e))
  }
}

// -------------------------------------------------------------------
// Tool registry — the SINGLE place where all Pi tools are listed
// To add a new tool:
//   1. Define a PiToolCall value in its Gleam module
//   2. Import it here
//   3. Add it to the list below
// -------------------------------------------------------------------

pub fn all_tools() -> List(PiToolCall) {
  [
    // Agent identity
    my_id_tool(),
    monitor_id_tool(),
    // Tasks
    task_add_tool(),
    task_list_tool(),
    // Stats
    stats_show_tool(),
    // Code versioning
    doc_save_tool(),
    // Issues
    issue_add_tool(),
    issue_list_tool(),
    issue_resolve_tool(),
    // Skills
    skill_list_tool(),
    skill_get_tool(),
    skill_search_tool(),
    // Meetings
    meeting_list_tool(),
    meeting_get_tool(),
    meeting_opinions_tool(),
    // Learning
    learn_save_tool(),
    // Memory
    memory_search_tool(),
    // Broadcast
    broadcast_send_tool(),
    broadcast_list_tool(),
    // Reflection (Monitor AI)
    areflect_tool(),
    // Task completion
    task_complete_tool(),
    // Agents
    agents_list_tool(),
    // Monitor
    monitor_status_tool(),
    monitor_health_tool(),
    monitor_alerts_tool(),
  ]
}

pub fn all_event_hooks() -> List(PiEventHook) {
  [
    unified_tool_call_hook(),
    session_start_hook(),
    before_agent_start_hook(),
    agent_start_hook(),
    agent_end_hook(),
    tool_result_hook(),
  ]
}

pub fn session_start_hook() -> PiEventHook {
  event_hook("session_start", [
    "    // Monitor: Initialize on session start",
    "    ctx.ui.setStatus('psypi-monitor', 'Monitor ready');",
    "    console.log('[Monitor] Session started');",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat)
}

pub fn before_agent_start_hook() -> PiEventHook {
  event_hook("before_agent_start", [
    "    // Monitor: Inject guidance before agent starts",
    "    console.log('[Monitor] Before agent start, reason:', event.reason);",
    "    // TODO: Query recent memories and inject as guidance",
    "    // const memories = await searchMemories(agentId);",
    "    // if (memories.length > 0) {",
    "    //   event.messages.push({ role: 'system', content: 'Recent context: ' + memories.join('; ') });",
    "    // }",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat)
}

pub fn agent_start_hook() -> PiEventHook {
  event_hook("agent_start", [
    "    // Monitor: Log agent start",
    "    console.log('[Monitor] Agent started:', event.reason);",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat)
}

pub fn agent_end_hook() -> PiEventHook {
  event_hook("agent_end", [
    "    // Monitor: Summarize work done",
    "    const msgs = event.messages.filter(m => m.role === 'assistant');",
    "    console.log('[Monitor] Agent ended. Turns:', msgs.length);",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat)
}

pub fn tool_result_hook() -> PiEventHook {
  event_hook("tool_result", [
    "    // Monitor: Analyze tool results",
    "    if (event.isError) {",
    "      console.log('[Monitor] Tool error:', event.toolName, event.result);",
    "    }",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat)
}

pub fn unified_tool_call_hook() -> PiEventHook {
  event_hook("tool_call", unified_tool_call_handler_body())
}

fn unified_tool_call_handler_body() -> String {
  [
    "    try {",
    "      // 0. Safety Check - Block Dangerous Operations",
    "      const dangerousPatterns = [",
    "        { pattern: /spawn.*pi/i, message: 'Spawning Pi causes infinite loop - blocked by Monitor' },",
    "        { pattern: /spawn.*psypi/i, message: 'Spawning psypi causes infinite loop - blocked by Monitor' },",
    "        { pattern: /rm.*-rf/i, message: 'Recursive delete is dangerous - blocked by Monitor' },",
    "        { pattern: /git.*push.*force/i, message: 'Force push is dangerous - blocked by Monitor' },",
    "        { pattern: /DROP.*TABLE/i, message: 'DROP TABLE is destructive - blocked by Monitor' },",
    "        { pattern: /DELETE.*FROM.*WHERE/i, message: 'DELETE without LIMIT is dangerous - blocked by Monitor' },",
    "      ];",
    "      const inputStr = JSON.stringify(event.input);",
    "      for (const { pattern, message } of dangerousPatterns) {",
    "        if (pattern.test(event.toolName) || pattern.test(inputStr)) {",
    "          console.log('[Monitor] BLOCKED:', message);",
    "          return { block: true, message: message };",
    "        }",
    "      }",
    "",
    "      // 1. Resolve Identity (using aliased name to avoid crashes)",
    "      const identity = await agent_identity_get_resolved_identity(false, _sessionId, 'psypi', '', '', 'psypi', '');",
    "      const rId = unwrapGleamResult(identity);",
    "      if (!rId.ok) return;",
    "      const agentId = rId.value.id;",
    "",
    "      // 2. Generic Activity Tracing",
    "      const { log_activity } = await import('./build/dev/javascript/psypi/psypi/activity_log.mjs');",
    "      const context = JSON.stringify({ tool: event.toolName, input: event.input });",
    "      log_activity(agentId, event.toolName, context).then(() => {}).catch(() => {});",
    "",
    "      // 3. Specialized Auto-Backup for modifying tools",
    "      if (event.toolName === 'edit' || event.toolName === 'write') {",
    "        const filePath = event.input?.path || event.input?.filePath;",
    "        if (filePath) {",
    "          const fs = await import('fs');",
    "          const content = fs.readFileSync(filePath, 'utf-8');",
    "          const { save_version } = await import('./build/dev/javascript/psypi/psypi/code_version.mjs');",
    "          await save_version(filePath, content, agentId, '', 'auto-backup before ' + event.toolName);",
    "          // Use setStatus for more visible persistent feedback in footer",
    "          ctx.ui.setStatus('psypi-autobackup', '✓ Auto-backed: ' + filePath.split('/').pop());",
    "        }",
    "      }",
    "    } catch (err) {",
    "      if (event.toolName === 'edit' || event.toolName === 'write') {",
    "        ctx.ui.setStatus('psypi-autobackup', '✗ Auto-backup failed: ' + err.message);",
    "      }",
    "    }",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

// -------------------------------------------------------------------
// JS text composition
// -------------------------------------------------------------------

fn imports_text(tools: List(PiToolCall)) -> String {
  let header =
    [
      "// extension.js - Generated by Gleam extension_generator",
      "// DO NOT EDIT - Regenerate with: gleam run -m psypi/extension_generator",
      "",
      "import { complete, getModel } from \"@mariozechner/pi-ai\";",
      "",
    ]
    |> list.map(fn(s) { s <> "\n" })
    |> string.concat

  let lines =
    tools
    |> list.map(to_import_line)
    |> list.unique
    |> list.map(fn(line) { line <> "\n" })
    |> string.concat

  header <> lines <> "\n"
}

fn helpers_text() -> String {
  [
    "  function unwrapGleamResult(result) {",
    "    if (!result) return { ok: false, error: 'null result' };",
    "    const typeName = result.constructor?.name || '';",
    "    if (typeName === 'Ok') return { ok: true, value: result['0'] };",
    "    if (typeName === 'Error') return { ok: false, error: result['0']?.['0'] || result['0']?.toString() || 'Unknown' };",
    "    return { ok: true, value: result };",
    "  }",
    "",
    "  // Session ID — obtained once at session start, never exposed again",
    "  let _sessionId = null;",
    "  pi.on('session_start', async (_event, ctx) => {",
    "    _sessionId = ctx.sessionManager.getSessionId() || '';",
    "  });",
    "",
    "  // Monitor LLM call helper - uses same model as worker",
    "  async function callMonitor(messages, systemPrompt) {",
    "    if (!ctx.model) throw new Error('No model available');",
    "    const auth = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model);",
    "    if (!auth.ok || !auth.apiKey) throw new Error(auth.error || 'No API key');",
    "    const response = await complete(",
    "      ctx.model,",
    "      { systemPrompt, messages },",
    "      { apiKey: auth.apiKey, headers: auth.headers }",
    "    );",
    "    return response.content",
    "      .filter(c => c.type === 'text')",
    "      .map(c => c.text)",
    "      .join('\\n');",
    "  }",
    "",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

fn tools_text(tools: List(PiToolCall)) -> String {
  tools
  |> list.map(to_js_text)
  |> string.concat
}

fn event_hooks_text(hooks: List(PiEventHook)) -> String {
  hooks
  |> list.map(event_hook_to_js)
  |> string.concat
}

pub fn generate() -> String {
  let tools = all_tools()
  let hooks = all_event_hooks()
  imports_text(tools)
  <> "\nexport default function(pi) {\n"
  <> helpers_text()
  <> event_hooks_text(hooks)
  <> tools_text(tools)
  <> monitor_consult_tool()
  <> "}\n"
}

fn monitor_consult_tool() -> String {
  [
    "  // psypi-monitor-consult - LLM-powered consultation tool",
    "  pi.registerTool({",
    "    name: 'psypi-monitor-consult',",
    "    description: 'Consult Monitor for difficult decisions - returns LLM-generated advice',",
    "    parameters: { question: { type: 'string' } },",
    "    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {",
    "      try {",
    "        const question = params.question || 'What should I consider?';",
    "        const systemPrompt = `You are Monitor, a senior technical advisor. Provide concise, actionable advice. Consider: safety, quality, architecture, trade-offs.`;",
    "        const messages = [{ role: 'user', content: [{ type: 'text', text: question }], timestamp: Date.now() }];",
    "        const response = await callMonitor(messages, systemPrompt);",
    "        return { content: [{ type: 'text', text: response }] };",
    "      } catch(e) { return { content: [{ type: 'text', text: 'Monitor error: ' + e.message }] }; }",
    "    }",
    "  });",
    "",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

pub fn main() {
  // Print to stdout (for debugging)
  generate() |> io.print
  // Also write to extension.js
  write_extension()
}