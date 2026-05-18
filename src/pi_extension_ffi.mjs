// pi_extension_ffi.mjs — FFI implementations for pi_extension.gleam
//
// These functions are called by the compiled Gleam code.
// They wrap ctx.ui.notify and ctx.ui.setStatus with proper string handling.

import { readFileSync } from 'fs';
import { complete, getModel } from '@mariozechner/pi-ai';

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
  }, { triggerTurn: false });
}

export function read_file_sync(path) {
  try {
    const content = readFileSync(String(path), 'utf-8');
    return { ok: true, value: content };
  } catch (e) {
    return { ok: false, value: e.message || 'Read failed' };
  }
}

export async function call_monitor(ctx, userPrompt, systemPrompt) {
  try {
    const model = ctx.model || getModel();
    const modelRegistry = ctx.modelRegistry;
    const messages = [
      { role: 'system', content: [{ type: 'text', text: String(systemPrompt) }] },
      { role: 'user', content: [{ type: 'text', text: String(userPrompt) }] },
    ];
    const result = await complete(model, messages, { modelRegistry });
    const text = result.choices?.[0]?.message?.content
      ?.filter(c => c.type === 'text')
      ?.map(c => c.text)
      ?.join(' ') || '';
    if (!text) {
      return { ok: false, value: 'callMonitor returned empty — LLM produced no output' };
    }
    return { ok: true, value: text };
  } catch (e) {
    return { ok: false, value: e.message || 'callMonitor failed' };
  }
}

export async function ctx_reload(ctx) {
  await ctx.reload();
}
