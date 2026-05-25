// extension_generator.gleam — Pi Extension Generator
// Composes all PiToolCall/PiEventHook/PiCommandReg values into extension.js
//
// Generator functions live in pi_tool_call.gleam (their proper home).
// Runtime helpers live in pi_extension_ffi.mjs (proper FFI home).
// This module only contains registries and composition logic.

import agent_identity.{my_id_tool}
import agents.{agents_list_tool}
import areflect.{areflect_tool}
import broadcast.{broadcast_list_tool, broadcast_send_tool}
import code_version.{doc_list_tool, doc_save_tool}
import event_hooks.{list_active_hooks_tool, list_hooks_tool}
import file_utils.{write_file}
import filepath
import gleam/io
import gleam/list
import gleam/option.{None, Some}
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
  type PiCommandReg, type PiEventHook, type PiMessageRenderer, type PiToolCall,
  Accent, Error as ThemeError, NotifyError, PiParam, PiToolCall, SilentSuccess,
  Warning, command_to_js, debounced_hook, event_hook, event_hook_to_js,
  from_param, lit, message_renderer, message_renderer_to_js, raw_json,
  system_prompt_hook, to_import_line, to_js_text,
}
import skill.{skill_get_tool, skill_list_tool, skill_search_tool}
import stats.{stats_show_tool}
import task.{task_add_tool, task_complete_tool, task_list_tool}

// ---------------------------------------------------------------------------
// Tool registry
// ---------------------------------------------------------------------------

pub fn all_tools() -> List(PiToolCall) {
  [
    my_id_tool(),
    task_add_tool(),
    task_list_tool(),
    task_complete_tool(),
    stats_show_tool(),
    doc_save_tool(),
    doc_list_tool(),
    issue_add_tool(),
    issue_list_tool(),
    issue_count_tool(),
    issue_get_tool(),
    issue_resolve_tool(),
    skill_list_tool(),
    skill_get_tool(),
    skill_search_tool(),
    meeting_list_tool(),
    meeting_get_tool(),
    meeting_opinions_tool(),
    meeting_create_tool(),
    meeting_say_tool(),
    learn_save_tool(),
    memory_search_tool(),
    broadcast_send_tool(),
    broadcast_list_tool(),
    areflect_tool(),
    agents_list_tool(),
    monitor_status_tool(),
    monitor_health_tool(),
    monitor_alerts_tool(),
    monitor_stats_tool(),
    monitor_suggest_tool(),
    list_hooks_tool(),
    list_active_hooks_tool(),
    consult_tool(),
    commit_tool(),
  ]
}

// ---------------------------------------------------------------------------
// Event hooks registry
// ---------------------------------------------------------------------------

pub fn all_event_hooks() -> List(PiEventHook) {
  [
    event_hook(
      "tool_call",
      "hook_on_tool_call",
      "on_tool_call",
      [
        from_param("event.toolName || ''"),
        from_param(
          "event.input ? (event.input.path || event.input.filePath || '') : ''",
        ),
        lit("ctx"),
        lit("pi"),
      ],
      None,
      SilentSuccess,
      NotifyError,
    ),
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
    system_prompt_hook(
      "before_agent_start",
      "hook_on_before_agent_start",
      "on_before_agent_start",
      [],
      NotifyError,
    ),
    event_hook(
      "agent_start",
      "hook_on_agent_start",
      "on_agent_start",
      [],
      None,
      SilentSuccess,
      NotifyError,
    ),
    debounced_hook(
      "agent_end",
      "hook_on_agent_end",
      "on_agent_end",
      [lit("ctx"), lit("pi")],
      "psypi_config",
      "get_debounce_ms",
      None,
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
      None,
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
    autonomic_listen_command(),
    autonomic_reload_command(),
  ]
}

// ---------------------------------------------------------------------------
// Message renderers registry
// ---------------------------------------------------------------------------

pub fn all_message_renderers() -> List(PiMessageRenderer) {
  [
    message_renderer(
      "autonomic-wakeup",
      "[A-agentbot]",
      Accent,
      Warning,
      True,
    ),
    message_renderer(
      "autonomic-error",
      "[A-agentbot ERROR]",
      ThemeError,
      ThemeError,
      True,
    ),
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
      "import { Text, Box } from \"@mariozechner/pi-tui\";",
      "import { notify_error as pi_extension_notify_error, unwrap_gleam_result as unwrapGleamResult, gleam_value_to_json as gleamValueToJson } from \"./build/dev/javascript/psypi/pi_extension.mjs\";",
      "import { record_trigger as event_hooks_record_trigger } from \"./build/dev/javascript/psypi/event_hooks.mjs\";",
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

fn message_renderers_text(renderers: List(PiMessageRenderer)) -> String {
  renderers
  |> list.map(message_renderer_to_js)
  |> string.concat
}

// ---------------------------------------------------------------------------
// Main generation
// ---------------------------------------------------------------------------

pub fn generate() -> String {
  let tools = all_tools()
  let hooks = all_event_hooks()
  let commands = all_commands()
  let renderers = all_message_renderers()
  imports_text(tools)
  <> "\nexport default function(pi) {\n"
  <> message_renderers_text(renderers)
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
    args: [
      from_param("params.message || ''"),
      from_param("params.review_id || ''"),
      lit("ctx"),
      lit("pi"),
    ],
    result_format: raw_json(),
  )
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
