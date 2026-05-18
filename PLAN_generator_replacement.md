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

---

## Execution Summary (Completed 2026-05-18)

### Files Created (under `src/`)

| New Real Module                     | Replaces Fake                            | Key Fix                                                                        |
| ----------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------ |
| `hook_before_agent_start.gleam`     | `generator/before_agent_start.gleam`     | Clean no-op structure                                                          |
| `hook_session_start.gleam`          | `generator/session_start.gleam`          | Uses `unwrapGleamResult` — fake silently swallowed Ok/Error                    |
| `hook_model_select.gleam`           | `generator/model_select.gleam`           | Uses `unwrapGleamResult` — fake silently swallowed Ok/Error                    |
| `hook_tool_call.gleam`              | `generator/tool_call.gleam`              | Uses `unwrapGleamResult` — fake always showed "Auto-backed up" even on failure |
| `hook_tool_result.gleam`            | `generator/tool_result.gleam`            | Clean error variable naming, consistent patterns                               |
| `hook_agent_lifecycle.gleam`        | `generator/agent_lifecycle.gleam`        | Delegates to `hook_agent_end_coordination`                                     |
| `hook_agent_end_coordination.gleam` | `generator/agent_end_coordination.gleam` | CRITICAL: Uses `db_query.execute()` — fake called non-existent `db.query()`    |

### Critical Bug Fixed

The most important fix was in **`agent_end_coordination`**: the fake version
called `db.query(sql, params)` which **does not exist** in the Gleam-compiled
output. The `db_query` module exports `execute()`, not `query()`, and the `db`
module's `query()` requires a `Connection` object. This would have **crashed
at runtime** every time the agent_end hook fired. The real version uses
`db_query.execute()` with `unwrapGleamResult` to properly handle the Gleam
Result type.

### Commits (6 total on `defake` branch)

1. `before_agent_start` — simplest, no-op
2. `session_start` — unwrapGleamResult for record_current_model
3. `model_select` — unwrapGleamResult for record_current_model
4. `tool_call` — unwrapGleamResult for save_version
5. `tool_result` — clean error handling
6. `agent_lifecycle + agent_end_coordination` — critical db_query.execute() fix

### Verification Results

- `gleam build` passes with zero errors after each replacement
- `gleam run -m extension_generator` produces valid `extension.js`
- All 7 event hooks (`tool_call`, `session_start`, `model_select`,
  `before_agent_start`, `agent_start`, `agent_end`, `tool_result`) are
  correctly generated in `extension.js`
- All Gleam-compiled function calls use `unwrapGleamResult` pattern
- All fake files renamed with `.fake` suffix in `src/generator/`

### Remaining Cleanup (Optional)

- Delete `.fake` files from `src/generator/` when no longer needed
- Delete `src/generator/GENERATOR_DOCS.md` when no longer needed
- Remove empty `src/generator/` directory
- Delete this plan file when no longer needed

---

## IdentityContext Refactoring (2026-05-18)

### What Changed

`get_resolved_identity` went from 6 positional args to 1 `IdentityContext`:

```gleam
// Before: 6 positional args — fragile, order matters, "autonomous" was misleading
get_resolved_identity(True, "psypi", provider, model_id, thinking_level, False)

// After: 1 value type — named fields, self-documenting, order doesn't matter
get_resolved_identity(IdentityContext(
  is_idle: True, project: "psypi", source: provider,
  model: model_id, thinking_level: thinking_level, global: False,
))
```

### Key Insight: `autonomous` = `ctx.is_idle`

The old `autonomous: Bool` parameter was never truly independent. It maps
directly to `ctx.isIdle()` in the Pi runtime:

- `ctx.isIdle() = true` → A-worker (Autonomic, event-driven)
- `ctx.isIdle() = false` → S-worker (Somatic, prompt-driven)

Renaming to `is_idle` makes this mapping explicit. The generated JS now passes
`is_idle: ctx.isIdle()` dynamically instead of hardcoding `true`/`false`.

### What Simplified

1. **`directive.gleam`** — No longer needs to remember arg order. Named fields
   are self-documenting. `is_idle: True` is clearer than the old positional
   `True` (which meant "autonomous").

2. **Pi tool definitions** — `somatic_id_tool()` and `autonomic_id_tool()` had
   6 separate `lit()` args that had to match the function signature position.
   One wrong position = wrong identity silently. Now they construct one object
   literal — field names are explicit, order doesn't matter.

3. **Tests** — Each test case went from a positional arg list to a named record.
   You can read the test and immediately know what `True` means (it's
   `is_idle`, not `autonomous`).

### What Could Simplify Further (YAGNI — Wait for It)

The `IdentityContext` is now a **value type** that can flow through the system.
This opens up simplifications that weren't possible with 6 loose args:

1. **`directive.gleam`** still manually extracts `provider` from `model_id`.
   But `IdentityContext` already has `source` (provider). If the Pi tool for
   `psypi-direct-worker` constructed an `IdentityContext` and passed it to
   `set_directive`, the function wouldn't need `model_id` and `thinking_level`
   as separate params — it would take `IdentityContext` directly. Two fewer args.

2. **`agent_identity_db.gleam`** — If it exists, it probably takes identity
   fields separately. With `IdentityContext` as the input type, it could take
   the whole context and derive everything from it.

3. **Hooks that need identity** — `hook_agent_end_coordination` currently
   doesn't call `get_resolved_identity` at all. But if it needed to log "who
   acted", it could construct `IdentityContext` from `ctx` and call the one
   function. No need to figure out which args to pass.

4. **`inter_review.gleam`** — Line 182 has a comment about
   `get_resolved_identity(permanent=true)`. That's the old signature. If it
   ever gets implemented, it would naturally take `IdentityContext`.

### The Cascade Pattern

When you make the input a value type instead of loose args, every function that
needs that data can accept the type instead of re-extracting the same fields.
The `IdentityContext` becomes a **currency** that flows through the system —
every module that deals with identity just takes the same coin.

But don't chase these simplifications proactively. They'll happen naturally
when each module needs to change for its own reasons. The refactoring already
paid for itself by making the signature match the architecture.

### Commits

- `0df2dca` — refactor: get_resolved_identity(ctx: IdentityContext) — 6 args → 1
- `124041a` — docs: update AGENTS.md, README.md, AGENT-IDENTITY.md for IdentityContext

---

## IdentityContext Owns Its Behavior (Planned)

### Principle

A type that only holds data is a DTO. A type that holds data AND knows how to
compute from it is a **smart type**. `IdentityContext` should be smart — it
should own `semantic_id()`, `resolved_identity()`, and `agent_id()`.

In Gleam, "methods on a type" means: functions that take the type as first arg
live in the same module as the type. When you import `IdentityContext`, you get
its behavior too.

### Current Structure (3 modules, behavior scattered)

```
agent_identity_types.gleam  — IdentityContext (data only), IdentityError, AgentId, AgentIdentity
agent_identity_logic.gleam  — generate_semantic_id(ctx)        ← behavior, separate module
agent_identity.gleam        — get_resolved_identity(ctx)        ← behavior, separate module
                               get_agent_id(ctx)                ← behavior, separate module
                               somatic_id_tool()                ← Pi integration
                               autonomic_id_tool()              ← Pi integration
```

Problem: To use `IdentityContext`, you import the type from one module, then
import the behavior from two other modules. The type and its behavior are
artificially separated.

### Proposed Structure (2 modules, behavior co-located)

```
agent_identity_types.gleam  — IdentityContext (data + behavior)
                               IdentityContext.semantic_id()      ← was generate_semantic_id
                               IdentityContext.resolved_identity() ← was get_resolved_identity
                               IdentityContext.agent_id()         ← was get_agent_id
                               IdentityError, AgentId, AgentIdentity (unchanged)

agent_identity.gleam        — somatic_id_tool()                  ← Pi integration only
                               autonomic_id_tool()                ← Pi integration only
```

`agent_identity_logic.gleam` is absorbed — its single function moves into
`agent_identity_types.gleam` as `IdentityContext.semantic_id()`.

### What Changes

| File                         | Change                                                                            |
| ---------------------------- | --------------------------------------------------------------------------------- |
| `agent_identity_types.gleam` | Add `semantic_id()`, `resolved_identity()`, `agent_id()`                          |
| `agent_identity_logic.gleam` | DELETE — absorbed into `agent_identity_types`                                     |
| `agent_identity.gleam`       | Remove `get_resolved_identity`, `get_agent_id`; import from types                 |
| `directive.gleam`            | `agent_identity.get_resolved_identity` → `agent_identity_types.resolved_identity` |
| `test/psypi_test.gleam`      | `agent_identity_logic.generate_semantic_id` → `agent_identity_types.semantic_id`  |

### What Does NOT Change

- `AgentIdentity`, `AgentId`, `IdentityError` types — stay in `agent_identity_types`
- `activity_log.gleam` — only uses `AgentId`, no change
- `agent_identity_db.gleam` — only uses `AgentIdentity`, no change
- `extension_generator.gleam` — only uses Pi tools from `agent_identity`, no change
- Pi tool `module` field — still `"agent_identity"` because the Pi tool calls
  the compiled JS function, and we'll re-export from `agent_identity.gleam`

### Naming Convention

Gleam convention: when a function lives in the same module as its first-arg type,
the function name drops the type prefix. So:

- `generate_semantic_id(ctx)` → `semantic_id(ctx)` (context is implied)
- `get_resolved_identity(ctx)` → `resolved_identity(ctx)` (context is implied)
- `get_agent_id(ctx)` → `agent_id(ctx)` (BUT: conflicts with existing `agent_id(s: String) -> AgentId`)

The `agent_id` conflict: there's already `pub fn agent_id(s: String) -> AgentId`
in `agent_identity_types.gleam` (the `AgentId` constructor helper). Options:

1. Rename the new function to `to_agent_id(ctx)` — "convert context to agent ID"
2. Rename the old helper to something else
3. Keep different names: `agent_id_from_string()` vs `agent_id(ctx)`

Best: rename old helper to `agent_id_from_string(s)` and use `agent_id(ctx)` for
the context method. The string helper is rarely used externally.

### Re-export for Pi Tools

Pi tool definitions reference `module: "agent_identity"`, so the compiled JS
calls `agent_identity_get_resolved_identity(...)`. After moving the function to
`agent_identity_types`, we need either:

1. Change `module` to `"agent_identity_types"` in Pi tool defs — changes the
   import path in extension.js
2. Re-export from `agent_identity.gleam` — `pub fn resolved_identity = agent_identity_types.resolved_identity`

Option 1 is cleaner — change the module reference. The import line in
extension.js will change from `agent_identity.mjs` to `agent_identity_types.mjs`,
which is fine since the function actually lives there now.

### Execution Order

1. Add `semantic_id()`, `resolved_identity()`, `agent_id()` to `agent_identity_types.gleam`
2. Rename old `agent_id(s: String)` to `agent_id_from_string(s: String)`
3. Update `agent_identity.gleam` — remove the moved functions, update Pi tool `module` field
4. Delete `agent_identity_logic.gleam`
5. Update `directive.gleam` import
6. Update `test/psypi_test.gleam` import
7. Update `agent_identity_db.gleam` if it uses `agent_id` helper
8. `gleam build` + `gleam test`
9. Git commit

---

## The CoffeeScript Insight — Why PiExtensionContext as Opaque Type Is Wrong

### The Question

"If you were to write an 'equal-to' class in CoffeeScript, would it make you
think differently about PiExtensionContext?"

### The Answer

Yes. An opaque `PiExtensionContext` type with `@external` methods wrapping
the JS `ctx` object is **CoffeeScript** — JavaScript with nicer syntax. The
Gleam compiler sees an opaque blob. It can't verify anything. We gain nothing
over writing the JS directly.

### What @external Actually Is

Looking at the Gleam stdlib (`gleam/dynamic`), `@external` is a **typed
extraction boundary** — like a special import. `Dynamic` is opaque; you use
`@external` and `decode` to extract typed data from it. The stdlib pattern is:

1. JS gives you `Dynamic` (untyped)
2. You extract/decode into Gleam types
3. All computation happens on the Gleam types

This is NOT "wrapping a JS object in a Gleam class." It's **extracting data
at the boundary, then computing purely.**

### The Correct Architecture

```
JS Layer (impure, ctx lives here)     Gleam Layer (pure, no ctx)
─────────────────────────────         ──────────────────────────
ctx.model?.id  ──extract──┐
ctx.isIdle()   ──extract──┼──→  IdentityContext (pure data record)
ctx.cwd        ──extract──┘     ├── semantic_id() → Result(String, Error)
                                  ├── resolved_identity() → Result(AgentIdentity, Error)
                                  └── agent_id() → Result(AgentId, Error)
```

The JS `ctx` object is **impure** — `ctx.isIdle()` changes moment to moment.
That's fine — it lives in JS, where impurity belongs. Gleam receives the
extracted snapshot as `IdentityContext`, and from that point everything is
pure, typed, and verifiable.

The "6 helper functions" that generate JS strings? They're actually **correct**
— they're the extraction layer. The bridge between impure JS `ctx` and pure
Gleam `IdentityContext`. They don't need to be wrapped in an opaque type.

### What About ctx.ui.notify, ctx.sessionManager, etc.?

These are **side effects**. They belong in FFI (like `pi_extension.gleam`
already does). They should NOT be methods on a Gleam type. Side effects
happen at the boundary, not in the pure layer.

### Revised Plan: IdentityContext Owns Its Behavior (No PiExtensionContext)

Drop `PiExtensionContext` entirely. Keep the JS extraction helpers in
`agent_identity.gleam` (they're the bridge). Move the pure computation
into `agent_identity_types.gleam`:

```
agent_identity_types.gleam  — IdentityContext (data + behavior)
                               IdentityContext.semantic_id()
                               IdentityContext.resolved_identity()
                               IdentityContext.agent_id()
                               IdentityError, AgentId, AgentIdentity

agent_identity.gleam        — JS extraction helpers (the bridge)
                               somatic_id_tool()
                               autonomic_id_tool()

agent_identity_logic.gleam  — DELETE (absorbed into agent_identity_types)
```

### Execution Order

1. Add `semantic_id()`, `resolved_identity()`, `agent_id()` to `agent_identity_types.gleam`
2. Rename old `agent_id(s: String)` to `agent_id_from_string(s: String)`
3. Update `agent_identity.gleam` — remove moved functions, update Pi tool `module` field
4. Delete `agent_identity_logic.gleam`
5. Update `directive.gleam` import
6. Update `test/psypi_test.gleam` import
7. Update `agent_identity_db.gleam` if it uses `agent_id` helper
8. `gleam build` + `gleam test`
9. Git commit
