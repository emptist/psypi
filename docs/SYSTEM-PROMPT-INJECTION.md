# A-agentbot → S-agentbot Communication via pi.sendMessage

## Problem

The Autonomic Agentbot (A-agentbot) was sending messages via `ctx.ui.notify()`. These are **fire-and-forget UI-only notifications** — the S-agentbot (LLM) never sees them in its conversation context.

## Solution

Use `pi.sendMessage()` — a native Pi SDK method that injects a `CustomMessage` into the session, visible to the LLM on the next turn.

### Pi SDK API

```typescript
pi.sendMessage({
  customType: "my-type",
  content: [{ type: "text", text: "message" }],
  display: "persistent",
  details: { ... },
}, {
  deliverAs: "nextTurn"
});
```

Options for `deliverAs`:
- `"steer"` — deliver after current turn finishes (interrupts)
- `"followUp"` — deliver when agent is fully idle
- `"nextTurn"` — queue for next user prompt (non-interrupting)

### Flow

```
A-agentbot (agent_end hook)
  ├── call_monitor() calls LLM with A's system prompt
  │   LLM returns polite reminder text
  └── pi.sendMessage({customType: 'autonomic-wakeup', content: msg})
        ↓
      CustomMessage queued in session
        ↓
      S-agentbot sees it on next turn
```

### Custom Message Types

- `autonomic-wakeup` — A's polite reminder to S (rendered with `[A-agentbot]` prefix)
- `autonomic-error` — error notifications from A (rendered with `[A-agentbot ERROR]` prefix)

Both are rendered via `pi.registerMessageRenderer()` in `pi_extension_ffi.mjs`.

### Why Not DB (system_directives table)?

The removed `system_directives` anti-pattern tried to use a database table as a message queue with `before_agent_start` reading and injecting into system prompt. This was over-engineered: S is an LLM that understands natural language. A just needs to talk to S.

`pi.sendMessage()` is the correct Pi SDK primitive for this — no DB intermediary, no Gleam result unwrapping, no identity lookup needed.

See README.md "Lesson: The system_directives Anti-Pattern" for the full story.

### Files

| File | Role |
|------|------|
| `src/hook_on_agent_end.gleam` | Debounce + call_monitor coordination |
| `src/pi_extension_ffi.mjs` | FFI: `call_monitor`, `sendMessage`, message renderers |
| `src/a_prompt_builder.gleam` | Composes A's system/user prompts |
| `src/a_db_reader.gleam` | Reads A's SOUL + jobs from DB |
