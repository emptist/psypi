// extension_generator.gleam — Pi Extension Generator
// Composes small generator modules into extension.js

import agent_identity.{autonomic_id_tool, somatic_id_tool}
import agents.{agents_list_tool}
import areflect.{areflect_tool}
import broadcast.{broadcast_list_tool, broadcast_send_tool}
import code_version.{doc_list_tool, doc_save_tool}
import directive.{clear_directives_tool, direct_agentbot_tool}
import event_hooks.{list_active_hooks_tool, list_hooks_tool}
import file_utils.{write_file}
import filepath
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/string
import issue_tools.{
  issue_add_tool, issue_count_tool, issue_get_tool, issue_list_tool,
  issue_resolve_tool,
}
import learning.{learn_save_tool}
import meeting.{
  meeting_create_tool, meeting_get_tool, meeting_list_tool,
  meeting_opinions_tool, meeting_say_tool,
}
import memory.{memory_search_tool}
import monitor_ai.{
  autonomic_listen_command, autonomic_reload_command, monitor_alerts_tool,
  monitor_health_tool, monitor_stats_tool, monitor_status_tool,
  monitor_suggest_tool,
}
import pi_tool_call.{
  type PiToolCall, type PiEventHook, type PiCommandReg, PiToolCall, PiParam,
  SilentSuccess, NotifyError,
  command_to_js, debounced_hook, event_hook, event_hook_to_js,
  to_import_line, to_js_text, from_param, lit, raw_event_hook, raw_json,
}
import skill.{skill_get_tool, skill_list_tool, skill_search_tool}
import stats.{stats_show_tool}
import task.{task_add_tool, task_complete_tool, task_list_tool}

// Generator modules (none remaining — all migrated to structured hooks)

// ---------------------------------------------------------------------------
// Tool registry
// ---------------------------------------------------------------------------

pub fn all_tools() -> List(PiToolCall) {
  [
    // Identity
    somatic_id_tool(),
    autonomic_id_tool(),
    // Tasks
    task_add_tool(),
    task_list_tool(),
    task_complete_tool(),
    // Stats
    stats_show_tool(),
    // Code versioning
    doc_save_tool(),
    doc_list_tool(),
    // Issues
    issue_add_tool(),
    issue_list_tool(),
    issue_count_tool(),
    issue_get_tool(),
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
    meeting_say_tool(),
    // Learning
    learn_save_tool(),
    // Memory
    memory_search_tool(),
    // Broadcast
    broadcast_send_tool(),
    broadcast_list_tool(),
    // Reflection
    areflect_tool(),
    // Agents
    agents_list_tool(),
    // Monitor
    monitor_status_tool(),
    monitor_health_tool(),
    monitor_alerts_tool(),
    monitor_stats_tool(),
    monitor_suggest_tool(),
    // Event hooks
    list_hooks_tool(),
    list_active_hooks_tool(),
    // Directives (Autonomic → Somatic communication)
    direct_agentbot_tool(),
    clear_directives_tool(),
    // Consult & Commit (structured PiToolCall)
    consult_tool(),
    commit_tool(),
  ]
}

// ---------------------------------------------------------------------------
// Event hooks registry
// ---------------------------------------------------------------------------

pub fn all_event_hooks() -> List(PiEventHook) {
  [
    // DISABLED: auto-backup hook — read_file_sync FFI bug in old cached code
    // event_hook(
    //   "tool_call",
    //   "hook_on_tool_call",
    //   "on_tool_call",
    //   [
    //     from_param("event.toolName || ''"),
    //     from_param("event.input ? (event.input.path || event.input.filePath || '') : ''"),
    //     lit("ctx"),
    //     lit("pi"),
    //   ],
    //   option.None,
    //   SilentSuccess,
    //   NotifyError,
    // ),
    event_hook(
      "session_start",
      "monitor",
      "record_current_model",
      [from_param("ctx.model")],
      Some("ctx.model"),
      SilentSuccess,
      NotifyError,
    ),
    event_hook(
      "model_select",
      "monitor",
      "record_current_model",
      [from_param("event.model")],
      Some("event.model"),
      SilentSuccess,
      NotifyError,
    ),
    raw_event_hook("before_agent_start", "    // no-op\n"),
    raw_event_hook("agent_start", "    // agent_start: S is starting, A stays silent\n"),
    debounced_hook(
      "agent_end",
      "hook_on_agent_end", "on_agent_end",
      [lit("ctx"), lit("pi")],
      "system_config", "get_debounce_ms",
      option.None,
      SilentSuccess,
      NotifyError,
    ),
    event_hook(
      "tool_result",
      "hook_on_tool_result",
      "on_tool_result",
      [
        from_param("JSON.stringify(event.result || '')"),
        from_param("event.toolName || ''"),
        lit("pi"),
      ],
      option.None,
      SilentSuccess,
      NotifyError,
    ),
  ]
}

// ---------------------------------------------------------------------------
// Commands registry
// ---------------------------------------------------------------------------

pub fn all_commands() -> List(PiCommandReg) {
  [
    // Monitor commands (from monitor_ai module)
    autonomic_listen_command(),
    autonomic_reload_command(),
  ]
}

// ---------------------------------------------------------------------------
// JS text composition
// ---------------------------------------------------------------------------

fn imports_text(tools: List(PiToolCall)) -> String {
  let header =
    [
      "// extension.js - Generated by Gleam extension_generator",
      "// DO NOT EDIT - Regenerate with: gleam run -m extension_generator",
      "",
      "import { notify_error as pi_extension_notify_error } from \"./build/dev/javascript/psypi/pi_extension.mjs\";",
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
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

fn tools_text(tools: List(PiToolCall)) -> String {
  tools
  |> list.map(to_js_text)
  |> string.concat
}

fn commands_text(commands: List(PiCommandReg)) -> String {
  commands
  |> list.map(command_to_js)
  |> string.concat
}

fn event_hooks_text(hooks: List(PiEventHook)) -> String {
  hooks
  |> list.map(event_hook_to_js)
  |> string.concat
}

// ---------------------------------------------------------------------------
// Main generation
// ---------------------------------------------------------------------------

pub fn generate() -> String {
  let tools = all_tools()
  let hooks = all_event_hooks()
  let commands = all_commands()
  imports_text(tools)
  <> "\nexport default function(pi) {\n"
  <> helpers_text()
  <> message_renderer_text()
  <> event_hooks_text(hooks)
  <> tools_text(tools)
  <> commands_text(commands)
  <> "}\n"
}

fn consult_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-consult-autonomic",
    description: "Consult the Autonomic Worker for difficult decisions. Only the Somatic Worker should use this.",
    params: [
      PiParam(name: "question", param_type: "string", required: True),
    ],
    module: "tool_consult",
    fn_name: "on_consult",
    args: [from_param("params.question || ''"), lit("ctx")],
    result_format: raw_json(),
  )
}

fn commit_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-commit",
    description: "Commit with Monitor inter-review.",
    params: [
      PiParam(name: "message", param_type: "string", required: True),
      PiParam(name: "review_id", param_type: "string", required: False),
    ],
    module: "tool_commit",
    fn_name: "on_commit",
    args: [from_param("params.message || ''"), from_param("params.review_id || ''"), lit("ctx")],
    result_format: raw_json(),
  )
}

fn message_renderer_text() -> String {
  [
    "  // Register custom renderer for A-agentbot (autonomic) wake-up messages\n",
    "  pi.registerMessageRenderer('autonomic-wakeup', (message, options, theme) => {\n",
    "    const { expanded } = options;\n",
    "    let text = theme.fg('accent', '[A-agentbot] ');\n",
    "    text += theme.fg('warning', message.content);\n",
    "    if (expanded && message.details) {\n",
    "      text += '\\n' + theme.fg('dim', JSON.stringify(message.details, null, 2));\n",
    "    }\n",
    "    return new Text(text, 0, 0);\n",
    "  });\n",
    "\n",
  ]
  |> list.map(fn(s) { s })
  |> string.concat
}

pub fn write_extension() -> Nil {
  let project_root = get_project_root()
  let extension_path = filepath.join(project_root, "extension.js")
  let content = generate()
  case write_file(extension_path, content) {
    Ok(_) -> Nil
    Error(e) -> io.println("Error writing extension.js: " <> string.inspect(e))
  }
}

pub fn main() {
  generate() |> io.print
  write_extension()
}

@external(javascript, "./node_ffi.mjs", "get_project_root")
pub fn get_project_root() -> String
