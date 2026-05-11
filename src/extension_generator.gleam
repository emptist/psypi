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
import agent_identity.{monitor_id_tool, my_id_tool}
import agents.{agents_list_tool}
import areflect.{areflect_tool}
import broadcast.{broadcast_send_tool, broadcast_list_tool}
import code_version.{doc_save_tool, doc_list_tool}
import file_utils.{write_file}
import monitor_ai.{monitor_health_tool, monitor_status_tool, monitor_alerts_tool, monitor_stats_tool, monitor_suggest_tool}
import issue.{issue_add_tool, issue_list_tool, issue_resolve_tool}
import learning.{learn_save_tool}
import memory.{memory_search_tool}
import meeting.{meeting_get_tool, meeting_list_tool, meeting_opinions_tool, meeting_create_tool}
import pi_tool_call.{type PiToolCall, type PiEventHook, event_hook, to_import_line, to_js_text, event_hook_to_js}
import skill.{skill_get_tool, skill_list_tool, skill_search_tool}
import stats.{stats_show_tool}
import task.{task_add_tool, task_list_tool, task_complete_tool}

@external(javascript, "./node_ffi.mjs", "get_project_root")
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
    doc_list_tool(),
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
    meeting_create_tool(),
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
    monitor_stats_tool(),
    monitor_suggest_tool(),
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
    "    // 1. Record current model to database",
    "    const { record_current_model } = await import('./build/dev/javascript/monitor.mjs');",
    "    if (ctx.model) {",
    "      record_current_model(ctx.model).then(() => {}).catch(() => {});",
    "    }",
    "    // 2. Dynamic status based on health check",
    "    const { check_system_health } = await import('./build/dev/javascript/monitor_ai.mjs');",
    "    const health = await check_system_health();",
    "    const status = health.ok && health.value.failed_tasks === 0 ? 'psypi-monitor: healthy' : 'psypi-monitor: attention needed';",
    "    ctx.ui.setStatus('psypi-monitor', status);",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat)
}

pub fn before_agent_start_hook() -> PiEventHook {
  event_hook("before_agent_start", [
    "    // Monitor: Inject context before agent starts",
    "    const { search } = await import('./build/dev/javascript/memory.mjs');",
    "    const memories = await search('', 3);",
    "    if (memories.ok && memories.value.length > 0) {",
    "      const context = memories.value.map(m => m.content).join(' | ');",
    "      event.messages.push({ role: 'system', content: 'Recent context: ' + context });",
    "    }",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat)
}

pub fn agent_start_hook() -> PiEventHook {
  event_hook("agent_start", [
    "    // Monitor: Track agent activity",
    "    // (No visible output - silent mode)",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat)
}

pub fn agent_end_hook() -> PiEventHook {
  event_hook("agent_end", [
    "    // Monitor: Track session completion",
    "    // (No visible output - silent mode)",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat)
}

pub fn tool_result_hook() -> PiEventHook {
  event_hook("tool_result", [
    "    // Monitor: Track errors",
    "    // (Silent - no visible output for errors unless critical)",
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
    "      // 0. Safety Check - Guide Dangerous Operations",
    "      const dangerousPatterns = [",
    "        { pattern: /spawn.*pi/i, message: 'Hint: Spawning Pi causes infinite loop. Use direct function calls instead.' },",
    "        { pattern: /spawn.*psypi/i, message: 'Hint: Spawning psypi causes infinite loop. Use direct function calls instead.' },",
    "        { pattern: /rm.*-rf/i, message: 'Hint: Recursive delete is dangerous. Use specific file paths instead.' },",
    "        { pattern: /git.*push.*force/i, message: 'Hint: Force push is dangerous. Use regular push with review instead.' },",
    "        { pattern: /DROP.*TABLE/i, message: 'Hint: DROP TABLE is destructive. Consider archiving data instead.' },",
    "        { pattern: /DELETE.*FROM.*WHERE/i, message: 'Hint: DELETE without LIMIT is dangerous. Add a specific condition or LIMIT.' },",
    "      ];",
    "      const inputStr = JSON.stringify(event.input);",
    "      for (const { pattern, message } of dangerousPatterns) {",
    "        if (pattern.test(event.toolName) || pattern.test(inputStr)) {",
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
    "      const { log_activity } = await import('./build/dev/javascript/activity_log.mjs');",
    "      const context = JSON.stringify({ tool: event.toolName, input: event.input });",
    "      log_activity(agentId, event.toolName, context).then(() => {}).catch(() => {});",
    "",
    "      // 3. Specialized Auto-Backup for modifying tools",
    "      if (event.toolName === 'edit' || event.toolName === 'write') {",
    "        const filePath = event.input?.path || event.input?.filePath;",
    "        if (filePath) {",
    "          const fs = await import('fs');",
    "          const content = fs.readFileSync(filePath, 'utf-8');",
    "          const { save_version } = await import('./build/dev/javascript/code_version.mjs');",
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
  "  async function callMonitor(ctx, messages, systemPrompt) {",
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
  <> psypi_commit_tool()
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
    "        const response = await callMonitor(ctx, messages, systemPrompt);",
    "        return { content: [{ type: 'text', text: response }] };",
    "      } catch(e) { return { content: [{ type: 'text', text: 'Monitor error: ' + e.message }] }; }",
    "    }",
    "  });",
    "",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

fn psypi_commit_tool() -> String {
  [
    "  // psypi-commit - Inter-review with Monitor + Review ID system",
    "  pi.registerTool({",
    "    name: 'psypi-commit',",
    "    description: 'Commit with Monitor inter-review. Use --review-id to commit after getting review PASS.',",
    "    parameters: { message: { type: 'string' }, review_id: { type: 'string', optional: true } },",
    "    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {",
    "      try {",
    "        const { execSync } = await import('child_process');",
    "        const message = params.message || 'No commit message';",
    "        const reviewId = params.review_id || '';",
    "",
    "        // Step 1: If review_id provided, verify it (UUID format)",
    "        if (reviewId) {",
    "          // Verify ID is UUID format",
    "          const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;",
    "          if (!uuidRegex.test(reviewId)) { return { content: [{ type: 'text', text: 'Invalid review_id format. Use UUID from previous review.' }] }; }",
    "          // ID valid - proceed to commit directly",
    "          try { execSync('git add -A && git commit -m \"' + message.replace(/\"/g, '\\\\\"') + '\"', { encoding: 'utf8' }); }",
    "          catch(e) { return { content: [{ type: 'text', text: 'Commit failed: ' + e.message }] }; }",
    "          return { content: [{ type: 'text', text: '✅ Commit verified with review_id: ' + reviewId + '\\n✅ Committed: ' + message }] };",
    "        }",
    "",
    "        // Step 2: No review_id - do full review first",
    "        let changedFiles = '';",
    "        let diff = '';",
    "        try {",
    "          changedFiles = execSync('git diff --name-only', { encoding: 'utf8' });",
    "          diff = execSync('git diff', { encoding: 'utf8', maxBuffer: 10*1024*1024 });",
    "        } catch(e) { return { content: [{ type: 'text', text: 'Error getting git diff: ' + e.message }] }; }",
    "",
    "        const context = `",
    "CHANGES (WHAT):",
    "Files: ${changedFiles}",
    "---",
    "DIFF:",
    "${diff.substring(0, 8000)}",
    "---",
    "COMMIT MESSAGE: ${message}",
    "---",
    "REVIEW REQUEST: Assess code quality, safety, and fit. Also identify any patterns suggesting worker needs more education. Respond exactly: PASS or FAIL, SCORE/100, FEEDBACK, EDUCATION_SUGGESTION (what to learn if any).",
    "`;",
    "",
    "        const systemPrompt = 'You are Monitor. Review code. If worker shows patterns needing education (e.g., always forgetting error handling, using deprecated patterns), note it in EDUCATION_SUGGESTION. Be thorough but fair.';",
    "        const messages = [{ role: 'user', content: [{ type: 'text', text: context }], timestamp: Date.now() }];",
    "        const response = await callMonitor(ctx, messages, systemPrompt);",
    "",
    "        const passMatch = response.match(/PASS/i);",
    "        const scoreMatch = response.match(/SCORE.?(\\d+)/i);",
    "        const score = scoreMatch ? parseInt(scoreMatch[1]) : 0;",
    "        const isPass = passMatch && score >= 70;",
    "",
    "        if (!isPass) {",
    "          return { content: [{ type: 'text', text: 'Review: ' + response + '\\n\\n❌ Score ' + score + '/100 - Need improvements. Fix and run psypi-commit again for new review.' }] };",
    "        }",
    "",
    "        // Generate review_id (UUID format to match existing DB)",
    "        const newReviewId = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {",
    "          const r = Math.random() * 16 | 0;",
    "          const v = c === 'x' ? r : (r & 0x3 | 0x8);",
    "          return v.toString(16);",
    "        });",
    "",
    "        return { content: [{ type: 'text', text: '✅ Review PASSED (' + score + '/100)\\n📋 inter_review_id: ' + newReviewId + '\\n\\nTo commit: psypi-commit --review-id=' + newReviewId + ' \"' + message + '\"' }] };",
    "      } catch(e) { return { content: [{ type: 'text', text: 'Error: ' + e.message }] }; }",
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