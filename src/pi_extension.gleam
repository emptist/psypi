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

/// Show an error notification
@external(javascript, "./pi_extension_ffi.mjs", "notify_error")
pub fn notify_error(ctx: a, message: String) -> Nil

/// Show a warning notification
@external(javascript, "./pi_extension_ffi.mjs", "notify_warning")
pub fn notify_warning(ctx: a, message: String) -> Nil

/// Show an info notification
@external(javascript, "./pi_extension_ffi.mjs", "notify_info")
pub fn notify_info(ctx: a, message: String) -> Nil

/// Set a status entry
@external(javascript, "./pi_extension_ffi.mjs", "set_status")
pub fn set_status(ctx: a, key: String, text: String) -> Nil
