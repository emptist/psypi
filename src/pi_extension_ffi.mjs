// pi_extension_ffi.mjs — FFI implementations for pi_extension.gleam
//
// These functions are called by the compiled Gleam code.
// They wrap ctx.ui.notify and ctx.ui.setStatus with proper string handling.

import { readFileSync } from 'fs';
import { Ok, Error } from './gleam.mjs';
console.error('[DIAG:pi_extension_ffi] MODULE LOADED');

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

export function ctx_is_idle(ctx) {
  return ctx.isIdle();
}

export function ctx_has_pending_messages(ctx) {
  return ctx.hasPendingMessages();
}

export function ctx_get_entries_json(ctx) {
  const entries = ctx.sessionManager.getEntries();
  return JSON.stringify(entries);
}

export function ctx_get_context_usage_json(ctx) {
  const usage = ctx.getContextUsage();
  return JSON.stringify(usage);
}

export function ctx_get_cwd(ctx) {
  return ctx.cwd || '';
}

export function pi_send_message(pi, customType, content, display) {
  pi.sendMessage({
    customType: String(customType),
    content: [{ type: 'text', text: String(content) }],
    display: String(display),
  }, { triggerTurn: true });
}

export function read_file_sync(path) {
  try {
    if (path === undefined || path === null) return new Error('path is ' + String(path));
    if (path === '') return new Error('path is empty string');
    const content = readFileSync(String(path), 'utf-8');
    return new Ok(content);
  } catch (e) {
    const msg = (e && e.message) ? String(e.message) : 'Read failed (no error message)';
    return new Error(msg);
  }
}

export async function ctx_reload(ctx) {
  await ctx.reload();
}

export function exec_sync(command) {
  try {
    const { execSync } = require('child_process');
    const output = execSync(String(command), { encoding: 'utf-8', maxBuffer: 10*1024*1024 });
    return new Ok(output);
  } catch (e) {
    const msg = (e && e.message) ? String(e.message) : (e ? String(e) : 'exec_sync: unknown error');
    return new Error(msg);
  }
}
