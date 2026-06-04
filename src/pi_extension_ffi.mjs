// pi_extension_ffi.mjs — FFI implementations for pi_extension.gleam
//
// These functions are called by the compiled Gleam code.
// They wrap ctx.ui.notify and ctx.ui.setStatus with proper string handling.
//
// ⚠️ ERROR REPORTING RULE (do not break) ⚠️
// ============================================================
// ctx.ui.notify (i.e. the ctx_notify wrapper below) is ONLY for
// A's *internal thinking* and *transient status messages*. It shows
// a transient toast in the TUI but the message is NOT persisted, is
// NOT seen by S, and disappears the moment the user types.
//
// For ANY Error, use pi.sendMessage(...) with customType="autonomic-error"
// and triggerTurn=false, deliverAs="followUp" instead. That is the only
// way an Error reaches the conversation log so S (or a human reading
// the transcript) can react to it.
//
// Using ctx.ui.notify for an Error will break the Error reporting
// system — the Error is silently swallowed, never persisted, never
// sent to S, and can never be triaged. The user has explicitly called
// this out as a non-negotiable invariant (2026-06-04).
// ============================================================

import { readFileSync } from 'fs';
import { Ok, Error } from './gleam.mjs';
import { completeSimple, getModel } from '@earendil-works/pi-ai';

// ctx_notify — wrapper around ctx.ui.notify
//
// ⚠️ This function MUST NOT be used for Errors. ⚠️
//
// Acceptable callers (A's internal thinking / transient status):
//   - "[AUTONOMIC] A loading soul + jobs..."          (status)
//   - "[A-agentbot] Reading soul from database..."    (status)
//   - "[A-agentbot] Cancelled due to user activity"   (status)
//
// Forbidden callers (Error reporting — must use pi.sendMessage):
//   - Any "<ERROR> ..." string                          → use pi.sendMessage
//   - notify_type="error"                               → use pi.sendMessage
//
// If a Gleam call site passes notify_type="error" or includes the
// substring "<ERROR>", that is a BUG — the call must be rewritten
// to use pi_extension.pi_send_message with customType="autonomic-error".
export function ctx_notify(ctx, message, type) {
  ctx.ui.notify(String(message), String(type));
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
    // ⚠️ BUG: This is an Error path and ctx.ui.notify is FORBIDDEN here.
    // It is acceptable for now ONLY because this branch is reached during
    // an FFI call from Gleam, and we have no `pi` handle in this scope to
    // call pi.sendMessage. The message will be invisible to S, but at
    // least A's user sees something in the TUI.
    //
    // The proper fix is to make ctx_get_cwd return a Result type at the
    // Gleam boundary and let the caller (hook_on_agent_end / on_tool_call)
    // decide between pi_send_message (error) and a graceful fallback. Do
    // NOT refactor this without also wiring pi through the call site.
    ctx.ui.notify('[AUTONOMIC] <ERROR> ctx_get_cwd: ctx.cwd is missing', 'error');
    return '';
  }
  return ctx.cwd;
}

export function ctx_get_source(ctx) {
  return ctx.model?.provider || '';
}

export function ctx_get_model_id(ctx) {
  return ctx.model?.id || '';
}

export function ctx_get_thinking_level(ctx) {
  return ctx.model?.thinkingLevel || '';
}

// pi_send_message — wrapper around pi.sendMessage
//
// This is the ONLY sanctioned path for Error reporting in psypi.
//
// Usage matrix (matches the "Error reporting system" rule, 2026-06-04):
//
//   Inform an Error (do NOT wake S, do NOT start a new turn):
//     customType = "autonomic-error"
//     triggerTurn = false
//     deliverAs = "followUp"
//   → Error appears in S's next turn as a follow-up message, not a new
//     S turn. Error is preserved in the conversation log.
//
//   Wake S after A finished its work (review saved, or save failed and
//   A is stuck):
//     customType = "autonomic-wakeup"
//     triggerTurn = true
//     deliverAs = "followUp"
//   → S starts a new turn and reacts to A's review. This is the ONLY
//     case where triggerTurn=true is legitimate. Never use it as a
//     "panic on any error" — that would re-introduce the degenerate
//     dialogue the user explicitly forbade.
//
//   Queue for S's next turn (no immediate wake):
//     customType = "autonomic-wakeup"
//     triggerTurn = false
//     deliverAs = "nextTurn"
//   → Reserved for future use; not currently used in psypi.
export function pi_send_message(pi, customType, content, display, triggerTurn, deliverAs) {
  const options = { triggerTurn: triggerTurn === true || triggerTurn === "true" };
  if (deliverAs === "nextTurn" || deliverAs === "followUp") {
    options.deliverAs = deliverAs;
  }
  pi.sendMessage({
    customType: String(customType),
    content: String(content),
    display: display === "persistent" || display === "true" || display === true,
  }, options);
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
  // Gleam compiled JS uses short class names (e.g. 'Task', 'Issue', 'Meeting')
  // NOT factory names like 'Task$Task'. Handle both for forward compatibility.
  const isGleamCustomType = name.includes('$') || [
    'Task', 'Issue', 'Meeting', 'Skill', 'Opinion', 'Broadcast',
    'Learning', 'Memory', 'AgentIdentity', 'Directive', 'InterReview',
    'CodeVersion', 'ActivityLog', 'Config', 'Stats', 'Project',
    'HealthMetrics', 'AlertMetrics', 'MonitorError', 'MonitorAction',
    'MonitorSuggestion', 'ModelStats', 'SafetyResult',
    'ReviewResult', 'ReviewFinding',
    'MemoryError', 'ReflectionError', 'IssueSummary',
    'ReflectionResult', 'SkillError',
    'SkillSource', 'SkillStatus', 'InterReviewError',
  ].includes(name);
  if (isGleamCustomType) {
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
