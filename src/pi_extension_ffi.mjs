// pi_extension_ffi.mjs — FFI implementations for pi_extension.gleam
//
// These functions are called by the compiled Gleam code.
// They wrap ctx.ui.notify and ctx.ui.setStatus with proper string handling.

export function notify_error(ctx, message) {
  ctx.ui.notify(String(message), "error");
}

export function notify_warning(ctx, message) {
  ctx.ui.notify(String(message), "warning");
}

export function notify_info(ctx, message) {
  ctx.ui.notify(String(message), "info");
}

export function set_status(ctx, key, text) {
  ctx.ui.setStatus(String(key), String(text));
}
