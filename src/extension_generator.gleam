// extension_generator.gleam — Pi Extension Generator
// Composes all PiToolCall/PiEventHook/PiCommandReg values into extension.js
//
// All JS text generation logic previously in separate pi_*.gleam modules
// has been inlined here. Do NOT re-extract into separate files.

import agent_identity.{my_id_tool}
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
import gleam/option.{Some, None}
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
  type PiToolCall, type PiEventHook, type PiCommandReg, type PiParam,
  type FnArg, type ResultFormat, type HookSuccessAction,
  PiToolCall, PiParam,
  JsLiteral, FromParam, RawJson, Template, CustomJs,
  SilentSuccess, NotifySuccess, SetStatus, NotifyError,
  event_hook, debounced_hook, raw_event_hook,
  from_param, lit, raw_json,
}
import skill.{skill_get_tool, skill_list_tool, skill_search_tool}
import stats.{stats_show_tool}
import task.{task_add_tool, task_complete_tool, task_list_tool}

// ---------------------------------------------------------------------------
// Inline: unwrapGleamResult helper (formerly pi_js_helpers.gleam)
// ---------------------------------------------------------------------------

fn unwrap_gleam_result_js() -> String {
  [
    "  function unwrapGleamResult(result) {",
    "    if (!result) return { ok: false, error: 'null result' };",
    "    const typeName = result.constructor?.name || '';",
    "    if (typeName === 'Ok') return { ok: true, value: result['0'] };",
    "    if (typeName === 'Error') return { ok: false, error: result['0'] || 'Unknown' };",
    "    return { ok: true, value: result };",
    "  }",
    "",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

// ---------------------------------------------------------------------------
// Inline: autonomic-wakeup message renderer (formerly pi_message_renderer.gleam)
// ---------------------------------------------------------------------------

fn autonomic_wakeup_renderer_js() -> String {
  [
    "  // Register custom renderer for A-agentbot (autonomic) wake-up messages",
    "  pi.registerMessageRenderer('autonomic-wakeup', (message, options, theme) => {",
    "    const { expanded } = options;",
    "    let text = theme.fg('accent', '[A-agentbot] ');",
    "    text += theme.fg('warning', message.content);",
    "    if (expanded && message.details) {",
    "      text += '\\n' + theme.fg('dim', JSON.stringify(message.details, null, 2));",
    "    }",
    "    return new Text(text, 0, 0);",
    "  });",
    "",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

// ---------------------------------------------------------------------------
// Inline: before_agent_start hook body (formerly pi_system_prompt.gleam)
// ---------------------------------------------------------------------------

fn before_agent_start_body_js() -> String {
  [
    "    return { systemPrompt: '\\n[A-S Role Model] You are the Somatic Agentbot (S-agentbot). Your ID starts with S-. You are NOT the Autonomic Agentbot (A-agentbot). Messages prefixed with [A-agentbot] come from A — your coordinator. A directs you on what to work on. Follow A\\'s instructions as task assignments. The human user is the person operating the terminal.' };",
    "",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

// ---------------------------------------------------------------------------
// Inline: PiToolCall → JS text (formerly pi_tool_gen.gleam)
// ---------------------------------------------------------------------------

fn params_to_js(params: List(PiParam)) -> String {
  case params {
    [] -> "{ \"type\": \"object\", \"properties\": {} }"
    _ -> {
      let properties =
        params
        |> list.map(fn(p) {
          let base = case p.param_type {
            "string" -> "{ \"type\": \"string\""
            "number" -> "{ \"type\": \"number\""
            "boolean" -> "{ \"type\": \"boolean\""
            _ -> "{ \"type\": \"" <> p.param_type <> "\""
          }
          "\"" <> p.name <> "\": " <> base <> " }"
        })
        |> string.join(",\n      ")

      let required =
        params
        |> list.filter(fn(p) { p.required })
        |> list.map(fn(p) { "\"" <> p.name <> "\"" })
        |> string.join(", ")

      "{ \"type\": \"object\",\n    \"properties\": {\n      " <> properties <> "\n    },\n    \"required\": [" <> required <> "]\n  }"
    }
  }
}

fn tool_args_to_js(args: List(FnArg)) -> String {
  args
  |> list.map(fn(a) {
    case a {
      JsLiteral(v) -> v
      FromParam(e) -> e
    }
  })
  |> string.join(", ")
}

fn result_to_js(format: ResultFormat) -> String {
  case format {
    RawJson -> "JSON.stringify(r.value)"
    Template(tpl) -> "`" <> tpl <> "`"
    CustomJs(expr) -> expr
  }
}

fn tool_to_js_text(tool: PiToolCall) -> String {
  let params_js = params_to_js(tool.params)
  let args_js = tool_args_to_js(tool.args)
  let call_expr = tool.module <> "_" <> tool.fn_name <> "(" <> args_js <> ")"
  let result_js = result_to_js(tool.result_format)
  let name = tool.name

  [
    "  // " <> tool.description,
    "  pi.registerTool({",
    "    name: \"" <> name <> "\",",
    "    description: \"" <> tool.description <> "\",",
    "    parameters: " <> params_js <> ",",
    "    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {",
    "      try {",
    "        const result = await " <> call_expr <> ";",
    "        const r = unwrapGleamResult(result);",
    "        if (!r.ok) {",
    "          pi_extension_notify_error(ctx, 'Tool " <> name <> " error: ' + r.error);",
    "        }",
    "        return r.ok ? { content: [{ type: \"text\", text: "
      <> result_js
      <> " }] } : { content: [{ type: \"text\", text: `Error: ${r.error}` }] };",
    "      } catch(e) {",
    "        pi_extension_notify_error(ctx, 'Tool " <> name <> " exception: ' + (e.message || String(e)));",
    "        return { content: [{ type: \"text\", text: `Error: ${e.message || String(e)}` }] };",
    "      }",
    "    }",
    "  });",
    "",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

fn tool_to_import_line(tool: PiToolCall) -> String {
  let base = "./build/dev/javascript/psypi"
  let alias = tool.module <> "_" <> tool.fn_name
  "import { " <> tool.fn_name <> " as " <> alias <> " } from \"" <> base <> "/" <> tool.module <> ".mjs\";"
}

// ---------------------------------------------------------------------------
// Inline: PiEventHook → JS text (formerly pi_hook_gen.gleam)
// ---------------------------------------------------------------------------

fn hook_success_action_to_js(action: HookSuccessAction) -> String {
  case action {
    SilentSuccess -> ""
    NotifySuccess(msg) -> "ctx.ui.notify('" <> msg <> "', 'info');"
    SetStatus(key, text) ->
      "ctx.ui.setStatus('" <> key <> "', '" <> text <> "');"
  }
}

fn hook_import_line_js(module: String, fn_name: String) -> String {
  let base = "./build/dev/javascript/psypi"
  let alias = module <> "_" <> fn_name
  "const " <> alias <> " = (await import('" <> base <> "/" <> module <> ".mjs'))." <> fn_name <> ";"
}

fn hook_call_expr_js(module: String, fn_name: String, args: List(FnArg)) -> String {
  let args_js =
    args
    |> list.map(fn(a) {
      case a {
        JsLiteral(v) -> v
        FromParam(e) -> e
      }
    })
    |> string.join(", ")
  module <> "_" <> fn_name <> "(" <> args_js <> ")"
}

fn event_hook_to_js(hook: PiEventHook) -> String {
  case hook {
    pi_tool_call.PiRawHook(event_name:, handler_body:) -> {
      [
        "  // Event hook: " <> event_name,
        "  pi.on('" <> event_name <> "', async (event, ctx) => {",
        handler_body,
        "    await event_hooks_record_trigger('" <> event_name <> "');",
        "  });",
        "",
      ]
      |> list.map(fn(s) { s <> "\n" })
      |> string.concat
    }

    pi_tool_call.PiEventHook(
      event_name:,
      module:,
      fn_name:,
      args:,
      guard:,
      on_success:,
      on_error:,
    ) -> {
      let import_ln = hook_import_line_js(module, fn_name)
      let call = hook_call_expr_js(module, fn_name, args)

      let guard_prefix = case guard {
        Some(g) -> "    if (" <> g <> ") {\n"
        None -> ""
      }
      let guard_suffix = case guard {
        Some(_) -> "    }\n"
        None -> ""
      }
      let success_js = hook_success_action_to_js(on_success)
      let error_catch = case on_error {
        NotifyError ->
          "      ctx.ui.notify('Hook " <> event_name <> " error: ' + (e.message || String(e)), 'error');\n"
          <> "      pi_extension_pi_send_message(pi, 'hook-error', 'Hook " <> event_name <> " error: ' + (e.message || String(e)), 'error');\n"
      }
      [
        "  // Event hook: " <> event_name,
        "  pi.on('" <> event_name <> "', async (event, ctx) => {",
        "    try {",
        guard_prefix,
        "      " <> import_ln,
        "      const result = await " <> call <> ";",
        "      const r = unwrapGleamResult(result);",
        "      if (r.ok) { " <> success_js <> " }",
        "      else { ctx.ui.notify('Hook " <> event_name <> " failed: ' + r.error, 'error'); pi_extension_pi_send_message(pi, 'hook-error', 'Hook " <> event_name <> " failed: ' + r.error, 'error'); }",
        "      await event_hooks_record_trigger('" <> event_name <> "');",
        guard_suffix,
        "    } catch(e) {",
        error_catch,
        "    }",
        "  });",
        "",
      ]
      |> list.map(fn(s) { s <> "\n" })
      |> string.concat
    }

    pi_tool_call.PiDebouncedHook(
      event_name:,
      module:,
      fn_name:,
      args:,
      debounce_ms_module:,
      debounce_ms_fn:,
      guard: _,
      on_success:,
      on_error:,
    ) -> {
      let debounce_import =
        hook_import_line_js(debounce_ms_module, debounce_ms_fn)
      let debounce_call =
        debounce_ms_module <> "_" <> debounce_ms_fn <> "()"
      let hook_import_ln = hook_import_line_js(module, fn_name)
      let call = hook_call_expr_js(module, fn_name, args)
      let success_js = hook_success_action_to_js(on_success)
      let error_catch = case on_error {
        NotifyError ->
          "        ctx.ui.notify('Hook " <> event_name <> " error: ' + (e.message || String(e)), 'error');\n"
          <> "        pi_extension_pi_send_message(pi, 'hook-error', 'Hook " <> event_name <> " error: ' + (e.message || String(e)), 'error');\n"
      }
      [
        "  // Event hook (debounced): " <> event_name,
        "  pi.on('" <> event_name <> "', async (event, ctx) => {",
        "    try {",
        "      " <> debounce_import,
        "      const debounceResult = await " <> debounce_call <> ";",
        "      const dr = unwrapGleamResult(debounceResult);",
        "      if (!dr.ok) { ctx.ui.notify('Hook " <> event_name <> " <ERROR> debounce config: ' + dr.error, 'error'); pi_extension_pi_send_message(pi, 'hook-error', 'Hook " <> event_name <> " <ERROR> debounce config: ' + dr.error, 'error'); return; }",
        "      const debounceMs = dr.value;",
        "      setTimeout(async () => {",
        "        try {",
        "          ctx.ui.notify('[AUTONOMIC] setTimeout callback fired for " <> event_name <> "', 'info');",
        "          " <> hook_import_ln,
        "          const result = await " <> call <> ";",
        "          const r = unwrapGleamResult(result);",
        "          if (r.ok) { " <> success_js <> " }",
        "          else { ctx.ui.notify('Hook " <> event_name <> " failed: ' + r.error, 'error'); pi_extension_pi_send_message(pi, 'hook-error', 'Hook " <> event_name <> " failed: ' + r.error, 'error'); }",
        "          await event_hooks_record_trigger('" <> event_name <> "');",
        "        } catch(e) {",
        error_catch,
        "        }",
        "      }, debounceMs);",
        "    } catch(e) {",
        "      ctx.ui.notify('Hook " <> event_name <> " debounce error: ' + (e.message || String(e)), 'error');",
        "      pi_extension_pi_send_message(pi, 'hook-error', 'Hook " <> event_name <> " debounce error: ' + (e.message || String(e)), 'error');",
        "    }",
        "  });",
        "",
      ]
      |> list.map(fn(s) { s <> "\n" })
      |> string.concat
    }
  }
}

// ---------------------------------------------------------------------------
// Inline: PiCommandReg → JS text (formerly pi_command_gen.gleam)
// ---------------------------------------------------------------------------

fn command_result_to_js(format: ResultFormat) -> String {
  case format {
    RawJson -> "JSON.stringify(r.value)"
    Template(tpl) -> "`" <> tpl <> "`"
    CustomJs(expr) -> expr
  }
}

fn command_hook_import_line(module: String, fn_name: String) -> String {
  let base = "./build/dev/javascript/psypi"
  let alias = module <> "_" <> fn_name
  "const " <> alias <> " = (await import('" <> base <> "/" <> module <> ".mjs'))." <> fn_name <> ";"
}

fn command_hook_call_expr(module: String, fn_name: String, args: List(FnArg)) -> String {
  let args_js =
    args
    |> list.map(fn(a) {
      case a {
        JsLiteral(v) -> v
        FromParam(e) -> e
      }
    })
    |> string.join(", ")
  module <> "_" <> fn_name <> "(" <> args_js <> ")"
}

fn command_to_js(cmd: PiCommandReg) -> String {
  case cmd {
    pi_tool_call.PiRawCommand(name:, description:, handler_body:) -> {
      [
        "  // " <> description,
        "  pi.registerCommand(\"" <> name <> "\", {",
        "    description: \"" <> description <> "\",",
        "    handler: async (args, ctx) => {",
        handler_body,
        "    }",
        "  });",
        "",
      ]
      |> list.map(fn(s) { s <> "\n" })
      |> string.concat
    }

    pi_tool_call.PiCommandReg(name:, description:, module:, fn_name:, args:, result_format:) -> {
      let import_ln = command_hook_import_line(module, fn_name)
      let call = command_hook_call_expr(module, fn_name, args)
      let result_js = command_result_to_js(result_format)
      [
        "  // " <> description,
        "  pi.registerCommand(\"" <> name <> "\", {",
        "    description: \"" <> description <> "\",",
        "    handler: async (args, ctx) => {",
        "      try {",
        "        " <> import_ln,
        "        const result = await " <> call <> ";",
        "        const r = unwrapGleamResult(result);",
        "        return r.ok ? { content: [{ type: \"text\", text: " <> result_js <> " }] } : { content: [{ type: \"text\", text: `Error: ${r.error}` }] };",
        "      } catch(e) {",
        "        return { content: [{ type: \"text\", text: `Error: ${e.message || String(e)}` }] };",
        "      }",
        "    }",
        "  });",
        "",
      ]
      |> list.map(fn(s) { s <> "\n" })
      |> string.concat
    }
  }
}

// ---------------------------------------------------------------------------
// Tool registry
// ---------------------------------------------------------------------------

pub fn all_tools() -> List(PiToolCall) {
  [
    // Identity
    my_id_tool(),
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
    event_hook(
      "tool_call",
      "hook_on_tool_call",
      "on_tool_call",
      [
        from_param("event.toolName || ''"),
        from_param("event.input ? (event.input.path || event.input.filePath || '') : ''"),
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
    raw_event_hook(
      "before_agent_start",
      before_agent_start_body_js(),
    ),
    raw_event_hook("agent_start", "    // agent_start: S is starting, A stays silent\n"),
    debounced_hook(
      "agent_end",
      "hook_on_agent_end", "on_agent_end",
      [lit("ctx"), lit("pi")],
      "system_config", "get_debounce_ms",
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
// JS text composition
// ---------------------------------------------------------------------------

fn imports_text(tools: List(PiToolCall)) -> String {
  let header =
    [
      "// extension.js - Generated by Gleam extension_generator",
      "// DO NOT EDIT - Regenerate with: gleam run -m extension_generator",
      "",
      "import { Text } from \"@mariozechner/pi-tui\";",
      "import { notify_error as pi_extension_notify_error, pi_send_message as pi_extension_pi_send_message } from \"./build/dev/javascript/psypi/pi_extension.mjs\";",
      "import { record_trigger as event_hooks_record_trigger } from \"./build/dev/javascript/psypi/event_hooks.mjs\";",
      "",
    ]
    |> list.map(fn(s) { s <> "\n" })
    |> string.concat

  let lines =
    tools
    |> list.map(tool_to_import_line)
    |> list.unique
    |> list.map(fn(line) { line <> "\n" })
    |> string.concat

  header <> lines <> "\n"
}

fn tools_text(tools: List(PiToolCall)) -> String {
  tools
  |> list.map(tool_to_js_text)
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
  <> unwrap_gleam_result_js()
  <> autonomic_wakeup_renderer_js()
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
    args: [from_param("params.message || ''"), from_param("params.review_id || ''"), lit("ctx"), lit("pi")],
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
