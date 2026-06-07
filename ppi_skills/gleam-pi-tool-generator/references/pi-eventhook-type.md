# PiEventHook Type Reference

## Type Definition

```gleam
pub type PiEventHook {
  PiEventHook(
    event_name: String,
    module: String,
    fn_name: String,
    args: List(FnArgument),
    guard: HookGuard,
    on_success: HookSuccessAction,
    on_error: HookErrorAction,
  )
  PiDebouncedHook(
    event_name: String,
    module: String,
    fn_name: String,
    args: List(FnArgument),
    debounce_ms_module: String,
    debounce_ms_fn: String,
    cancel_on: List(String),
    guard: HookGuard,
    on_success: HookSuccessAction,
    on_error: HookErrorAction,
  )
}
```

## HookSuccessAction

```gleam
pub type HookSuccessAction {
  SilentSuccess
  NotifySuccess(String)
  SetStatus(String, String)
}
```

## HookErrorAction

```gleam
pub type HookErrorAction {
  NotifyError
}
```

## HookGuard

```gleam
pub type HookGuard {
  CtxFieldExists(String)     // if (ctx.field) { ... }
  EventFieldExists(String)   // if (event.field) { ... }
  NoGuard                    // always execute
}
```

## Constructors

```gleam
event_hook(
  event_name, module, fn_name, args, guard, on_success, on_error
)

debounced_hook(
  event_name, module, fn_name, args,
  debounce_ms_module, debounce_ms_fn, cancel_on,
  guard, on_success, on_error
)
```

## Example: Tool Call Hook

```gleam
event_hook(
  "tool_call",
  "hook_on_tool_call",
  "on_tool_call",
  [event_field("toolName", None), event_file_path(), ctx(), pi()],
  NoGuard,
  SilentSuccess,
  NotifyError,
)
```

## Example: Session Start Hook with Guard

```gleam
event_hook(
  "session_start",
  "monitor",
  "record_current_model",
  [ctx_field("model")],
  CtxFieldExists("model"),
  SilentSuccess,
  NotifyError,
)
```

## Example: Debounced Agent End Hook

```gleam
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

## Available Pi Events

| Event | When it fires |
|-------|---------------|
| `session_start` | New session started |
| `tool_call` | Before a tool executes (can block) |
| `tool_result` | After a tool returns |
| `agent_start` | Agent starts a turn |
| `agent_end` | Agent finishes a turn |
| `model_select` | Model selection changes |
| `message_end` | A message is finalized |

## Safety Rules

1. **Handler must be a Gleam function** — never hand-write JS strings
2. **Use `HookGuard` for conditions** — never use `Option(String)` for guards
3. **Keep handler bodies small** — complex logic should be in Gleam modules
4. **Don't block tool calls unless necessary** — return early if the hook doesn't apply
5. **Hook errors use `pi.sendMessage`** — hooks have no return value, must use persistent message

## DELETED (Do NOT Reintroduce)

| Old | New | Why |
|-----|-----|-----|
| `guard: Some("ctx.model")` | `CtxFieldExists("model")` | Old allowed arbitrary JS expressions |
| `guard: None` | `NoGuard` | Old used Option(String), not structured |
