// pi_extension.gleam — Pi Extension notification helpers
//
// These functions wrap ctx.ui.notify and ctx.ui.setStatus calls.
// They use FFI to directly invoke the JS methods on the ctx object.
//
// Design:
//   - The generator imports these compiled functions
//   - Generated JS wrappers call them instead of ad-hoc string concatenation
//   - Gleam type system ensures proper usage at the Gleam level
//   - At the JS level, they are simple wrappers around ctx.ui.*

import gleam/javascript/promise

@external(javascript, "./pi_extension_ffi.mjs", "ctx_notify")
pub fn ctx_notify(ctx: a, message: String, notify_type: String) -> Nil

@external(javascript, "./pi_extension_ffi.mjs", "set_status")
pub fn set_status(ctx: a, key: String, text: String) -> Nil

@external(javascript, "./pi_extension_ffi.mjs", "ctx_is_idle")
pub fn ctx_is_idle(ctx: a) -> Bool

@external(javascript, "./pi_extension_ffi.mjs", "ctx_has_pending_messages")
pub fn ctx_has_pending_messages(ctx: a) -> Bool

@external(javascript, "./pi_extension_ffi.mjs", "ctx_get_entries_json")
pub fn ctx_get_entries_json(ctx: a) -> String

@external(javascript, "./pi_extension_ffi.mjs", "ctx_get_context_usage_json")
pub fn ctx_get_context_usage_json(ctx: a) -> String

@external(javascript, "./pi_extension_ffi.mjs", "ctx_get_cwd")
pub fn ctx_get_cwd(ctx: a) -> String

@external(javascript, "./pi_extension_ffi.mjs", "ctx_get_source")
pub fn ctx_get_source(ctx: a) -> String

@external(javascript, "./pi_extension_ffi.mjs", "ctx_get_model_id")
pub fn ctx_get_model_id(ctx: a) -> String

@external(javascript, "./pi_extension_ffi.mjs", "ctx_get_thinking_level")
pub fn ctx_get_thinking_level(ctx: a) -> String

@external(javascript, "./pi_extension_ffi.mjs", "pi_send_message")
pub fn pi_send_message(
  pi: a,
  custom_type: String,
  content: String,
  display: String,
  trigger_turn: Bool,
) -> Nil

@external(javascript, "./pi_extension_ffi.mjs", "read_file_sync")
pub fn read_file_sync(path: String) -> Result(String, String)

@external(javascript, "./pi_extension_ffi.mjs", "call_monitor")
pub fn call_monitor(
  ctx: a,
  user_prompt: String,
  system_prompt: String,
) -> promise.Promise(Result(String, String))

@external(javascript, "./pi_extension_ffi.mjs", "ctx_reload")
pub fn ctx_reload(ctx: a) -> promise.Promise(Nil)

@external(javascript, "./pi_extension_ffi.mjs", "exec_sync")
pub fn exec_sync(command: String) -> Result(String, String)

@external(javascript, "./pi_extension_ffi.mjs", "unwrapGleamResult")
pub fn unwrap_gleam_result(result: a) -> b

@external(javascript, "./pi_extension_ffi.mjs", "gleamValueToJson")
pub fn gleam_value_to_json(val: a) -> b

@external(javascript, "./pi_extension_ffi.mjs", "now_ms")
pub fn now_ms() -> Int
