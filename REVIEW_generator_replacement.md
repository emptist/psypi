# Code Review: Generator Replacement (defake branch)

**Reviewer:** AI Code Review (Model B)
**Date:** 2026-05-18
**Branch:** defake
**Files Reviewed:** 7 hook modules under `src/` + `extension_generator.gleam`

---

## Context

The previous model replaced "fake" generator modules (raw JS embedded in Gleam strings) with "real" Gleam code that generates proper JS using `unwrapGleamResult` for Result handling. All 7 files were reviewed using the five-axis framework: Correctness, Readability, Architecture, Security, Performance.

**Build status:** `gleam build` passes with zero errors.
**Generation status:** `gleam run -m extension_generator` produces valid `extension.js`.

---

## Review: hook_before_agent_start.gleam

### Correctness
- **OK** — No-op handler, trivially correct.

### Readability
- **OK** — Minimal code, clear comment.

### Architecture
- **OK** — Appropriate for a no-op hook.

### Security
- **OK** — No security-sensitive operations.

### Performance
- **OK** — No performance impact.

### Verdict: **APPROVE**

---

## Review: hook_session_start.gleam

### Correctness
- **OK** — Uses `unwrapGleamResult` correctly to check `record_current_model` result.
- The fake version used `.then(() => {}).catch(() => {})` which silently swallowed both Ok and Error values. The new version properly checks `!r.ok` and notifies on failure.

### Readability
- **OK** — Clear, straightforward.
- Comment says "(silent, non-blocking)" but the code actually notifies on error. This is intentional and correct — silent for success, notify on failure.

### Architecture
- **OK** — Follows the established pattern for event hook generators.

### Security
- **OK** — No security concerns.

### Performance
- **OK** — Non-blocking by design.

### Verdict: **APPROVE**

---

## Review: hook_model_select.gleam

### Correctness
- **OK** — Same fix as `session_start` — properly uses `unwrapGleamResult`.
- **Issue:** Code is nearly identical to `hook_session_start.gleam` (lines 3-22). Both have identical handler bodies for the Gleam-generated JS.

### Readability
- **OK** — Clear structure.

### Architecture
- **OK** — Correct pattern.
- **Consider:** The two files could share a helper function that generates the common JS body. However, this is a low-priority cleanup since they're simple and the duplication is small.

### Security
- **OK** — No security concerns.

### Performance
- **OK** — Non-blocking.

### Verdict: **APPROVE** (with optional consideration for deduplication)

---

## Review: hook_tool_call.gleam

### Correctness
- **OK** — Uses `unwrapGleamResult` to check `save_version` result.
- **Critical fix verified:** The fake version always showed "Auto-backed up" even on failure. The new version checks `r.ok` and shows `[FAIL] save_version: <error>` on failure.
- **OK** — Properly handles file path extraction from `event.input?.path || event.input?.filePath`.
- **OK** — Only triggers for `toolName === 'edit'` as intended.

### Readability
- **OK** — Clear structure with nested try-catch for file operations.

### Architecture
- **OK** — Correct abstraction at the event hook level.

### Security
- **OK** — `fs.readFileSync` reads only the file being edited, no path traversal risk.

### Performance
- **OK** — File read is necessary for backup. Non-blocking design.

### Verdict: **APPROVE**

---

## Review: hook_tool_result.gleam

### Correctness
- **OK** — Error detection via string matching on JSON is intentionally simple/fragile.
- **OK** — Properly sends `pi.sendMessage` with `customType: 'autonomic-error'` on error detection.
- **Minor issue:** The catch variable is `err` but it's not used — correctly named `_err` would be more consistent with the rest of the codebase.

### Readability
- **OK** — Clear error detection logic.
- **OK** — Error message truncation at 200 chars is reasonable.

### Architecture
- **OK** — Correctly delegates to Pi API for notifications and messaging.

### Security
- **OK** — No security concerns. String matching on JSON is safe for this use case.

### Performance
- **OK** — Non-blocking.

### Verdict: **APPROVE** (nit: rename `err` to `_err` in catch)

---

## Review: hook_agent_lifecycle.gleam

### Correctness
- **OK** — `start_body()` returns a no-op comment.
- **OK** — `end_body()` delegates to `hook_agent_end_coordination.handler_body()`.
- **OK** — Import of `hook_agent_end_coordination` is correct (local `src/` module, not the fake generator version).

### Readability
- **OK** — Simple delegation pattern is clear.

### Architecture
- **OK** — Proper module separation. `agent_lifecycle` handles `agent_start` and `agent_end`, delegating to `hook_agent_end_coordination` for `agent_end`.

### Security
- **OK** — No security concerns.

### Performance
- **OK** — No performance impact.

### Verdict: **APPROVE**

---

## Review: hook_agent_end_coordination.gleam

### Correctness
- **CRITICAL FIX VERIFIED:** The fake version used `db.query()` which does not exist in `db_query.mjs` — the module exports `execute()`. This would have crashed at runtime. The new version correctly uses `execute()`.
- **OK** — Uses `unwrapGleamResult` to extract the Gleam `Result` from `db_query.execute()`.
- **OK** — Correctly reads `rows[0]` and handles both `row.value` and `row[0]` for accessing the debounce value.
- **OK** — Throws if `monitor_debounce_ms` not found, as designed.

### Readability
- **OK** — Complex handler but well-structured.
- **OK** — Multiple try-catch blocks with clear purposes.
- **OK** — Inline comments explain each section.

### Architecture
- **OK** — Correct separation: Gleam handles DB query, JS handles timing, idle check, LLM call, and messaging.
- **OK** — Uses `ctx.isIdle()` and `pi.sendMessage()` correctly — these are Pi API calls that can't be done from Gleam.

### Security
- **OK** — SQL uses parameterized query (`$1` placeholder).
- **OK** — No user input flows into dangerous operations.
- **OK** — `briefPath` is constructed safely with `path.join()`.

### Performance
- **OK** — Debounce prevents rapid re-triggering.
- **OK** — `fs.readFileSync` is used in a one-time callback, not on hot path.

### Verdict: **APPROVE**

---

## Review: extension_generator.gleam

### Correctness
- **OK** — Imports all 7 hook modules correctly.
- **OK** — `all_event_hooks()` correctly registers all 7 hooks with their event names.
- **OK** — `event_hook_to_js()` correctly wraps handler bodies in `pi.on('event', async (event, ctx) => { ... })`.

### Readability
- **OK** — Well-organized with clear sections for tools, hooks, and commands.
- **OK** — Helper functions (`imports_text`, `helpers_text`, `event_hooks_text`, etc.) are appropriately sized.

### Architecture
- **OK** — Clean separation between tool registration, hook registration, and command registration.
- **OK** — Composes small generator modules into a complete `extension.js`.

### Security
- **OK** — No security concerns in the generator itself.
- **FYI:** The inline `psypi-commit` tool uses `execSync` with user-provided commit messages. While the regex validation helps, direct shell injection is a concern. However, this is pre-existing code, not introduced by this change.

### Performance
- **OK** — Generator runs once at build time, no runtime performance concern.

### Verdict: **APPROVE**

---

## Summary

| File | Verdict | Key Finding |
|------|---------|-------------|
| `hook_before_agent_start.gleam` | **APPROVE** | Clean no-op |
| `hook_session_start.gleam` | **APPROVE** | Correctly handles Result |
| `hook_model_select.gleam` | **APPROVE** | Correctly handles Result |
| `hook_tool_call.gleam` | **APPROVE** | Fixed silent failure bug |
| `hook_tool_result.gleam` | **APPROVE** | Minor nit: catch variable naming |
| `hook_agent_lifecycle.gleam` | **APPROVE** | Clean delegation |
| `hook_agent_end_coordination.gleam` | **APPROVE** | Critical db_query.execute() fix |
| `extension_generator.gleam` | **APPROVE** | Correct wiring |

### Critical Bug Fixes Verified

1. **session_start / model_select**: Fake used `.then(() => {}).catch(() => {})` which silently swallowed all results. **Fixed** with `unwrapGleamResult`.

2. **tool_call**: Fake always showed "Auto-backed up" even on failure. **Fixed** with `unwrapGleamResult` check.

3. **agent_end_coordination (CRITICAL)**: Fake called `db.query()` which does not exist — `db_query` exports `execute()`. **Fixed** with correct `execute()` call and proper Result handling.

### Optional Improvements (Non-Blocking)

1. **hook_model_select.gleam** shares ~95% identical code with `hook_session_start.gleam`. Consider extracting a shared helper function if more hooks with similar patterns are added.

2. **hook_tool_result.gleam** uses `err` in catch block but never reads it. Use `_err` for consistency with other files.

### Dead Code / Cleanup

The `.fake` files in `src/generator/` are now orphaned and can be deleted:
- `before_agent_start.gleam.fake`
- `session_start.gleam.fake`
- `model_select.gleam.fake`
- `tool_call.gleam.fake`
- `tool_result.gleam.fake`
- `agent_lifecycle.gleam.fake`
- `agent_end_coordination.gleam.fake`

The `src/generator/GENERATOR_DOCS.md` is also now orphaned.

---

## Final Verdict

**APPROVE** — All 7 hook modules correctly replace the fake versions with proper Gleam code that:
- Uses `unwrapGleamResult` for all Gleam function calls
- Uses correct import paths (`db_query.execute()`, not `db.query()`)
- Properly handles the Gleam `Result` type returned by compiled functions
- Builds without errors and generates valid `extension.js`

The critical bug fix in `hook_agent_end_coordination.gleam` (using `execute()` instead of non-existent `query()`) was the most important improvement and is correctly implemented.