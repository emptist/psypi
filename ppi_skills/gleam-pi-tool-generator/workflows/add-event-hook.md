# Add a New Event Hook

## Required Reading
- `references/pi-eventhook-type.md` — PiEventHook type and patterns
- `references/hook-guard.md` — HookGuard type
- `references/architecture.md` — Generator architecture

## Process

### Step 1: Create the Hook Function

In a Gleam module (e.g., `my_module.gleam`), create the handler function:

```gleam
pub fn on_my_event(ctx: PiCtx, pi: PiApi) -> promise.Promise(Nil) {
  // ... handler implementation in Gleam
}
```

### Step 2: Create PiEventHook Value

In the same module or in `extension_generator.gleam`, add:

```gleam
import pi_tool_call.{
  PiEventHook, event_hook, debounced_hook,
  event_field, event_json_field, event_file_path, ctx, pi,
  CtxFieldExists, EventFieldExists, NoGuard,
  SilentSuccess, NotifyError,
}

pub fn my_hook() -> PiEventHook {
  event_hook(
    "tool_call",              // Pi event name
    "my_module",              // Gleam module name
    "on_my_event",            // Handler function name
    [event_field("toolName", None), ctx(), pi()],  // Arguments
    NoGuard,                  // Guard condition
    SilentSuccess,            // On success action
    NotifyError,              // On error action
  )
}
```

### Step 3: Import in Generator

In `extension_generator.gleam`:

```gleam
import my_module.{my_hook}
```

Add to `all_event_hooks()`:

```gleam
pub fn all_event_hooks() -> List(PiEventHook) {
  [
    // ... existing hooks
    my_hook(),  // ← new
  ]
}
```

### Step 4: Build and Test

```bash
gleam clean && gleam build
./bin/ppi.mjs
```

### Step 5: Verify

Check that the hook is in the generated `extension.js`:

```bash
grep "pi.on('tool_call'" extension.js
```

## Hook Types

### Regular Event Hook
```gleam
event_hook(
  event_name, module, fn_name, args, guard, on_success, on_error
)
```

### Debounced Event Hook (for agent_end)
```gleam
debounced_hook(
  event_name, module, fn_name, args,
  debounce_ms_module, debounce_ms_fn,   // module.function to get debounce delay
  cancel_on,                             // events that cancel the timer
  guard, on_success, on_error
)
```

## Guard Conditions

```gleam
NoGuard                    // Always execute
CtxFieldExists("model")   // Only if ctx.model is truthy
EventFieldExists("model") // Only if event.model is truthy
```

## Common Mistakes

- **Using `guard: Some("ctx.model")`** — this NO LONGER WORKS. Use `CtxFieldExists("model")`
- **Using `guard: None`** — this NO LONGER WORKS. Use `NoGuard`
- **Forgetting to add to `all_event_hooks()`** — the hook won't be emitted
- **Not catching errors** — event hooks should never crash the extension

## Success Criteria
- [ ] Hook defined as `PiEventHook` value in Gleam
- [ ] Handler implemented as a Gleam function (not hand-written JS)
- [ ] Imported in `extension_generator.gleam` and added to `all_event_hooks()`
- [ ] `gleam clean && gleam build` succeeds
- [ ] `./bin/ppi.mjs` starts without error
- [ ] Hook appears in generated `extension.js`
