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

## System Review Task (Ongoing)

### Review ID: ca9e914c-cce6-4db4-b3b1-29779d8e1837
- **Title:** Architecture Over-Engineering Audit
- **Methodology:** 5-question framework: (1) Who uses them? (2) Why not simpler? (3) Real problem? (4) Real Gleam solve? (5) Inevitable?
- **Status:** in_progress — 24 findings saved to `review_findings` table (#430-#453)
- **Severity breakdown:** 5 critical, 10 high, 8 medium, 1 low

### Key Findings Summary

| Category | Count | Worst Offenders |
|----------|-------|-----------------|
| over_engineering | 4 | a_orchestrator (161 lines, 1 caller), a_db_reader (255 lines, false per-agent split), s_db_reader (94 lines, 1 used fn) |
| redundant_check | 2 | is_s_still_idle() queries ghost table, hook_on_agent_end double-checks idle |
| ghost_table | 2 | agent_sessions (never written to), system_reviews (didn't exist until this session!) |
| duplicate_code | 3 | db_error_to_string x20 copies, two MonitorError types, duplicate now_ms FFI |
| dead_code | 6 | read_s_jobs_from_db, current_time_ms, housekeeping, prepare_context, check_safety, analyze_and_act, record_review_score |
| false_abstraction | 1 | monitor_ai + monitor = 877 lines with same error type, no separation principle |
| boilerplate | 1 | db.with_connection forces 20 copies of error mapper |
| logic_error | 4 | FAILED status doesn't exist in tasks table (3 bugs), string.contains error detection |

### Meta-Finding: system_review_db.gleam Was Dead Code (#453)
- The `system_reviews` and `review_findings` tables **did not exist** in the database before this session
- No migration ever created `system_reviews`; migration 027 creates `review_findings` but depends on `system_reviews`
- All 559 lines of `system_review_db.gleam` would fail at runtime with "relation does not exist"
- Tables were created during this session to make the system review infrastructure functional
- **All previous review findings were inserted via raw SQL migrations, not through the Gleam API**

### What Still Needs Auditing
- `task.gleam`, `issue_db.gleam`, `project.gleam`, `meeting.gleam`, `skill.gleam`, `broadcast.gleam`, `areflect.gleam`, `memory.gleam`, `learning.gleam`, `agents.gleam`, `code_version.gleam`, `event_hooks.gleam`, `inter_review.gleam` — all follow the same db_error_to_* boilerplate pattern
- `hook_on_tool_call.gleam` — needs review for similar issues
- `seed.gleam`, `simple_migrate.gleam` — utility files
- The entire `psypi_config.gleam` — DB-backed config that may have similar issues

### Next Steps for System Review
1. Continue auditing remaining files with 5-question framework
2. Focus on the db_error_to_* boilerplate pattern — it's in every DB module
3. Verify findings #430-#453 are actionable and not duplicates of earlier reviews
4. When audit is complete, mark review as completed via `system_review_db.complete_review()`

## Build & Deploy

```bash
gleam clean && gleam build
gleam run -m extension_generator
gleam test  # 87 tests
```
