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

import gleam/option.{type Option}

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
// Hook constructors
// -------------------------------------------------------------------

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
    guard:,
    on_success:,
    on_error:,
  )
}

// -------------------------------------------------------------------
// Command constructors
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
