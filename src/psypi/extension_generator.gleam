// extension_generator.gleam — Pi Extension Generator
//
// Design:
//   - Each Gleam module exports PiToolCall values (e.g., agent_identity.my_id_tool())
//   - The generator COLLECTS these values and composes them into extension.js
//   - Everything is TEXT — Gleam writes JS source code as strings
//
// Two sources of JS text:
//   1. PiToolCall.to_js_text() → pi.registerTool({...}) blocks
//   2. PiToolCall.to_import_line() → import { fn } from "path.mjs"
//
// The generator is a COOK: it gathers ingredients (PiToolCall values),
// prepares them (converts to JS text), and assembles the final dish (extension.js).

import filepath
import gleam/io
import gleam/list
import gleam/string
import psypi/agent_identity.{monitor_id_tool, my_id_tool}
import psypi/code_version.{doc_save_tool}
import psypi/file_utils.{write_file}
import psypi/issue.{issue_add_tool, issue_list_tool, issue_resolve_tool}
import psypi/learning.{learn_save_tool}
import psypi/meeting.{meeting_get_tool, meeting_list_tool, meeting_opinions_tool}
import psypi/memory.{memory_search_tool}
import psypi/pi_tool_call.{
  type PiEventHook, type PiToolCall, event_hook, event_hook_to_js,
  to_import_line, to_js_text,
}
import psypi/skill.{skill_get_tool, skill_list_tool, skill_search_tool}
import psypi/stats.{stats_show_tool}
import psypi/task.{task_add_tool, task_list_tool}

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
  ]
}

pub fn all_event_hooks() -> List(PiEventHook) {
  [
    auto_backup_hook(),
    activity_tracing_hook(),
  ]
}

fn auto_backup_hook() -> PiEventHook {
  event_hook("tool_call", auto_backup_handler_body())
}

/// Generates the auto-backup handler body as JS text.
/// This is a Gleam function — not hand-written JS. AIs can't mess it up.
fn auto_backup_handler_body() -> String {
  [
    "    if (event.toolName === 'edit' || event.toolName === 'write') {",
    "      const filePath = event.input?.path || event.input?.filePath;",
    "      if (!filePath) return;",
    "      try {",
    "        const fs = await import('fs');",
    "        const content = fs.readFileSync(filePath, 'utf-8');",
    "        const { save_version } = await import('./build/dev/javascript/psypi/psypi/code_version.mjs');",
    "        const identity = await get_resolved_identity(false, _sessionId, 'psypi', '', '', 'psypi', '');",
    "        const r = unwrapGleamResult(identity);",
    "        if (r.ok) {",
    "          await save_version(filePath, content, r.value.id, '', 'auto-backup before ' + event.toolName);",
    "          ctx.ui.notify('Auto-backup: ' + filePath.split('/').pop(), 'info');",
    "        }",
    "      } catch (err) {",
    "        ctx.ui.notify('Auto-backup failed: ' + err.message, 'error');",
    "      }",
    "    }",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

/// Activity tracing hook - logs ALL tool executions to activity_log table
/// One line of code catches ALL activity - no need to add logging to individual functions!
fn activity_tracing_hook() -> PiEventHook {
  event_hook("tool_call", activity_tracing_handler_body())
}

fn activity_tracing_handler_body() -> String {
  [
    "    // Activity tracing: log every tool call to activity_log",
    "    try {",
    "      const { log_activity } = await import('./build/dev/javascript/psypi/psypi/activity_log.mjs');",
    "      const { get_agent_id } = await import('./build/dev/javascript/psypi/psypi/agent_identity.mjs');",
    "      const r = get_agent_id(false, 'psypi', 'psypi', _sessionId, '');",
    "      const agentId = r.ok ? r.value : null;",
    "      if (!agentId) return;",
    "      const context = JSON.stringify({ tool: event.toolName, input: event.input });",
    "      log_activity(agentId, event.toolName, context).then(() => {}).catch(() => {});",
    "    } catch (err) {}",
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
  <> "}\n"
}

pub fn main() {
  // Print to stdout (for debugging)
  generate() |> io.print
  // Also write to extension.js
  write_extension()
}
