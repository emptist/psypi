# Handover — 2026-05-30 (fresh session)

## Current State

Pi has been restarted with the new extension.js. **Some fixes are now active**, but there's a bug to fix first.

## ✅ Confirmed Working

- **psypi-task-add** — Creates tasks successfully (project_id UUID fix works)
  - Test: `psypi-task-add title="Test"` → `Task: 897ec562-f080-4873-9a40-fa4d4a43ed54` ✅

## 🐛 Bug Found: psypi-tasks list fails

**Error:** `{"0":"Failed to decode task row"}`

**Root cause:** The `task_decoder()` in `src/task.gleam` doesn't include `project_id` field, but the `list()` SQL query selects all columns including `project_id`. The decoder fails because the row has an unexpected column.

**Fix needed:** Either:
1. Add `project_id` to the `task_decoder()` and `Task` type, OR
2. Explicitly list columns in the `list()` SQL query instead of relying on `SELECT *`

**File:** `src/task.gleam` — `task_decoder()` function and `sql_with_filters()` SQL query

## ⏳ Fixes Still Pending (built but untested)

These are built into extension.js and should work after the list() bug is fixed:

1. **Debounce timer dedup + idle_since tracking** — Pi should no longer fire A-bot during active work
2. **A-bot fully_functional=True** — A-bot should run full workflow (DB reads + LLM call)
3. **DecodeError priority fix** — priority field decoders use `decode.int` instead of `decode.string`
4. **inter_review NULL params** — `request_review` passes `dynamic.nil()` instead of `dynamic.string("")` for nullable UUID params

## ⚠️ Critical Lesson Learned

**NEVER call psypi tools from inside Pi to test them.** A tool crash kills the entire Pi session with `ERR_HTTP2_INVALID_SESSION`. Always verify code correctness through `gleam build` and `gleam test` first.

## What To Do Next (Priority Order)

### 1. Fix psypi-tasks list decoder bug
- Add `project_id` to `Task` type and `task_decoder()`, OR
- Change SQL to explicitly list columns
- Rebuild: `gleam clean && gleam build && gleam run -m extension_generator`
- Restart Pi and test

### 2. Test A-bot workflow
- After list() fix, verify A-bot fires correctly when S goes idle
- Check that debounce + idle_since gating works (A shouldn't fire during active work)
- Check that inter-review prompt detection works

### 3. Test psypi-commit inter-review flow
- The `request_review` fix (NULL instead of empty string for UUID params) needs testing
- Phase 1: `psypi-commit message="test"` should create inter-review record
- Phase 2: `psypi-commit message="test" review_id="<uuid>"` should commit after review

## Key Files

| File | Status |
|------|--------|
| `src/task.gleam` | **BUG:** task_decoder missing project_id field |
| `src/a_orchestrator.gleam` | ✅ fully_functional=True, dead code removed |
| `src/pi_tool_call.gleam` | ✅ Timer dedup + debounceMs caching |
| `src/hook_on_agent_end.gleam` | ✅ idle_since time-based gating |
| `src/pi_extension_ffi.mjs` | ✅ now_ms, get_config, set_config |
| `src/inter_review.gleam` | ✅ NULL params for nullable UUIDs |
| `src/a_db_reader.gleam` | ✅ priority decoder uses decode.int |
| `src/s_db_reader.gleam` | ✅ priority decoder uses decode.int |

## Build & Deploy

```bash
gleam clean && gleam build
gleam run -m extension_generator
gleam test  # 87 tests, all should pass
# Then restart Pi
```

## Open Issues

| Issue | Status |
|-------|--------|
| 6cf92c87 — A-bot inter-review | Fixes built, needs Pi testing |
| cc64c9f5 — DecodeError priority | Fix built, needs Pi testing |
