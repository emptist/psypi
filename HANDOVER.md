# Handover — 2026-05-30 (fresh session, post-Pi-restart)

## ✅ All Fixes Built and Committed

All fixes below are in `extension.js` and ready to test after Pi restart.

### 1. psypi-task-add project_id fix (f6c7d2b, 798a722)
- Added `project_id` parameter to `add()` function
- Default project UUID: `0d324e68-b399-4b85-bd8a-6b1ef7b46168`
- DB column has DEFAULT set to same UUID
- **Tested:** ✅ Creates tasks successfully

### 2. psypi-tasks list decoder fix (d13aca9)
- Added `project_id: Option(String)` to `Task` type
- Added `project_id` to `task_decoder()`
- Added `project_id::text` to SELECT query
- **Status:** Built, 87 tests pass, needs Pi restart to verify

### 3. Debounce timer dedup + idle_since tracking (f6c7d2b)
- Timer dedup via `clearTimeout` + module-level `_debounceTimerId`
- debounceMs cached at module level (`_debounceMs`)
- `idle_since` time-based gating in `hook_on_agent_end.gleam`
- `now_ms`, `get_config`, `set_config` FFI functions added

### 4. A-bot re-enabled (ae0adda, 79231eb)
- `fully_functional = True` in `a_orchestrator.gleam`
- Dead code gate removed
- Inter-review detection in `a_prompt_builder.gleam`

### 5. DecodeError priority fix (built in earlier session)
- `a_db_reader.gleam`: priority decoder uses `decode.int`
- `s_db_reader.gleam`: priority decoder uses `decode.int`

### 6. inter_review NULL params fix (5aea9d1)
- `request_review` passes `dynamic.nil()` instead of `dynamic.string("")` for nullable UUID params
- Fixes `"invalid input syntax for type uuid"` error

### 7. DB indexes + migration (0920ec1, 025)
- `idx_tasks_project_id` and `idx_tasks_status` indexes
- Migration `025_add_tasks_project_id.sql`

### 8. Docs + tests
- README.md, ARCHITECTURE.md updated
- 87 tests passing (up from 82)
- Skills reviewed and fixed

## ⚠️ Critical Lesson

**NEVER call psypi tools from inside Pi to test them.** A tool crash kills the entire Pi session with `ERR_HTTP2_INVALID_SESSION`. Always verify through `gleam build` and `gleam test` first.

## Inter-Review Flow

A-bot does NOT review immediately. The flow is:
1. S calls `psypi-commit` (no review_id) → creates `inter_reviews` record with status `pending`
2. S goes idle → `agent_end` fires → debounce → A-bot picks up pending review
3. A-bot reviews, updates `inter_reviews` with score/response, sets status `completed`
4. S calls `psypi-commit` with `review_id` → validates score ≥ 50 → git commit

**Key insight:** A-bot only reviews when S is idle (after debounce). If S keeps working, review stays `pending`.

## Pending Inter-Review

Review ID: `df31f009-7f00-4b91-8eec-e6c1c832af24` (status: pending)
- Triggered by `psypi-commit` for HANDOVER.md update
- Waiting for S to go idle so A-bot can review

## What To Test After Pi Restart

### Priority 1: Basic tool verification
- `psypi-task-add title="test"` → should return task UUID ✅ (already tested)
- `psypi-tasks` → should list tasks without decode error
- `psypi-task-complete task_id="<uuid>"` → should complete task

### Priority 2: A-bot workflow
- Let S go idle → A-bot should fire after debounce period
- A-bot should review pending inter-review records
- Check `psypi-autonomic-health` for system status

### Priority 3: Complete inter-review flow
- After A-bot reviews, call `psypi-commit` with review_id to finalize commit

### Priority 4: psypi-areflect, psypi-learn-save
- Test that `[object Object]` error is fixed

## Open Issues

| Issue | Status |
|-------|--------|
| 6cf92c87 — A-bot inter-review | Fixes built, needs testing after restart |
| cc64c9f5 — DecodeError priority | Fix built, needs testing after restart |
| TBD — Inter-review system fundamentally broken | **NEW** — see investigation task |

## Pending Tasks

| Task | Description |
|------|-------------|
| d02f8a8b | Review inter-review process and logic — deep investigation |

## Build & Deploy

```bash
gleam clean && gleam build
gleam run -m extension_generator
gleam test  # 87 tests
```
