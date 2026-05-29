# Issues Introduced During Inter-Review/Commit Redesign

## Date: 2026-05-29
## Source Commits: 01f702a, 3c7eaed, 5518253, 28faf98

---

## Bug #1: `a_db_reader.get_last_a_session_at()` queries non-existent `config` table

**Severity:** Critical
**Source:** Commit 5518253 (redesign: add inter-review step to A-bot workflow)
**File:** `src/a_db_reader.gleam` line 231

**Problem:**
```sql
SELECT value FROM config WHERE key = 'last_a_session_at'
```
The table `config` does not exist. The only config table is `psypi_config` (migration 007). This query always fails.

**Impact:**
- `get_recent_commits()` always receives empty `last_session`
- Falls back to `git log --oneline -20` instead of commits since last A session
- A-bot reviews the last 20 commits every time instead of only new ones
- Wastes context window on already-reviewed commits

**Fix:**
Change SQL to read from `psypi_config`:
```sql
SELECT value FROM psypi_config WHERE key = 'last_a_session_at'
```
This is a one-line fix in `a_db_reader.gleam`.

**Affected parties:** None beyond `a_db_reader.gleam` itself — the function signature and return type stay the same.

---

## Bug #2: `a_orchestrator.gleam` writes `last_a_session_at` to in-memory store

**Severity:** Critical
**Source:** Commit 5518253
**File:** `src/a_orchestrator.gleam` line 148

**Problem:**
```gleam
set_config("last_a_session_at", int.to_string(now))
```
This calls `pi_extension.set_config()` which writes to the in-memory `_configStore` JS object. The value is:
- Never read by `a_db_reader.get_last_a_session_at()` (which queries DB)
- Lost on process restart
- Never persisted

Combined with Bug #1, this creates a complete write/read disconnect:
- Write → in-memory JS object (never read)
- Read → `config` DB table (doesn't exist)

**Impact:**
- `last_a_session_at` is never actually tracked
- Even after fixing Bug #1, the DB would always return NotFound
- `get_recent_commits` would still fall back to last 20 commits

**Fix:**
Replace `pi_extension.set_config` with `psypi_config.set`:
```gleam
// Before:
set_config("last_a_session_at", int.to_string(now))

// After:
promise.await(psypi_config.set("last_a_session_at", int.to_string(now)), fn(_) {
  // continue
})
```
This requires:
1. Add `import psypi_config` to `a_orchestrator.gleam`
2. Remove `set_config` from `pi_extension` import
3. Wrap the subsequent code in `promise.await` since `psypi_config.set` is async
4. Add `idle_since` (default "0") and `last_a_session_at` (default "") to `seed.gleam`

**Affected parties:**
- `a_orchestrator.gleam` — must restructure `handle_monitor_response` for async
- `seed.gleam` — must seed new config keys
- `pi_extension.gleam` — can remove `set_config` declaration after all consumers migrated
- `pi_extension_ffi.mjs` — can remove `_configStore`, `get_config`, `set_config` after all consumers migrated

---

## Bug #3: `hook_on_agent_end.gleam` uses in-memory config for `idle_since` and `monitor_debounce_ms`

**Severity:** High
**Source:** Commit 5518253
**File:** `src/hook_on_agent_end.gleam` lines 27-28, 60-122

**Problem:**
```gleam
import pi_extension.{..., get_config, ..., set_config, ...}
```
All `idle_since` and `monitor_debounce_ms` reads/writes go through `pi_extension.get_config/set_config` which uses the in-memory `_configStore`. This means:
- `idle_since` is lost on process restart (if Pi restarts while S is idle, A never wakes)
- `monitor_debounce_ms` in DB is ignored (in-memory store has no value until set)
- Two sources of truth for the same config keys

**Impact:**
- After Pi restart during idle period, A-bot never wakes because `idle_since` is lost
- Debounce config changes in DB have no effect until process restart
- `seed.gleam` seeds `monitor_debounce_ms` to DB but the hook reads from in-memory

**Fix:**
Replace all `get_config`/`set_config` calls with `psypi_config.get`/`psypi_config.set`.

Key challenge: **sync → async conversion**. The current code uses synchronous pattern matching:
```gleam
case get_config("idle_since") {
  option.None -> ...
  option.Some("0") -> ...
  option.Some(idle_since_str) -> ...
}
```
Must become async:
```gleam
promise.await(psypi_config.get("idle_since"), fn(result) {
  case result {
    Error(NotFound(_)) -> ...  // key not in DB = first time
    Ok("0") -> ...             // was cleared
    Ok(idle_since_str) -> ...  // has a timestamp
    Error(e) -> ...            // other error
  }
})
```

**Affected parties:**
- `hook_on_agent_end.gleam` — major rewrite of `check_idle_since` and `on_agent_end`
- `pi_extension.gleam` — remove `get_config`/`set_config` after migration
- `pi_extension_ffi.mjs` — remove `_configStore` after migration

**Note:** The `debounced_hook` JS generator in `extension_generator.gleam` already reads `monitor_debounce_ms` from `psypi_config.get_debounce_ms()` (DB). So the debounce timer itself uses DB correctly. But `hook_on_agent_end.gleam` re-reads it from in-memory — this is the second, redundant read that should also use DB.

---

## Bug #4: `task.gleam` completely broken — build fails

**Severity:** Critical
**Source:** Commit 28faf98 (chore: add migration plan)
**File:** `src/task.gleam`

**Problem:**
Commit 28faf98 rewrote `task.gleam` with 16+ compile errors:
1. Missing imports: `gleam/dynamic`, `gleam/dynamic/decode`, `gleam/javascript/promise`, `gleam/option`
2. `DecodeError` variant removed from `TaskError` but still referenced
3. `db.with_connection` called with 1 arg (needs 2 — error handler was removed)
4. `int_param` doesn't exist in `pi_tool_call.gleam`
5. `promise.await` used without `promise` import
6. Type mismatch: `Error(...)` returns `Result` where `promise.Promise(Result)` expected

Also deleted three tools (`task_list_tool`, `task_complete_tool`, `task_add_tool`) and replaced with one broken `task_tool()`.

**Impact:**
- Entire project fails to build
- `psypi-tasks` and `psypi-task-complete` tools no longer exist
- `extension_generator.gleam` still imports the deleted functions → more build errors

**Fix:**
Revert `task.gleam` to its pre-28faf98 state (commit 88332a7). The old version had working `task_add_tool`, `task_list_tool`, `task_complete_tool` with proper imports and types.

If the intent was to add `project.resolve_or_create(cwd)` to the `add` function, that should be done incrementally on top of the working version, not by rewriting the entire file.

**Affected parties:**
- `task.gleam` — revert to pre-28faf98 state
- `extension_generator.gleam` — no changes needed (imports will work again after revert)

---

## Bug #5: Dual agent ID computation path (FFI JS vs Gleam)

**Severity:** Medium
**Source:** Commit 01f702a (redesign: simplify psypi-commit)
**Files:** `src/pi_extension_ffi.mjs` (get_agent_id), `src/agent_identity.gleam` / `src/agent_identity_types.gleam` (semantic_id)

**Problem:**
Two separate implementations compute the agent ID:
1. **FFI JS** (`pi_extension_ffi.mjs:get_agent_id`): Synchronous, used by `tool_commit.gleam`
2. **Gleam** (`agent_identity_types.gleam:semantic_id`): Async, used by `agent_identity.gleam:my_id_tool`

They could diverge if one is updated without the other. Currently they produce the same format (`{prefix}-{project|G}-{source}-{model}[-{thinking}]`), but there's no enforcement.

**Impact:**
- If someone fixes a bug in one path but not the other, IDs become inconsistent
- `psypi-commit` uses FFI path, `psypi-my-id` uses Gleam path — could show different IDs
- Commit 3c7eaed fixed the Gleam path for G-in-project-position but did NOT update the FFI path (though the FFI path happened to already have the correct logic)

**Fix (two options):**

**Option A: Unify on Gleam path** — Make `tool_commit.gleam` call `agent_identity.get_current_agent_id()` (async) instead of `pi_extension.get_agent_id(ctx)` (sync). This requires making `on_commit` async, which it already is (returns `promise.Promise`).

**Option B: Keep FFI but add validation** — Add a test that asserts both paths produce the same output for the same inputs. Keep FFI for performance but ensure they stay in sync.

Recommended: **Option A** — single source of truth in Gleam. The FFI `get_agent_id` can be removed after migration.

**Affected parties:**
- `tool_commit.gleam` — change `get_agent_id(ctx)` to `agent_identity.get_current_agent_id(ctx)` (or equivalent async call)
- `pi_extension_ffi.mjs` — remove `get_agent_id` function
- `pi_extension.gleam` — remove `get_agent_id` declaration
- `agent_identity.gleam` — ensure `get_current_agent_id` or `my_id_tool` is usable from `tool_commit`

---

## Bug #6: `extension_generator.gleam` imports deleted task functions

**Severity:** Critical (build blocker)
**Source:** Commit 28faf98 (deleted functions in task.gleam)
**File:** `src/extension_generator.gleam` line 50

**Problem:**
```gleam
import task.{task_add_tool, task_complete_tool, task_list_tool}
```
These three functions were deleted in commit 28faf98 and replaced with a single `task_tool()`.

**Impact:** Build fails.

**Fix:** This is resolved by reverting `task.gleam` (Bug #4 fix). If task.gleam is reverted, the imports work again.

If a future change to task.gleam is desired, `extension_generator.gleam` must be updated in the same commit.

---

## Bug #7: Planning files committed to repository

**Severity:** Low
**Source:** Commit 28faf98
**Files:** `migration-plan.txt`, `.planning/phases/01-inter-review-commit-separation/`

**Problem:**
Temporary planning artifacts were committed to the repo. These should be in `.trae/` directory or the database, not in the repo.

**Fix:**
Delete these files and add `.planning/` to `.gitignore`.

**Affected parties:** None.

---

## Bug #8: SKILL.md describes bug instead of correct design

**Severity:** Medium
**Source:** My edit (commit 88332a7 context)
**File:** `ppi_skills/psypi-basics/SKILL.md`

**Problem:**
The SKILL.md contains:
```
**BUG (needs fixing):** `hook_on_agent_end.gleam` and `a_orchestrator.gleam` currently use
`pi_extension.get_config/set_config` which reads/writes an in-memory JS object...
```
Documentation should describe the **correct** architecture, not the current buggy behavior. The bug is tracked here (in this issues document). The SKILL.md should state that config is stored in `psypi_config` DB table and accessed via `psypi_config.gleam` — period.

**Fix:**
Remove the "BUG (needs fixing)" paragraph from SKILL.md. The correct design is already described above it. The A-Bot Event Flow section already correctly says "Checks `idle_since` from `psypi_config` DB table" — that's the correct description.

**Affected parties:** None — this is a documentation-only change.

---

## Fix Order (Dependency-Aware)

The fixes must be applied in this order due to dependencies:

### Phase 1: Restore Build (unblock everything)

| Step | Bug | What | Files |
|------|-----|------|-------|
| 1.1 | #4 | Revert `task.gleam` to pre-28faf98 state | `src/task.gleam` |
| 1.2 | #6 | Verify build passes (imports restored) | — |
| 1.3 | #7 | Delete planning files, update `.gitignore` | `migration-plan.txt`, `.planning/`, `.gitignore` |

### Phase 2: Fix Config System (critical runtime bugs)

| Step | Bug | What | Files |
|------|-----|------|-------|
| 2.1 | #1 | Fix `a_db_reader` SQL: `config` → `psypi_config` | `src/a_db_reader.gleam` |
| 2.2 | #2 | Replace `set_config` with `psypi_config.set` in `a_orchestrator.gleam` | `src/a_orchestrator.gleam` |
| 2.3 | #2 | Add `idle_since` and `last_a_session_at` to `seed.gleam` | `src/seed.gleam` |
| 2.4 | #3 | Rewrite `hook_on_agent_end.gleam` to use `psypi_config.get/set` | `src/hook_on_agent_end.gleam` |
| 2.5 | #3 | Remove `get_config`/`set_config` from `pi_extension.gleam` and `pi_extension_ffi.mjs` | `src/pi_extension.gleam`, `src/pi_extension_ffi.mjs` |
| 2.6 | — | Verify build passes | — |

### Phase 3: Fix Agent ID Dual Path

| Step | Bug | What | Files |
|------|-----|------|-------|
| 3.1 | #5 | Make `tool_commit.gleam` use `agent_identity` Gleam path instead of FFI | `src/tool_commit.gleam`, `src/agent_identity.gleam` |
| 3.2 | #5 | Remove `get_agent_id` from FFI | `src/pi_extension_ffi.mjs`, `src/pi_extension.gleam` |
| 3.3 | — | Verify build passes | — |

### Phase 4: Documentation

| Step | Bug | What | Files |
|------|-----|------|-------|
| 4.1 | #8 | Remove "BUG (needs fixing)" from SKILL.md | `ppi_skills/psypi-basics/SKILL.md` |
| 4.2 | — | Update design doc to reflect all fixes | `docs/design_inter_review_commit_separation.md` |

---

## Config Key Inventory (Post-Fix)

After all fixes, the `psypi_config` table will contain these keys:

| Key | Default | Written by | Read by |
|-----|---------|-----------|---------|
| `monitor_debounce_ms` | `300000` | `seed.gleam` | `hook_on_agent_end.gleam`, `extension_generator.gleam` (debounced_hook) |
| `idle_since` | `0` | `hook_on_agent_end.gleam` | `hook_on_agent_end.gleam` |
| `last_a_session_at` | `` | `a_orchestrator.gleam` | `a_db_reader.gleam` |
| `last_wakeup` | `` | `seed.gleam` | (currently unused) |

All accessed via `psypi_config.gleam` — no in-memory store.

---

## Bug #9: Duplicate `now_ms` FFI with inconsistent signatures

**Severity:** High
**Source:** Multiple commits by different AIs
**Files:** `src/pi_extension_ffi.mjs`, `src/node_ffi.mjs`, `src/a_context_utils.gleam`

**Problem:**
Two `now_ms` FFI implementations exist with **different return types**:

1. `pi_extension_ffi.mjs:now_ms()` → returns `Date.now()` (raw `Int`)
   - Declared in `pi_extension.gleam` as `pub fn now_ms() -> Int`
   - Used by: `hook_on_agent_end.gleam`, `a_orchestrator.gleam`

2. `node_ffi.mjs:now_ms()` → returns `new Ok(Date.now())` (Gleam `Result(Int, String)`)
   - Declared in `a_context_utils.gleam` as `fn now_ms() -> Result(Int, String)`
   - Used by: `a_context_utils.gleam:current_time_ms()`

Same function name, same purpose, different FFI files, different return types. If someone accidentally imports the wrong one, they get a type mismatch or silent wrong behavior.

**Gleam official standard violation:**
> "Externals should be used sparingly. Always prefer Gleam based solutions."
There is no reason for two FFI implementations of the same function. One is enough.

**Fix:**
1. Keep `pi_extension.now_ms() -> Int` as the single source (simpler, no Result wrapping needed for `Date.now()`)
2. Change `a_context_utils.gleam:current_time_ms()` to call `pi_extension.now_ms()` instead of its own FFI
3. Remove `now_ms` from `node_ffi.mjs`

**Affected parties:**
- `a_context_utils.gleam` — remove local `now_ms` FFI, import from `pi_extension`
- `node_ffi.mjs` — remove `now_ms` function

---

## Bug #10: Orphan FFI file `time_utils_ffi.mjs`

**Severity:** Medium
**Source:** Commit 7d8fed7 (fix: replace hand-written JS strings with Gleam code)
**File:** `src/time_utils_ffi.mjs`

**Problem:**
`time_utils_ffi.mjs` contains a single function `now_iso8601()` but no `.gleam` file references it. The corresponding `time_utils.gleam` was deleted but the FFI file was left behind.

**Impact:** Dead code, confusion about which FFI files are active.

**Fix:** Delete `src/time_utils_ffi.mjs`.

**Affected parties:** None — nothing imports it.

---

## Bug #11: `read_file_sync` FFI duplicates `simplifile.read()`

**Severity:** High
**Source:** Original codebase, perpetuated by multiple AIs
**Files:** `src/pi_extension_ffi.mjs`, `src/pi_extension.gleam`, `src/hook_on_tool_call.gleam`

**Problem:**
`pi_extension_ffi.mjs:read_file_sync()` wraps Node.js `readFileSync` and returns `Result(String, String)`.

But `simplifile` is already a project dependency (`gleam.toml`) and its `simplifile.read()` function:
- Also wraps `readFileSync` on the JS target (confirmed in `simplifile_js.mjs:readBits`)
- Returns `Result(String, FileError)` — same semantics
- Is a well-tested, community-maintained package

**Gleam official standard violation:**
> "Always prefer Gleam based solutions, using externals only when there is no suitable alternative."
> "Check there is no existing Gleam package that provides the functionality you need."

`simplifile.read()` IS the suitable alternative. Writing our own FFI for it violates the standard.

**Fix:**
1. In `hook_on_tool_call.gleam`, replace `pi_extension.read_file_sync(path)` with `simplifile.read(path)`
2. Handle the `FileError` → `String` error mapping
3. Remove `read_file_sync` from `pi_extension.gleam` and `pi_extension_ffi.mjs`

**Affected parties:**
- `hook_on_tool_call.gleam` — change import and call site
- `pi_extension.gleam` — remove `read_file_sync` declaration
- `pi_extension_ffi.mjs` — remove `read_file_sync` function and `readFileSync` import

---

## Bug #12: `check_git_exists` FFI duplicates `simplifile.is_directory()`

**Severity:** Medium
**Source:** Commit 8c6e4ef (refactor: replace JS IIFEs in agent_identity with Gleam code)
**Files:** `src/agent_identity_ffi.mjs`, `src/agent_identity.gleam`

**Problem:**
`agent_identity_ffi.mjs:check_git_exists()` does:
```javascript
export function check_git_exists(cwd) {
  return existsSync(join(cwd, '.git'));
}
```

`simplifile.is_directory()` does the same thing and is already a project dependency:
```gleam
simplifile.is_directory(cwd <> "/.git")  // Returns Result(Bool, FileError)
```

**Gleam official standard violation:**
> "Check there is no existing Gleam package that provides the functionality you need."

**Fix:**
1. In `agent_identity.gleam`, replace the FFI call with `simplifile.is_directory()`
2. Handle `Result(Bool, FileError)` → `Bool` mapping (default to `False` on error)
3. Delete `agent_identity_ffi.mjs` entirely

**Affected parties:**
- `agent_identity.gleam` — replace FFI with `simplifile.is_directory()`
- `agent_identity_ffi.mjs` — delete entirely

---

## Bug #13: `node_ffi.mjs` contains multiple unused/redundant functions

**Severity:** Medium
**Source:** Accumulated by multiple AIs over time
**File:** `src/node_ffi.mjs`

**Problem:**
`node_ffi.mjs` contains functions that are either:
- **Unused:** `execute()`, `exists()`, `ensure_dir()`, `write_text_file()` — no `.gleam` file references them
- **Duplicate:** `now_ms()` — duplicates `pi_extension_ffi.mjs:now_ms()` with different signature (Bug #9)

Only 3 functions are actually used:
- `get_project_root()` — by `extension_generator.gleam`
- `get_project_id_env()` — by `db.gleam`
- `get_database_url()` — by `db.gleam`
- `spawn_pi()` — by `main.gleam`

**Fix:**
Remove all unused functions from `node_ffi.mjs`. Keep only the 4 that are referenced.

**Affected parties:** None — the removed functions have no callers.

---

## Bug #14: `gleamValueToJson` and `unwrapGleamResult` use fragile constructor name matching

**Severity:** Medium
**Source:** Original codebase
**File:** `src/pi_extension_ffi.mjs`

**Problem:**
`gleamValueToJson()` hardcodes 15+ Gleam constructor names:
```javascript
if (name.startsWith('Task$Task') || name.startsWith('Issue$Issue') || 
    name.startsWith('Meeting$Meeting') || name.startsWith('Skill$Skill') || ...)
```

`unwrapGleamResult()` checks for `Ok`/`Error` constructor names:
```javascript
if (typeName === 'Ok') return { ok: true, value: result['0'] };
if (typeName === 'Error') return { ok: false, error: ... };
```

**Gleam official standard violation:**
> "The external code written in other languages cannot be analysed and type checked by the Gleam compiler, making bugs and runtime errors possible."

The Gleam compiler can change internal representation at any version. These functions rely on undocumented internal details.

**Impact:**
- Adding a new Gleam type (e.g., `Directive`) requires updating this JS function
- Gleam compiler upgrade could change constructor naming → silent breakage
- Easy to forget to update when adding new types

**Fix (long-term):**
Consider using `gleam_json` encoding on the Gleam side instead of JS-side introspection. For now, document this as a known fragility point and add a comment in the code.

**Affected parties:** None immediately — this is a maintenance hazard, not a current bug.

---

## FFI Audit Summary (2026-05-29)

**Gleam official standard** (from `/Users/jk/gits/hub/tools_ai/refers/gleam-language/website/documentation/externals-guide.djot`):
> "Externals should be used sparingly. Always prefer Gleam based solutions."
> FFI is justified only for: (1) runtime APIs, (2) existing non-Gleam code that's impractical to rewrite.
> Always check for existing Gleam packages first.

### Current FFI Inventory (26 declarations)

| # | Function | FFI File | Verdict | Reason |
|---|---|---|---|---|
| 1-13 | ctx/pi accessors | pi_extension_ffi | ✅ Justified | Access Pi runtime JS objects |
| 14 | read_file_sync | pi_extension_ffi | ❌ Bug #11 | simplifile.read() exists in deps |
| 15 | call_monitor | pi_extension_ffi | ✅ Justified | Complex Pi API interaction |
| 16 | ctx_reload | pi_extension_ffi | ✅ Justified | Access ctx.reload() |
| 17 | exec_sync | pi_extension_ffi | ✅ Justified | child_process, no Gleam alt |
| 18-19 | unwrapGleamResult, gleamValueToJson | pi_extension_ffi | ⚠️ Bug #14 | Fragile, but no alt yet |
| 20 | now_ms | pi_extension_ffi | ✅ Justified | Date.now(), no stdlib time |
| 21 | check_git_exists | agent_identity_ffi | ❌ Bug #12 | simplifile.is_directory() exists |
| 22 | get_project_root | node_ffi | ✅ Justified | process.cwd() |
| 23 | now_ms | node_ffi | ❌ Bug #9 | Duplicate + inconsistent |
| 24-25 | get_project_id_env, get_database_url | node_ffi | ✅ Justified | process.env |
| 26 | spawn_pi | node_ffi | ✅ Justified | child_process.spawn |

### Files to Delete After Fixes

| File | Bug | Reason |
|---|---|---|
| `src/time_utils_ffi.mjs` | #10 | Orphan, no .gleam references it |
| `src/agent_identity_ffi.mjs` | #12 | Replaced by simplifile.is_directory() |

### Updated Fix Order

Phase 1-4 remain as before. Add Phase 5 for FFI cleanup:

### Phase 5: FFI Cleanup (Gleam Standard Compliance)

| Step | Bug | What | Files |
|------|-----|------|-------|
| 5.1 | #10 | Delete `time_utils_ffi.mjs` | `src/time_utils_ffi.mjs` |
| 5.2 | #9 | Unify `now_ms`: fix `a_context_utils.gleam` to use `pi_extension.now_ms()`, remove from `node_ffi.mjs` | `src/a_context_utils.gleam`, `src/node_ffi.mjs` |
| 5.3 | #11 | Replace `read_file_sync` with `simplifile.read()` | `src/hook_on_tool_call.gleam`, `src/pi_extension.gleam`, `src/pi_extension_ffi.mjs` |
| 5.4 | #12 | Replace `check_git_exists` FFI with `simplifile.is_directory()`, delete `agent_identity_ffi.mjs` | `src/agent_identity.gleam`, `src/agent_identity_ffi.mjs` |
| 5.5 | #13 | Remove unused functions from `node_ffi.mjs` | `src/node_ffi.mjs` |
| 5.6 | — | Verify build passes | — |
