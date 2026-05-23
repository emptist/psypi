# Fix `before_agent_start` Hook to Record Event Trigger

## Goal
Ensure the `before_agent_start` hook records its execution in the `event_hooks` table **before** returning the system prompt.

## Problem
In the generated `extension.js`, the `before_agent_start` hook currently does:

```js
pi.on('before_agent_start', async (event, ctx) => {
    return { systemPrompt: '...' };        // exits immediately
    await event_hooks_record_trigger(...); // UNREACHABLE DEAD CODE
});
```

The `return` statement exits the function before `event_hooks_record_trigger` is called, so the hook's execution is never recorded in the database.

## Root Cause
In `src/extension_generator.gleam`:
1. `before_agent_start_body_js()` emits a raw JS string containing `return { systemPrompt: ... };`
2. The `PiRawHook` branch in `event_hook_to_js()` appends `await event_hooks_record_trigger(...)` **after** the raw body — unreachable after the `return`

## Fix
Modify `before_agent_start_body_js()` in `src/extension_generator.gleam` to emit the trigger call **before** the `return`:

```gleam
fn before_agent_start_body_js() -> String {
  [
    "    await event_hooks_record_trigger('before_agent_start');",
    "    return { systemPrompt: '\\n[A-S Role Model] ...' };",
    "",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
```

Then regenerate `extension.js` with `gleam run -m extension_generator`.

## Files Changed
- `src/extension_generator.gleam` — swap trigger/return order in `before_agent_start_body_js()`
- `extension.js` — regenerated (auto-generated, not hand-edited)

## Verification
After regeneration, `extension.js` should show:
```js
pi.on('before_agent_start', async (event, ctx) => {
    await event_hooks_record_trigger('before_agent_start');
    return { systemPrompt: '...' };
});
```
