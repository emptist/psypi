# Plan: Replace Fake Generator Modules with Real Gleam Code

## Problem Analysis

The 7 files under `src/generator/` are "fake" — they embed raw JavaScript strings
inside Gleam source code without leveraging Gleam's type system, FFI, or proper
calling conventions. Several generate JS that would FAIL at runtime because they
call Gleam-compiled functions with wrong signatures.

### Critical Bugs in Fake Files

1. **`agent_end_coordination.gleam`** — Imports `db_query.mjs` and calls
   `db.query(sql, params)` directly. But the Gleam `db_query` module exports
   `execute()`, not `query()`. And the `db` module's `query()` requires a
   `Connection` object. **This would crash at runtime.**

2. **`session_start.gleam` / `model_select.gleam`** — Call
   `record_current_model(ctx.model)` but don't handle the Gleam `Result` type
   returned by the compiled function. They use `.then(() => {}).catch(() => {})`
   which silently swallows both Ok and Error values.

3. **`tool_call.gleam`** — Calls `save_version()` with 5 args but doesn't use
   `unwrapGleamResult` to check if the operation succeeded. The `ctx.ui.setStatus`
   call always shows "Auto-backed up" even if it failed.

4. **`tool_result.gleam`** — Uses `pi.sendMessage()` with `customType:
   'autonomic-error'` but the message format may not match Pi's expectations.
   The error detection is fragile (string matching on JSON).

5. **`before_agent_start.gleam`** — Just a comment, no-op. Trivially "correct"
   but useless as Gleam code.

6. **`agent_lifecycle.gleam`** — Delegates to `agent_end_coordination`, inheriting
   its bugs.

## Architecture: How Real Gleam Code Should Work

The Pi Extension API requires `extension.js` to be a JavaScript file with:
```js
export default function(pi) {
  pi.on('event_name', async (event, ctx) => { ... });
  pi.registerTool({ name, description, parameters, execute });
}
```

Gleam CANNOT produce this file directly — Pi won't accept `.gleam` or
Gleam-compiled `.mjs` as an extension. The generator approach is correct:
**Gleam writes JS source text**, which becomes `extension.js`.

The "real" approach improves on the fake by:

1. **Using `unwrapGleamResult`** — The helper already exists in the generated
   `extension.js`. All calls to Gleam-compiled functions should use it.

2. **Correct import paths** — Gleam compiles `src/foo.gleam` to
   `build/dev/javascript/psypi/foo.mjs`. The generated JS must import from
   this path.

3. **Correct function signatures** — The generated JS must call Gleam functions
   with the right number and type of arguments.

4. **Proper error handling** — Use `unwrapGleamResult` to check Ok/Error and
   report failures via `ctx.ui.notify()`.

5. **Minimal JS, maximum Gleam** — Where possible, move logic into Gleam
   functions and call them from thin JS wrappers.

## File-by-File Replacement Plan

### Order: Simplest → Most Complex

| #   | Fake File                                | New File                            | Key Changes                                                |
| --- | ---------------------------------------- | ----------------------------------- | ---------------------------------------------------------- |
| 1   | `generator/before_agent_start.gleam`     | `hook_before_agent_start.gleam`     | No-op, properly structured                                 |
| 2   | `generator/session_start.gleam`          | `hook_session_start.gleam`          | Use unwrapGleamResult for record_current_model             |
| 3   | `generator/model_select.gleam`           | `hook_model_select.gleam`           | Use unwrapGleamResult for record_current_model             |
| 4   | `generator/tool_call.gleam`              | `hook_tool_call.gleam`              | Use unwrapGleamResult for save_version                     |
| 5   | `generator/tool_result.gleam`            | `hook_tool_result.gleam`            | Keep Pi API calls in JS, improve error detection           |
| 6   | `generator/agent_lifecycle.gleam`        | `hook_agent_lifecycle.gleam`        | Delegate to hook_agent_end_coordination                    |
| 7   | `generator/agent_end_coordination.gleam` | `hook_agent_end_coordination.gleam` | Use db_query.execute() instead of db.query(), fix all bugs |

### Process for Each File

1. Create new real Gleam module under `src/`
2. Rename fake file by appending `.fake`
3. Update `extension_generator.gleam` imports
4. Run `gleam build` to verify
5. Git commit

### Import Path Convention

The `pi_tool_call.to_import_line()` function generates import lines like:
```js
import { fn_name as module_fn_name } from "./build/dev/javascript/psypi/module.mjs";
```

For event hooks, we'll use dynamic imports inside the handler body:
```js
const { fn_name } = await import('./build/dev/javascript/psypi/module.mjs');
```

This matches the pattern already used in the fake files and is correct for
lazy-loading within event handlers.

### The `unwrapGleamResult` Pattern

Every call to a Gleam-compiled function should use:
```js
const result = await gleam_function(args);
const r = unwrapGleamResult(result);
if (!r.ok) {
  ctx.ui.notify('Error: ' + r.error, 'error');
}
```

This ensures Gleam's Result type is properly handled and errors are surfaced.

### agent_end_coordination: The Big Fix

The most critical fix. The fake version calls `db.query()` which doesn't exist
in the compiled output. The real version should:

1. Use `db_query.execute()` to read `monitor_debounce_ms` from `system_config`
2. The `db_query.execute(sql, params)` function returns
   `promise.Promise(Result(QueryResult, QueryError))` which compiles to a
   JS Promise resolving to a Gleam Result
3. Use `unwrapGleamResult` to extract the value
4. Keep `setTimeout`, `ctx.isIdle()`, `callMonitor()`, and `pi.sendMessage()`
   in JS (they're Pi API calls that can't be done from Gleam)

## Verification

After each replacement:
1. `gleam build` must pass with no errors
2. The generated `extension.js` must have the same structure
3. Event hook handlers must correctly call Gleam-compiled functions
4. All Gleam Result types must be unwrapped properly
