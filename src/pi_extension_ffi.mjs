// pi_extension_ffi.mjs — FFI implementations for pi_extension.gleam
//
// These functions are called by the compiled Gleam code.
// They wrap ctx.ui.notify and ctx.ui.setStatus with proper string handling.

import { readFileSync } from 'fs';
import { Ok, Error } from './gleam.mjs';
import { complete, getModel } from '@earendil-works/pi-ai';

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
    content: String(content),
    display: true,
  }, { triggerTurn: true, deliverAs: 'steer' });
}

export async function call_monitor(ctx, userPrompt, systemPrompt) {
  try {
    const model = ctx.model;
    const modelRegistry = ctx.modelRegistry;
    if (!model) {
      return new Error('callMonitor v3: ctx.model is missing');
    }
    notify_info(ctx, '[AUTONOMIC] call_monitor v3: model=' + (model.id || model.provider || 'unknown'));
    const auth = await modelRegistry.getApiKeyAndHeaders(model);
    if (!auth.ok || !auth.apiKey) {
      return new Error('callMonitor v3: no API key for ' + (model.provider || 'unknown') + ': ' + (auth.error || 'auth failed'));
    }
    notify_info(ctx, '[AUTONOMIC] call_monitor v3: auth ok, calling complete...');
    const context = {
      systemPrompt: String(systemPrompt),
      messages: [
        { role: 'user', content: [{ type: 'text', text: String(userPrompt) }], timestamp: Date.now() },
      ],
    };
    const result = await complete(model, context, { apiKey: auth.apiKey, headers: auth.headers });
    notify_info(ctx, '[AUTONOMIC] call_monitor v3: complete returned, stopReason=' + (result?.stopReason || 'none') + ' contentLen=' + (result?.content?.length || 0));
    if (result?.errorMessage) {
      return new Error('callMonitor v3: LLM error: ' + result.errorMessage);
    }
    let text = '';
    if (Array.isArray(result?.content)) {
      text = result.content.filter(c => c.type === 'text').map(c => c.text).join(' ');
    }
    if (!text && typeof result?.text === 'string') {
      text = result.text;
    }
    if (!text) {
      return new Error('callMonitor v3: empty output, stopReason=' + (result?.stopReason || 'none'));
    }
    return new Ok(text);
  } catch (e) {
    return new Error(e.message || 'callMonitor failed');
  }
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
    const output = execSync(String(command), { encoding: 'utf-8', maxBuffer: 10 * 1024 * 1024 });
    return new Ok(output);
  } catch (e) {
    const msg = (e && e.message) ? String(e.message) : (e ? String(e) : 'exec_sync: unknown error');
    return new Error(msg);
  }
}
