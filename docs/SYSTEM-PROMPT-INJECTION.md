# A-worker → S-worker Communication via pi.sendMessage

## Problem

The Autonomic Worker (A-worker) was sending messages via `ctx.ui.notify()`. These are **fire-and-forget UI-only notifications** — the S-worker (LLM) never sees them in its conversation context.

```
agent_end hook:
  ctx.ui.notify("What should we do next?", "info")  ← S-worker never sees this

tool_result hook:
  ctx.ui.notify("Tool error: ...", "error")          ← S-worker never sees this
```

## Solution

Use `pi.sendMessage()` — a native Pi SDK method that injects a `CustomMessage` into the session, visible to the LLM on the next turn.

### Pi SDK API (from extensions docs)

```typescript
pi.sendMessage({
  customType: "my-type",
  content: [{ type: "text", text: "message" }],
  display: "persistent",
  details: { ... },
}, {
  deliverAs: "nextTurn"  // Queue for next user prompt
});
```

Options for `deliverAs`:
- `"steer"` — deliver after current turn finishes (interrupts)
- `"followUp"` — deliver when agent is fully idle
- `"nextTurn"` — queue for next user prompt (non-interrupting)

### What Changed

| Hook | Before | After |
|------|--------|-------|
| `agent_end` | `ctx.ui.notify(msg, 'info')` only | `ctx.ui.notify(msg, 'info')` (debug) + `pi.sendMessage(...)` (visible to S-worker) |
| `tool_result` | `ctx.ui.notify('Tool error: ...')` only | `ctx.ui.notify(...)` (debug) + `pi.sendMessage(...)` (visible to S-worker) |

### Flow

```
A-worker (agent_end)
  ├── ctx.ui.notify(msg, 'info')     ← UI debug message (unchanged)
  └── pi.sendMessage({...}, {deliverAs: 'nextTurn'})
        ↓
      CustomMessage queued in session
        ↓
      S-worker sees it on next turn
```

### Custom Message Types

- `autonomic-message` — from `agent_end` (context usage, git status reminders)
- `autonomic-error` — from `tool_result` (tool execution errors)

### Files Changed

| File | Change |
|------|--------|
| `src/generator/agent_lifecycle.gleam` | Added `pi.sendMessage()` call alongside existing `ctx.ui.notify()` |
| `src/generator/tool_result.gleam` | Added `pi.sendMessage()` call alongside existing `ctx.ui.notify()` |

### Why Not DB (system_directives table)?

First attempt used the `system_directives` DB table as a message queue with `before_agent_start` reading and injecting into system prompt. This failed because:

1. Gleam functions return `Promise(Result(T, E))` — JS needs `unwrapGleamResult()` to access `.ok`/`.value`
2. Hook code didn't use `unwrapGleamResult()`, so `.ok` checks always failed
3. Added unnecessary complexity (DB round-trip, identity resolution, consume tracking)

`pi.sendMessage()` is the correct Pi SDK primitive for this — no DB, no Gleam result unwrapping, no identity lookup needed.
