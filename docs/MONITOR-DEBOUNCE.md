# Monitor Debounce Time

The Autonomic Agentbot (Monitor) waits after the Somatic Agentbot goes idle before sending a wake-up message.

## A-bot's Two Modes: Waiting and Working

A-bot has exactly two modes:

1. **Waiting mode** — A stopwatch runs, counting how long S has been **continuously idle** (`ctx.isIdle() === true`, `ctx.isStreaming === false`). The stopwatch **resets to zero** on any S activity signal. The stopwatch **resets to zero** when A starts working.

2. **Working mode** — Triggered when and only when the stopwatch reaches `monitor_debounce_ms`. A reads soul/jobs from DB, calls LLM via `call_monitor()`, and sends results to S.

**The stopwatch is the only technically non-trivial part of the entire A/S system.** Everything else uses Pi's built-in support.

### Stopwatch Logic (CRITICAL)

```
Stopwatch state: psypi_config.idle_since (Unix ms timestamp, or "0" when not running)

On ANY S activity (agent_end while S is NOT idle, tool_call, user input):
  → stopwatch RESETS TO ZERO (idle_since = "0")

On agent_end AND ctx.isIdle()=true AND no pending messages:
  → IF idle_since = "0": START stopwatch (idle_since = now_ms()), DO NOT work yet
  → IF idle_since != "0": CHECK elapsed = now_ms() - idle_since
      → elapsed >= monitor_debounce_ms: RESET stopwatch, START WORKING
      → elapsed < monitor_debounce_ms: DO NOTHING, keep waiting

When A starts working: stopwatch RESETS TO ZERO
```

**Key invariant**: The stopwatch ONLY advances while S is continuously idle. Any S activity resets it. A working also resets it. This guarantees A never interrupts S.

**NEVER reduce debounce time as a "fix"** — the debounce duration is a design choice, not a bug. If A-bot doesn't fire, it means S hasn't been idle long enough. That is correct behavior.

## Configuration

- **Key:** `monitor_debounce_ms`
- **Default:** 300000ms (5 minutes)
- **Current:** 900000ms (15 minutes) — extended during active development to avoid interruptions
- **Location:** `psypi_config` table

## Setting a Custom Value

```sql
UPDATE psypi_config SET value = '300000' WHERE key = 'monitor_debounce_ms';
```

Values (in milliseconds):
- 300000 = 5 minutes (default)
- 120000 = 2 minutes
- 60000 = 1 minute

## How It Works

1. When `agent_end` fires (S-agentbot finishes)
2. extension.js: `setTimeout(callback, debounceMs)` with timer dedup (clear previous timer before starting new one). Debounce value read from `psypi_config.monitor_debounce_ms` (cached after first read).
3. After debounce timer fires, `hook_on_agent_end.on_agent_end(ctx, pi)` executes the stopwatch logic above.
4. If stopwatch satisfied — `hook_on_agent_end.gleam`'s `coordinate_when_idle()` reads soul+jobs+state from DB via `a_db_reader`, builds prompts via `a_prompt_builder`, calls `call_monitor()`, sends result via `pi_send_message()`.

**Changes to debounce take effect after restart** (cached at module level in extension.js).

## A-bot Communication Rules

- **A's thinking/progress** → `ctx.ui.notify()` — visible in TUI, does NOT trigger S
- **A's output for S** → `pi.sendMessage({customType: 'autonomic-wakeup', content: msg}, {triggerTurn: true})` — injects message into S's session, triggers a new S turn
- Both A and S can see each other's messages, forming a **dialogue pattern**

## Debugging Failed Wake-up Messages

If you see `[Monitor] Wake up. (callMonitor failed: <error>)`, the LLM call failed. Common reasons:
- No model available
- Missing API key
- Network error

The error message helps S-agentbot debug the issue.