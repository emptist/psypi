# Code Review: table-redesign Branch

**Date:** 2026-06-06
**Reviewer:** opencode (mimo-v2-pro-max)
**Branch:** table-redesign
**Scope:** 17 modified files across tool registration, error reporting, and type system

---

## Overview

Two major improvements:
1. **Type-safe parameter generation** — replacing raw JS strings (`from_param`, `lit`) with structured `FnArgument`/`ParamSrc` types
2. **Error reporting fix** — routing hook errors through `pi.sendMessage()` instead of `ctx.ui.notify()`

---

## Good

- **Structured parameter types are correct.** `ParamField`, `OptionalParamField`, `IntParamField`, `EventField`, etc. each generate the right JS. The defaults match the original `from_param()` strings exactly.
- **Error reporting fix is the right call.** All `⚠️ ERROR REPORTING BUG ⚠️` comments have been resolved. Hook errors now go through `pi.sendMessage({customType: 'autonomic-error', ...})` — the only way S-bot can see them.
- **`hook_error_to_js()` centralizes the pattern** — one function generates the error reporting JS, applied consistently across all hook types (system_prompt, event, debounced).
- **Tool registrations are cleaner.** `param("title", Some(""))` is far more readable than `from_param('params.title || ""')`.
- **Tests cover all `ParamSrc` variants** — good coverage of the new type system.
- **Tests removed stale comments** — minor but clean.

---

## Concerns

1. **The debounced hook uses `pi` in generated JS without declaring it as a `FnArgument`.** In `extension_generator.gleam`, the debounced hook's args list doesn't include `pi()` — yet the generated `setTimeout` callback references `pi.sendMessage(...)` via `hook_error_to_js`. This works because the generated `pi.on(...)` callback has `pi` in its closure scope, but it's implicit. Worth a comment or at least a mental note.

2. **Old `FnArgument` type comment says "removed after migration"** but there's no migration path defined. If there are any remaining `JsLiteral`/`FromParam` usages outside this diff, they'd break. The diff looks complete though — all 17 modified files migrated.

3. **Untracked files** (`ppitest.mjs` through `ppitest6.mjs`, `.planning/phases/`) — these look like test/debug artifacts. Intentional or should they be gitignored?

4. **The `param_src_to_js` and `fn_argument_to_js` functions are private.** Good — they're implementation details. But the `ParamSrc` type itself is `pub` — consider whether external consumers need it or if it should be internal.

---

## Verdict

Good changes. The type safety improvement is significant — no more raw JS strings leaking into Gleam code, and the error reporting fix closes a real bug where S-bot couldn't see hook failures. Ship it (after cleaning up the test artifacts).
