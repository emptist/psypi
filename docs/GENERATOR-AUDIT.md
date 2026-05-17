# Plan: Replace Fake Generator Files with Pure Gleam

## Runtime Pipeline (verified)

```
bin/ppi.mjs
  │
  │  import { generate } from './build/dev/javascript/psypi/extension_generator.mjs'
  │  ↑ compiled from src/extension_generator.gleam by `gleam build`
  │
  │  content = generate()   ← Gleam function, runs at this moment
  │  writeFileSync('extension.js', content)
  │
  │  spawn('pi', ['-e', 'extension.js', ...])
  │
  ▼
Pi TUI loads extension.js
```

**Key:** `generate()` is a pure Gleam function that returns a `String`. No hand-written JS. The `handler_body()` functions it calls are also pure Gleam functions that return `String`.

## How handler_body() Currently Works (the violation)

```gleam
// src/generator/session_start.gleam
pub fn handler_body() -> String {
  [
    "    // Session start: record model (silent)\n",
    "    try {\n",
    "      const { record_current_model } = await import('./build/dev/javascript/psypi/monitor.mjs');\n",
    "      if (ctx.model) {\n",
    "        record_current_model(ctx.model).then(() => {}).catch(() => {});\n",
    "      }\n",
    "    } catch(err) {\n",
    "      // Non-blocking\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
```

This returns a **hardcoded JS string**. The Gleam code is just a string concatenation machine. The actual logic is hand-written JS.

## How handler_body() Should Work (the proper pattern)

The `handler_body()` function should **generate** JS text from structured Gleam data, using the same patterns as `to_js_text()` in `pi_tool_call.gleam`.

The proper approach: **change `PiEventHook` to have structured fields** (like `PiToolCall`), and update `event_hook_to_js()` to generate the full JS wrapper from those fields.

Then `handler_body()` functions become trivial — they just return the result of calling `event_hook_to_js()` on a structured `PiEventHook` value.

Wait — that creates a circular dependency. Let me think again.

Actually, the simplest approach: **don't change `PiEventHook` at all.** Instead, make the `handler_body()` functions generate JS text properly using Gleam's string manipulation, constructing the JS from structured data rather than hardcoding it.

But that's still hand-written JS construction. The REAL fix is to give `PiEventHook` the same structure as `PiToolCall`.

## Decision: Change PiEventHook to Structured Type

**Current:**
```gleam
pub type PiEventHook {
  PiEventHook(
    event_name: String,
    handler_body: String,  // raw JS text
  )
}
```

**New:**
```gleam
pub type PiEventHook {
  PiEventHook(
    event_name: String,
    module: String,     // Gleam module to import
    fn_name: String,    // Gleam function to call
    args: List(FnArg),  // arguments (reuse existing FnArg type)
  )
}
```

**Rationale:** Mirrors `PiToolCall` structure. `FnArg` already supports `JsLiteral` (for `ctx.model?.id`, `event.toolName`, etc.) and `FromParam` (not needed for events, but reuse is fine). No new types needed.

## Decision: Update event_hook_to_js() to Generate from Structure

**Current:**
```gleam
pub fn event_hook_to_js(hook: PiEventHook) -> String {
  [
    "  // Event hook: " <> hook.event_name,
    "  pi.on('" <> hook.event_name <> "', async (event, ctx) => {",
    hook.handler_body,           // ← raw JS pasted in
    "  });",
    "",
  ]
  ...
}
```

**New:**
```gleam
pub fn event_hook_to_js(hook: PiEventHook) -> String {
  let args_js = args_to_js(hook.args)   // reuse existing args_to_js
  let call_expr = hook.module <> "_" <> hook.fn_name <> "(" <> args_js <> ")"
  let name = hook.event_name

  [
    "  // Event hook: " <> name,
    "  pi.on('" <> name <> "', async (event, ctx) => {",
    "    try {",
    "      const result = await " <> call_expr <> ";",
    "      const r = unwrapGleamResult(result);",
    "      if (!r.ok) {",
    "        ctx.ui.notify('" <> name <> " hook error: ' + r.error, 'error');",
    "      }",
    "    } catch(e) {",
    "      ctx.ui.notify('" <> name <> " hook exception: ' + e.message, 'error');",
    "    }",
    "  });",
    "",
  ]
  ...
}
```

**Rationale:** Generates the complete `pi.on()` wrapper from structured data. Same try/catch pattern the fake files used. Uses `unwrapGleamResult` (already defined in `helpers_text()`). Error notification via `ctx.ui.notify()`.

## Decision: Update event_hook() Helper

**Current:**
```gleam
pub fn event_hook(name: String, handler_body: String) -> PiEventHook {
  PiEventHook(event_name: name, handler_body: handler_body)
}
```

**New:**
```gleam
pub fn event_hook(
  event_name: String,
  module: String,
  fn_name: String,
  args: List(FnArg),
) -> PiEventHook {
  PiEventHook(event_name: event_name, module: module, fn_name: fn_name, args: args)
}
```

## Decision: Update to_import_line for Event Hooks

Event hooks need imports too. Reuse the same `to_import_line` pattern:

```gleam
// Already works — same as tools:
"import { fn_name as module_fn_name } from \"./build/dev/javascript/psypi/module.mjs\";"
```

Need to add event hook imports to `imports_text()` in extension_generator.

## Decision: Each Fake File Maps to a Structured PiEventHook Value

### session_start → monitor.on_session_start

**New function in monitor.gleam:**
```gleam
pub fn on_session_start(model_name: String) -> promise.Promise(Result(Nil, MonitorError)) {
  record_current_model(model_name)
}
```

**New value in monitor.gleam:**
```gleam
pub fn session_start_hook() -> PiEventHook {
  PiEventHook(
    event_name: "session_start",
    module: "monitor",
    fn_name: "on_session_start",
    args: [lit("ctx.model?.id || ''")],
  )
}
```

**Trace:** `record_current_model` exists, takes `String`. Pass `ctx.model?.id` as JsLiteral. Generated JS: `monitor_on_session_start(ctx.model?.id || '')`.

### model_select → monitor.on_model_select

**New function in monitor.gleam:**
```gleam
pub fn on_model_select(model_name: String) -> promise.Promise(Result(Nil, MonitorError)) {
  record_current_model(model_name)
}
```

**New value in monitor.gleam:**
```gleam
pub fn model_select_hook() -> PiEventHook {
  PiEventHook(
    event_name: "model_select",
    module: "monitor",
    fn_name: "on_model_select",
    args: [lit("event.model?.id || ''")],
  )
}
```

### tool_call → code_version.auto_backup_on_edit

**New function in code_version.gleam:**
```gleam
pub fn auto_backup_on_edit(tool_name: String, file_path: String) -> promise.Promise(Result(String, DbError)) {
  case tool_name {
    "edit" -> {
      case simplifile.read(file_path) {
        Ok(content) -> save_version(file_path, content, "psypi", "", "auto-backup")
        Error(_) -> promise.resolve(Error(DbError("File not found: " <> file_path)))
      }
    }
    _ -> promise.resolve(Ok("skipped"))
  }
}
```

**New value in code_version.gleam:**
```gleam
pub fn tool_call_hook() -> PiEventHook {
  PiEventHook(
    event_name: "tool_call",
    module: "code_version",
    fn_name: "auto_backup_on_edit",
    args: [
      lit("event.toolName || ''"),
      lit("event.input?.path || event.input?.filePath || ''"),
    ],
  )
}
```

**Trace:** Conditional logic and file reading move into Gleam. Event hook passes `event.toolName` and `event.input.path` as JsLiteral args. Uses `simplifile.read` (Gleam's file reading).

### tool_result → event_hooks.on_tool_result

**New function in event_hooks.gleam:**
```gleam
pub fn on_tool_result(tool_name: String, result_json: String) -> promise.Promise(Result(Nil, db.DbError)) {
  // Error detection in Gleam
  let is_error = string.contains(result_json, "\"error\"")
    || string.contains(result_json, "Error:")
    || string.contains(result_json, "execution error")
    || string.contains(result_json, "tool_execution_blocked")

  case is_error {
    True -> record_error(tool_name, "Tool returned error: " <> result_json)
    False -> promise.resolve(Ok(Nil))
  }
}
```

**New value in event_hooks.gleam:**
```gleam
pub fn tool_result_hook() -> PiEventHook {
  PiEventHook(
    event_name: "tool_result",
    module: "event_hooks",
    fn_name: "on_tool_result",
    args: [
      lit("event.toolName || 'unknown'"),
      lit("JSON.stringify(event.result || '')"),
    ],
  )
}
```

**Trace:** Error detection logic moves from JS string parsing to Gleam `string.contains`. Records error in `psypi_event_hooks` table via existing `record_error` function.

### before_agent_start → no-op

**New function in event_hooks.gleam:**
```gleam
pub fn noop() -> promise.Promise(Result(Nil, db.DbError)) {
  promise.resolve(Ok(Nil))
}
```

**New value in event_hooks.gleam:**
```gleam
pub fn before_agent_start_hook() -> PiEventHook {
  PiEventHook(
    event_name: "before_agent_start",
    module: "event_hooks",
    fn_name: "noop",
    args: [],
  )
}
```

### agent_start → no-op

Same pattern as before_agent_start.

### agent_end → delete entirely

The agent_end coordination was 200+ lines of embedded JS with DB queries, setTimeout, LLM calls, and `pi.sendMessage`. It was the source of the `gleamList.toArray` crash. Delete it. If needed later, implement as a proper Gleam tool.

## Files to Modify

1. **`src/pi_tool_call.gleam`** — Change `PiEventHook` type fields. Update `event_hook_to_js()`. Update `event_hook()` helper. Add `to_import_line` support for event hooks.

2. **`src/monitor.gleam`** — Add `on_session_start()`, `on_model_select()`, `session_start_hook()`, `model_select_hook()`.

3. **`src/code_version.gleam`** — Add `auto_backup_on_edit()`, `tool_call_hook()`.

4. **`src/event_hooks.gleam`** — Add `on_tool_result()`, `noop()`, `tool_result_hook()`, `before_agent_start_hook()`, `agent_start_hook()`.

5. **`src/extension_generator.gleam`** — Remove all `import generator/*` lines. Replace `all_event_hooks()` to use new `*_hook()` values. Add event hook imports to `imports_text()`.

## Files to Delete

All 7 files in `src/generator/`.

## Build & Test

1. `rm -rf build/ && gleam build`
2. `gleam run -m extension_generator` (to verify generation works)
3. Check `extension.js` output
4. Test in Pi TUI via `bin/ppi.mjs`
