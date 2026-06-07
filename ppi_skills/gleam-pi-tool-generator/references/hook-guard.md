# HookGuard Reference

## Type Definition

```gleam
/// Structured guard condition — describes WHEN a hook should execute.
pub type HookGuard {
  CtxFieldExists(String)
  EventFieldExists(String)
  NoGuard
}
```

## Variants

### CtxFieldExists(field) — Execute only if ctx.field is truthy
```gleam
CtxFieldExists("model")        // → if (ctx.model) { ... }
```

Use when: the hook should only fire if a Pi context property exists.

### EventFieldExists(field) — Execute only if event.field is truthy
```gleam
EventFieldExists("model")      // → if (event.model) { ... }
```

Use when: the hook should only fire if an event property exists.

### NoGuard — Always execute
```gleam
NoGuard                        // → no if-condition, always runs
```

Use when: the hook should always execute regardless of context.

## Examples

```gleam
// Session start hook — only if model is set
event_hook(
  "session_start",
  "monitor",
  "record_current_model",
  [ctx_field("model")],
  CtxFieldExists("model"),
  SilentSuccess,
  NotifyError,
)

// Model select hook — only if event has model
event_hook(
  "model_select",
  "monitor",
  "record_current_model",
  [event_field("model", None)],
  EventFieldExists("model"),
  SilentSuccess,
  NotifyError,
)

// Agent end hook — always execute (debounce handles timing)
debounced_hook(
  "agent_end",
  "hook_on_agent_end",
  "on_agent_end",
  [ctx(), pi()],
  "psypi_config",
  "get_debounce_ms",
  ["agent_start", "input"],
  NoGuard,
  SilentSuccess,
  NotifyError,
)
```

## DELETED (Do NOT Reintroduce)

| Old | New | Why |
|-----|-----|-----|
| `guard: Some("ctx.model")` | `CtxFieldExists("model")` | Old allowed arbitrary JS expressions |
| `guard: Some("event.model")` | `EventFieldExists("model")` | Old allowed arbitrary JS expressions |
| `guard: None` | `NoGuard` | Old used Option(String), not a structured type |
