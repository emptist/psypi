// pi_tool_call.gleam — Types for Pi tool/command/hook registration
//
// Design:
//   - Each Gleam module that wants to expose a Pi tool defines a PiToolCall value
//   - PiToolCall carries ALL metadata required by Pi Extension API
//   - The generator collects PiToolCall values and composes them into extension.js
//   - Everything is TEXT — Gleam writes JS source code, not JS objects
//
// Pi Extension API requires:
//   1. pi.registerTool({ name, description, parameters, execute })
//   2. execute returns { content: [{ type: "text", text: "..." }] }
//   3. Import the Gleam-compiled .mjs module

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// -------------------------------------------------------------------
// Types
// -------------------------------------------------------------------

pub type ResultFormat {
  RawJson
  Template(String)
  CustomJs(String)
}

pub type PiParam {
  PiParam(name: String, param_type: String, required: Bool)
}

// OLD FnArg — removed after migration to FnArgument

// -------------------------------------------------------------------
// FnArgument + ParamSrc (replace old FnArg + JsLiteral + FromParam)
// -------------------------------------------------------------------

/// Structured parameter source — describes WHERE to get a value.
/// extension.js reads these at runtime to extract values from Pi callbacks.
pub type ParamSrc {
  /// params.name ?? default (e.g. params.title ?? "")
  ParamField(name: String, default: Option(String))
  /// params?.name ?? null (for optional filter params)
  OptionalParamField(name: String)
  /// parseInt(params?.name ?? String(default)) (for integer params from string input)
  IntParamField(name: String, default: Int)
  /// event?.name ?? default (for hook event properties)
  EventField(name: String, default: Option(String))
  /// JSON.stringify(event?.name ?? '') (for complex event data)
  EventJsonField(name: String)
  /// event?.input?.path || event?.input?.filePath || '' (for file edit hooks)
  EventFilePath
  /// ctx.name (e.g. ctx.model for session_start hook)
  CtxField(name: String)
  /// args || '' (for command handlers where params = args string)
  ArgsField
}

/// Structured function argument — replaces JsLiteral + FromParam(String).
/// Each variant describes WHAT to pass, not HOW (that's extension.js's job).
pub type FnArgument {
  /// Extract value from Pi callback params/event/ctx
  FromParam(ParamSrc)
  /// Pass the Pi ctx object directly
  Ctx
  /// Pass the Pi pi object directly
  Pi
  /// String constant (e.g. "psypi", "", "cli")
  StringConst(String)
  /// Integer constant (e.g. 5, 10)
  IntConst(Int)
  /// Null constant
  NullConst
}

pub type PiToolCall {
  PiToolCall(
    name: String,
    description: String,
    params: List(PiParam),
    module: String,
    fn_name: String,
    args: List(FnArgument),
    result_format: ResultFormat,
  )
}

pub type HookSuccessAction {
  SilentSuccess
  NotifySuccess(String)
  SetStatus(String, String)
}

pub type HookErrorAction {
  NotifyError
}

pub type PiEventHook {
  PiEventHook(
    event_name: String,
    module: String,
    fn_name: String,
    args: List(FnArgument),
    guard: Option(String),
    on_success: HookSuccessAction,
    on_error: HookErrorAction,
  )
  PiDebouncedHook(
    event_name: String,
    module: String,
    fn_name: String,
    args: List(FnArgument),
    debounce_ms_module: String,
    debounce_ms_fn: String,
    cancel_on: List(String),
    guard: Option(String),
    on_success: HookSuccessAction,
    on_error: HookErrorAction,
  )
  PiSystemPromptHook(
    event_name: String,
    module: String,
    fn_name: String,
    args: List(FnArgument),
    on_error: HookErrorAction,
  )
}

pub type PiCommandReg {
  PiCommandReg(
    name: String,
    description: String,
    module: String,
    fn_name: String,
    args: List(FnArgument),
    result_format: ResultFormat,
  )
}

pub type ThemeColor {
  Accent
  Warning
  Error
  Dim
}

pub type PiMessageRenderer {
  PiMessageRenderer(
    custom_type: String,
    prefix: String,
    prefix_color: ThemeColor,
    content_color: ThemeColor,
    show_details: Bool,
  )
}

// -------------------------------------------------------------------
// PiParam helpers
// -------------------------------------------------------------------

pub fn string_param(name: String) -> PiParam {
  PiParam(name: name, param_type: "string", required: True)
}

pub fn opt_string_param(name: String) -> PiParam {
  PiParam(name: name, param_type: "string", required: False)
}

pub fn number_param(name: String) -> PiParam {
  PiParam(name: name, param_type: "number", required: True)
}

// -------------------------------------------------------------------
// FnArgument + ParamSrc constructors
// -------------------------------------------------------------------

pub fn param(name: String, default: Option(String)) -> FnArgument {
  FromParam(ParamField(name:, default:))
}

pub fn opt_param(name: String) -> FnArgument {
  FromParam(OptionalParamField(name:))
}

pub fn int_param(name: String, default: Int) -> FnArgument {
  FromParam(IntParamField(name:, default:))
}

pub fn event_field(name: String, default: Option(String)) -> FnArgument {
  FromParam(EventField(name:, default:))
}

pub fn event_json_field(name: String) -> FnArgument {
  FromParam(EventJsonField(name:))
}

pub fn event_file_path() -> FnArgument {
  FromParam(EventFilePath)
}

pub fn ctx_field(name: String) -> FnArgument {
  FromParam(CtxField(name:))
}

pub fn args_field() -> FnArgument {
  FromParam(ArgsField)
}

pub fn ctx() -> FnArgument {
  Ctx
}

pub fn pi() -> FnArgument {
  Pi
}

pub fn str(value: String) -> FnArgument {
  StringConst(value)
}

pub fn int_val(value: Int) -> FnArgument {
  IntConst(value)
}

pub fn null_val() -> FnArgument {
  NullConst
}

// -------------------------------------------------------------------
// ResultFormat helpers
// -------------------------------------------------------------------

pub fn raw_json() -> ResultFormat {
  RawJson
}

pub fn template(tpl: String) -> ResultFormat {
  Template(tpl)
}

pub fn custom_js(expr: String) -> ResultFormat {
  CustomJs(expr)
}

// -------------------------------------------------------------------
// PiToolCall → JS text
// -------------------------------------------------------------------

pub fn params_to_js(params: List(PiParam)) -> String {
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

      "{ \"type\": \"object\",\n    \"properties\": {\n      "
      <> properties
      <> "\n    },\n    \"required\": ["
      <> required
      <> "]\n  }"
    }
  }
}

pub fn args_to_js(args: List(FnArgument)) -> String {
  args
  |> list.map(fn(a) { fn_argument_to_js(a) })
  |> string.join(", ")
}

fn fn_argument_to_js(fa: FnArgument) -> String {
  case fa {
    FromParam(ps) -> param_src_to_js(ps)
    Ctx -> "ctx"
    Pi -> "pi"
    StringConst(v) -> "\"" <> v <> "\""
    IntConst(v) -> int.to_string(v)
    NullConst -> "null"
  }
}

fn param_src_to_js(ps: ParamSrc) -> String {
  case ps {
    ParamField(name, default) -> {
      let default_js = case default {
        Some(d) -> "\"" <> d <> "\""
        None -> "\"\""
      }
      "params." <> name <> " ?? " <> default_js
    }
    OptionalParamField(name) -> "params?." <> name <> " ?? null"
    IntParamField(name, default) ->
      "parseInt(params?." <> name <> " ?? '" <> int.to_string(default) <> "')"
    EventField(name, default) -> {
      let default_js = case default {
        Some(d) -> "\"" <> d <> "\""
        None -> "''"
      }
      "event?." <> name <> " ?? " <> default_js
    }
    EventJsonField(name) ->
      "JSON.stringify(event?." <> name <> " ?? '')"
    EventFilePath ->
      "event?.input?.path || event?.input?.filePath || ''"
    CtxField(name) -> "ctx." <> name
    ArgsField -> "args || ''"
  }
}

pub fn result_to_js(format: ResultFormat) -> String {
  case format {
    RawJson -> "JSON.stringify(gleamValueToJson(r.value))"
    Template(tpl) -> "`" <> tpl <> "`"
    CustomJs(expr) -> expr
  }
}

pub fn to_js_text(tool: PiToolCall) -> String {
  let params_js = params_to_js(tool.params)
  let args_js = args_to_js(tool.args)
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
    "          pi_extension_ctx_notify(ctx, 'Tool "
      <> name
      <> " error: ' + r.error, 'error');",
    "        }",
    "        return r.ok ? { content: [{ type: \"text\", text: "
      <> result_js
      <> " }] } : { content: [{ type: \"text\", text: `Error: ${r.error}` }] };",
    "      } catch(e) {",
    "        pi_extension_ctx_notify(ctx, 'Tool "
      <> name
      <> " exception: ' + (e.message || String(e)), 'error');",
    "        return { content: [{ type: \"text\", text: `Error: ${e.message || String(e)}` }] };",
    "      }",
    "    }",
    "  });",
    "",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

pub fn to_import_line(tool: PiToolCall) -> String {
  let base = "./build/dev/javascript/psypi"
  let alias = tool.module <> "_" <> tool.fn_name
  "import { "
  <> tool.fn_name
  <> " as "
  <> alias
  <> " } from \""
  <> base
  <> "/"
  <> tool.module
  <> ".mjs\";"
}

// -------------------------------------------------------------------
// PiEventHook → JS text
// -------------------------------------------------------------------

fn success_action_to_js(action: HookSuccessAction) -> String {
  case action {
    SilentSuccess -> ""
    NotifySuccess(msg) -> "ctx.ui.notify('" <> msg <> "', 'info');"
    SetStatus(key, text) ->
      "ctx.ui.setStatus('" <> key <> "', '" <> text <> "');"
  }
}

/// Generate JS that reports an error via pi.sendMessage (not ctx.ui.notify).
///
/// Per the Error reporting rule: errors must go through
/// pi.sendMessage(customType="autonomic-error", triggerTurn=false,
/// deliverAs="followUp"). ctx.ui.notify is for transient status only.
fn hook_error_to_js(event_name: String, error_expr: String) -> String {
  "pi.sendMessage({ customType: 'autonomic-error', content: 'Hook "
  <> event_name
  <> " error: ' + "
  <> error_expr
  <> ", display: true }, { triggerTurn: false, deliverAs: 'followUp' });"
}

pub fn hook_import_line(module: String, fn_name: String) -> String {
  let base = "./build/dev/javascript/psypi"
  let alias = module <> "_" <> fn_name
  "const "
  <> alias
  <> " = (await import('"
  <> base
  <> "/"
  <> module
  <> ".mjs'))."
  <> fn_name
  <> ";"
}

pub fn hook_call_expr(
  module: String,
  fn_name: String,
  args: List(FnArgument),
) -> String {
  let args_js =
    args
    |> list.map(fn(a) { fn_argument_to_js(a) })
    |> string.join(", ")
  module <> "_" <> fn_name <> "(" <> args_js <> ")"
}

pub fn event_hook_to_js(hook: PiEventHook) -> String {
  case hook {
    PiSystemPromptHook(event_name:, module:, fn_name:, args:, on_error:) -> {
      let import_ln = hook_import_line(module, fn_name)
      let call = hook_call_expr(module, fn_name, args)
      let error_catch = case on_error {
        NotifyError ->
          hook_error_to_js(event_name, "(e.message || String(e))") <> "\n"
      }
      let failed_result_js = hook_error_to_js(event_name, "r.error") <> "\n"
      [
        "  // Event hook (system prompt): " <> event_name,
        "  pi.on('" <> event_name <> "', async (event, ctx) => {",
        "    try {",
        "      " <> import_ln,
        "      const result = await " <> call <> ";",
        "      const r = unwrapGleamResult(result);",
        "      if (r.ok) { return { systemPrompt: r.value }; }",
        "      else { " <> failed_result_js <> " }",
        "      await event_hooks_record_trigger('" <> event_name <> "');",
        "    } catch(e) {",
        error_catch,
        "    }",
        "  });",
        "",
      ]
      |> list.map(fn(s) { s <> "\n" })
      |> string.concat
    }

    PiEventHook(
      event_name:,
      module:,
      fn_name:,
      args:,
      guard:,
      on_success:,
      on_error:,
    ) -> {
      let import_ln = hook_import_line(module, fn_name)
      let call = hook_call_expr(module, fn_name, args)

      let guard_prefix = case guard {
        Some(g) -> "    if (" <> g <> ") {\n"
        None -> ""
      }
      let guard_suffix = case guard {
        Some(_) -> "    }\n"
        None -> ""
      }
      let success_js = success_action_to_js(on_success)
      let error_catch = case on_error {
        NotifyError ->
          hook_error_to_js(event_name, "(e.message || String(e))") <> "\n"
      }
      let failed_result_js = hook_error_to_js(event_name, "r.error") <> "\n"
      [
        "  // Event hook: " <> event_name,
        "  pi.on('" <> event_name <> "', async (event, ctx) => {",
        "    try {",
        guard_prefix,
        "      " <> import_ln,
        "      const result = await " <> call <> ";",
        "      const r = unwrapGleamResult(result);",
        "      if (r.ok) { " <> success_js <> " }",
        "      else { " <> failed_result_js <> " }",
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

    PiDebouncedHook(
      event_name:,
      module:,
      fn_name:,
      args:,
      debounce_ms_module:,
      debounce_ms_fn:,
      cancel_on:,
      guard: _,
      on_success:,
      on_error:,
    ) -> {
      let debounce_import = hook_import_line(debounce_ms_module, debounce_ms_fn)
      let debounce_call = debounce_ms_module <> "_" <> debounce_ms_fn <> "()"
      let hook_import_ln = hook_import_line(module, fn_name)
      let call = hook_call_expr(module, fn_name, args)
      let success_js = success_action_to_js(on_success)
      let error_catch = case on_error {
        NotifyError ->
          hook_error_to_js(event_name, "(e.message || String(e))") <> "\n"
      }
      let failed_result_js = hook_error_to_js(event_name, "r.error") <> "\n"
      let debounce_config_error_js =
        hook_error_to_js(event_name, "'debounce config: ' + dr.error") <> "\n"
      let outer_catch_js =
        hook_error_to_js(
          event_name,
          "'debounce setup: ' + (e.message || String(e))",
        )
        <> "\n"
      let cancel_js =
        cancel_on
        |> list.map(fn(ev) {
          let cancel_msg = case ev {
            "agent_start" -> "S became active"
            "input" -> "user activity"
            _ -> ev
          }
          let mark_worked = case ev {
            "agent_start" -> "      _hasWorked = true;\n"
            _ -> ""
          }
          [
            "  // Cancel debounce timer on: " <> ev,
            "  pi.on('" <> ev <> "', async (_event, _ctx) => {",
            mark_worked,
            "    if (_debounceTimerId) { clearTimeout(_debounceTimerId); _debounceTimerId = null; _ctx.ui.notify('[A-agentbot] Waiting cancelled — "
              <> cancel_msg
              <> "', 'status'); }",
            "  });",
            "",
          ]
          |> list.map(fn(s) { s <> "\n" })
          |> string.concat
        })
        |> string.concat
      [
        "  // Event hook (debounced): " <> event_name,
        "  let _debounceTimerId = null;",
        "  let _debounceMs = null;",
        "  let _hasWorked = false;",
        "  pi.on('" <> event_name <> "', async (event, ctx) => {",
        "    try {",
        "      if (!_hasWorked) { return; }",
        "      const _wasWaiting = _debounceTimerId !== null;",
        "      if (_debounceTimerId) clearTimeout(_debounceTimerId);",
        "      _debounceTimerId = null;",
        "      " <> debounce_import,
        "      if (_debounceMs == null) {",
        "        const debounceResult = await " <> debounce_call <> ";",
        "        const dr = unwrapGleamResult(debounceResult);",
        "        if (!dr.ok) { " <> debounce_config_error_js <> "  return; }",
        "        _debounceMs = dr.value;",
        "      }",
        "      _debounceTimerId = setTimeout(async () => {",
        "        _debounceTimerId = null;",
        "        _hasWorked = false;",
        "        try {",
        "          " <> hook_import_ln,
        "          const result = await " <> call <> ";",
        "          const r = unwrapGleamResult(result);",
        "          if (r.ok) { " <> success_js <> " }",
        "          else { " <> failed_result_js <> " }",
        "          await event_hooks_record_trigger('" <> event_name <> "');",
        "        } catch(e) {",
        error_catch,
        "        }",
        "      }, _debounceMs);",
        "      if (!_wasWaiting) { ctx.ui.notify('[A-agentbot] Waiting for S to become idle...', 'status'); }",
        "    } catch(e) {",
        outer_catch_js,
        "    }",
        "  });",
        "",
      ]
      |> list.map(fn(s) { s <> "\n" })
      |> string.concat
      <> cancel_js
    }
  }
}

// -------------------------------------------------------------------
// PiMessageRenderer → JS text
// -------------------------------------------------------------------

fn theme_color_to_js(color: ThemeColor) -> String {
  case color {
    Accent -> "'accent'"
    Warning -> "'warning'"
    Error -> "'error'"
    Dim -> "'dim'"
  }
}

pub fn message_renderer(
  custom_type: String,
  prefix: String,
  prefix_color: ThemeColor,
  content_color: ThemeColor,
  show_details: Bool,
) -> PiMessageRenderer {
  PiMessageRenderer(
    custom_type:,
    prefix:,
    prefix_color:,
    content_color:,
    show_details:,
  )
}

pub fn message_renderer_to_js(renderer: PiMessageRenderer) -> String {
  let prefix_color_js = theme_color_to_js(renderer.prefix_color)
  let content_color_js = theme_color_to_js(renderer.content_color)
  let details_block = case renderer.show_details {
    True ->
      "    if (expanded && message.details) {\n"
      <> "      text += '\\n' + theme.fg('dim', JSON.stringify(message.details, null, 2));\n"
      <> "    }\n"
    False -> ""
  }
  [
    "  pi.registerMessageRenderer('"
      <> renderer.custom_type
      <> "', (message, { expanded }, theme) => {",
    "    let text = theme.fg("
      <> prefix_color_js
      <> ", '"
      <> renderer.prefix
      <> " ');",
    "    text += theme.fg(" <> content_color_js <> ", message.content);",
    details_block,
    "    const box = new Box(1, 1, (t) => theme.bg('customMessageBg', t));",
    "    box.addChild(new Text(text, 0, 0));",
    "    return box;",
    "  });",
    "",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

// -------------------------------------------------------------------
// Hook constructors
// -------------------------------------------------------------------

pub fn system_prompt_hook(
  event_name: String,
  module: String,
  fn_name: String,
  args: List(FnArgument),
  on_error: HookErrorAction,
) -> PiEventHook {
  PiSystemPromptHook(event_name:, module:, fn_name:, args:, on_error:)
}

pub fn event_hook(
  event_name: String,
  module: String,
  fn_name: String,
  args: List(FnArgument),
  guard: Option(String),
  on_success: HookSuccessAction,
  on_error: HookErrorAction,
) -> PiEventHook {
  PiEventHook(
    event_name:,
    module:,
    fn_name:,
    args:,
    guard:,
    on_success:,
    on_error:,
  )
}

pub fn debounced_hook(
  event_name: String,
  module: String,
  fn_name: String,
  args: List(FnArgument),
  debounce_ms_module: String,
  debounce_ms_fn: String,
  cancel_on: List(String),
  guard: Option(String),
  on_success: HookSuccessAction,
  on_error: HookErrorAction,
) -> PiEventHook {
  PiDebouncedHook(
    event_name:,
    module:,
    fn_name:,
    args:,
    debounce_ms_module:,
    debounce_ms_fn:,
    cancel_on:,
    guard:,
    on_success:,
    on_error:,
  )
}

// -------------------------------------------------------------------
// PiCommandReg → JS text
// -------------------------------------------------------------------

pub fn command(
  name: String,
  description: String,
  module: String,
  fn_name: String,
  args: List(FnArgument),
  result_format: ResultFormat,
) -> PiCommandReg {
  PiCommandReg(name:, description:, module:, fn_name:, args:, result_format:)
}

pub fn command_to_js(cmd: PiCommandReg) -> String {
  case cmd {
    PiCommandReg(name:, description:, module:, fn_name:, args:, result_format:) -> {
      let import_line = hook_import_line(module, fn_name)
      let call = hook_call_expr(module, fn_name, args)
      let result_js = result_to_js(result_format)
      [
        "  // " <> description,
        "  pi.registerCommand(\"" <> name <> "\", {",
        "    description: \"" <> description <> "\",",
        "    handler: async (args, ctx) => {",
        "      try {",
        "        " <> import_line,
        "        const result = await " <> call <> ";",
        "        const r = unwrapGleamResult(result);",
        "        return r.ok ? { content: [{ type: \"text\", text: "
          <> result_js
          <> " }] } : { content: [{ type: \"text\", text: `Error: ${r.error}` }] };",
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
