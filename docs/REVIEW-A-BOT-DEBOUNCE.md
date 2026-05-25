# A-Bot Debounce System — Complete Root Cause Analysis & Fix Plan

**Date:** 2026-05-26
**Scope:** agent_end debounce hook, A-S communication, timer management
**Related Issues:** b9ea707f, f0c389d5, 0bd23575 (all consolidated into 16ef800a)

---

## 1. System Overview

The A-bot (Autonomic) wakes up after S-bot (Somatic) finishes a turn and goes idle. The chain:

```
S finishes turn
  → Pi fires "agent_end" event
    → extension.js: pi.on('agent_end') handler (GENERATED from PiDebouncedHook)
      → reads debounceMs from psypi_config table (DB call)
      → starts setTimeout(debounceMs)
        → setTimeout callback fires
          → calls hook_on_agent_end.gleam:on_agent_end(ctx, pi)
            → checks ctx.isIdle() && !ctx.hasPendingMessages()
              → if idle: coordinate_with_s()
                → double-checks ctx.isIdle()
                → checks DB: is_s_still_idle()
                  → if still idle: coordinate_when_idle()
                    → reads soul + jobs + project state from DB
                    → calls LLM via call_monitor()
                    → sends wake-up message via pi_send_message()
```

### Key Files in the Chain

| File | Role |
|---|---|
| `src/pi_tool_call.gleam` | Defines PiDebouncedHook type + generates JS for agent_end handler |
| `src/extension_generator.gleam` | Collects hooks, composes extension.js |
| `src/hook_on_agent_end.gleam` | Gleam handler: idle check → coordinate → orchestrate |
| `src/a_orchestrator.gleam` | Reads soul+jobs+state from DB, calls LLM, sends message |
| `src/a_db_reader.gleam` | DB reads: soul, jobs, project state, idle check |
| `src/a_prompt_builder.gleam` | Composes system/user prompts for A's LLM call |
| `src/a_context_utils.gleam` | Context window parsing, time utilities |
| `src/psypi_config.gleam` | Config read/write (debounce_ms, idle_since, etc.) |
| `src/pi_extension.gleam` | FFI declarations for ctx/pi operations |
| `src/pi_extension_ffi.mjs` | FFI implementations (notify, send_message, call_monitor, etc.) |
| `src/node_ffi.mjs` | Node.js FFI (now_ms, execute, etc.) |
| `extension.js` | GENERATED — the actual running code |

---

## 2. Root Cause Analysis

### Bug A: Timer Stacking (Issue b9ea707f)

**Symptom:** Multiple `setTimeout` callbacks stack up, each triggering a full A-workflow.

**Root cause:** The generated JS in `pi_tool_call.gleam` `event_hook_to_js()` for `PiDebouncedHook` starts a new `setTimeout` on every `agent_end` event with no dedup:

```javascript
// Current generated code (extension.js lines 157-180)
pi.on('agent_end', async (event, ctx) => {
  // ... read debounceMs ...
  setTimeout(async () => {
    // ... full A workflow (DB reads + LLM call + message send)
  }, debounceMs);
});
```

If S finishes 3 turns within the debounce window, 3 independent timers are queued. All 3 fire, each doing DB reads + LLM calls + sending messages.

**Fix:** Add a module-level timer ID variable. Clear any existing timer before starting a new one:

```javascript
let _debounceTimerId = null;
pi.on('agent_end', async (event, ctx) => {
  try {
    if (_debounceTimerId) clearTimeout(_debounceTimerId);
    // ... read debounceMs ...
    _debounceTimerId = setTimeout(async () => {
      _debounceTimerId = null;
      // ... A workflow
    }, debounceMs);
  } catch(e) { ... }
});
```

### Bug B: Timer Resets on Every Turn (Issue f0c389d5)

**Symptom:** A fires immediately after S's last turn, not after S has been idle for `debounceMs`.

**Root cause:** Because a new `setTimeout` starts on every `agent_end`, the timer resets each time. If S keeps working, the timer keeps resetting. A fires `debounceMs` after the *last* turn, not after S *first* became idle.

**Fix:** Track when S first becomes idle. Only start the timer once. This requires:
1. Recording `idle_since` timestamp when S first goes idle
2. On subsequent `agent_end` events, checking if `now - idle_since >= debounceMs`
3. Only proceeding if enough time has passed

### Bug C: No idle_since Tracking (Issue 0bd23575)

**Symptom:** A fires immediately, bypassing `monitor_debounce_ms`.

**Root cause:** The fix described in issue 0bd23575 (commits 960c2f1, 388a92c) was never fully implemented. The current `hook_on_agent_end.gleam` has NO `idle_since` tracking — it only checks `ctx.isIdle()` as a boolean snapshot. The `now_ms()` FFI exists but is not used in the hook.

**Fix:** Add time-based gating in `hook_on_agent_end.gleam`:
1. When S is not idle → clear `idle_since` in psypi_config
2. When S is idle and `idle_since` is not set → record current timestamp
3. When S is idle and `idle_since` is set → check if `now - idle_since >= debounceMs`
4. Only proceed with A workflow if enough time has passed

### Bug D: DB Call on Every agent_end (Performance)

**Symptom:** `psypi_config_get_debounce_ms()` is called on every `agent_end` — a DB round-trip per S turn.

**Root cause:** The generated JS reads `debounceMs` from DB inside the `agent_end` handler with no caching.

**Fix:** Cache `debounceMs` at module level after first read.

---

## 3. Doc-Code Gaps Found

### Gap 1: README.md — Wrong table name
**File:** `README.md` line ~165
**Docs say:** "Read `monitor_debounce_ms` from `system_config` table"
**Code says:** `psypi_config` table (seed.gleam line 49, psypi_config.gleam)
**Impact:** Misleading — anyone following the docs would query the wrong table.

### Gap 2: README.md — Phase 1 described but not implemented
**File:** `README.md` lines ~155-175
**Docs say:** "Phase 1: Immediate Feedback — `agent_end` fires → check `ctx.isIdle()` → call `ctx.ui.notify()` right away"
**Code says:** No Phase 1 exists. The hook jumps straight to debounce (Phase 2).
**Impact:** The documented 3-phase protocol doesn't match the 2-phase implementation.

### Gap 3: README.md — "Current bug" section is outdated
**File:** `README.md` lines ~175-180
**Docs say:** "Phase 1 is missing from the code" and "callMonitor is returning empty output"
**Code says:** Phase 1 is indeed missing, but `call_monitor` has been fixed (retry logic, error handling). The "empty output" bug may be resolved.
**Impact:** Partially outdated — the call_monitor fix isn't reflected.

### Gap 4: ARCHITECTURE.md — Missing modules
**File:** `docs/ARCHITECTURE.md`
**Docs say:** File structure lists only core modules
**Code says:** Many modules are missing from the listing: `a_orchestrator.gleam`, `a_prompt_builder.gleam`, `a_context_utils.gleam`, `psypi_config.gleam`, `event_hooks.gleam`, `seed.gleam`, `node_ffi.mjs`, `pi_extension_ffi.mjs`
**Impact:** Incomplete architecture reference.

### Gap 5: ARCHITECTURE.md — Wrong FFI file name
**File:** `docs/ARCHITECTURE.md`
**Docs say:** `pi_extension_ffi.mjs` is listed under `src/`
**Code says:** The file IS at `src/pi_extension_ffi.mjs` — this is actually correct. But the generated `extension.js` imports from `./build/dev/javascript/psypi/pi_extension.mjs` (the compiled Gleam output), not directly from the FFI.
**Impact:** Minor — the import chain is more complex than documented.

### Gap 6: Issue 9d6b6b02 — Fix already applied but issue still open
**File:** `src/pi_extension_ffi.mjs` line 148
**Issue says:** `unwrapGleamResult` uses raw `result['0']` → `[object Object]`
**Code says:** Already fixed: `JSON.stringify(gleamValueToJson(result['0']))`
**Impact:** The `[object Object]` bug should be resolved. Issue 9d6b6b02 was marked resolved on May 24, which is correct.

### Gap 7: Issue cc64c9f5 — Fix applied but needs restart
**File:** `src/a_db_reader.gleam`
**Issue says:** `decode.string` → `decode.int` for priority field, fix built but Pi needs restart
**Code says:** Fix is in the source and in extension.js. The "restart required" note is from May 25 — Pi has likely been restarted since.
**Impact:** Issue should be verified and closed.

### Gap 8: agent_soul content outdated (Issue 22261e08)
**File:** `agent_souls` table in DB
**Issue says:** Soul content references `system_config` table and old responsibilities
**Code says:** The seed data in `seed.gleam` only inserts if not exists (`ON CONFLICT DO NOTHING`), so old data persists.
**Impact:** A-bot and S-bot read stale soul content from DB.

---

## 4. Fix Plan

### Fix 1: Timer Dedup in Generated JS (fixes Bug A + B)
**File:** `src/pi_tool_call.gleam` — `event_hook_to_js()` for `PiDebouncedHook`

Add module-level timer tracking:
```javascript
let _debounceTimerId = null;
let _debounceMs = null;

pi.on('agent_end', async (event, ctx) => {
  try {
    // Clear any existing timer
    if (_debounceTimerId) clearTimeout(_debounceTimerId);
    
    // Cache debounceMs after first read
    if (_debounceMs == null) {
      const psypi_config_get_debounce_ms = (await import('./build/dev/javascript/psypi/psypi_config.mjs')).get_debounce_ms;
      const debounceResult = await psypi_config_get_debounce_ms();
      const dr = unwrapGleamResult(debounceResult);
      if (!dr.ok) { ctx.ui.notify('Hook agent_end <ERROR> debounce config: ' + dr.error, 'error'); return; }
      _debounceMs = dr.value;
    }
    
    // Start new timer
    _debounceTimerId = setTimeout(async () => {
      _debounceTimerId = null;
      try {
        ctx.ui.notify('[AUTONOMIC] setTimeout callback fired for agent_end', 'info');
        const hook_on_agent_end_on_agent_end = (await import('./build/dev/javascript/psypi/hook_on_agent_end.mjs')).on_agent_end;
        const result = await hook_on_agent_end_on_agent_end(ctx, pi);
        const r = unwrapGleamResult(result);
        if (r.ok) { }
        else { ctx.ui.notify('Hook agent_end failed: ' + r.error, 'error'); }
        await event_hooks_record_trigger('agent_end');
      } catch(e) {
        ctx.ui.notify('Hook agent_end error: ' + (e.message || String(e)), 'error');
      }
    }, _debounceMs);
  } catch(e) {
    ctx.ui.notify('Hook agent_end debounce error: ' + (e.message || String(e)), 'error');
  }
});
```

### Fix 2: idle_since Time-Based Gating (fixes Bug C)
**File:** `src/hook_on_agent_end.gleam`

Add time-based gating using `psypi_config`:
```gleam
import a_context_utils
import a_db_reader
import a_orchestrator
import gleam/javascript/promise
import gleam/string
import pi_extension.{...}
import psypi_config.{get_int, set}
import node_ffi.{now_ms}  // or use a_context_utils.current_time_ms()

pub fn on_agent_end(ctx: a, pi: b) -> promise.Promise(Result(Nil, String)) {
  case ctx_is_idle(ctx) {
    False -> {
      // S is active — clear idle_since
      promise.await(set("idle_since", "0"), fn(_) {
        promise.resolve(Ok(Nil))
      })
    }
    True -> {
      // S is idle — check how long
      promise.await(get_int("idle_since"), fn(idle_result) {
        case idle_result {
          Ok(0) | Error(_) -> {
            // First time seeing idle — record timestamp
            let now = a_context_utils.current_time_ms()
            promise.await(set("idle_since", int.to_string(now)), fn(_) {
              promise.resolve(Ok(Nil))
            })
          }
          Ok(idle_since) -> {
            let now = a_context_utils.current_time_ms()
            let elapsed = now - idle_since
            // Read debounceMs from config
            promise.await(psypi_config.get_debounce_ms(), fn(dm_result) {
              case dm_result {
                Ok(debounce_ms) -> {
                  case elapsed >= debounce_ms {
                    True -> {
                      // Debounce satisfied — proceed
                      set("idle_since", "0")
                      // ... proceed with A workflow ...
                    }
                    False -> promise.resolve(Ok(Nil))
                  }
                }
                Error(_) -> promise.resolve(Ok(Nil))
              }
            })
          }
        }
      })
    }
  }
}
```

### Fix 3: Update README.md
**File:** `README.md`
- Fix `system_config` → `psypi_config` references
- Update Phase 1 description to match actual implementation
- Remove outdated "Current bug" section or update with current status

### Fix 4: Update ARCHITECTURE.md
**File:** `docs/ARCHITECTURE.md`
- Add missing modules to file structure
- Document the full A-chain: hook → orchestrator → prompt_builder → call_monitor

### Fix 5: Resolve Stale Issues
- Issue 9d6b6b02: Already resolved (FFI fix in place) — verify and close
- Issue cc64c9f5: Fix in code — verify and close
- Issue 22261e08: Update agent_souls content in DB

---

## 5. Verification Checklist

- [ ] S finishes a turn → only ONE setTimeout exists (no stacking)
- [ ] S finishes multiple turns within debounce window → timer doesn't reset
- [ ] S stays idle for `monitor_debounce_ms` → A fires exactly once
- [ ] S becomes busy before debounce expires → A does NOT fire
- [ ] `psypi_config.idle_since` is set when S goes idle
- [ ] `psypi_config.idle_since` is cleared when S becomes active
- [ ] `psypi_config.idle_since` is cleared after A fires
- [ ] No DB call for debounceMs on every agent_end (cached after first read)
- [ ] README.md matches actual implementation
- [ ] ARCHITECTURE.md lists all modules

---

## 6. Build & Deploy

After code changes:
```bash
gleam clean && gleam build
gleam run -m extension_generator
# Restart Pi
```
