# Plan: Implement Simple A-Worker → S-Worker Coordination via Direct Messaging

## Goal
Implement the core psypi coordination mechanism where the Autonomic Worker (A-worker) wakes the Somatic Worker (S-worker) by emitting a system/user prompt when `ctx.isIdle()` becomes true.

## Current State
- The conceptual mechanism is **already correct** in psypi's architecture.
- It relies on direct messaging: `pi.sendMessage()` or `pi.broadcast()`.
- No existing implementation uses this simple approach; coordination is under‑developed.

## Required Implementation Steps

1. **Detect Idle State**
   - In the *Monitor* (A-worker), poll or listen for `ctx.isIdle()` becoming true.[User oomment: and still true after x(=3) seconds].
   - This can be done via a timer loop or by hooking into the `agent_end`/`tool_result` events that signal completion.

2. **Emit a Wake‑up Prompt**
   - When idle is detected, send a prompt to the S‑worker.
   - Use either:
     - `pi.sendMessage(message, targetAgentId)` for direct messaging to a specific S‑worker.
     - `pi.broadcast(message)` for a global broadcast (both work).

3. **Message Content**
   - Include a recognizable `[Monitor]` prefix so the S‑worker can filter it.
   - Content should indicate new tasks, reminders, or directives.
   - Example: `"[Monitor] ⏰ Wake‑up call! New tasks ready for processing."`

4. **Persist Across Sessions (Optional)(User comment: not needed at all)**
   - Ensure prompts survive process restarts if needed.
   - Use `psypi-memory-save` or a DB entry to keep track of outstanding prompts.

5. **Integrate with Existing Hooks**
   - Leverage active hooks (`tool_result`, `session_start`, etc.) to trigger the idle‑check loop.
   - Example: set up a `pi.on('tool_result', ...)` listener that schedules the next idle check.

6. **Testing & Validation**
   - Write unit tests that simulate `ctx.isIdle()` returning true.
   - Verify the prompt reaches the intended S‑worker.
   - Confirm system prompts are injected correctly by the before_agent_start hook.

## File Structure for Implementation
- `src/monitor/worker_coordination.gleam` – Core idle detection & messaging logic.
- `src/monitor/worker_coordination.hook.gleam` – Hook registration (e.g., `tool_result` listener).
- `extension_generator.gleam` – Ensure generated `extension.js` includes the new code paths.
- `README-update.md` – Document the new coordination feature.

## Acceptance Criteria
- When an S‑worker finishes its turn and becomes idle, the A‑worker automatically sends a system prompt.
- The S‑worker receives the prompt and resumes work with an updated system context.
- Logs show a "[Monitor]" message appearing before the S‑worker’s next action.
- No breaking changes to existing functionality.

## Timeline
- **Day 1**: Draft `worker_coordination.gleam` and hook registration.
- **Day 2**: Update `extension_generator.gleam` and regenerate `extension.js`.
- **Day 3**: Write tests, integrate with existing hooks, perform final review.
- **Day 4**: Documentation update and final commit.

## Risks & Mitigations
- **Risk**: Over‑polling could cause performance issues.
  - *Mitigation*: Use debounce/throttle; only check when relevant events (`tool_result`, `session_start`) fire.
- **Risk**: Prompt injection conflicts with existing prompt modifications.
  - *Mitigation*: Prefix messages clearly (`[Monitor]`) and allow configurable injection points.

---

## Implementation Summary

### Files Created

1. **`src/worker_coordination.gleam`** — Core Gleam module with two functions:
   - `has_outstanding_work()` — queries DB for open issues and pending tasks, returns `Bool`
   - `build_wake_message()` — queries DB for open issues, pending tasks, and failed tasks; returns a `[Monitor]` prefixed message string

2. **`src/generator/agent_end_coordination.gleam`** — Generator module that produces JS text for the `agent_end` hook:
   - On `agent_end`, sets a 3-second `setTimeout`
   - After delay, checks `ctx.isIdle()`
   - If still idle, dynamically imports `worker_coordination.mjs` and calls `build_wake_message()`
   - Sends the message via one of two methods:
     - `[M]` `pi.sendMessage()` — direct structured message to current session with `triggerTurn: true` (default, active)
     - `[B]` `pi.broadcast()` — global broadcast (commented out, for experimentation)

### Files Modified

3. **`src/generator/agent_lifecycle.gleam`** — `end_body()` now delegates to `agent_end_coordination.handler_body()` instead of the previous "REMOVED" placeholder. `start_body()` unchanged.

### Files Not Modified (no changes needed)

- **`extension_generator.gleam`** — The `agent_end` hook was already registered in `all_event_hooks()`. No new `PiToolCall`, `PiEventHook`, or `PiCommandReg` types were needed.
- **`extension.js`** — Auto-regenerated correctly via `gleam run -m extension_generator`.

### Design Decisions

- **Used `agent_end` hook** (not `tool_result`) — `agent_end` fires once per turn when the worker finishes, which is the natural point to check idle state. `tool_result` fires after every tool call (mid-turn), making it unsuitable for idle detection.
- **No new types required** — Existing `PiEventHook` + generator pattern handles everything. The Gleam functions are called via dynamic `import()` from the generated JS, not exposed as Pi tools.
- **Both messaging methods included** — `[M]` and `[B]` are provided for easy experimentation by uncommenting one and commenting out the other.
- **No polling** — Purely event-driven via `agent_end` hook, consistent with the plan's debounce/throttle mitigation.

### Build Status

- Clean build: `rm -rf build/ && gleam build` — no errors, no warnings
- `extension.js` regenerated successfully
- No breaking changes to existing functionality

### Testing Status

- Not yet tested in live Pi TUI session — pending user restart and validation

---

## SDK Context Findings (2026-05-16)

After reading the Pi SDK extensions reference, here is what `ctx` and `pi` provide to the A-worker inside event hooks:

### What `ctx` provides (ExtensionContext)

| Property | Description | Useful for A-worker? |
|---|---|---|
| `ctx.isIdle()` | Whether agent is idle | ✅ Already used for idle detection |
| `ctx.getContextUsage()` | Token usage vs model context window | ✅ Could decide whether to wake S-worker based on context fullness |
| `ctx.sessionManager` | Read-only access to session entries, messages, history | ✅ Could read recent conversation to understand what S-worker was doing |
| `ctx.model` / `ctx.modelRegistry` | Current model info, API keys | ℹ️ Available but not needed for coordination |
| `ctx.getSystemPrompt()` | Current system prompt string | ℹ️ Could inspect S-worker's instructions |
| `ctx.signal` | Abort signal (usually undefined when idle) | ❌ Not useful in idle context |
| `ctx.hasPendingMessages()` | Whether queued messages exist | ✅ Could check before sending wake-up to avoid duplicates |
| `ctx.cwd` | Current working directory | ℹ️ Available if needed |
| `ctx.ui` | UI methods (notify, setStatus, etc.) | ✅ Could show status in TUI footer |
| `ctx.shutdown()` | Request graceful shutdown | ❌ Not needed |
| `ctx.compact()` | Trigger compaction | ❌ Not needed |

### What `pi` provides (ExtensionAPI)

| Method | Description | Useful for A-worker? |
|---|---|---|
| `pi.sendMessage(msg, opts)` | Inject custom message into session | ✅ Already used for wake-up |
| `pi.broadcast(msg)` | Global broadcast | ✅ Alternative method [B] |
| `pi.sendUserMessage(content)` | Send user message (appears as if typed) | ✅ Could be used instead of sendMessage |
| `pi.appendEntry(type, data)` | Persist extension state across sessions | ✅ Could log wake-up history |
| `pi.setSessionName(name)` | Set session display name | ❌ Not needed |
| `pi.setLabel(entryId, label)` | Bookmark entries in session tree | ❌ Not needed |
| `pi.getCommands()` | List available slash commands | ℹ️ Could check what S-worker can do |
| `pi.getActiveTools()` | List active tools | ℹ️ Already used in callMonitor helper |
| `pi.registerTool()` | Register new tool | ❌ Not needed for coordination |
| `pi.registerCommand()` | Register slash command | ❌ Not needed for coordination |
| `pi.on(event, handler)` | Subscribe to events | ✅ Already used for agent_end |
| `pi.exec(cmd, args)` | Execute shell command | ❌ Not needed |
| `pi.reload()` | Reload extensions | ❌ Not needed |

### Key Insight

**`ctx` and `pi` together provide rich context about the session state** — the A-worker can:

1. **Read conversation history** via `ctx.sessionManager.getEntries()` — understand what the S-worker was doing before going idle
2. **Check context usage** via `ctx.getContextUsage()` — decide if it's a good time to wake the worker (e.g., wait for compaction if context is full)
3. **Check pending messages** via `ctx.hasPendingMessages()` — avoid duplicate wake-ups
4. **Persist state** via `pi.appendEntry()` — log wake-up events for debugging
5. **Use `pi.sendUserMessage()`** — alternative to `pi.sendMessage()` that appears as a real user message

**What `ctx` does NOT provide:**
- Direct DB state (issue counts, task counts, etc.) — still requires DB queries
- The S-worker's internal state or memory

### Simplified Architecture

The A-worker does NOT need to query the DB or compose smart messages. The minimal pattern is:

```
agent_end → setTimeout(5s) → ctx.isIdle()
  → pi.sendMessage('[Monitor] Wake up.', { triggerTurn: true })
    → S-worker wakes, checks psypi-issues / psypi-tasks itself
```

The S-worker is smart enough to check for pending work. The A-worker's only job is to **wake it up**.

### Possible Enhancements (Future)

If smarter wake-up messages are needed:
- Read `ctx.sessionManager.getEntries()` to understand recent activity
- Query DB for work counts and include in message
- Use `ctx.getContextUsage()` to add context-aware hints (e.g., "context is 80% full, consider compacting")
- Use `pi.appendEntry()` to log wake-up patterns for self-improvement analysis

---

## Update (2026-05-16): Smarter Message Composition

### Changes Made

1. **Renamed `customType`** from `monitor-wake-up` to `monitor-calling` — better reflects the A-worker actively calling the S-worker.

2. **LLM now receives context** — the system prompt now includes:
   - Identity: "You are the Autonomic Worker (A-worker), the Monitor"
   - Token/context usage from `ctx.getContextUsage()` — so the LLM can mention compaction if context is full
   - Instruction to compose a context-appropriate message (1-2 sentences)
   - Fallback to static message if LLM call fails

3. **Removed `worker_coordination.gleam` dependency** — no longer imports or calls the Gleam DB query module. The A-worker composes messages entirely via `callMonitor` in JS.

### Current Flow

```
agent_end → setTimeout(5s) → ctx.isIdle()
  → ctx.getContextUsage() → token info
    → callMonitor(systemPrompt + tokenInfo)
      → LLM composes contextual [Monitor] message
        → pi.sendMessage({ customType: 'monitor-calling' }, { triggerTurn: true })
          → S-worker wakes, checks for work
```

### Observations

- LLM message varies each time (non-deterministic) — sometimes adds flair like "idle time is entropy"
- LLM can hallucinate — claimed pending work when DB was empty
- Token usage info is now fed into the LLM, so it can mention context fullness
- The S-worker always double-checks by calling psypi-issues/psypi-tasks itself, so hallucinations are harmless

---

*Prepared by the Autonomic Worker planning module. Implementation updated with context-aware message composition.*
