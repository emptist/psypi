// pi_tool_call.gleam — Pi Tool Call type
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
import gleam/option.{type Option, Some, None}
import gleam/string

// -------------------------------------------------------------------
// Types
// -------------------------------------------------------------------

/// How to format the tool result
pub type ResultFormat {
  /// JSON.stringify the result
  RawJson
  /// Template string, e.g. "Task: ${r.value}"
  Template(String)
  /// Custom JS expression that produces the text
  CustomJs(String)
}

/// A parameter for the Pi tool (maps to TypeBox schema)
pub type PiParam {
  PiParam(name: String, param_type: String, required: Bool)
}

/// Argument to pass to the Gleam function call
pub type FnArg {
  /// Literal JS expression, e.g. "false", "\"psypi\"", "_sessionId"
  JsLiteral(String)
  /// Read from Pi tool params, e.g. "params.title || \"\""
  FromParam(String)
}

/// Complete definition of one Pi tool
pub type PiToolCall {
  PiToolCall(
    // Pi tool identity
    name: String,
    description: String,
    // Pi parameters schema (JS text for TypeBox)
    params: List(PiParam),
    // Which Gleam module/function to call
    module: String,
    fn_name: String,
    // Arguments to pass to the Gleam function
    args: List(FnArg),
    // How to format the result
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
  IgnoreError
}

pub type PiEventHook {
  PiEventHook(
    event_name: String,
    module: String,
    fn_name: String,
    args: List(FnArg),
    guard: Option(String),
    on_success: HookSuccessAction,
    on_error: HookErrorAction,
  )
  PiDebouncedHook(
    event_name: String,
    module: String,
    fn_name: String,
    args: List(FnArg),
    debounce_ms_module: String,
    debounce_ms_fn: String,
    debounce_default: Int,
    guard: Option(String),
    on_success: HookSuccessAction,
    on_error: HookErrorAction,
  )
  PiRawHook(
    event_name: String,
    handler_body: String,
  )
}

pub type PiCommandReg {
  PiCommandReg(
    name: String,
    description: String,
    module: String,
    fn_name: String,
    args: List(FnArg),
    result_format: ResultFormat,
  )
  PiRawCommand(
    name: String,
    description: String,
    handler_body: String,
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
// FnArg helpers
// -------------------------------------------------------------------

pub fn lit(arg: String) -> FnArg {
  JsLiteral(arg)
}

pub fn from_param(expr: String) -> FnArg {
  FromParam(expr)
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
// These functions convert PiToolCall values into JavaScript source text
// -------------------------------------------------------------------

/// Generate the TypeBox parameters schema as JS text
/// Produces proper JSON Schema: { type: "object", properties: {...}, required: [...] }
/// This is required for strict models like LM Studio's Qwen3-4b which reject
/// the shorthand format with "invalid_union_discriminator: Expected 'object'"
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

      "{ \"type\": \"object\",\n    \"properties\": {\n      " <> properties <> "\n    },\n    \"required\": [" <> required <> "]\n  }"
    }
  }
}

/// Generate the function call arguments as JS text
pub fn args_to_js(args: List(FnArg)) -> String {
  args
  |> list.map(fn(a) {
    case a {
      JsLiteral(v) -> v
      FromParam(e) -> e
    }
  })
  |> string.join(", ")
}

/// Generate the result formatting JS text
pub fn result_to_js(format: ResultFormat) -> String {
  case format {
    RawJson -> "JSON.stringify(r.value)"
    Template(tpl) -> "`" <> tpl <> "`"
    CustomJs(expr) -> expr
  }
}

/// Generate the complete pi.registerTool({...}) block as JS text
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

/// Generate the import statement for this tool's Gleam module
/// Uses aliased imports to avoid name collisions (e.g., add from task.mjs vs issue.mjs)
pub fn to_import_line(tool: PiToolCall) -> String {
  let base = "./build/dev/javascript/psypi"
  let alias = tool.module <> "_" <> tool.fn_name
  "import { " <> tool.fn_name <> " as " <> alias <> " } from \"" <> base <> "/" <> tool.module <> ".mjs\";"
}

fn success_action_to_js(action: HookSuccessAction) -> String {
  case action {
    SilentSuccess -> ""
    NotifySuccess(msg) -> "ctx.ui.notify('" <> msg <> "', 'info');"
    SetStatus(key, text) ->
      "ctx.ui.setStatus('" <> key <> "', '" <> text <> "');"
  }
}

fn error_action_to_js(action: HookErrorAction) -> String {
  case action {
    NotifyError -> "ctx.ui.notify('Hook error: ' + (e.message || String(e)), 'error');"
    IgnoreError -> ""
  }
}

fn hook_import_line(module: String, fn_name: String) -> String {
  let base = "./build/dev/javascript/psypi"
  let alias = module <> "_" <> fn_name
  "const " <> alias <> " = (await import('" <> base <> "/" <> module <> ".mjs'))." <> fn_name <> ";"
}

fn hook_call_expr(module: String, fn_name: String, args: List(FnArg)) -> String {
  module <> "_" <> fn_name <> "(" <> args_to_js(args) <> ")"
}

pub fn event_hook_to_js(hook: PiEventHook) -> String {
  case hook {
    PiRawHook(event_name:, handler_body:) -> {
      [
        "  // Event hook: " <> event_name,
        "  pi.on('" <> event_name <> "', async (event, ctx) => {",
        handler_body,
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
      let import_line = hook_import_line(module, fn_name)
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
      let _error_js = error_action_to_js(on_error)
      let error_catch = case on_error {
        NotifyError -> "      ctx.ui.notify('Hook " <> event_name <> " error: ' + (e.message || String(e)), 'error');\n"
        IgnoreError -> ""
      }
      [
        "  // Event hook: " <> event_name,
        "  pi.on('" <> event_name <> "', async (event, ctx) => {",
        "    try {",
        guard_prefix,
        "      " <> import_line,
        "      const result = await " <> call <> ";",
        "      const r = unwrapGleamResult(result);",
        "      if (r.ok) { " <> success_js <> " }",
        "      else { ctx.ui.notify('Hook " <> event_name <> " failed: ' + r.error, 'error'); }",
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
      debounce_default:,
      guard: _,
      on_success:,
      on_error:,
    ) -> {
      let debounce_import =
        hook_import_line(debounce_ms_module, debounce_ms_fn)
      let debounce_call =
        debounce_ms_module <> "_" <> debounce_ms_fn <> "()"
      let hook_import_line_ = hook_import_line(module, fn_name)
      let call = hook_call_expr(module, fn_name, args)
      let success_js = success_action_to_js(on_success)
      let _error_js = error_action_to_js(on_error)
      let error_catch = case on_error {
        NotifyError -> "        ctx.ui.notify('Hook " <> event_name <> " error: ' + (e.message || String(e)), 'error');\n"
        IgnoreError -> ""
      }
      [
        "  // Event hook (debounced): " <> event_name,
        "  pi.on('" <> event_name <> "', async (event, ctx) => {",
        "    try {",
        "      let debounceMs;",
        "      {",
        "        " <> debounce_import,
        "        const result = await " <> debounce_call <> ";",
        "        const r = unwrapGleamResult(result);",
        "        debounceMs = r.ok ? r.value : " <> int.to_string(debounce_default) <> ";",
        "      }",
        "      setTimeout(async () => {",
        "        try {",
        "          " <> hook_import_line_,
        "          const result = await " <> call <> ";",
        "          const r = unwrapGleamResult(result);",
        "          if (r.ok) { " <> success_js <> " }",
        "          else { ctx.ui.notify('Hook " <> event_name <> " failed: ' + r.error, 'error'); }",
        "        } catch(e) {",
        error_catch,
        "        }",
        "      }, debounceMs);",
        "    } catch(e) {",
        "      ctx.ui.notify('Hook " <> event_name <> " debounce error: ' + (e.message || String(e)), 'error');",
        "    }",
        "  });",
        "",
      ]
      |> list.map(fn(s) { s <> "\n" })
      |> string.concat
    }
  }
}

pub fn raw_event_hook(name: String, handler_body: String) -> PiEventHook {
  PiRawHook(event_name: name, handler_body: handler_body)
}

pub fn event_hook(
  event_name: String,
  module: String,
  fn_name: String,
  args: List(FnArg),
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
  args: List(FnArg),
  debounce_ms_module: String,
  debounce_ms_fn: String,
  debounce_default: Int,
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
    debounce_default:,
    guard:,
    on_success:,
    on_error:,
  )
}

// -------------------------------------------------------------------
// PiCommandReg → JS text
// -------------------------------------------------------------------

pub fn raw_command(name: String, description: String, handler_body: String) -> PiCommandReg {
  PiRawCommand(name: name, description: description, handler_body: handler_body)
}

pub fn command(
  name: String,
  description: String,
  module: String,
  fn_name: String,
  args: List(FnArg),
  result_format: ResultFormat,
) -> PiCommandReg {
  PiCommandReg(name:, description:, module:, fn_name:, args:, result_format:)
}

pub fn command_to_js(cmd: PiCommandReg) -> String {
  case cmd {
    PiRawCommand(name:, description:, handler_body:) -> {
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
