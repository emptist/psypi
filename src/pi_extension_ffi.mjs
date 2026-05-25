// pi_extension_ffi.mjs — FFI implementations for pi_extension.gleam
//
// These functions are called by the compiled Gleam code.
// They wrap ctx.ui.notify and ctx.ui.setStatus with proper string handling.

import { readFileSync } from 'fs';
import { Ok, Error } from './gleam.mjs';
import { completeSimple, getModel } from '@earendil-works/pi-ai';

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
  if (!ctx.cwd) {
    ctx.ui.notify('[AUTONOMIC] <ERROR> ctx_get_cwd: ctx.cwd is missing', 'error');
    return '';
  }
  return ctx.cwd;
}

export function pi_send_message(pi, customType, content, display) {
  pi.sendMessage({
    customType: String(customType),
    content: String(content),
    display: true,
  }, { triggerTurn: true });
}

export async function call_monitor(ctx, userPrompt, systemPrompt) {
  try {
    const model = ctx.model;
    const modelRegistry = ctx.modelRegistry;
    if (!model) {
      return new Error('callMonitor: ctx.model is missing');
    }

    const auth = await modelRegistry.getApiKeyAndHeaders(model);
    if (!auth.ok || !auth.apiKey) {
      return new Error('callMonitor: no API key for ' + (model.provider || 'unknown') + ': ' + (auth.error || 'auth failed'));
    }

    const context = {
      systemPrompt: String(systemPrompt),
      messages: [
        { role: 'user', content: [{ type: 'text', text: String(userPrompt) }], timestamp: Date.now() },
      ],
    };

    let result = await completeSimple(model, context, { apiKey: auth.apiKey, headers: auth.headers, reasoning: 'medium' });

    const extractText = (r) => {
      let t = '';
      if (Array.isArray(r?.content)) {
        t = r.content.filter(c => c.type === 'text').map(c => c.text).join(' ');
      }
      if (!t && typeof r?.text === 'string') {
        t = r.text;
      }
      return t;
    };

    let hasThinking = Array.isArray(result?.content) && result.content.some(c => c.type === 'thinking');
    let text = extractText(result);

    const shouldRetry = !text || (result?.errorMessage && (result.errorMessage === 'terminated' || result.errorMessage.includes('rate')));
    if (shouldRetry) {
      result = await completeSimple(model, context, { apiKey: auth.apiKey, headers: auth.headers, reasoning: 'none' });
      hasThinking = Array.isArray(result?.content) && result.content.some(c => c.type === 'thinking');
      text = extractText(result);
    }

    if (result?.errorMessage && !text) {
      return new Error('LLM error: ' + result.errorMessage);
    }
    if (!text) {
      if (hasThinking) {
        return new Error('LLM only thought, no text output. stopReason=' + (result?.stopReason || 'none'));
      }
      return new Error('empty output, stopReason=' + (result?.stopReason || 'none') + ' contentTypes=' + (Array.isArray(result?.content) ? result.content.map(c => c.type).join(',') : 'none'));
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

export function now_ms() {
  return Date.now();
}

// Simple in-memory config store for idle_since tracking
let _configStore = {};

export function get_config(key) {
  return _configStore[key] || null;
}

export function set_config(key, value) {
  _configStore[key] = value;
}

export function unwrapGleamResult(result) {
  if (!result) return { ok: false, error: 'null result' };
  const typeName = result.constructor?.name || '';
  if (typeName === 'Ok') return { ok: true, value: result['0'] };
  if (typeName === 'Error') return { ok: false, error: JSON.stringify(gleamValueToJson(result['0'])) || 'Unknown' };
  return { ok: true, value: result };
}

export function gleamValueToJson(val) {
  if (val === null || val === undefined) return val;
  if (typeof val !== 'object') return val;
  const name = val.constructor?.name || '';
  if (name === 'NonEmpty') {
    const arr = [];
    let cur = val;
    while (cur && cur.constructor?.name === 'NonEmpty') {
      arr.push(gleamValueToJson(cur.head));
      cur = cur.tail;
    }
    return arr;
  }
  if (name.startsWith('Task$Task') || name.startsWith('Issue$Issue') || name.startsWith('Meeting$Meeting') || name.startsWith('Skill$Skill') || name.startsWith('Opinion$Opinion') || name.startsWith('Broadcast$Broadcast') || name.startsWith('Learning$Learning') || name.startsWith('Memory$Memory') || name.startsWith('AgentIdentity$AgentIdentity') || name.startsWith('Directive$Directive') || name.startsWith('InterReview$InterReview') || name.startsWith('CodeVersion$CodeVersion') || name.startsWith('ActivityLog$ActivityLog') || name.startsWith('Config$Config') || name.startsWith('Stats$Stats')) {
    return Object.fromEntries(Object.entries(val).map(([k, v]) => [k, gleamValueToJson(v)]));
  }
  if (name === 'Some') return gleamValueToJson(val['0'] ?? val[0]);
  if (name === 'None') return null;
  if (name === 'Ok') return { ok: true, value: gleamValueToJson(val['0'] ?? val[0]) };
  if (name === 'Error') return { ok: false, error: gleamValueToJson(val['0'] ?? val[0]) };
  if (name.includes('$') && !name.startsWith('_')) {
    const variantName = name.split('$').pop();
    const fields = Object.entries(val).map(([k, v]) => gleamValueToJson(v));
    if (fields.length === 0) return variantName;
    if (fields.length === 1) return { type: variantName, value: fields[0] };
    return { type: variantName, fields: fields };
  }
  if (Array.isArray(val)) return val.map(gleamValueToJson);
  return Object.fromEntries(Object.entries(val).map(([k, v]) => [k, gleamValueToJson(v)]));
}
