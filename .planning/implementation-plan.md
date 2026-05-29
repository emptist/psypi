# Implementation Plan: Psypi — Bugs Verified Against Source Code

## Phase 1: Decode Bugs (Tools That Error)

### Task 1: `inter_review.gleam` — `requested_at` missing `::text`
**Files:** `src/inter_review.gleam` lines 148, 283, 358
**Change:** Add `::text` to `requested_at` in 3 queries
**Verify:** `gleam build`

### Task 2: `memory.gleam` — `save()` RETURNING id decoded with 7-field decoder
**Files:** `src/memory.gleam`
**Change:** Use 1-field `id` decoder for RETURNING id
**Verify:** `gleam build`

### Task 3: `memory.gleam` — `search()` SELECT * missing `::text` on `created_at`
**Files:** `src/memory.gleam`
**Change:** Replace SELECT * with explicit columns + `created_at::text`
**Verify:** `gleam build`

### Task 4: `skill.gleam` — `get()`/`search()` missing `::text` on jsonb
**Files:** `src/skill.gleam` (2 queries)
**Change:** Add `content::text, reference_list::text`
**Verify:** `gleam build`

### Task 5: `a_db_reader.gleam` — `read_open_issues()` wrong status `closed`
**Files:** `src/a_db_reader.gleam` (1 line)
**Change:** `'closed'` → `'wont_fix','duplicate'`
**Verify:** `gleam build`

---

## Phase 2: Wire Inter-Review Persistence

### Task 6: `a_orchestrator.gleam` — call `inter_review.save_review_result()`
**Files:** `src/a_orchestrator.gleam` (~3 lines)
**Change:** In `handle_monitor_response()`, after LLM returns Ok(response), call `inter_review.save_review_result(review_id, response, score)` before `pi_send_message`. `let _ =` fire-and-forget.
**Verify:** `gleam build`. Code inspection.

### Task 7: `inter_review.gleam` — verify `request_review()` params match SQL function
**Files:** `src/inter_review.gleam`
**Change:** Query `pg_get_function_arguments` for `request_inter_review`, align params. Same for `create_review_for_commits()`.
**Verify:** `gleam build`.

---

## Phase 3: SQL Bugs

### Task 8: `broadcast.gleam` — `stats()` rewrite (3 bugs)
**Files:** `src/broadcast.gleam` (~15 lines)
**Change:** Remove `status` filter. `priority >= 2` → `priority IN ('high','critical')`. `COUNT(*)::int`.
**Verify:** Test in psql first. `gleam build`.

### Task 9: `monitor_ai.gleam` — `auto_file_issue()` column name + missing project_id
**Files:** `src/monitor_ai.gleam` (~5 lines)
**Change:** `type` → `issue_type`. Add `project_id` (hardcode UUID now, `Project.resolve()` later).
**Verify:** `gleam build`.

### Task 10: `areflect.gleam` — add `project_id` to `save_issue()` and `save_task()`
**Files:** `src/areflect.gleam` (~10 lines)
**Change:** Add `project_id` to both INSERTs + params. Hardcode UUID.
**Verify:** `gleam build`.

---

## Phase 4: FFI Cleanup

### Task 11: Delete orphan `time_utils_ffi.mjs`
**Files:** `src/time_utils_ffi.mjs`
**Change:** Delete file. No Gleam code references it.
**Verify:** `gleam build`.

### Task 12: Delete orphan functions in `node_ffi.mjs`
**Files:** `src/node_ffi.mjs`
**Change:** Remove `execute`, `exists`, `ensure_dir`, `write_text_file`, `get_env`, `now_ms`. Keep `get_project_root`, `spawn_pi`, `get_project_id_env`, `get_database_url`.
**Verify:** `gleam build`.

### Task 13: Remove duplicate `@external now_ms` from `a_context_utils.gleam`
**Files:** `src/a_context_utils.gleam`
**Change:** `a_context_utils.current_time_ms()` should use `pi_extension.now_ms()` (returns Int). Delete the local `@external` declaration and `import gleam/option` if only used for now_ms.
**Verify:** `gleam build`.

### Task 14: Replace `agent_identity.check_git_exists` FFI with `simplifile.is_directory()`
**Files:** `src/agent_identity.gleam` + delete `src/agent_identity_ffi.mjs`
**Change:** Replace `@external` fn with Gleam function using `simplifile.is_directory(cwd <> "/.git")`.
**Verify:** `gleam build`. Delete `agent_identity_ffi.mjs`.

---

## Phase 5: Token Budget

### Task 15: `a_orchestrator.gleam` — use `compose_within_budget()`
**Files:** `src/a_orchestrator.gleam` (1 import + 1 line)
**Change:** Add `import system_prompt_types.{compose_within_budget}`. Line 70: `compose(compose_within_budget(a_prompt_builder.build_system_prompt(soul_content, a_jobs, context_window)))`.
**Verify:** `gleam build`.

---

## Phase 6: Seed + Multi-Statement

### Task 16: `seed.gleam` — split multi-statement SQL
**Files:** `src/seed.gleam` (~10 lines)
**Change:** `seed_agent_souls()` and `seed_agent_prefixes()` each pass `INSERT A; INSERT B` as one string. Split into separate `INSERT` calls using existing `seed_idempotent(label, sql)` pattern.
**Verify:** `gleam build`. Check DB: all souls and prefixes present.

### Task 17: `monitor_ai.gleam` — disable `housekeeping()` stub
**Files:** `src/monitor_ai.gleam` (1 fn)
**Change:** Replace body with `io.println("[housekeeping] no-op") Ok(Nil)`.
**Verify:** `gleam build`.

### Task 18: `monitor_ai.gleam` — disable `tool_consult()` stub
**Files:** `src/monitor_ai.gleam` (1 fn)
**Change:** Replace body with `io.println("[consult] use psypi-meeting-say instead") Ok(Nil)`.
**Verify:** `gleam build`.

---

## Already Done (Verified Against Source)

- `SkillSource.AiBuilt` — present in `src/skill.gleam` line 14
- `IssueStatus` has `Acknowledged/WontFix/Duplicate` — present lines 15, 18, 19
- `TaskStatus.FakeComplete` — present line 14
- `MeetingStatus.Pending` — already removed
- `unwrapGleamResult` error serialization — already uses `JSON.stringify(gleamValueToJson(...))`
- `meeting.gleam` decode — SQL uses `::text` casts in SELECT
- Timer stacking / debounce fix — Phase 2 from handoff
- `idle_since` / `last_a_session_at` — Phase 2 from handoff

---

## Not Included

- Expanding Gleam structs to match all 60 DB columns (other projects own them)
- Adding Gleam enum types for 29 implicit enum columns (design choice)
- Connection pooling (architectural change)
- Runtime `Project.resolve()` (hardcode UUID covers current need)
- `read_file_sync` FFI kept as-is (works, `simplifile` alternative is cosmetic)

---

## Order

1. Tasks 1-5 (decode bugs, independent)
2. Tasks 11-14 (FFI cleanup, independent)
3. Task 7 (param mapping)
4. Task 6 (wire save_review_result — needs 1, 7 done)
5. Tasks 8-10 (SQL bugs)
6. Task 15 (token budget)
7. Tasks 16-18 (seed + stubs, low priority)

---

*Verified against git HEAD `461c9e1` source code. Every task has exact file + line references.*
