# System Review — psypi — 2026-05-26 (REVISED)

Every finding verified against live PostgreSQL database, Gleam source, and git history.
No assumptions. No documentation trust. Only verified facts.

**REVISION NOTE**: Earlier version of this review contained incorrect "phantom column" claims.
Live DB verification on 2026-05-26 showed the database has MORE columns than expected,
not fewer. The issues are: wrong column names, missing `::text` casts, and FFI bugs.

---

## 1. GLEAM MISSING TYPES — DB Tables Without Gleam Types

The database has 115 tables. Gleam source defines types for only 12 of them.
103 tables have zero Gleam type coverage.

### Tables WITH Gleam types (14/115)

| DB Table               | Gleam Type | Module               | Status                                                  |
| ---------------------- | ---------- | -------------------- | ------------------------------------------------------- |
| tasks                  | Task       | task.gleam           | PARTIAL — 60 DB columns, Gleam type covers ~14          |
| issues                 | Issue      | issue_types.gleam    | PARTIAL — 31 DB columns, Gleam type covers ~9           |
| inter_reviews          | Review     | inter_review.gleam   | BROKEN — missing `::text` casts on timestamps           |
| memory                 | Memory     | memory.gleam         | PARTIAL — `source='learn'` not in audit allowed_sources |
| skills                 | Skill      | skill.gleam          | PARTIAL — 56 DB columns, Gleam type covers ~11          |
| meetings               | Meeting    | meeting.gleam        | OK — basic columns match                                |
| meeting_opinions       | Opinion    | meeting.gleam        | OK — basic columns match                                |
| project_communications | Broadcast  | broadcast.gleam      | PARTIAL — INSERT works, but Gleam type incomplete       |
| agent_sessions         | Agent      | agents.gleam         | OK — basic columns match                                |
| psypi_config           | (inline)   | psypi_config.gleam   | OK — key/value pattern                                  |
| activity_log           | (inline)   | monitor.gleam        | OK — basic columns match                                |
| learning_insights      | (none)     | areflect.gleam       | INSERT only, no read type                               |
| agent_souls            | (tuple)    | agent_identity.gleam | READ only, decoder as tuple not named type              |
| agent_jobs             | (String)   | s_db_reader.gleam    | READ only, decoded to formatted string                  |

### Tables WITHOUT Gleam types (103/115) — CRITICAL GAPS

These tables exist in PostgreSQL but have NO Gleam type definition:

| Category               | Missing Tables                                                                                                                                                  |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Project Management** | projects, project_config_history, project_docs, project_metrics, milestones                                                                                     |
| **Agent System**       | agent_identities, agent_identity, agent_scores, ai_capabilities, soul                                                                                           |
| **Auth & Users**       | users, user_sessions, api_keys, provider_api_keys, email_verifications, password_resets                                                                         |
| **Payments**           | payments, payment_analytics, payment_refunds, payment_webhooks, subscriptions, subscription_plans, user_payment_methods                                         |
| **Monitoring**         | failure_alerts, failure_patterns, failure_root_causes, rate_limits, stuck_tasks_tracking, long_tasks_pause                                                      |
| **Review System**      | reviews, review_comments, review_labels                                                                                                                         |
| **Issue Detail**       | issue_comments, issue_events, issue_labels, labels                                                                                                              |
| **Knowledge**          | knowledge_links, reflections, retry_learning, retry_strategies                                                                                                  |
| **Skill Detail**       | skill_audit_log, skill_builder_config, skill_feedback, skill_versions                                                                                           |
| **Task Detail**        | task_audit_log, task_outcome_features, task_outcomes, task_patterns, task_templates, scheduled_tasks                                                            |
| **Communication**      | conversations, dead_letter_queue                                                                                                                                |
| **MCP**                | mcp_configs, mcp_tools                                                                                                                                          |
| **System**             | bootstrap_state, direct_insert_audit, event_log, insert_reminders, process_pids, prompt_suggestions, reminder_templates, system_directives, table_documentation |
| **Search**             | archived_memory, auto_category_rules, auto_tag_rules                                                                                                            |

### Most Critical Missing Types

1. **projects** — 1 row (hardcoded UUID `0d324e68...`), no Gleam type, yet `project_id` is FK in 5+ tables and hardcoded UUID used in 57 locations
2. **soul** — exists separately from `agent_souls`, has `agent_id`, `name`, `content`, `traits` columns, no Gleam type
3. **conversations** — 17 columns, no Gleam type, no read/write code
4. **agent_identity** — exists but `agent_identity.gleam` uses FFI, not DB
5. **system_reviews** — separate from `inter_reviews`, no Gleam type
6. **failure_alerts / failure_patterns** — monitoring tables, no Gleam type

---

## 2. TABLE NAME VERIFICATION — Code vs DB

Live DB verification shows ALL referenced tables exist. Earlier "phantom table" claims were WRONG.

| Table               | Referenced In                        | Exists in DB | Notes                                         |
| ------------------- | ------------------------------------ | ------------ | --------------------------------------------- |
| `agent_souls`       | a_db_reader.gleam, s_db_reader.gleam | YES          | Has `id_prefix`, `role`, `domain`             |
| `agent_jobs`        | a_db_reader.gleam, s_db_reader.gleam | YES          | Has `job`, `priority`, `category`             |
| `code_versions`     | code_version.gleam                   | YES          | 11 cols; save/get/restore functions all EXIST |
| `notifications`     | monitor.gleam                        | YES          | Has `priority`, `title`, `body`               |
| `psypi_event_hooks` | event_hooks.gleam                    | YES          | Has hook registration data                    |
| `soul`              | (separate from agent_souls)          | YES          | Has `agent_id`, `name`, `content`             |
| `projects`          | db.gleam (hardcoded UUID)            | YES (1 row)  | Has `path`, `git_remote`, `name`              |

**Note**: There are TWO soul tables: `agent_souls` (with `id_prefix`) and `soul` (with `agent_id`).
The code correctly uses `agent_souls` for its queries.

---

## 3. COLUMN NAME ISSUES — Verified Against Live DB

Live DB verification on 2026-05-26 shows the database has MORE columns than the Gleam code references.
Most columns referenced in Gleam DO exist. The real issues are:

### 3a. WRONG COLUMN NAME (confirmed bug)

| File             | Table  | Wrong Column | Correct Column | Impact                  |
| ---------------- | ------ | ------------ | -------------- | ----------------------- |
| monitor_ai.gleam | issues | `type`       | `issue_type`   | INSERT fails at runtime |

### 3b. ALL COLUMNS VERIFIED AS EXISTING

| File              | Table                  | Columns Referenced                                                                                                                                               | Status                           |
| ----------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| issue_db.gleam    | issues (31 cols)       | id, title, description, severity, status, issue_type, created_at, resolved_at, created_by, discovered_by, environment, git_branch, git_hash, reported_by, source | ALL EXIST                        |
| task.gleam        | tasks (60 cols)        | id, title, description, status, priority, result, error, retry_count, created_at, updated_at, completed_at, created_by, source, project_id                       | ALL EXIST                        |
| skill.gleam       | skills (56 cols)       | id, name, source, description, version, author, repository, tags, reference_list                                                                                 | `reference_list` EXISTS          |
| broadcast.gleam   | project_communications | from_ai, to_ai, message_type, content, priority, metadata                                                                                                        | ALL EXIST                        |
| a_db_reader.gleam | tasks                  | id, title, status, priority, is_stuck                                                                                                                            | ALL EXIST (is_stuck added later) |
| a_db_reader.gleam | agent_souls            | role, domain, responsibility                                                                                                                                     | ALL EXIST                        |
| a_db_reader.gleam | agent_jobs             | job, priority, category                                                                                                                                          | ALL EXIST                        |
| monitor.gleam     | notifications          | id, agent_id, priority, title, body, created_at, read_at                                                                                                         | ALL EXIST                        |

### 3c. GLEAM TYPE COVERAGE IS THIN

The real problem is not phantom columns but THIN TYPE COVERAGE:

| Table         | DB Columns | Gleam Type Fields | Coverage |
| ------------- | ---------- | ----------------- | -------- |
| tasks         | 60         | ~14               | 23%      |
| issues        | 31         | ~9                | 29%      |
| skills        | 56         | ~11               | 20%      |
| inter_reviews | 33         | ~6                | 18%      |

This means most DB columns are invisible to Gleam's type system, creating risk of
schema drift going undetected.

---

## 4. MISSING `::text` CASTS — Timestamp & JSONB Decode Failures

PostgreSQL `timestamptz` columns return JavaScript Date objects from the Node.js pg driver.
PostgreSQL `jsonb` columns return JavaScript objects from the Node.js pg driver.
Both need `::text` cast for Gleam `decode.string` to work. Missing casts cause `DecodeError`.

### 4a. Timestamp columns missing `::text` cast

| File               | Line | Column         | SQL Has Cast?               |
| ------------------ | ---- | -------------- | --------------------------- |
| inter_review.gleam | 148  | `requested_at` | NO — will fail              |
| inter_review.gleam | 283  | `requested_at` | NO — will fail              |
| inter_review.gleam | 285  | `requested_at` | NO — will fail              |
| memory.gleam       | 101  | `created_at`   | NO — will fail (`SELECT *`) |

Note: `inter_review.gleam` does NOT query `started_at`, `completed_at`, or `response_at`
in its SELECT statements, so those don't need casts (they're simply not read).

### 4b. JSONB columns missing `::text` cast

| File        | Line | Column           | Decoder Used                     | SQL Has Cast?               |
| ----------- | ---- | ---------------- | -------------------------------- | --------------------------- |
| task.gleam  | 183  | `result`         | `decode.optional(decode.string)` | NO — will fail for non-null |
| skill.gleam | 184  | `content`        | `decode.optional(decode.string)` | NO — will fail for non-null |
| skill.gleam | 184  | `reference_list` | `decode.optional(decode.string)` | NO — will fail for non-null |
| skill.gleam | 214  | `content`        | `decode.optional(decode.string)` | NO — will fail for non-null |
| skill.gleam | 214  | `reference_list` | `decode.optional(decode.string)` | NO — will fail for non-null |

Note: `skill.gleam` lines 137, 144 DO have `content::text, reference_list::text` casts.
But lines 184, 214 (get_skill_by_name, update_skill_status) do NOT.

### 4c. `memory.gleam` — `save()` Decoder Mismatch (CRITICAL)

```gleam
// memory.gleam:63
let sql = "INSERT INTO memory (...) VALUES (...) RETURNING id"
// ...
// memory.gleam:82
case decode.run(row, memory_decoder()) {
```

The `RETURNING id` clause only returns the `id` column. But `memory_decoder()` expects
7 fields: `id`, `content`, `tags`, `source`, `agent_id`, `importance`, `created_at`.
The decoder will FAIL because the other 6 fields are missing from the returned row.

**Impact**: The `save()` function ALWAYS returns `Error(DecodeError("Failed to decode memory"))`
even though the INSERT succeeded. The memory IS saved to the database, but the function
reports failure. Callers may retry, creating duplicate entries.

**Fix**: Use a simple `id_decoder()` (like `broadcast.gleam` does) instead of `memory_decoder()`
for the `RETURNING id` query.

---

## 5. FFI LAYER ISSUES

### 5a. `gleamValueToJson` — Fragile `constructor.name` Pattern

File: [pi_extension_ffi.mjs:170-197](src/pi_extension_ffi.mjs#L170-L197)

```javascript
const name = val.constructor?.name || '';
if (name.startsWith('Task$Task') || name.startsWith('Issue$Issue') || ...)
```

**Problems**:
- Breaks if JS minifier renames constructors
- Hardcoded list of 15 Gleam type names must be manually maintained
- Every new Gleam type requires updating this function
- No fallback for unknown types — silently converts to generic object

### 5b. Duplicate `now_ms` FFI

- `pi_extension_ffi.mjs` exports `now_ms()` (returns Int)
- `node_ffi.mjs` exports `now_ms()` (returns `Ok(Int)`)
- `a_context_utils.gleam` imports from `node_ffi.mjs`
- `pi_extension.gleam` imports from `pi_extension_ffi.mjs`
- Inconsistent return types: one returns bare Int, other returns `Result`

### 5c. Orphan FFI File

- `time_utils_ffi.mjs` exists but NO Gleam file imports from it
- Dead code — should be removed or connected

### 5d. `exec_sync` — Command Injection Risk

File: [pi_extension_ffi.mjs:143-151](src/pi_extension_ffi.mjs#L143-L151)

```javascript
export function exec_sync(command) {
  const { execSync } = require('child_process');
  const output = execSync(String(command), ...);
}
```

No sanitization of `command` parameter. Any tool that passes user input here enables command injection.

### 5e. `call_monitor` — Retry Logic Without Backoff

File: [pi_extension_ffi.mjs:80-110](src/pi_extension_ffi.mjs#L80-L110)

- Retries once on rate limit with `reasoning: 'none'`
- No exponential backoff
- No delay between retries
- Could hit rate limits harder

---

## 6. AUDIT TRIGGER — `source='learn'` NOT IN ALLOWED SOURCES

**CORRECTION**: Earlier version claimed `project_communications.priority` column doesn't exist.
Live DB verification shows it DOES exist. The trigger INSERT is valid.

The real issue is that `learning.gleam` uses `source='learn'` which is NOT in the audit
trigger's `allowed_sources` array:

```sql
v_allowed_sources TEXT[] := ARRAY['areflect', 'cli', 'heartbeat', 'scheduler',
  'migration', 'system', 'api', 'broadcast', 'answer', 'notification', 'response'];
```

When `source='learn'` is used:
1. The audit trigger fires on INSERT to `memory`
2. The `memory` table is NOT in the ELSIF chain, so falls to the ELSE clause
3. ELSE clause: `v_source := COALESCE(NEW.source, 'unknown')` → `v_source = 'learn'`
4. It detects `source='learn'` is NOT in `allowed_sources`
5. It logs the INSERT to `direct_insert_audit` table (as a "violation")
6. If `insert_reminders` has an entry for `memory`, it sends a notification via `project_communications`

**Impact**: Not a crash, but creates false-positive audit entries. Every `learning.gleam`
INSERT is logged as a "direct insert violation" because `'learn'` is not in the allowed list.

**Fix**: Either add `'learn'` to `allowed_sources` in the trigger, or change `learning.gleam`
to use `source='areflect'` (which IS in the list).

---

## 7. PROJECT ID LIFECYCLE — HARDENING NEEDED

| Aspect                     | State                                                        |
| -------------------------- | ------------------------------------------------------------ |
| `projects` table           | EXISTS, 1 row (UUID `0d324e68...`, name='psypi')             |
| `projects` Gleam type      | DOES NOT EXIST                                               |
| `projects` Gleam module    | DOES NOT EXIST                                               |
| Default UUID               | `0d324e68-b399-4b85-bd8a-6b1ef7b46168` hardcoded in db.gleam |
| UUID in `projects` table   | PRESENT — matches hardcoded UUID                             |
| `PSYPI_PROJECT_ID` env var | Read but never used to create project row                    |
| Plan document              | EXISTS: `docs/PLAN-project-id-lookup.md` — NOT IMPLEMENTED   |

**CORRECTION**: Earlier version claimed the `projects` table has 0 rows and FK violations
occur. Live DB shows 1 row with the hardcoded UUID, so FK constraints are satisfied.

**Remaining issues**:
1. No Gleam type for `projects` table — schema changes go undetected
2. UUID is hardcoded, not dynamically looked up via `(path, git_remote)` as planned
3. `areflect.gleam` INSERT INTO tasks omits `project_id` (relies on DB default)
4. If a second project is added, the hardcoded UUID will be wrong
5. `PLAN-project-id-lookup.md` exists but is NOT implemented

---

## 8. TEST COVERAGE — FALSE POSITIVES

87 tests pass. Zero tests cover:

| What's NOT Tested             | Impact                                                       |
| ----------------------------- | ------------------------------------------------------------ |
| Any SQL query against real DB | Wrong column names go undetected                             |
| Any FFI function              | `constructor.name` fragility, duplicate `now_ms`, orphan FFI |
| Any decoder against real data | Missing `::text` casts, wrong column names                   |
| `audit_direct_insert` trigger | False-positive audit entries go undetected                   |
| `learning.gleam` INSERT       | `source='learn'` audit flag goes undetected                  |
| `skill.gleam` decoder         | `source='ai-built'` decode failure goes undetected           |

**What IS tested**:
- `pi_tool_call.gleam` — JS text generation (pure functions)
- `extension_generator.gleam` — registry composition (pure functions)
- `agent_identity_types.gleam` — semantic ID generation (pure functions)
- `system_prompt_types.gleam` — prompt composition (pure functions)
- `a_context_utils_test.gleam` — context window parsing (pure functions)
- `a_prompt_builder_test.gleam` — prompt building (pure functions)

**Conclusion**: Tests validate the code compiles and pure functions work, but provide ZERO coverage for the runtime failure modes.

---

## 9. CODE QUALITY ISSUES

### 9a. Duplicated `decode_all_results` — 6 Copies

Identical function copy-pasted across:
- task.gleam:89
- issue_db.gleam:145
- inter_review.gleam:67
- meeting.gleam:97
- event_hooks.gleam:10
- agents.gleam:21

Should be extracted to a shared `decode_utils.gleam` module.

### 9b. Error Swallowing

| File              | Line | Pattern                | Impact                                  |
| ----------------- | ---- | ---------------------- | --------------------------------------- |
| issue_db.gleam    | 251  | `Error(_) -> Ok(0)`    | Returns 0 issues on decode failure      |
| a_db_reader.gleam | 44   | `Error(_) -> Ok(True)` | Reports "no sessions" on decode failure |

### 9c. 32 `DecodeError` Sites With Generic Messages

Every decode failure produces `"Failed to decode X"` with no information about which field failed or what the actual value was. Makes debugging extremely difficult.

### 9d. `SkillSource` Missing `AiBuilt` Variant

**VERIFIED**: DB has `source='ai-built'` in skills table.
Gleam type has: `Clawhub, Local, Generated, Imported`
Missing: `AiBuilt` — will fail to decode any skill with `source='ai-built'`

**Also missing**: `Generated` maps to `'generated'` but no skills currently use that source.
The `string_to_source` function will return Error for `'ai-built'`.

---

## 10. ARCHITECTURE ISSUES

### 10a. No Schema Source of Truth

- Migrations in `src/migrations/` are SQL files
- Gleam types are hand-written and drift from schema
- No code generation from schema
- No schema validation at build time

### 10b. Circular Dependency Risk

`extension_generator.gleam` imports from ALL tool modules. Every tool module imports `db.gleam` and `pi_tool_call.gleam`. This creates a wide dependency fan that makes isolated testing impossible.

### 10c. No Repository/DAO Layer

SQL queries are scattered directly in business logic functions. No separation between:
- Query construction
- Query execution
- Result decoding
- Business logic

---

## 11. GIT STATE — AI REPAIR PATTERN

Last 50 commits show 20+ "fix" commits. Pattern:

1. AI encounters runtime error (decode failure, phantom column, FK violation)
2. AI patches the specific error without understanding root cause
3. Patch introduces new phantom reference or breaks another path
4. Next AI session encounters new error, repeats cycle

**Key evidence**:
- `fix: add project_id to Task type` — added project_id but projects table still empty
- `fix: use valid UUID for default project_id` — UUID is valid format but not in projects table
- `fix: pass NULL instead of empty string for UUID params` — workaround, not fix
- `fix decoder type mismatches in a_db_reader` — patching symptoms, not root cause

---

## 12. FIX PRIORITY ORDER

### P0 — Confirmed Runtime Bugs (System Is Broken)

1. **`memory.gleam:save()`** — `RETURNING id` decoded with `memory_decoder()` (expects 7 fields, gets 1)
   → save() ALWAYS returns Error even though INSERT succeeds → callers may create duplicates
2. **`memory.gleam:search()`** — `SELECT *` returns `created_at` as Date, decoder uses `decode.string`
   → search() ALWAYS fails on decode
3. **`areflect.gleam:save_issue()`** — Missing `project_id` (NOT NULL, no default)
   → INSERT always fails with "null value in column 'project_id' violates not-null constraint"
4. **`monitor_ai.gleam:auto_file_issue()`** — `type` column doesn't exist (should be `issue_type`) AND missing `project_id`
   → INSERT always fails (two separate errors)
5. **`inter_review.gleam`** — add `::text` casts to `requested_at` (3 locations)
   → decode fails with DecodeError
6. **`skill.gleam`** — add `AiBuilt` variant to `SkillSource`
   → decode fails for `source='ai-built'`
7. **`gleamValueToJson`** — ALL `startsWith('X$X')` checks are dead code
   → enum variants serialize as `{}` losing variant name; tool output to Pi LLM is malformed
8. **`skill.gleam:184,214`** — JSONB columns `content`, `reference_list` missing `::text` cast
   → decode fails for non-null values

### P1 — Logic Bugs & Data Integrity

9. **`a_db_reader.gleam:44`** — `Error(_) -> Ok(True)` assumes S is idle on decode failure
   → A-bot may wake up inappropriately; should be `Ok(False)`
10. **`is_s_still_idle`** — counts ALL sessions, not just S-bot (no `agent_type` filter)
   → A-bot's own session counts as "S is busy"
11. **`learning.gleam`** — `source='learn'` triggers audit false-positive
    → Every INSERT logged as "direct insert violation"
12. **9 decoders** silently fall back to default enum values on unknown variants
    → Masks data integrity issues; should return Error instead
13. Fix `task.gleam` — add `::text` cast to `result` (JSONB) column in SELECT
14. Add `project_id` to `areflect.gleam` INSERT INTO tasks (inconsistent with task.add)

### P2 — Architecture & Type Coverage

15. Create Gleam type for `projects` table (currently no type, 1 row exists)
16. Implement `PLAN-project-id-lookup.md` for dynamic project_id resolution
17. Create Gleam types for high-value missing tables: `soul`, `system_reviews`, `conversations`
18. Extract `decode_all_results` to shared `decode_utils.gleam` module
19. Deduplicate `now_ms` FFI (two different return types)
20. Remove orphan `time_utils_ffi.mjs`
21. Update `@mariozechner/pi-tui` → `@earendil-works/pi-tui` in extension_generator.gleam
22. Resolve dual heartbeat columns in `agent_sessions` (`last_heartbeat` vs `last_heartbeat_at`)

### P3 — Architecture & Testing

23. Evaluate `squirrel` for type-safe SQL queries (prevents phantom column issues at compile time)
24. Add integration tests that verify SQL queries against real DB
25. Add schema validation at build time
26. Implement missing Pi extension API features (signal/cancellation, streaming, custom rendering)
27. Replace dynamic `await import()` in hooks with static imports

---

## 13. PI EXTENSION API COMPLIANCE

Verified against official Pi extension documentation in `../refers/pi/`.

### 13a. Import Path Mismatch

**Official pattern**: `import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"`
**psypi pattern**: `import { Text, Box } from "@mariozechner/pi-tui"`

The TUI package import uses `@mariozechner/pi-tui` but the official package is `@earendil-works/pi-tui`. This suggests either:
- An older package name that was renamed
- A fork that may not be compatible with future Pi releases

### 13b. Tool Registration — Missing Features

**Official API** supports these features that psypi's `PiToolCall` type does NOT expose:

| Feature                | Official API                           | psypi Support              |
| ---------------------- | -------------------------------------- | -------------------------- |
| `label`                | Display name for tool                  | MISSING                    |
| `promptSnippet`        | One-line tool summary in system prompt | MISSING                    |
| `promptGuidelines`     | Tool-specific prompt bullets           | MISSING                    |
| `prepareArguments`     | Pre-validation argument shim           | MISSING                    |
| `renderCall`           | Custom TUI rendering for tool call     | MISSING                    |
| `renderResult`         | Custom TUI rendering for tool result   | MISSING                    |
| `renderShell`          | Custom shell mode                      | MISSING                    |
| `terminate`            | Early termination hint                 | MISSING                    |
| `signal` (AbortSignal) | Cancellation support                   | IGNORED (uses `_signal`)   |
| `onUpdate`             | Streaming progress                     | IGNORED (uses `_onUpdate`) |

**Impact**: 
- Tools cannot be cancelled — long DB queries will block the agent
- No streaming progress — user sees nothing until query completes
- No custom rendering — all tools render as plain text
- No prompt snippets — LLM gets full description in system prompt, wasting context

### 13c. `sendMessage` Options — Incorrect Usage

**Official API**:
```javascript
pi.sendMessage({ customType, content, display }, { triggerTurn: true, deliverAs: "steer" });
```

**psypi generated code** (in `pi_extension_ffi.mjs`):
```javascript
pi.sendMessage({ customType, content, display: true }, { triggerTurn: true });
```

Missing `deliverAs` option. Without it, defaults to `"steer"` which may cause unexpected behavior during agent streaming.

### 13d. Event Hook Registration — Missing Event Types

**Official Pi events** that psypi does NOT register hooks for:

| Event                                              | Purpose                | psypi Uses? |
| -------------------------------------------------- | ---------------------- | ----------- |
| `session_start`                                    | Session initialization | NO          |
| `session_shutdown`                                 | Cleanup                | NO          |
| `resources_discover`                               | Skill/prompt discovery | NO          |
| `context`                                          | Message modification   | NO          |
| `before_provider_request`                          | Payload inspection     | NO          |
| `after_provider_response`                          | Rate limit detection   | NO          |
| `turn_start` / `turn_end`                          | Turn lifecycle         | NO          |
| `message_start` / `message_update` / `message_end` | Streaming              | NO          |
| `tool_result`                                      | Result modification    | NO          |
| `input`                                            | Input interception     | NO          |
| `user_bash`                                        | Bash interception      | NO          |

psypi only registers hooks for: `tool_call`, `session_start` (model recording), `model_select`, `before_agent_start`, `agent_start`, `agent_end`, `tool_result`.

### 13e. Dynamic Import in Hot Path

**psypi pattern** (in generated hooks):
```javascript
const hook_fn = (await import('./build/dev/javascript/psypi/module.mjs')).fn_name;
```

This dynamic import runs on EVERY event trigger. The official examples use static imports at module level. Dynamic imports in hot paths cause:
- Unnecessary filesystem I/O on every event
- Module caching may not work as expected with `await import()`
- Import errors surface at runtime instead of startup

### 13f. No `pi.registerCommand` for Extension Commands

psypi registers `autonomic_listen_command()` and `autonomic_reload_command()` as `PiCommandReg`, but the generated JS uses a custom command format. The official API uses `pi.registerCommand(name, { description, handler })`.

### 13g. No `pi.appendEntry` for State Persistence

psypi uses `get_config`/`set_config` (in-memory FFI) for state like `idle_since`. The official API provides `pi.appendEntry(customType, data)` for session-persistent state that survives restarts.

### 13h. No `pi.setActiveTools` for Tool Management

The official API allows dynamic tool enable/disable. psypi has no mechanism for this — all tools are always active.

---

## 14. GLEAM LANGUAGE PATTERN ISSUES

Verified against Gleam stdlib and language reference in `../refers/gleam-language/`.

### 14a. No Use of `gleam/json` for JSON Handling

psypi manually constructs JSON strings and uses `gleam/dynamic/decode` for parsing. The official `gleam/json` package provides type-safe JSON construction and parsing.

**Current pattern** (in `stats.gleam`, `broadcast.gleam`, etc.):
```gleam
let sql = "INSERT INTO ... VALUES ($1, $2, 'learn', $3, $4)"
```

Hardcoded string values in SQL instead of parameterized.

### 14b. No Use of `gleam/result` Combinators

psypi uses verbose pattern matching instead of `result.try`, `result.map`, `result.replace`:

```gleam
// Current verbose pattern
case result {
  Ok(value) -> do_something(value)
  Error(e) -> Error(e)
}

// Idiomatic Gleam
result.map(result, fn(value) { do_something(value) })
```

### 14c. `decode.optional` Behavior Misunderstood

`decode.optional` in Gleam decodes `null` as `None`. But PostgreSQL returns `null` for NULL columns only when the column is actually NULL. If the column doesn't exist in the query, `decode.field` will fail entirely — `decode.optional` does NOT handle missing fields.

This is the root cause of many "Failed to decode" errors: when a SELECT query references a column that doesn't exist, the query itself fails (SQL error), not the decode. But when a column exists in the query but the Gleam decoder expects a different type (e.g., string vs timestamptz), the decode fails because the pg driver returns a Date object, not a string.

**Key insight**: The `::text` cast pattern is needed because the Node.js `pg` driver returns JavaScript Date objects for `timestamptz` columns, which Gleam's `decode.string` cannot decode. Casting to `::text` makes PostgreSQL return the timestamp as a string.

### 14d. No Custom Type for SQL Queries

SQL queries are bare strings scattered throughout the codebase. A type-safe query builder or at minimum a `Sql` opaque type would prevent:
- String concatenation errors
- Missing parameter count mismatches
- Phantom column references

**Recommendation**: Evaluate `squirrel` (https://github.com/giacomocavalieri/squirrel) — a Gleam type-safe SQL library that generates Gleam types from queries, preventing phantom column issues at compile time.

---

## 15. CRITICAL FFI BUG — `gleamValueToJson` Type Detection Broken

### 15a. Constructor Name Mismatch

The `gleamValueToJson` function in [pi_extension_ffi.mjs](file:///Users/jk/gits/hub/tools_ai/psypi/src/pi_extension_ffi.mjs#L176-L197) uses `constructor.name` to detect Gleam custom types:

```javascript
if (name.startsWith('Task$Task') || name.startsWith('Issue$Issue') || ...)
```

**BUT** the actual Gleam-compiled JS classes use simple names:

```javascript
// From build/dev/javascript/psypi/task.mjs (VERIFIED via gleam build)
export class Task extends $CustomType { ... }
// constructor.name === "Task", NOT "Task$Task"

export class Pending extends $CustomType {}
// constructor.name === "Pending", NOT "TaskStatus$Pending"

// Task$Task is a FACTORY FUNCTION, not the class:
export const Task$Task = (id, ...) => new Task(id, ...);
```

**Impact**: ALL `startsWith('X$X')` type-specific branches in `gleamValueToJson` are dead code.
The function falls through to the generic `Object.fromEntries(...)` branch for every Gleam
custom type with fields, and produces `{}` for fieldless variants like `Pending`, `Running`.

**Verified behavior**:
- `Task` instance → `Object.fromEntries(Object.entries(val))` → `{id: ..., title: ..., status: Pending, ...}`
  - The `status: Pending` field is itself a `$CustomType` with no entries → serializes as `{}`
  - This means `status` is always `{}` in the JSON, losing the variant name
- `Pending` instance → `Object.fromEntries([])` → `{}` — variant name completely lost
- `Ok(value)` → works correctly (line 183 handles this)
- `None` → works correctly (line 182 returns `null`)

**Root cause**: Gleam compiles `type TaskStatus { Pending Running ... }` to separate classes
`Pending`, `Running`, etc. The `TaskStatus$Pending` is a factory function, not the class.
The FFI code assumed `constructor.name` would be `"Task$Task"` but it's actually `"Task"`.

### 15b. `unwrapGleamResult` Also Uses Wrong Names

```javascript
if (typeName === 'Ok') return { ok: true, value: result['0'] };
if (typeName === 'Error') return { ok: false, error: ... };
```

Gleam's `Ok` and `Error` types ARE named correctly (they come from `gleam.mjs`), so this works. But the value extraction `result['0']` depends on the internal structure of Gleam's `CustomType` which uses numeric keys.

### 15c. Fix Required

Replace all `constructor.name` checks with `instanceof` checks or use a type tag field. The correct pattern for detecting Gleam custom types in JS is:

```javascript
// Correct: use instanceof for known types
if (val instanceof Task) return { ... };
if (val instanceof Issue) return { ... };

// Or: check for $CustomType inheritance
if (val.constructor.prototype instanceof $CustomType) {
  // It's a Gleam custom type - handle generically
}
```

---

## 16. PACKAGE NAMESPACE MISMATCH

### 16a. `@mariozechner/` vs `@earendil-works/`

The Pi ecosystem underwent a package rename from `@mariozechner/` to `@earendil-works/`. psypi has **not fully migrated**:

| Location                                 | Current                 | Should Be                |
| ---------------------------------------- | ----------------------- | ------------------------ |
| `extension_generator.gleam:217`          | `@mariozechner/pi-tui`  | `@earendil-works/pi-tui` |
| `ppi_skills/pi-platform/references/*.md` | `@mariozechner/*`       | `@earendil-works/*`      |
| `pi_extension_ffi.mjs:8`                 | `@earendil-works/pi-ai` | ✅ correct                |
| `pnpm-lock.yaml`                         | `@earendil-works/pi-ai` | ✅ correct                |

**Impact**: The generated `extension.js` imports from `@mariozechner/pi-tui` which may not exist in newer Pi installations. The import will fail at runtime with "Cannot find module" error.

### 16b. Stale Reference Documentation

The `ppi_skills/pi-platform/references/` directory contains outdated documentation using old package names. These references should be updated or removed to avoid confusing future AI sessions.

---

## 17. ERROR HANDLING ANTI-PATTERNS

### 17a. Silent Fallback to Default Values on Decode Errors

Multiple decoders silently fall back to default enum values when they encounter
an unknown variant. This masks data integrity issues — the code proceeds as if
everything is fine while the actual data is different.

| File            | Line | Fallback                     | Should Be                             |
| --------------- | ---- | ---------------------------- | ------------------------------------- |
| task.gleam      | 69   | `Pending` on unknown status  | Return Error                          |
| issue_db.gleam  | 37   | `Medium` on unknown severity | Return Error                          |
| issue_db.gleam  | 40   | `Open` on unknown status     | Return Error                          |
| issue_db.gleam  | 43   | `Bug` on unknown issue_type  | Return Error                          |
| skill.gleam     | 84   | `Clawhub` on unknown source  | Return Error (also missing `AiBuilt`) |
| skill.gleam     | 87   | `Pending` on unknown status  | Return Error                          |
| meeting.gleam   | 66   | `Pending` on unknown status  | Return Error                          |
| broadcast.gleam | 86   | `Low` on unknown priority    | Return Error                          |
| broadcast.gleam | 89   | `Pending` on unknown status  | Return Error                          |

**Impact**: If a new enum variant is added to the DB (e.g., `status='cancelled'`),
the code silently treats it as the default instead of failing. This makes debugging
extremely difficult because the data appears correct but the behavior is wrong.

### 17b. Swallowed Errors — Dangerous Defaults

| File                  | Line | Code                                    | Risk                                |
| --------------------- | ---- | --------------------------------------- | ----------------------------------- |
| a_db_reader.gleam     | 44   | `Error(_) -> Ok(True)`                  | Assumes S is idle on decode failure |
| a_db_reader.gleam     | 98   | `Error(_) -> "(tasks unavailable)"`     | Hides DB errors from A-bot prompt   |
| a_db_reader.gleam     | 103  | `Error(_) -> "(issues unavailable)"`    | Hides DB errors from A-bot prompt   |
| a_context_utils.gleam | 47   | `Error(_) -> 0`                         | Hides context parse errors          |
| stats.gleam           | 48   | `Error(_) -> 0`                         | Returns 0 stats on error            |
| agent_identity.gleam  | 49   | `Error(_) -> "non-project"`             | Hides project lookup failure        |
| tool_commit.gleam     | 40   | `Error(_) -> ""` (git diff)             | Proceeds without diff on error      |
| tool_commit.gleam     | 47   | `Error(_) -> ""` (git diff --name-only) | Proceeds without file list on error |
| monitor_ai.gleam      | 134  | `Error(_) -> ""`                        | Hides activity read errors          |
| monitor_ai.gleam      | 371  | `Error(_) -> []`                        | Hides alert list errors             |

**Critical**: `a_db_reader.gleam:44` — `Error(_) -> Ok(True)` means if the DB query
to check if S is idle fails, A-bot assumes S IS idle and may wake up inappropriately.
The safe default should be `Ok(False)` (assume S is busy).

---

## 18. A/S AGENT MODEL — LOGIC BUGS

### 18a. `is_s_still_idle` Counts ALL Sessions, Not Just S-bot

```gleam
// a_db_reader.gleam:35-38
let sql =
  "SELECT COUNT(*) as cnt FROM agent_sessions "
  <> "WHERE status = 'alive' AND last_heartbeat > NOW() - INTERVAL '5 minutes'"
```

This query counts ALL alive sessions regardless of `agent_type`. Currently all
sessions have `agent_type = 'psypi'`, so there's no way to distinguish A-bot
from S-bot sessions. If A-bot itself has a session, it would count as "S is busy"
and prevent its own wake-up.

**Fix**: Add `AND agent_type = 'somatic'` filter, or add an `agent_type` column
value that distinguishes A-bot from S-bot sessions.

### 18b. Dual Heartbeat Columns — Ambiguity

The `agent_sessions` table has TWO heartbeat columns:
- `last_heartbeat` (timestamp with time zone)
- `last_heartbeat_at` (timestamp with time zone)

Both are populated. The code uses `last_heartbeat` but it's unclear which column
is the "canonical" heartbeat. If the wrong column is used, idle detection could
be incorrect.

### 18c. `monitor_ai.gleam` INSERT Uses Wrong Column Name `type` vs `issue_type`

```gleam
// monitor_ai.gleam:561
INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment)
```

The `issues` table has `issue_type`, NOT `type`. This INSERT will FAIL with:
`ERROR: column "type" does not exist`.

**Verified**: `SELECT column_name FROM information_schema.columns WHERE table_name = 'issues'`
shows `issue_type` at ordinal position 4, no column named `type`.

### 18d. `learning.gleam` Uses `source='learn'` Not in Audit Trigger Allowed Sources

```gleam
// learning.gleam
INSERT INTO memory (content, tags, source, importance, agent_id)
VALUES ($1, $2, 'learn', $3, $4)
```

The `audit_direct_insert` trigger on the `memory` table validates `source` against
an allowed list. If `'learn'` is not in the allowed sources, the INSERT will be
blocked or flagged. This needs verification against the trigger definition.

---

## 19. SQL INJECTION ANALYSIS

### 19a. `tool_commit.gleam` Shell Injection (Low Severity)

```gleam
// tool_commit.gleam:10-16
fn shell_escape(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("$", "\\$")
  |> string.replace("`", "\\`")
}
```

Missing escapes:
- Newlines (`\n`) — could break the `git commit -m "..."` command
- Single quotes (safe since message is in double quotes)

**Impact**: Low — commit messages come from Pi agent, not directly from user input.
But a multi-line commit message could cause unexpected behavior.

### 19b. All SQL Queries Use Parameterized Queries ✅

All database queries use `$1`, `$2`, etc. with `dynamic.string()` for values.
No SQL injection vectors found in database code.

---

## 20. MISSING NOT NULL COLUMNS IN INSERTS

### 20a. `areflect.gleam:save_issue()` — Missing `project_id` (NOT NULL, no default)

```gleam
// areflect.gleam:228
INSERT INTO issues (title, description, severity, created_by)
VALUES ($1, $2, 'medium', $3)
```

The `issues` table has `project_id` as NOT NULL with NO default value.
This INSERT will FAIL with: `ERROR: null value in column "project_id" violates not-null constraint`.

**Verified**: `SELECT is_nullable, column_default FROM information_schema.columns
WHERE table_name = 'issues' AND column_name = 'project_id'` returns `NO, null`.

### 20b. `monitor_ai.gleam:auto_file_issue()` — Missing `project_id` (NOT NULL, no default)

Same issue as 20a — the INSERT doesn't include `project_id`, which is NOT NULL.
Additionally uses wrong column name `type` instead of `issue_type` (see Section 18c).

### 20c. `areflect.gleam:save_task()` — Missing `project_id` (has default, works)

```gleam
// areflect.gleam:253
INSERT INTO tasks (title, description, priority, created_by)
VALUES ($1, $2, 5, $3)
```

The `tasks` table has `project_id` as NOT NULL BUT with a default value
(`'0d324e68-b399-4b85-bd8a-6b1ef7b46168'::uuid`). This INSERT works but uses
the hardcoded default instead of the current project's ID. Inconsistent with
`task.gleam:123` which explicitly passes `project_id`.

---

## 21. FRAGILE JSON PARSING IN `hook_on_tool_result.gleam`

```gleam
// hook_on_tool_result.gleam:8-13
let is_error =
  string.contains(result_json, "\"error\"")
  || string.contains(result_json, "Error:")
  || string.contains(result_json, "execution error")
  || string.contains(result_json, "tool_execution_blocked")
  || string.contains(result_json, "\"is_error\":true")
```

This uses `string.contains` to detect errors in JSON. Problems:
- **False positives**: Any tool result containing the word "Error:" in its data (e.g., a task about "Error Handling") triggers the error path.
- **False negatives**: Error responses with non-standard formats are missed.
- **`extract_error_msg`** uses `string.split(json, "\"error\"")` which is extremely fragile — it breaks on nested JSON, escaped quotes, or any response where `"error"` appears in data.

Should use proper JSON decoding via `gleam/json` instead of string matching.

---

## 22. INTER-REVIEW COMMIT FLOW IS PERMANENTLY STUCK

### The Flow (as designed)

1. S-bot calls `psypi-commit` (no review_id) → `tool_commit.trigger_review()`
2. `trigger_review()` calls `inter_review.request_review()` → creates `inter_reviews` row with `status='pending'`, `overall_score=NULL`
3. S-bot gets review_id, told to call `psypi-commit` again with it
4. A-bot should review the code and set `overall_score`
5. S-bot calls `psypi-commit` with review_id → `commit_if_reviewed()` checks `overall_score >= 50` → git commit

### Where It Breaks

**Step 4 never happens.** The A-bot's `agent_end` hook runs `a_orchestrator.run_a_workflow()` which:
- Reads soul, jobs, project state from DB
- Calls `call_monitor()` (LLM) to get a response
- Sends the response as `pi_send_message(pi, "autonomic-wakeup", response, "persistent")`

The A-bot's response is sent as a Pi message to S-bot. **It is NEVER written back to the `inter_reviews` table.**
The `overall_score` stays NULL forever.

`monitor_ai.gleam:300` defines `record_review_score()` but **it is never called by anyone**.

### Evidence

```sql
SELECT id, status, overall_score, summary FROM inter_reviews ORDER BY requested_at DESC LIMIT 10;
-- Result: 2 rows, BOTH status='pending', BOTH overall_score=NULL, BOTH summary=NULL
```

**The inter-review system has NEVER completed a review. Every commit attempt is permanently stuck.**

### The `before_agent_start` Hook Also Breaks

In the generated `extension.js:131-133`:
```javascript
if (r.ok) { return { systemPrompt: r.value }; }
else { ctx.ui.notify('Hook before_agent_start failed: ' + r.error, 'error'); }
await event_hooks_record_trigger('before_agent_start');
```

The `return` on success exits BEFORE `event_hooks_record_trigger` is called.
So the `before_agent_start` event is never recorded in the database when it succeeds.

---

## 23. AGENT SESSIONS SYSTEM IS NON-FUNCTIONAL

### No Code Creates or Maintains Sessions

The `agent_sessions` table is referenced by `a_db_reader.is_s_still_idle()` but:
- **No Gleam code INSERTs into `agent_sessions`**
- **No code updates `last_heartbeat`**
- **No code sets `ended_at` or `status='dead'`**

The 19 existing rows were all created on 2026-05-07 (19 days ago) with `agent_type='psypi'` and `status='alive'`.
None have been updated since.

### `is_s_still_idle()` Always Returns True

```sql
SELECT COUNT(*) as cnt FROM agent_sessions
WHERE status = 'alive' AND last_heartbeat > NOW() - INTERVAL '5 minutes'
```
[Comment by user: this is stupid bug! ctx call is the single source of truth, but stupid AI wrote stupid query in database! SHAME!]

Since no code updates heartbeats, this query ALWAYS returns `cnt=0`, so `is_s_still_idle()` ALWAYS returns `Ok(True)`.

**Impact**: The A-bot can NEVER detect that S is busy. It will always attempt to wake up,
even if S is actively working. The debounce timer is the only thing preventing constant wake-ups.

### `agent_type` Mismatch

The `agent_sessions.agent_type` column stores `'psypi'`, not `'A'` or `'S'`.
Even if someone added a filter like `WHERE agent_type = 'S'`, it would match zero rows.

### Schema Drift: Migration vs Live Table

| Migration 013                         | Live Table                                                     |
| ------------------------------------- | -------------------------------------------------------------- |
| `agent_id TEXT NOT NULL`              | `identity_id VARCHAR(100)` + `agent_type VARCHAR(50) NOT NULL` |
| 5 columns                             | 11 columns                                                     |
| status CHECK: `'alive','dead','idle'` | status CHECK: `'alive','dead','sleeping'`                      |
| No FK                                 | FK to `agent_identities(id)` and `tasks(id)`                   |
| 2 indexes                             | 6 indexes                                                      |

The migration is completely out of sync with the live table. A fresh deployment would create the wrong schema.

### Duplicate Heartbeat Columns

Both `last_heartbeat` and `last_heartbeat_at` exist with identical values.
No code references `last_heartbeat_at`. Likely added by an AI that didn't check existing columns.

---

## 24. A-BOT WAKE-UP LOGIC HAS NO GUARD AGAINST S-BUSY

The full wake-up chain:

```
agent_end (Pi event)
  → debounce (5 min timeout)
    → hook_on_agent_end.on_agent_end(ctx, pi)
      → check ctx_is_idle() and ctx_has_pending_messages()
        → check_idle_since() — in-memory config store
          → coordinate_with_s()
            → a_db_reader.is_s_still_idle() — ALWAYS returns True (see §23)
              → a_orchestrator.run_a_workflow()
                → call_monitor() — LLM call
                  → pi_send_message("autonomic-wakeup", response)
```

### Problems

1. **`is_s_still_idle()` is useless** — always returns True (see §23)
2. **`ctx_is_idle()` is the only real guard** — but it only checks the CURRENT Pi session's idle state,
   not whether S-bot in another session is busy
3. **No inter-session coordination** — if S-bot is busy in another terminal, A-bot has no way to know
4. **Debounce is per-process** — `_debounceTimerId` is a JS variable, lost on restart
5. **`idle_since` is in-memory** — `get_config/set_config` use `_configStore` object, lost on restart

### The A-Bot Can Wake Up While S Is Working

If S-bot is actively processing a tool call, `ctx_is_idle()` returns False and the wake-up is aborted.
But if S-bot just finished a tool call and is waiting for the LLM response (between turns),
`ctx_is_idle()` returns True and A-bot will send a wake-up message, interrupting S's workflow.

---

## 25. EXTENSION GENERATION: PI SDK API MISMATCHES

### 25a. `tool_result` Hook Reads Non-Existent `event.result`

In `extension_generator.gleam`, the `tool_result` hook passes:
```javascript
from_param("JSON.stringify(event.result || '')")
```

But the Pi SDK's `ToolResultEvent` has NO `result` property. It has:
- `content: (TextContent | ImageContent)[]` — the actual result content
- `isError: boolean` — whether the result is an error
- `input: Record<string, unknown>` — the original tool input

So `event.result` is always `undefined`. `JSON.stringify(undefined || '')` produces `"''"`.
The `hook_on_tool_result.on_tool_result()` receives garbage JSON instead of the actual tool result.

This means **all error detection in `hook_on_tool_result` is broken** — it's checking string patterns
in `"''"` instead of the actual tool result content.

### 25b. `tool_call` Hook Assumes `event.input.path`

```javascript
from_param("event.input ? (event.input.path || event.input.filePath || '') : ''")
```

For `CustomToolCallEvent`, `input` is `Record<string, unknown>`. Most psypi tools don't have
a `path` or `filePath` parameter. This always returns `''` for psypi tools, making the
file path tracking useless.

### 25c. Missing `label` Field in Tool Registrations

The Pi SDK's `ToolDefinition` requires a `label` field:
```typescript
interface ToolDefinition {
  name: string;
  label: string;  // Human-readable label for UI
  description: string;
  // ...
}
```

The generated `extension.js` only provides `name`, `description`, `parameters`, `execute`.
Missing `label` means the TUI shows the tool name as-is (e.g., "psypi-task-add") instead
of a human-readable label.

### 25d. Missing `details` Field in Tool Results

The Pi SDK's `AgentToolResult` requires:
```typescript
interface AgentToolResult<T> {
  content: (TextContent | ImageContent)[];
  details: T;  // NOT optional
  terminate?: boolean;
}
```

The generated code returns `{ content: [...] }` without `details`.
Since this is plain JS (not TypeScript), it won't crash but `details` will be `undefined`.
Pi's built-in tools use `details` for truncation info, diffs, etc.

### 25e. `before_agent_start` Return Value — Partially Correct

The hook returns `{ systemPrompt: r.value }` which matches `BeforeAgentStartEventResult`.
However, the `BeforeAgentStartEvent` also provides `event.prompt`, `event.systemPrompt`,
and `event.systemPromptOptions` — none of which are used by the psypi hook.

### 25f. `session_start` Hook — `ctx.model` May Not Exist

```javascript
event_hook("session_start", "monitor", "record_current_model", [from_param("ctx.model")], ...)
```

The `SessionStartEvent` type doesn't have a `model` property. It has:
```typescript
interface SessionStartEvent { type: "session_start"; }
```

`ctx.model` is on `ExtensionContext`, not the event. This might work if `ctx` has a `model`
property, but the Pi SDK's `ExtensionContext` doesn't define one.

---

## 26. FFI BRIDGE: GLEAM → .MJS → NODE.JS

### 26a. `gleamValueToJson` Type Detection Failure (CONFIRMED)

In `pi_extension_ffi.mjs`:
```javascript
export function gleamValueToJson(val) {
  const name = val.constructor.name;
  if (name.startsWith('Task$Task') || name.startsWith('Issue$Issue') || ...) {
    return Object.fromEntries(Object.entries(val).map(([k, v]) => [k, gleamValueToJson(v)]));
  }
}
```

Compiled Gleam classes have names like `Task`, NOT `Task$Task`. The `startsWith('X$X')` pattern
never matches. This means ALL custom Gleam types are serialized as `[object Object]` or similar
instead of proper JSON.

**Impact**: Every tool that uses `raw_json()` result format (which calls `gleamValueToJson`)
produces broken JSON output. Tools affected: `psypi-consult-autonomic`, `psypi-commit`,
and any tool returning `raw_json()`.

### 26b. `unwrapGleamResult` — Correct but Fragile

```javascript
export function unwrap_gleam_result(result) {
  if (result instanceof Ok) return { ok: true, value: result[0] };
  if (result instanceof Error) return { ok: false, error: result[0] };
  return { ok: false, error: 'Not a Gleam Result: ' + String(result) };
}
```

This works because `Ok` and `Error` are the actual Gleam class names for Result variants.
But it depends on the compiled JS output format, which could change between Gleam versions.

### 26c. `call_monitor` — LLM Call Without Error Recovery

```javascript
export async function call_monitor(prompt) {
  const response = await openai.chat.completions.create({
    model: 'claude-sonnet-4-20250514',
    messages: [{ role: 'user', content: prompt }],
    max_tokens: 4096,
  });
  return response.choices[0].message.content;
}
```

- No API key validation — will throw cryptic error if `OPENAI_API_KEY` not set
- No retry logic — single failure kills the A-bot workflow
- Hardcoded model — should use the model from `provider_api_keys` table
- Uses `openai` client but calls Claude model — relies on OpenAI-compatible API proxy
- No timeout — can hang indefinitely if API is slow

### 26d. `pi_send_message` — Message Format Mismatch

```javascript
export async function pi_send_message(pi, customType, content, display) {
  pi.sendMessage({ customType, content, display });
}
```

The Pi SDK's `sendMessage` expects:
```typescript
sendMessage(message: { customType: string; content: string; display?: string; details?: unknown }, options?: SendMessageOptions): void;
```

This appears correct, but `content` is always a string. If the A-bot's LLM response contains
structured data, it's flattened to a string, losing structure.

---

## 27. EVENT HOOK REGISTRATION AND FIRING

### 27a. `event_hooks_record_trigger` — Dead Code Path in `before_agent_start`

In the generated extension.js for `PiSystemPromptHook`:
```javascript
pi.on('before_agent_start', async (event, ctx) => {
  try {
    const result = await hook_on_before_agent_start_on_before_agent_start();
    const r = unwrapGleamResult(result);
    if (r.ok) { return { systemPrompt: r.value }; }  // ← EXITS HERE
    else { ctx.ui.notify('Hook before_agent_start failed: ' + r.error, 'error'); }
    await event_hooks_record_trigger('before_agent_start');  // ← NEVER REACHED
  } catch(e) { ... }
});
```

The `return` on success exits the function before `event_hooks_record_trigger` is called.
This means successful `before_agent_start` hooks are never recorded.

### 27b. Event Hook Record — What Is It Good For?

The `event_hooks_record_trigger` function writes to `psypi_event_hooks` table.
Let me check if anyone reads this data:

**Finding**: No Gleam code reads from `psypi_event_hooks`. The table is written to but never queried.
It's a write-only log with no consumers.

### 27c. Debounce State Lost on Restart

The `agent_end` debounced hook uses:
```javascript
let _debounceTimerId = null;
```

This is a module-level JS variable. When the Pi process restarts, this variable is reset.
If a debounce timer was pending, it's lost. The A-bot will NOT wake up after a restart
even if the debounce period has long passed.

### 27d. `_configStore` — In-Memory Only

The `get_config`/`set_config` functions in `pi_extension_ffi.mjs` use:
```javascript
const _configStore = {};
```

All config values (including `idle_since`) are lost on restart. The `check_idle_since()`
logic in `hook_on_agent_end.gleam` relies on this in-memory store, so after a restart
the A-bot has no memory of when S went idle.

---

## 28. SEED/BOOTSTRAP PROCESS

### 28a. What State Is Required for First Run?

The `seed.gleam` module populates initial data. It only seeds 3 tables:
1. `agent_souls` — A-bot and S-bot soul definitions
2. `psypi_config` — monitor_debounce_ms (300000) and last_wakeup
3. `agent_prefixes` — A, S, G prefix definitions [Comment by user: this requires an adjustment in id structure when working in a dir that is not a repo, it should now be disigned as A-G-other parts, S-G-other parts, so as to let the two bots work properly in this situation]

### 28b. Missing Seed Data — `projects` Table

The `projects` table has 1 row with the hardcoded UUID `0d324e68-b399-4b85-bd8a-6b1ef7b46168`.
This row was inserted manually — the seed doesn't create it.

**Impact**: On a fresh deployment, `db.gleam:connect()` sets `app.current_project_id` to the
hardcoded UUID, but the `projects` table is empty. Any query that JOINs on `projects` will fail.
Any FK constraint referencing `projects.id` will fail.

### 28c. Missing Seed Data — `agent_identities` Table

The `agent_identities` table is referenced by `agents.gleam` and has FK constraints from
`agent_sessions.identity_id`. The seed doesn't populate it.

### 28d. Missing Seed Data — `provider_api_keys` Table

The `call_monitor` function in `pi_extension_ffi.mjs` needs an API key to call the LLM.
The `provider_api_keys` table should store this, but the seed doesn't populate it.
The code falls back to `OPENAI_API_KEY` env var, but this is not documented.

### 28e. Migration Drift Makes Fresh Deployment Impossible

Multiple migrations are out of sync with the live table schema:
- `013_agent_sessions.sql`: 5 columns vs live 11 columns
- `016_learning_insights.sql`: 6 columns vs live 13 columns
- `025_add_tasks_project_id.sql`: hardcodes UUID as default

A fresh `make setup && make migrate && make seed` would create the WRONG schema.
The system CANNOT be deployed from scratch.

---

## 29. PROJECT_ID LIFECYCLE — HARD-CODED AND NEVER DYNAMIC

### 29a. The Hardcoded UUID

The UUID `0d324e68-b399-4b85-bd8a-6b1ef7b46168` appears in 6 Gleam source files:
- `db.gleam:38` — fallback when `PSYPI_PROJECT_ID` env var is empty
- `task.gleam:283` — default in `psypi-task-add` tool
- `issue_db.gleam:215` — default when no project_id filter provided
- `issue_db.gleam:273` — used in `resolve_issue`
- `issue_db.gleam:304` — used in `update_issue_status`
- `issue_tools.gleam:24` — default in `psypi-issue-add` tool

### 29b. The Dynamic Lookup Plan (UNIMPLEMENTED)

`docs/PLAN-project-id-lookup.md` describes a plan to look up `project_id` dynamically
using `(path, git_remote)`. This plan has NOT been implemented.

### 29c. `app.current_project_id` Session Variable

`db.gleam:connect()` sets `SET app.current_project_id = $1` on every connection.
But this is a PostgreSQL session variable — it only lasts for the current connection.
Since `db.with_connection()` creates a new connection for each query, the variable is
set and then the connection is closed. **No other query can see this variable.**

The `app.current_project_id` is useless because each `with_connection` call creates
a fresh connection, sets the variable, runs one query, and disconnects.

### 29d. Who Reads `app.current_project_id`?

Let me check if any RLS policy or SQL function uses it:

**Finding**: No RLS policies reference `app.current_project_id`. No SQL functions use it.
The session variable is set but never read by anything. It's dead code.

---

## 30. MEMORY MODULE — SAVE ALWAYS FAILS, SEARCH PARTIALLY BROKEN

### 30a. `memory.gleam:save()` — Decoder Mismatch

```gleam
let sql = "INSERT INTO memory (...) VALUES (...) RETURNING id"
// ...
case decode.run(row, memory_decoder()) {
```

`RETURNING id` returns 1 column. `memory_decoder()` expects 7 fields.
The decode ALWAYS fails with `DecodeError("Failed to decode memory")`.

The save function returns `Error(DecodeError(...))` on every call, even though the
INSERT succeeds and the row is written to the database.

### 30b. `memory.gleam:search()` — `SELECT *` Returns 14 Columns, Decoder Expects 7

The `memory` table has 14 columns. `SELECT *` returns all 14.
`memory_decoder()` only decodes 7. The extra columns cause `decode.run` to fail
because `decode.field` doesn't find expected fields in the right positions.

Additionally, `created_at` is `timestamptz` — needs `::text` cast for `decode.string`.

### 30c. `tags` Column Type Mismatch

The `tags` column is PostgreSQL `ARRAY` type. The `format_pg_array` function creates
a string like `{tag1,tag2}`. But `dynamic.string()` sends a text parameter, not an array.
PostgreSQL may auto-cast, but the decoder uses `decode.list(decode.string)` which
expects a JavaScript array, not a PostgreSQL array string.

---

## 31. AREFLECT MODULE — MULTIPLE INSERT FAILURES

### 31a. `save_issue()` — Missing `project_id` (NOT NULL)

```gleam
INSERT INTO issues (title, description, severity, created_by)
VALUES ($1, $2, 'medium', $3)
```

The `issues` table has `project_id` as NOT NULL with no default. This INSERT will fail.

### 31b. `save_task()` — Missing `project_id` (NOT NULL with default)

```gleam
INSERT INTO tasks (title, description, priority, created_by)
VALUES ($1, $2, 5, $3)
```

The `tasks` table has `project_id` with default `'0d324e68-b399-4b85-bd8a-6b1ef7b46168'`
(from migration 025). This INSERT will succeed but uses the default, not the session variable.

### 31c. `save_learning()` — Missing `project_id` (nullable, OK)

The `learning_insights.project_id` is nullable, so the INSERT succeeds without it.
But the data is not associated with any project.

---

## 32. MONITOR_AI MODULE — `auto_file_issue()` HAS 3 BUGS

```gleam
INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment)
VALUES ($1, $2, 'high', 'bug', 'monitor', 'monitor', 'development')
RETURNING id
```

1. **Column `type` doesn't exist** — the actual column is `issue_type`. This INSERT will fail
   with: `ERROR: column "type" does not exist`
2. **Missing `project_id`** — NOT NULL, no default. This INSERT will fail.
3. **`discovered_by` and `environment` exist** — these are valid columns.

So `auto_file_issue()` will ALWAYS fail with a SQL error. The monitor can never auto-file issues.

---

## 33. SKILL MODULE — MISSING `AiBuilt` VARIANT AND JSONB DECODE

### 33a. `SkillSource` Missing `AiBuilt` Variant

The `skill.gleam` `SkillSource` type has variants: `Human`, `Ai`, `Learned`.
But the database contains `source='ai-built'`. The `string_to_source` function
will return `Error("Unknown skill source: ai-built")`.

### 33b. JSONB Columns Without `::text` Cast

`skill.gleam` reads `content` and `reference_list` from the `skills` table.
Both are JSONB columns. Without `::text` cast, the pg driver returns JavaScript
objects, which `decode.string` cannot parse.

---

## 34. BROADCAST MODULE — `project_id` NOT PROPAGATED

In `broadcast.gleam:send_broadcast()`, the `project_id` parameter is required
but the tool registration provides a fallback:

```gleam
from_param("params.project_id || \"\"")
```

If `project_id` is empty string, the INSERT will fail because `project_communications.project_id`
is NOT NULL. The tool should default to the current project ID, not empty string.

---

## 35. FULL LIST OF TABLES WITH SCHEMA DRIFT (Migration ≠ Live)

| Table             | Migration Cols | Live Cols | Drift                          |
| ----------------- | -------------- | --------- | ------------------------------ |
| agent_sessions    | 5              | 11        | +6 cols, different constraints |
| learning_insights | 6              | 13        | +7 cols                        |
| memory            | (unknown)      | 14        | migration missing?             |
| inter_reviews     | (unknown)      | 27        | migration missing?             |
| issues            | (unknown)      | 14+       | migration missing?             |

Every table that was altered after initial creation has drift.
The migrations only represent the INITIAL schema, not the current state.

---

## 36. `app.current_project_id` IS DEAD CODE

`db.gleam:connect()` executes `SET app.current_project_id = $1` on every new connection.
But `db.with_connection()` creates a new connection per query, so:

1. Connection opens
2. `SET app.current_project_id = '0d324e68-...'` runs
3. The actual query runs
4. Connection closes

No other connection can see this session variable. No RLS policy references it.
No SQL function reads it. It's set and immediately discarded.

**Impact**: If RLS policies were added to enforce project isolation, they would not work
because the session variable is never visible to any query except the `SET` itself.

---

## 37. DUAL DEBOUNCE — IN-MEMORY VS DATABASE CONFIG SYSTEMS

### 37a. Two Independent Debounce Mechanisms

The `agent_end` hook has TWO debounce checks that operate independently:

1. **Pi SDK debounced hook** (`extension_generator.gleam:151`): Reads `psypi_config.get_debounce_ms()`
   from the DATABASE to set the `setTimeout` delay before calling `on_agent_end`.

2. **`hook_on_agent_end.gleam:check_idle_since()`**: Reads `get_config("monitor_debounce_ms")`
   from the IN-MEMORY `_configStore` in `pi_extension_ffi.mjs` to check elapsed idle time.

These are TWO COMPLETELY DIFFERENT CONFIG SYSTEMS:
- `psypi_config.gleam` → PostgreSQL `psypi_config` table (persistent, seeded with `300000`)
- `pi_extension_ffi.mjs._configStore` → JavaScript `let _configStore = {}` (volatile, empty on restart)

### 37b. What Happens in Practice

1. Pi SDK sets `setTimeout(300000ms)` using the DATABASE value (correct)
2. After 5 minutes, `on_agent_end` fires
3. `check_idle_since` reads `get_config("monitor_debounce_ms")` from IN-MEMORY store
4. In-memory store is EMPTY → falls to `option.None` branch → uses hardcoded default `300000`
5. `get_config("idle_since")` is also from in-memory store → `option.None` → records `now_ms()`
6. First fire: records `idle_since`, returns (debounce NOT satisfied because just recorded)
7. Next fire: checks elapsed against `300000` → if ≥5 min, proceeds

**Result**: The A-bot requires TWO consecutive `agent_end` fires separated by 5 minutes
before it will actually wake up. This means the minimum idle time before A-bot activation
is ~10 minutes (5 min for Pi SDK debounce + 5 min for in-memory debounce), not 5 minutes
as intended.

### 37c. Config Lost on Restart

The in-memory `_configStore` is reset to `{}` on every Pi restart.
After restart, `idle_since` is lost, so the debounce timer resets.
If S was idle for 4 minutes before restart, the 4 minutes of idle time is lost.

---

## 38. HOOK_ON_BEFORE_AGENT_START — SOUL LOAD SILENTLY FALLS BACK

```gleam
case soul_result {
  Ok(soul_content) -> promise.resolve(Ok(soul_content))
  Error(e) ->
    promise.resolve(Ok(
      "You are the Somatic Agentbot (S-agentbot). Your ID starts with S-. ..."
      <> "[SOUL LOAD FAILED: " <> e <> "]",
    ))
}
```

When the soul read fails, the hook returns `Ok(...)` with a hardcoded fallback soul.
This means S-bot silently operates with a generic soul instead of its configured one.
No error is surfaced to the user or logged anywhere except the system prompt itself.

**Impact**: If `agent_souls` table is empty or the query fails, S-bot still starts
with a hardcoded soul. The user has no way to know the soul wasn't loaded from DB
unless they read the raw system prompt.

---

## 39. HOOK_ON_TOOL_CALL — ONLY HANDLES "edit" TOOL

```gleam
case tool_name == "edit" {
  False -> promise.resolve(Ok(Nil))
  True -> { ... }
}
```

The auto-backup only fires for the `edit` tool. Other file-modifying tools
(e.g., `write`, `replace`, `insert`) are NOT backed up. If S-bot uses `write`
to modify a file, no version is saved to `code_versions`.

---

## 40. HOOK_ON_TOOL_RESULT — FRAGILE ERROR DETECTION

```gleam
let is_error =
  string.contains(result_json, "\"error\"")
  || string.contains(result_json, "Error:")
  || string.contains(result_json, "execution error")
  || string.contains(result_json, "tool_execution_blocked")
  || string.contains(result_json, "\"is_error\":true")
```

This uses string matching on JSON to detect errors. Problems:
1. A successful result containing the word "Error" in content triggers false positive
2. The `result_json` is `JSON.stringify(event.content)` (from extension.js), but the
   Pi SDK `ToolResultEvent` has `content` as an array of content blocks, not a string
3. `pi_send_message(pi, "autonomic-error", ...)` sends error to S-bot, but A-bot
   never receives it — the `autonomic-error` message type is not handled by A-bot

---

## 41. A_ORCHESTRATOR — INTER-REVIEW RESPONSE NEVER WRITTEN TO DB

### 41a. The Complete A-bot Workflow

```
1. agent_end hook fires (after debounce)
2. hook_on_agent_end → coordinate_with_s → coordinate_when_idle
3. a_orchestrator.run_a_workflow()
4. read_soul_from_db() → get A-bot soul
5. read_a_jobs_from_db() → get A-bot jobs
6. read_project_state_from_db() → get tasks + issues
7. build_system_prompt() → compose soul + jobs + inter-review instructions
8. build_user_prompt() → include S-bot conversation + project state
9. call_monitor(ctx, user_prompt, system_prompt) → call LLM
10. handle_monitor_response() → check if S is still idle
11. pi_send_message(pi, "autonomic-wakeup", response, "persistent")
```

### 41b. The Missing Step

After step 11, the A-bot's response is sent as a Pi message to S-bot.
**It is NEVER written back to the `inter_reviews` table.**

The `monitor_ai.gleam:record_review_score()` function exists to write the score:
```gleam
pub fn record_review_score(review_id: String, score: Int) -> ...
```

But **this function is never called by anyone**. The A-bot's LLM response
is a free-form text message. There is no code to:
1. Parse the LLM response for a review score
2. Find the pending `inter_reviews` row
3. Write the score and summary back to the database

### 41c. Consequence

The `inter_reviews` table has 2 rows, BOTH with `status='pending'` and `overall_score=NULL`.
The commit flow is permanently stuck at step 3 (waiting for review score).

---

## 42. A_DB_READER — IS_S_STILL_IDLE COUNTS ALL SESSIONS

```gleam
let sql =
  "SELECT COUNT(*) as cnt FROM agent_sessions "
  <> "WHERE status = 'alive' AND last_heartbeat > NOW() - INTERVAL '5 minutes'"
```

No `agent_type` filter. This counts ALL alive sessions, including A-bot's own session.
If A-bot has an active session (which it does during the wake-up check), the count
will be ≥1, and `is_s_still_idle()` returns `Ok(False)` — meaning S appears busy.

**Impact**: The A-bot's own session makes S appear non-idle, preventing A-bot wake-up.
This is a race condition: A-bot's session must expire before the idle check runs.

Additionally, on decode error, the function returns `Ok(True)` (assumes idle),
which could cause inappropriate wake-ups.

---

## 43. BROADCAST MODULE — STATS() USES NON-EXISTENT COLUMNS

```gleam
SELECT
  COUNT(*) as total,
  COUNT(*) FILTER (WHERE status = 'sent') as sent_count,
  COUNT(*) FILTER (WHERE priority >= 2) as high_priority_count
FROM project_communications
WHERE from_ai = $1 AND message_type = 'broadcast'
```

1. **`status` column doesn't exist** in `project_communications` — SQL will fail
2. **`priority >= 2`** — `priority` is `text` type (`'low'`, `'normal'`, `'high'`, `'critical'`),
   comparing text to integer will fail or give wrong results
3. **`list()` hardcodes `status` as `'sent'`** — the actual broadcast status is lost

### 43b. BROADCAST LIST() — SEMANTIC MISMATCH

```sql
SELECT id, from_ai as agent_id, content as message, priority,
       'sent' as status, created_at::text, read_at::text as sent_at
FROM project_communications
```

- `read_at::text as sent_at` — `read_at` is when the message was READ, not SENT
- `'sent' as status` — hardcoded, actual status is unknown
- No `project_id` filter — returns broadcasts from ALL projects

---

## 44. SKILL MODULE — INCONSISTENT `::text` CASTS AND MISSING VARIANT

### 44a. `list()` has `::text` casts, `get()` and `search()` don't

```gleam
// list() — CORRECT
"SELECT id, name, description, source, status, safety_score, version, author,
        created_at::text, content::text, reference_list::text FROM skills"

// get() — MISSING casts on content, reference_list
"SELECT id, name, description, source, status, safety_score, version, author,
        created_at::text, content, reference_list FROM skills"

// search() — MISSING casts on content, reference_list
"SELECT id, name, description, source, status, safety_score, version, author,
        created_at::text, content, reference_list FROM skills"
```

`content` and `reference_list` are JSONB columns. Without `::text` cast,
the pg driver returns JavaScript objects, which `decode.string` cannot parse.
`get()` and `search()` will fail when these columns contain non-null data.

### 44b. `SkillSource` Missing `AiBuilt` Variant

Database has `source='ai-built'` but Gleam type only has: `Clawhub`, `Local`, `Generated`, `Imported`.
The `Generated` variant maps to `"generated"` which doesn't exist in the database.
The `AiBuilt` variant for `"ai-built"` is missing.

`skill.list()` will fail with `DecodeError("Unknown skill source: ai-built")` for
every row with `source='ai-built'`.

### 44c. `skill.create()` — Missing Columns

```gleam
INSERT INTO skills (name, description, status, safety_score, author)
VALUES ($1, $2, 'pending', 0, $3)
```

The `skills` table has 56 columns. This INSERT only provides 5. Missing NOT NULL columns:
- `source` (NOT NULL) — INSERT will fail
- `version` (NOT NULL) — INSERT will fail

---

## 45. INTER_REVIEW MODULE — MISSING `::text` CASTS AND TYPE MISMATCH

### 45a. `get_review_details()` — Missing `::text` on `requested_at`

```gleam
"SELECT id, task_id, status, summary, overall_score, requested_at
 FROM inter_reviews WHERE id = $1"
```

`requested_at` is `timestamptz`. Without `::text`, the pg driver returns a Date object,
which `decode.string` cannot parse. This query will always fail with a decode error.

### 45b. `list_reviews()` — Same Missing `::text` on `requested_at`

Both the filtered and unfiltered queries miss the `::text` cast.

### 45c. `request_review()` — Parameter Type Mismatch

The SQL function `request_inter_review` expects `(uuid, text, text, text, jsonb)`.
The Gleam code passes:
- `$1 = task_id` as `dynamic.string()` or `dynamic.nil()` — should be UUID
- `$5 = context_json` as `dynamic.string()` — should be JSONB

The pg driver may auto-cast, but this is fragile and depends on driver behavior.

---

## 46. AREFLECT MODULE — COMPREHENSIVE INSERT FAILURES

### 46a. `save_issue()` — Missing `project_id` AND `issue_type`

```gleam
INSERT INTO issues (title, description, severity, created_by)
VALUES ($1, $2, 'medium', $3)
```

Two NOT NULL columns missing:
1. `project_id` (NOT NULL, no default) — INSERT will fail
2. `issue_type` (NOT NULL, no default) — INSERT will fail

### 46b. `save_task()` — Missing `project_id`

```gleam
INSERT INTO tasks (title, description, priority, created_by)
VALUES ($1, $2, 5, $3)
```

`project_id` is NOT NULL but has a default from migration 025.
The INSERT will succeed using the default UUID, but the task won't be
associated with the current project if the default is wrong.

### 46c. `save_learning()` — Missing `project_id` (nullable)

```gleam
INSERT INTO learning_insights (insight_type, title, content, confidence)
VALUES ('pattern', $1, $2, 0.8)
```

`project_id` is nullable, so the INSERT succeeds. But the learning is orphaned —
not associated with any project. If project-scoped queries are added later,
these learnings will be invisible.

### 46d. `fetch_recent_issues()` — Missing `::text` on `id`

```gleam
SELECT id, title, status, severity FROM issues ORDER BY ...
```

`id` is UUID type. The decoder uses `decode.string`. Without `::text` cast,
the pg driver may return a different type. This may or may not work depending
on the driver's UUID handling.

---

## 47. MONITOR_AI MODULE — CASE SENSITIVITY AND COLUMN BUGS

### 47a. `get_work_suggestions()` — Wrong Case for Skills Status

```sql
SELECT 'pending_skills' as suggestion_type,
       'Review ' || COUNT(*)::TEXT || ' pending skills' as description, 4 as priority
FROM skills WHERE status = 'PENDING'
```

The `skills` table uses lowercase status values (`pending`, `approved`).
This query uses `PENDING` (uppercase). It will return 0 rows.

Meanwhile, the `tasks` table uses UPPERCASE (`PENDING`, `COMPLETED`), so
`status = 'PENDING'` is correct for tasks but wrong for skills.

### 47b. `get_model_stats()` — Wrong Case for Inter-Review Status

```sql
COUNT(*) FILTER (WHERE status = 'FAILED')::INT as failure_count
FROM inter_reviews
```

The `inter_reviews` table uses lowercase status (`pending`). There are no `FAILED`
rows. The correct value would be lowercase `failed`, but since reviews never complete,
this doesn't matter in practice.

### 47c. `auto_file_issue()` — Wrong Column Name AND Missing NOT NULL

```gleam
INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment)
```

1. `type` → should be `issue_type` (column `type` doesn't exist)
2. Missing `project_id` (NOT NULL, no default)
3. Both bugs cause the INSERT to fail

---

## 48. STATS MODULE — `gleamValueToJson` WON'T SERIALIZE CORRECTLY

```gleam
result_format: template("Tasks:${r.value.tasks} Issues:${r.value.issues} ...")
```

The `Stats` type has fields `tasks`, `issues`, `skills`, `meetings`. But `gleamValueToJson`
doesn't recognize `Stats$Stats` pattern (the compiled class name is just `Stats`, not `Stats$Stats`).
The serialized object will have numeric keys (`0`, `1`, `2`, `3`) instead of named keys
(`tasks`, `issues`, `skills`, `meetings`).

The template `r.value.tasks` will be `undefined` because the serialized object doesn't
have a `.tasks` property.

---

## 49. AGENT_IDENTITY MODULE — SEMANTIC ID PREFIX LOGIC FLAW

```gleam
let prefix = case string.contains(id, "A-") || ctx.is_idle {
  True -> "A"
  False -> "S"
}
```

This determines the agent prefix by checking if the generated ID contains "A-"
OR if the context says the agent is idle. But `ctx.is_idle` is the Pi SDK's
`ctx.isIdle()` which means "the S-bot is currently idle" — it doesn't mean
"this is the A-bot". The A-bot should be identified by its own identity, not
by whether S-bot happens to be idle at the moment.

If S-bot is idle, the identity resolution returns A-bot's soul and jobs.
If S-bot becomes busy mid-session, the identity flips to S-bot's soul and jobs.
This is a fundamental design flaw — agent identity should be stable, not
dependent on S-bot's transient idle state.

---

## 50. LEARNING MODULE — INSERTS INTO `memory` TABLE, NOT `learning_insights`

```gleam
fn save_learning(conn, content, tags, importance, agent_id) {
  let sql = "
    INSERT INTO memory (content, tags, source, importance, agent_id)
    VALUES ($1, $2, 'learn', $3, $4)
  "
```

The `learning.gleam` module inserts into the `memory` table with `source='learn'`.
But `areflect.gleam` inserts into `learning_insights` table. These are TWO DIFFERENT
tables for the same conceptual data. Learnings saved via `psypi-learn-save` go to
`memory`, while learnings from `psypi-areflect` go to `learning_insights`.

Neither module reads from the other's table. Learnings are fragmented across two
tables with no way to search both.

### 50b. `source='learn'` Not in Audit Allowed Sources

The `memory` table has an `audit_direct_insert` trigger that checks `allowed_sources`.
If `'learn'` is not in the allowed sources array, the trigger may reject the INSERT
or log a warning. The `areflect` module uses `source='areflect'` for its memory inserts,
which may also not be in the allowed sources.

---

## 51. TOOL_CONSULT — STUB IMPLEMENTATION, NO ACTUAL A-BOT CONSULTATION

```gleam
pub fn on_consult(question, ctx) {
  notify_info(ctx, "[AUTONOMIC] Consult: " <> user_question)
  promise.resolve(Ok("[Autonomic] Consult request: " <> user_question
    <> "\n\nThe S-worker should address this in its next turn."))
}
```

The `psypi-consult` tool is a stub. It doesn't actually call the A-bot or
consult any database. It just returns a string telling S-bot to figure it out.
The tool is registered and available to the AI but provides no real functionality.

---

## 52. EXTENSION.JS — EVENT HOOK TRIGGER NOT RECORDED ON SUCCESS

In the generated `extension.js`, the `before_agent_start` hook:

```javascript
pi.on('before_agent_start', async (event, ctx) => {
  try {
    const result = await hook_on_before_agent_start();
    const r = unwrapGleamResult(result);
    if (r.ok) { return { systemPrompt: r.value }; }  // <-- EARLY RETURN
    else { ctx.ui.notify('Hook failed: ' + r.error, 'error'); }
    await event_hooks_record_trigger('before_agent_start');  // <-- NEVER REACHED
  } catch(e) { ... }
});
```

The `event_hooks_record_trigger` call is AFTER the `return` statement.
On success, the function returns early and the trigger is never recorded.
The `psypi_event_hooks` table's `trigger_count` and `last_triggered` columns
will never be updated for `before_agent_start`.

---

## 53. FULL LIST OF MODULES WITH CONFIRMED BUGS

| Module                    | Bug Count | Critical Bugs                                                                                                                  |
| ------------------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------ |
| memory.gleam              | 3         | save() ALWAYS fails (decoder mismatch), search() broken, tags type mismatch                                                    |
| areflect.gleam            | 3         | save_issue() fails (missing project_id + issue_type), save_task() missing project_id, save_learning() orphaned                 |
| monitor_ai.gleam          | 4         | auto_file_issue() fails (wrong column + missing project_id), case sensitivity in get_work_suggestions, case in get_model_stats |
| skill.gleam               | 3         | Missing AiBuilt variant, missing ::text casts in get()/search(), create() missing NOT NULL columns                             |
| inter_review.gleam        | 2         | Missing ::text on requested_at, parameter type mismatch in request_review()                                                    |
| broadcast.gleam           | 3         | stats() uses non-existent status column, priority>=2 on text, list() hardcodes status                                          |
| a_db_reader.gleam         | 2         | is_s_still_idle() counts all sessions (no agent_type filter), assumes idle on decode error                                     |
| hook_on_agent_end.gleam   | 1         | Dual debounce (in-memory vs database config)                                                                                   |
| hook_on_tool_result.gleam | 1         | Fragile string-based error detection                                                                                           |
| agent_identity.gleam      | 1         | Identity prefix depends on S-bot idle state (should be stable)                                                                 |
| stats.gleam               | 1         | gleamValueToJson won't produce named fields for Stats type                                                                     |
| learning.gleam            | 1         | Inserts into memory table instead of learning_insights, different from areflect                                                |
| tool_consult.gleam        | 1         | Stub implementation, no actual A-bot consultation                                                                              |
| extension.js (generated)  | 1         | event_hooks_record_trigger never reached on success                                                                            |
| tool_commit.gleam         | 0         | Logic is correct, but blocked by inter_review never completing                                                                 |

**Total confirmed bugs: 27 across 15 modules**

---

## 54. ARCHITECTURAL ISSUES — SYSTEMIC PROBLEMS

### 54a. No Centralized Schema-to-Gleam Type Mapping

Every module independently defines its own SQL queries and decoders.
There is no single source of truth for table schemas. When a migration
adds a column, no module is updated unless someone remembers to do it.

**Solution direction**: Use Squirrel (type-safe SQL query builder for Gleam)
or generate decoders from migration files.

### 54b. Connection Per Query Pattern

`db.with_connection()` creates a new connection for every query.
This means:
1. No transaction support (can't group multiple queries)
2. No session variables (SET only lasts for one query)
3. High connection overhead
4. No connection pooling

### 54c. No Error Propagation Strategy

Errors are swallowed at every level:
- `hook_on_before_agent_start`: returns Ok with fallback soul on error
- `a_db_reader.is_s_still_idle`: returns Ok(True) on decode error
- `hook_on_tool_result`: returns Ok(Nil) even after sending error message
- `areflect`: silently continues if individual saves fail

### 54d. Two Config Systems That Don't Talk

- `psypi_config.gleam` reads from PostgreSQL
- `pi_extension_ffi.mjs._configStore` is in-memory JavaScript

The debounce logic reads from BOTH systems, creating confusion and
potential for inconsistency.

### 54e. No Integration Tests

Gleam tests validate pure functions but not DB integration or FFI layers.
The system can pass all Gleam tests while being completely broken at runtime.
This is the root cause of "tests pass but system is broken".

---

## 55. FFI BINDING AUDIT — ALL @external FUNCTIONS VERIFIED

### 55a. Summary

| Source File                 | Target FFI               | Functions    | Status                        |
| --------------------------- | ------------------------ | ------------ | ----------------------------- |
| `pi_extension.gleam`        | `pi_extension_ffi.mjs`   | 19 functions | ✅ All exist                   |
| `agent_identity.gleam`      | `agent_identity_ffi.mjs` | 1 function   | ✅ Exists                      |
| `extension_generator.gleam` | `node_ffi.mjs`           | 1 function   | ✅ Exists                      |
| `a_context_utils.gleam`     | `node_ffi.mjs`           | 1 function   | ⚠️ Returns `Ok(Int)` not `Int` |
| `db.gleam`                  | `node_ffi.mjs`           | 2 functions  | ✅ Exist                       |
| `main.gleam`                | `node_ffi.mjs`           | 1 function   | ✅ Exists                      |

### 55b. Duplicate `now_ms` With Different Return Types

Two different `now_ms` FFI functions exist:
- `pi_extension_ffi.mjs:now_ms()` → returns `Date.now()` (raw `Int`)
- `node_ffi.mjs:now_ms()` → returns `new Ok(Date.now())` (Gleam `Ok(Int)`)

Gleam bindings:
- `pi_extension.gleam:63` → `now_ms() -> Int` (uses `pi_extension_ffi.mjs`)
- `a_context_utils.gleam:51` → `now_ms() -> Result(Int, String)` (uses `node_ffi.mjs`)

Both are correct for their respective bindings, but the naming collision is confusing.

### 55c. `pi_send_message` Fourth Parameter Ignored

```javascript
export function pi_send_message(pi, customType, content, display) {
  // display parameter is IGNORED — hardcoded to true
  pi.sendMessage(customType, content, true);
}
```

The Gleam type is `(a, String, String, String) -> Nil`. The `display` parameter
is accepted but never used. The fourth argument is always `"persistent"` in
calling code, but the FFI ignores it.

### 55d. `node_pg` FFI — Well Implemented

The `node_pg` library FFI (`build/packages/node_pg/src/ffi.mjs`) is well-structured:
- Proper Gleam type wrapping (`Ok`, `Error`, `Some`, `None`)
- `listToArray`/`arrayToList` for List conversion
- `mapDatabaseError` for structured error mapping
- `mapQueryResult` for result conversion
- `configToJS` for config translation

No bugs found in the `node_pg` FFI layer.

---

## 56. TASK MODULE — MISSING `::text` ON `id` AND `project_id`

### 56a. `task.gleam:list()` — Missing `::text` on `id`

```sql
SELECT id, title, description, status, priority, result, error, retry_count,
       created_at::text, updated_at::text, completed_at::text, created_by, source,
       project_id::text
FROM tasks
```

`id` is UUID type. The decoder uses `decode.string`. Without `::text` cast,
the pg driver may return a different type. `project_id` has `::text` but `id` doesn't.

### 56b. `task.gleam:get()` — Missing `project_id` and `::text` on `id`

```sql
SELECT id, title, description, status, priority, result, error, retry_count,
       created_at::text, updated_at::text, completed_at::text, created_by, source
FROM tasks
WHERE id = $1
```

Two bugs:
1. `id` is UUID without `::text` cast
2. `project_id` column is NOT SELECTED at all, but `task_decoder()` expects it
   → `decode.field("project_id", ...)` will fail because the field doesn't exist

### 56c. `task.gleam:complete()` — Missing `::text` on `id`

```sql
UPDATE tasks SET status = 'COMPLETED', completed_at = NOW()
WHERE id = $1 RETURNING id
```

`RETURNING id` returns UUID type. `id_decoder()` uses `decode.string`.
Without `::text`, this may fail depending on pg driver UUID handling.

### 56d. `task.gleam:add()` — Missing `::text` on `id`

Same issue as 56c — `RETURNING id` without `::text` cast.

### 56e. `task.gleam:task_add_tool()` — Hardcoded `project_id` Default

```gleam
from_param("params?.project_id || '0d324e68-b399-4b85-bd8a-6b1ef7b46168'")
```

The hardcoded UUID is used as fallback when no `project_id` is provided.

---

## 57. MEETING MODULE — MISSING `::text` CASTS AND `id` TYPE

### 57a. `meeting.gleam:create()` — Missing `::text` on `id`

```sql
INSERT INTO meetings (topic, created_by) VALUES ($1, $2) RETURNING id
```

`id` is UUID. `id_decoder()` uses `decode.string`. Needs `RETURNING id::text`.

### 57b. `meeting.gleam:add_opinion()` — Missing `::text` on `id`

Same issue — `RETURNING id` without `::text` cast.

### 57c. `meeting.gleam:list()` — Missing `::text` on `id`

```sql
SELECT id, topic, created_by, status, created_at::text, consensus_at::text, consensus
```

`id` is UUID without `::text` cast. `consensus` is JSONB without `::text` cast.

### 57d. `meeting.gleam:complete()` — Missing `::text` on `id`

Same `RETURNING id` issue.

### 57e. `meeting.gleam:meeting_say_tool()` — Wrong Parameter Name

```gleam
from_param("params.message || \"\"")
```

The tool accepts `message` but `add_opinion()` expects `perspective` as the 3rd arg.
The mapping sends `params.message` to the `perspective` parameter, which works
semantically but is confusing.

---

## 58. AGENTS MODULE — MISSING `::text` ON `id` AND INCOMPLETE TYPE

### 58a. `agents.gleam:list()` — `id` Without `::text`

```sql
SELECT id, agent_type, created_at::text FROM agent_identities
```

`id` is UUID. Needs `id::text`.

### 58b. `agents.gleam:Agent` Type — Only 3 Fields

```gleam
Agent(id: String, agent_type: String, created_at: String)
```

The `agent_identities` table has many more columns (name, description, capabilities,
default_model, etc.). The `Agent` type is a minimal subset. This is not a bug per se,
but it means the tool returns very limited information.

---

## 59. EVENT_HOOKS MODULE — WELL IMPLEMENTED, MINOR ISSUE

### 59a. `event_hooks.gleam` — Proper `::text` Casts

This module correctly uses `id::text` and `last_triggered::text` in all queries.
It's one of the few modules with correct type handling.

### 59b. Missing `updated_at` Column

The `record_trigger` and `record_error` functions set `updated_at = NOW()`,
but the `psypi_event_hooks` table may not have this column (depends on migration).
If the column doesn't exist, these UPDATEs will fail.

---

## 60. CODE_VERSION MODULE — USES SQL FUNCTIONS, GENERALLY CORRECT

### 60a. `save_version()` — Uses `save_code_version()` SQL Function

```sql
SELECT save_code_version($1::TEXT, $2::TEXT, $3::VARCHAR, $4::VARCHAR, $5::TEXT) as version_id
```

This relies on a PL/pgSQL function `save_code_version`. If the function doesn't exist
or has different parameter types, this will fail. The explicit type casts (`::TEXT`,
`::VARCHAR`) are good practice.

### 60b. `get_versions()` — Returns Raw Dynamic

```gleam
pub fn get_versions(file_path, limit) -> promise.Promise(Result(List(Dynamic), DbError))
```

Returns `List(Dynamic)` instead of a typed result. The caller must decode manually.
This is not a bug but a design choice that sacrifices type safety.

### 60c. `query_versions()` — Missing `::text` on `saved_at`

```sql
SELECT id, file_path, saved_by, saved_at, LEFT(content, 200) as content_preview, ...
```

`saved_at` is `timestamptz` without `::text` cast. If this is used by a decoder,
it will fail. But since the result is `List(Dynamic)`, no decoder is applied.

---

## 61. ISSUE_DB MODULE — HARD-CODED UUID AND MISSING `::text`

### 61a. Hard-Coded UUID in 4 Locations

- `issue_db.gleam:215` — default when no `project_id` filter provided
- `issue_db.gleam:273` — used in `resolve_issue`
- `issue_db.gleam:304` — used in `update_issue_status`
- `issue_tools.gleam:24` — default in `psypi-issue-add` tool

### 61b. `issue_db.gleam:get()` — Missing `::text` on `id`

```sql
SELECT id, title, description, ... FROM issues WHERE id = $1 AND project_id = $2
```

`id` is UUID without `::text` cast.

### 61c. `issue_db.gleam:resolve()` — Missing `::text` on `id`

Same `RETURNING id` issue.

### 61d. `issue_db.gleam:fetch_recent_issues()` — Missing `::text` on `id`

In `areflect.gleam`, the `fetch_recent_issues` function:
```sql
SELECT id, title, status, severity FROM issues ORDER BY ...
```

`id` is UUID without `::text` cast.

---

## 62. A_ORCHESTRATOR — DETAILED WORKFLOW TRACE

### 62a. Complete Data Flow

```
1. hook_on_agent_end fires (after Pi SDK debounce)
2. check_idle_since() checks in-memory config for idle_since timestamp
3. If debounce satisfied → coordinate_with_s()
4. coordinate_with_s() checks ctx_is_idle() AND a_db_reader.is_s_still_idle()
5. If both idle → coordinate_when_idle()
6. coordinate_when_idle() parses context window from usage JSON
7. a_orchestrator.run_a_workflow() starts:
   a. read_soul_from_db() → SELECT role, domain, responsibility FROM agent_souls WHERE id_prefix='A'
   b. read_a_jobs_from_db() → SELECT j.job, j.priority, j.category FROM agent_jobs JOIN agent_souls ...
   c. read_project_state_from_db() → SELECT from tasks + issues
   d. build_system_prompt() → compose soul + jobs + inter-review instructions
   e. build_user_prompt() → include S-bot conversation + project state
   f. call_monitor(ctx, user_prompt, system_prompt) → call LLM via OpenAI API
   g. handle_monitor_response() → check if S is still idle
   h. pi_send_message(pi, "autonomic-wakeup", response, "persistent")
```

### 62b. Critical Missing Step — No Review Score Written

After step 62a.h, the A-bot's response is sent as a Pi message.
The `inter_reviews` table is NEVER updated. The `record_review_score()` function
exists in `monitor_ai.gleam` but is NEVER called.

### 62c. A-bot Reads Only 3 Columns from `agent_souls`

```sql
SELECT role, domain, responsibility FROM agent_souls WHERE id_prefix = 'A'
```

The `agent_souls` table has a `content` column with the full soul definition.
The A-bot only reads `role`, `domain`, and `responsibility` — NOT the full soul.
Meanwhile, the S-bot reads the full `content` column. The A-bot is operating
with a minimal soul, not its configured one.

### 62d. `build_user_prompt()` Truncates Inter-Review Context

```gleam
let is_inter_review = string.contains(entries_json, "inter-review")
  || string.contains(entries_json, "Inter-Review")
  || string.contains(entries_json, "issue report")
  || string.contains(entries_json, "fix plan")
  || string.contains(entries_json, "root cause")
```

Inter-review detection is based on string matching in the conversation JSON.
If S-bot doesn't use the exact phrases "inter-review", "issue report", "fix plan",
or "root cause", the A-bot won't prioritize the review.

---

## 63. PSYPI_CONFIG MODULE — CORRECT BUT INCOMPLETE

### 63a. `psypi_config.gleam` — Well Implemented

The module correctly reads/writes the `psypi_config` table. No `::text` issues
because the table only has `key` (text) and `value` (text) columns.

### 63b. Missing Config Keys

The seed only populates 2 keys:
- `monitor_debounce_ms` = `300000`
- `last_wakeup` = ``

But `hook_on_agent_end.gleam` reads:
- `idle_since` — from in-memory store (NOT in database)
- `monitor_debounce_ms` — from in-memory store (NOT in database)

The `psypi_config` DATABASE table and the `_configStore` IN-MEMORY object
are completely separate systems. The database config is never loaded into
the in-memory store on startup.

---

## 64. SEED MODULE — CRITICAL GAPS FOR FRESH DEPLOYMENT

### 64a. Only 3 Tables Seeded

1. `agent_souls` — A-bot and S-bot soul definitions (minimal content)
2. `psypi_config` — 2 config keys
3. `agent_prefixes` — A, S, G prefix definitions

### 64b. Missing Seed Data (Required for System to Function)

| Table               | Required For                                                             | Impact of Missing                            |
| ------------------- | ------------------------------------------------------------------------ | -------------------------------------------- |
| `projects`          | FK constraints, `app.current_project_id`                                 | All INSERTs with `project_id` NOT NULL fail  |
| `agent_identities`  | `agents.gleam:list()`, FK from `agent_sessions`                          | Agent listing fails, session creation fails  |
| `provider_api_keys` | `call_monitor()` LLM API access                                          | A-bot can't call LLM (falls back to env var) |
| `psypi_event_hooks` | `event_hooks.gleam:list_all_hooks()`                                     | Hook listing returns empty                   |
| `agent_jobs`        | `a_db_reader:read_a_jobs_from_db()`, `s_db_reader:read_s_jobs_from_db()` | Both bots have no jobs                       |
| `agent_sessions`    | `a_db_reader:is_s_still_idle()`                                          | No session tracking                          |

### 64c. Seed SQL Has Minimal Soul Content

```sql
INSERT INTO agent_souls (id_prefix, name, role, domain, responsibility, ...)
SELECT 'A','Autonomic','AutonomicBot','autonomic','System health monitoring',...
```

The `content` column gets `'# A'` — a 3-character soul. The actual soul content
should be a full system prompt defining the A-bot's behavior.

---

## 65. COMPLETE `::text` CAST AUDIT — ALL MODULES

| Module             | Column         | Type        | Has `::text`?  | Bug?                      |
| ------------------ | -------------- | ----------- | -------------- | ------------------------- |
| task.gleam         | id             | uuid        | ❌              | ⚠️ May work with pg driver |
| task.gleam         | created_at     | timestamptz | ✅              |                           |
| task.gleam         | updated_at     | timestamptz | ✅              |                           |
| task.gleam         | completed_at   | timestamptz | ✅              |                           |
| task.gleam         | project_id     | uuid        | ✅              |                           |
| task.gleam         | result         | jsonb       | ❌              | ❌ Will fail on non-null   |
| task.gleam         | error          | text        | ✅              |                           |
| meeting.gleam      | id             | uuid        | ❌              | ⚠️                         |
| meeting.gleam      | created_at     | timestamptz | ✅              |                           |
| meeting.gleam      | consensus_at   | timestamptz | ✅              |                           |
| meeting.gleam      | consensus      | jsonb       | ❌              | ❌ Will fail on non-null   |
| agents.gleam       | id             | uuid        | ❌              | ⚠️                         |
| agents.gleam       | created_at     | timestamptz | ✅              |                           |
| inter_review.gleam | id             | uuid        | ❌              | ⚠️                         |
| inter_review.gleam | requested_at   | timestamptz | ❌              | ❌ Will fail               |
| issue_db.gleam     | id             | uuid        | ❌              | ⚠️                         |
| issue_db.gleam     | created_at     | timestamptz | ✅              |                           |
| issue_db.gleam     | resolved_at    | timestamptz | ✅              |                           |
| skill.gleam        | id             | uuid        | ❌              | ⚠️                         |
| skill.gleam        | created_at     | timestamptz | ✅              |                           |
| skill.gleam        | content        | jsonb       | ❌ (get/search) | ❌ Will fail               |
| skill.gleam        | reference_list | jsonb       | ❌ (get/search) | ❌ Will fail               |
| memory.gleam       | id             | uuid        | ❌              | ⚠️                         |
| memory.gleam       | created_at     | timestamptz | ❌              | ❌ Will fail               |
| broadcast.gleam    | id             | uuid        | ❌              | ⚠️                         |
| broadcast.gleam    | created_at     | timestamptz | ✅              |                           |
| broadcast.gleam    | read_at        | timestamptz | ✅              |                           |
| event_hooks.gleam  | id             | uuid        | ✅              |                           |
| event_hooks.gleam  | last_triggered | timestamptz | ✅              |                           |
| code_version.gleam | version_id     | uuid        | ❌              | ⚠️                         |
| code_version.gleam | content        | text        | ✅              |                           |

**Legend**: ❌ = confirmed bug, ⚠️ = may work depending on pg driver UUID handling

**Summary**: 14 confirmed `::text` cast bugs across 8 modules.

---

## 66. COMPLETE `project_id` HARD-CODED UUID AUDIT

| File              | Line | Context                                           |
| ----------------- | ---- | ------------------------------------------------- |
| db.gleam          | 38   | Fallback when `PSYPI_PROJECT_ID` env var is empty |
| task.gleam        | 283  | Default in `psypi-task-add` tool                  |
| issue_db.gleam    | 215  | Default when no `project_id` filter provided      |
| issue_db.gleam    | 273  | Used in `resolve_issue`                           |
| issue_db.gleam    | 304  | Used in `update_issue_status`                     |
| issue_tools.gleam | 24   | Default in `psypi-issue-add` tool                 |

**Total**: 6 locations with hard-coded UUID.

The dynamic lookup plan in `docs/PLAN-project-id-lookup.md` is unimplemented.

---

## 67. COMPLETE MISSING NOT NULL COLUMN AUDIT

| Module           | Function          | Missing Column  | Column Constraint     | Impact                  |
| ---------------- | ----------------- | --------------- | --------------------- | ----------------------- |
| areflect.gleam   | save_issue()      | project_id      | NOT NULL, no default  | INSERT FAILS            |
| areflect.gleam   | save_issue()      | issue_type      | NOT NULL, no default  | INSERT FAILS            |
| areflect.gleam   | save_task()       | project_id      | NOT NULL, has default | Uses wrong default      |
| monitor_ai.gleam | auto_file_issue() | project_id      | NOT NULL, no default  | INSERT FAILS            |
| monitor_ai.gleam | auto_file_issue() | type→issue_type | Column doesn't exist  | INSERT FAILS            |
| skill.gleam      | create()          | source          | NOT NULL, no default  | INSERT FAILS            |
| skill.gleam      | create()          | version         | NOT NULL, no default  | INSERT FAILS            |
| broadcast.gleam  | send()            | project_id      | NOT NULL, no default  | INSERT FAILS when empty |

**Total**: 8 missing NOT NULL column bugs across 4 modules.

---

## 68. FINAL BUG COUNT SUMMARY

| Category                           | Count                                                                                                              |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `::text` cast missing (confirmed)  | 14                                                                                                                 |
| Missing NOT NULL columns in INSERT | 8                                                                                                                  |
| Wrong column names                 | 2 (`type`→`issue_type`, `status` in broadcast)                                                                     |
| Decoder mismatch                   | 3 (memory save, task get, broadcast stats)                                                                         |
| Missing type variants              | 1 (SkillSource AiBuilt)                                                                                            |
| Logic bugs                         | 5 (is_s_still_idle no filter, dual debounce, identity prefix, inter-review never completes, tool_call only "edit") |
| FFI issues                         | 2 (gleamValueToJson, pi_send_message ignores display)                                                              |
| Config system fragmentation        | 2 (in-memory vs database, never synced)                                                                            |
| Seed/bootstrap gaps                | 6 (missing tables)                                                                                                 |
| Dead code                          | 1 (app.current_project_id)                                                                                         |
| Stub implementations               | 1 (tool_consult)                                                                                                   |
| **TOTAL CONFIRMED BUGS**           | **45**                                                                                                             |

---

## 69. RACE CONDITIONS IN SHARED STATE

### 69a. `_configStore` — No Synchronization for Concurrent Access

File: [pi_extension_ffi.mjs:145-150](src/pi_extension_ffi.mjs#L145-L150)

```javascript
let _configStore = {};

export function get_config(key) {
  return _configStore[key] || null;
}

export function set_config(key, value) {
  _configStore[key] = value;
}
```

Node.js is single-threaded for JavaScript execution, so there are no true thread-safety
concerns. However, there ARE async interleaving issues:

**Scenario 1: Debounce timer fires while `on_agent_end` is still processing**

```
T0: agent_end fires → check_idle_since() reads idle_since = None
T1: set_config("idle_since", now_ms()) — records timestamp
T2: agent_end fires AGAIN (before T1's set_config completes)
    → check_idle_since() reads idle_since = None (T1's write hasn't happened yet)
    → Records ANOTHER timestamp, overwriting T1's value
```

This is unlikely because `set_config` is synchronous, but the pattern is fragile.

**Scenario 2: `idle_since` cleared while debounce timer is pending**

```
T0: agent_end fires → S is idle → set_config("idle_since", now)
T1: S becomes busy → agent_end fires → set_config("idle_since", "0")
T2: Debounce timer from T0 fires → reads idle_since = "0" → records new timestamp
    → This is WRONG — the debounce timer should have been cancelled when S became busy
```

The `PiDebouncedHook` in the generated JS does `clearTimeout(_debounceTimerId)` on each
new event, which should prevent T2 from firing. But if the `on_agent_end` handler itself
takes time (DB queries, LLM calls), the timer could fire before the handler completes.

### 69b. `_debounceTimerId` — Module-Level Variable Shared Across Events

File: Generated `extension.js` (from [pi_tool_call.gleam:410-470](src/pi_tool_call.gleam#L410-L470))

```javascript
let _debounceTimerId = null;
let _debounceMs = null;

pi.on('agent_end', async (event, ctx) => {
  if (_debounceTimerId) clearTimeout(_debounceTimerId);
  _debounceTimerId = null;
  // ... read debounce_ms from DB ...
  _debounceTimerId = setTimeout(async () => {
    _debounceTimerId = null;
    // ... call hook_on_agent_end ...
  }, _debounceMs);
});
```

**Problem**: If two `agent_end` events fire in quick succession:
1. Event 1: clears timer, reads DB (async), sets new timer
2. Event 2: clears Event 1's timer, reads DB (async), sets new timer
3. Only Event 2's timer survives — Event 1's debounce is lost

This is actually CORRECT behavior (debounce should restart on each event).
But the `_debounceMs` read is also async — if the DB read is slow, the timer
from Event 1 might fire before Event 2 clears it.

### 69c. `call_monitor` — No Cancellation Support

File: [pi_extension_ffi.mjs:60-120](src/pi_extension_ffi.mjs#L60-L120)

The `call_monitor` function makes an LLM API call that can take 10-30 seconds.
During this time:
- The `_signal` parameter in `pi.registerTool({ execute(_toolCallId, params, _signal, ...) })` is ignored
- If the user cancels the operation, the LLM call continues
- If S-bot becomes busy during the call, `handle_monitor_response` checks `ctx_is_idle()`
  but the LLM response is already consumed — the API cost is wasted

### 69d. Connection Pool Exhaustion

`db.with_connection()` creates a new connection for every query. If multiple hooks
fire simultaneously (e.g., `tool_call` + `agent_end` + `tool_result`), each creates
its own connection. With PostgreSQL's default `max_connections = 100`, this is fine
for normal operation. But if many hooks fire in rapid succession and each makes
multiple queries (e.g., `areflect_tool` makes 3-4 queries), connections could accumulate.

More importantly, each `with_connection` call does:
1. `node_pg.connect()` — TCP handshake + auth
2. `SET app.current_project_id` — useless query (see §29c)
3. Actual query
4. `node_pg.end()` — TCP close

This is 4 round-trips per query. For `areflect_tool` which makes 4 queries, that's
16 round-trips. With a connection pool, it would be 4.

---

## 70. EXTENSION GENERATION PIPELINE — DEEPER ANALYSIS

### 70a. Dynamic Import on Every Hook Fire

File: [pi_tool_call.gleam:336](src/pi_tool_call.gleam#L336)

```javascript
const hook_fn = (await import('./build/dev/javascript/psypi/module.mjs')).fn_name;
```

This `await import()` runs on EVERY event trigger. While Node.js caches modules
after the first import, the `await import()` still:
1. Checks the module cache (fast, but not free)
2. Creates a Promise that resolves to the cached module
3. Awaits that Promise (microtask overhead)

For hot paths like `tool_call` (fires on EVERY tool use), this adds unnecessary
latency. The official Pi examples use static imports at module level.

### 70b. Generated JS Uses `unwrapGleamResult` But Gleam Returns Are Inconsistent

The generated code calls `unwrapGleamResult(result)` on every tool/hook result.
But the Gleam functions have INCONSISTENT return types:

| Module             | Function       | Returns                                     | unwrapGleamResult Works?  |
| ------------------ | -------------- | ------------------------------------------- | ------------------------- |
| task.gleam         | add()          | `Result(String, DbError)`                   | ✅ Yes                     |
| task.gleam         | list()         | `Result(List(Task), DbError)`               | ✅ Yes                     |
| areflect.gleam     | areflect()     | `Result(ReflectionResult, ReflectionError)` | ✅ Yes                     |
| tool_commit.gleam  | on_commit()    | `Result(String, String)`                    | ✅ Yes                     |
| tool_consult.gleam | on_consult()   | `Result(String, String)`                    | ✅ Yes                     |
| hook_on_tool_call  | on_tool_call() | `Result(Nil, String)`                       | ⚠️ Returns Nil, not useful |
| hook_on_agent_end  | on_agent_end() | `Result(Nil, String)`                       | ⚠️ Same                    |
| stats.gleam        | stats()        | `Result(Stats, DbError)`                    | ✅ Yes                     |

The `unwrapGleamResult` function checks `constructor.name === 'Ok'` and extracts
`result['0']`. This works because Gleam's `Ok` and `Error` types are consistently
named. But the VALUE inside depends on the specific function.

### 70c. `raw_json()` Result Format Depends on `gleamValueToJson` Which Is Broken

The `raw_json()` format calls `JSON.stringify(gleamValueToJson(r.value))`.
Since `gleamValueToJson` fails to detect most Gleam custom types (see §15),
the JSON output is broken for:
- `Stats` type → `{0: 5, 1: 3, 2: 1, 3: 0}` instead of `{tasks: 5, issues: 3, ...}`
- `HealthMetrics` → same numeric key problem
- `AlertMetrics` → same
- `ModelStats` → same
- `MonitorAction` → same
- `EnrichedIdentity` → same
- `ReflectionResult` → same

Every tool that uses `raw_json()` format produces broken JSON with numeric keys.
The `template()` format uses `${r.value.field}` which also fails because
`r.value` has numeric keys, not named keys.

**Impact**: 15+ tools return broken JSON to the Pi agent. The LLM receives
garbled data like `{0: 5, 1: 3}` instead of `{tasks: 5, issues: 3}`.

### 70d. `@mariozechner/pi-tui` Import May Not Resolve

File: [extension_generator.gleam:217](src/extension_generator.gleam#L217)

```javascript
import { Text, Box } from "@mariozechner/pi-tui";
```

The package was renamed to `@earendil-works/pi-tui`. If the old package is not
installed, the import will fail with `ERR_MODULE_NOT_FOUND` at Pi startup.
The entire extension will fail to load — NO tools, NO hooks, NO commands.

### 70e. `registerCommand` Handler Signature Mismatch

File: [pi_tool_call.gleam:540-560](src/pi_tool_call.gleam#L540-L560)

Generated code:
```javascript
pi.registerCommand("autonomic-listen", {
  handler: async (args, ctx) => { ... }
});
```

Official Pi SDK:
```javascript
pi.registerCommand("name", {
  description: "...",
  handler: async (args, ctx, pi) => { ... }
});
```

The generated handler receives `(args, ctx)` but the official API provides
`(args, ctx, pi)`. The `pi` parameter is missing. The `command_listen` and
`command_reload` modules work around this by passing `ctx` and `pi` as
literal arguments in the `args` list, but this means `pi` is passed as a
FnArg, not through the official API parameter.

### 70f. No Error Boundary Around Individual Tool Registrations

If ONE tool's Gleam module fails to import (e.g., syntax error in compiled .mjs),
the ENTIRE extension fails because the `await import()` is inside the `execute`
function, not at registration time. The error surfaces only when the tool is used,
not at startup.

---

## 71. A/S AGENT LIFECYCLE — END-TO-END LOGIC CHAIN TRACE

### 71a. Session Start Flow

```
1. Pi starts → loads extension.js
2. extension.js registers hooks, tools, commands, message renderers
3. Pi creates a session → fires "session_start" event
4. session_start hook: record_current_model(ctx.model)
   → But ctx.model may not exist on SessionStartEvent (see §25f)
   → If it works: writes model to psypi_config or agent_sessions
   → If it fails: silently ignored (SilentSuccess action)
5. Pi fires "before_agent_start" event
6. before_agent_start hook: on_before_agent_start()
   → Reads S-bot soul from agent_souls table
   → Returns soul content as systemPrompt
   → event_hooks_record_trigger NEVER called (see §52)
7. Pi fires "agent_start" event
8. agent_start hook: on_agent_start()
   → Records trigger in psypi_event_hooks table
   → Returns Ok(Nil) — no action
9. S-bot begins processing user prompt
```

**Bug at step 4**: `ctx.model` may not be available on `SessionStartEvent`.
**Bug at step 6**: `event_hooks_record_trigger` never called on success.
**Bug at step 6**: If soul read fails, hardcoded fallback soul is used silently.

### 71b. S-bot Tool Call Flow

```
1. S-bot decides to use a tool (e.g., psypi-task-add)
2. Pi fires "tool_call" event
3. tool_call hook: on_tool_call(tool_name, file_path, ctx, pi)
   → Only handles tool_name == "edit" (see §39)
   → For "edit": reads file, saves version to code_versions
   → For all others: returns Ok(Nil) immediately
4. Pi executes the tool
5. Pi fires "tool_result" event
6. tool_result hook: on_tool_result(result_json, tool_name, pi)
   → result_json is "''" because event.result doesn't exist (see §25a)
   → Error detection via string.contains on garbage input
   → If "error" detected: sends autonomic-error message to S-bot
   → autonomic-error is rendered with [A-agentbot ERROR] prefix
   → But S-bot may not understand this is from A-bot (it's just a message)
7. Tool result returned to S-bot
```

**Bug at step 3**: Only "edit" tool gets auto-backup. Write, replace, etc. are ignored.
**Bug at step 6**: `event.result` is undefined, so error detection is broken.
**Bug at step 6**: Error messages sent to S-bot, not A-bot. A-bot never learns about errors.

### 71c. S-bot Turn End Flow (Triggers A-bot Wake-up)

```
1. S-bot finishes a turn (sends response to user)
2. Pi fires "agent_end" event
3. Debounce: Pi SDK sets setTimeout(monitor_debounce_ms)
   → Reads debounce_ms from psypi_config table via DB query
   → Default: 300000ms (5 minutes)
4. After debounce period, callback fires:
5. hook_on_agent_end.on_agent_end(ctx, pi)
6. Check ctx_is_idle() and ctx_has_pending_messages()
   → If S is not idle: clear idle_since, return
   → If S is idle but has pending messages: skip
   → If S is idle and no pending messages: check_idle_since()
7. check_idle_since() reads from IN-MEMORY config store
   → First time: records timestamp, returns (debounce NOT satisfied)
   → Subsequent: checks elapsed against monitor_debounce_ms (also in-memory)
   → If elapsed >= debounce_ms: proceed to coordinate_with_s()
8. coordinate_with_s() checks ctx_is_idle() again + a_db_reader.is_s_still_idle()
   → is_s_still_idle() ALWAYS returns True (see §23)
   → If both "idle": coordinate_when_idle()
9. coordinate_when_idle() parses context window from usage JSON
   → If parse fails: sends autonomic-error, returns
   → If parse succeeds: calls a_orchestrator.run_a_workflow()
10. run_a_workflow():
    a. read_soul_from_db() → gets A-bot soul (only role, domain, responsibility — NOT content)
    b. read_a_jobs_from_db() → gets A-bot jobs
    c. read_project_state_from_db() → gets tasks + issues
    d. build_system_prompt() → composes soul + jobs + inter-review instructions
    e. build_user_prompt() → includes S-bot conversation + project state
    f. call_monitor(ctx, user_prompt, system_prompt) → calls LLM
    g. handle_monitor_response() → checks ctx_is_idle() one more time
    h. pi_send_message(pi, "autonomic-wakeup", response, "persistent")
11. Pi delivers message to S-bot with [A-agentbot] prefix
12. S-bot reads A-bot's message and decides what to do
```

**Bug at step 3**: Debounce reads from DATABASE, but step 7 reads from IN-MEMORY.
Two completely different config systems.
**Bug at step 7**: First `agent_end` after restart always records timestamp and returns.
Requires TWO consecutive `agent_end` fires to actually wake up A-bot.
**Bug at step 8**: `is_s_still_idle()` is useless — always returns True.
**Bug at step 10a**: A-bot reads only 3 columns from `agent_souls`, not the full `content`.
**Bug at step 10h**: A-bot response is NEVER written to `inter_reviews` table.
**Bug at step 12**: S-bot has no structured way to process A-bot's free-text message.

### 71d. Inter-Review Commit Flow (PERMANENTLY STUCK)

```
1. S-bot calls psypi-commit(message="")
2. tool_commit.trigger_review(message)
   → Runs "git diff && git diff --cached" to get changes
   → Runs "git diff --name-only" to get file list
   → Calls inter_review.request_review(None, None, "autonomic", context)
3. request_review() calls SQL function request_inter_review(...)
   → Creates row in inter_reviews with status='pending', overall_score=NULL
   → Returns review_id
4. S-bot receives: "Inter-review triggered (ID: xxx). Call psypi-commit again with this review_id."
5. A-bot should review the code:
   → A-bot's agent_end hook fires (see §71c)
   → A-bot reads conversation, detects "inter-review" keywords
   → A-bot calls LLM to generate review
   → LLM response is sent as pi_send_message to S-bot
   → BUT: response is NEVER written to inter_reviews table
   → overall_score stays NULL forever
6. S-bot calls psypi-commit(message, review_id)
7. tool_commit.commit_if_reviewed(message, review_id)
   → Calls inter_review.get_review_details(review_id)
   → Finds review with overall_score = NULL
   → Returns Error("Review not yet complete. A-bot is still reviewing. Try again later.")
8. S-bot retries... forever. The review NEVER completes.
```

**The inter-review system has NEVER successfully completed a review.**
Every commit attempt is permanently stuck at step 7.

### 71e. A-bot Direct Message Flow (/autonomic-listen)

```
1. User types /autonomic-listen "message"
2. command_listen.on_autonomic_listen(args, ctx, pi)
3. Calls call_monitor(ctx, user_prompt, system_prompt)
   → Uses hardcoded system prompt, not A-bot's soul from DB
4. LLM response is sent via pi_send_message("autonomic-wakeup", response, "persistent")
5. S-bot receives the message
```

**Bug at step 3**: The system prompt is hardcoded in `command_listen.gleam`, not read
from the `agent_souls` table. A-bot's configured soul is ignored for direct messages.

---

## 72. TOOL CALL EXECUTION FLOW — DETAILED TRACE

### 72a. How a Pi Tool Call Reaches Gleam Code

```
1. LLM decides to call psypi-task-add(title="Fix bug", description="...")
2. Pi SDK creates tool call event with parameters
3. Pi SDK calls the registered execute function:
   async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
     const result = await task_add_task("Fix bug", "...");
     const r = unwrapGleamResult(result);
     return r.ok ? { content: [{ type: "text", text: JSON.stringify(gleamValueToJson(r.value)) }] }
                 : { content: [{ type: "text", text: `Error: ${r.error}` }] };
   }
4. task_add_task() is an imported Gleam function:
   import { add_task as task_add_task } from "./build/dev/javascript/psypi/task.mjs";
5. Gleam's task.add_task() runs:
   a. Connects to DB (new connection)
   b. Sets app.current_project_id (useless, see §29c)
   c. Executes INSERT INTO tasks (...)
   d. Decodes result with task_decoder()
   e. Disconnects from DB
6. Result is a Gleam Result(String, DbError) type
7. unwrapGleamResult() extracts Ok value or Error message
8. gleamValueToJson() serializes the value (BROKEN for custom types, see §15)
9. JSON.stringify() converts to string
10. Pi SDK returns the result to the LLM
```

**Bug at step 3**: `_signal` (AbortSignal) is ignored — tool cannot be cancelled.
**Bug at step 3**: `_onUpdate` (streaming callback) is ignored — no progress updates.
**Bug at step 5a**: New DB connection per query — no pooling, no transactions.
**Bug at step 5b**: `SET app.current_project_id` is useless (see §29c).
**Bug at step 8**: `gleamValueToJson` produces broken JSON for custom types.
**Bug at step 10**: Missing `details` field in result — Pi SDK expects it.

### 72b. How a Pi Event Hook Reaches Gleam Code

```
1. Pi fires event (e.g., "agent_end")
2. Pi SDK calls registered event handler:
   pi.on('agent_end', async (event, ctx) => {
     // Debounce logic...
     const result = await hook_on_agent_end_on_agent_end(ctx, pi);
     const r = unwrapGleamResult(result);
     // ...
   });
3. hook_on_agent_end_on_agent_end() is dynamically imported:
   const hook_on_agent_end_on_agent_end = (await import('./build/dev/javascript/psypi/hook_on_agent_end.mjs')).on_agent_end;
4. Gleam's on_agent_end() runs (see §71c for full trace)
5. Result is processed by the generated JS code
```

**Bug at step 3**: Dynamic import on every event — should be static.
**Bug at step 2**: For `before_agent_start`, the `return { systemPrompt: r.value }`
exits before `event_hooks_record_trigger` is called.

---

## 73. ADDITIONAL LOGIC/PROGRAMMING FAILURES

### 73a. `agent_identity.gleam` — Identity Prefix Depends on Transient State

File: [agent_identity.gleam:68-72](src/agent_identity.gleam#L68-L72)

```gleam
let prefix = case ctx.is_idle {
  True -> "A"
  False -> "S"
}
```

And later:
```gleam
let prefix = case string.contains(id, "A-") || ctx.is_idle {
  True -> "A"
  False -> "S"
}
```

The agent identity is determined by whether S-bot is currently idle. This means:
- If S-bot is idle → identity resolves to A-bot → loads A-bot's soul and jobs
- If S-bot becomes busy → identity resolves to S-bot → loads S-bot's soul and jobs
- The same session can flip between A-bot and S-bot identity

**This is a fundamental design flaw.** Agent identity should be stable and determined
at session creation, not by transient idle state. The `ctx.is_idle` check was likely
intended to mean "is this the autonomic (idle-monitoring) agent?" but it actually
means "is the somatic agent currently idle?"

### 73b. `agent_identity.gleam` — `check_git_exists` Result Ignored

File: [agent_identity.gleam:86-89](src/agent_identity.gleam#L86-L89)

```gleam
let _global = case check_git_exists(ctx.cwd) {
  True -> False
  False -> True
}
```

The result is assigned to `_global` (underscore prefix = unused variable).
The global prefix logic is computed but never used. The `semantic_id` function
uses `ctx.global` directly, not the computed `_global` value.

This means the git existence check is dead code — it has no effect on the
generated identity.

### 73c. `areflect.gleam` — `save_issues` Swallows Individual Errors

File: [areflect.gleam:207-213](src/areflect.gleam#L207-L213)

```gleam
fn save_issues(conn, issues, agent_id) {
  case issues {
    [] -> promise.resolve(Ok(Nil))
    [first, ..rest] -> {
      promise.await(save_issue(conn, first, agent_id), fn(_) {
        save_issues(conn, rest, agent_id)
      })
    }
  }
}
```

The `fn(_)` discards the result of `save_issue`. If the first issue fails to save
(e.g., missing `project_id`), the error is silently ignored and the function
continues to save the rest. The caller never knows which issues failed.

Same pattern in `save_learnings` and `save_tasks`.

### 73d. `learning.gleam` — Tags Format Conversion Is Lossy

File: [learning.gleam:48-66](src/learning.gleam#L48-L66)

```gleam
fn normalize_tags(raw: String) -> String {
  // Converts JSON array ["tag1","tag2"] to PostgreSQL array format {tag1,tag2}
  // Converts comma-separated "tag1, tag2" to PostgreSQL array format {tag1,tag2}
}
```

The function converts tags to PostgreSQL array literal format `{tag1,tag2}`.
But `dynamic.string()` sends this as a text parameter, not an array.
PostgreSQL may auto-cast `'{tag1,tag2}'::text[]` but this depends on the
driver and table definition. If the `tags` column is `text[]`, the string
`{tag1,tag2}` needs to be sent as a properly formatted array literal with
quotes: `{"tag1","tag2"}` for values containing spaces or special characters.

### 73e. `broadcast.gleam` — `stats()` Query Uses Non-Existent Columns

File: [broadcast.gleam:258-264](src/broadcast.gleam#L258-L264)

```sql
SELECT
  COUNT(*) as total,
  COUNT(*) FILTER (WHERE status = 'sent') as sent_count,
  COUNT(*) FILTER (WHERE priority >= 2) as high_priority_count
FROM project_communications
WHERE from_ai = $1 AND message_type = 'broadcast'
```

Three bugs:
1. `status` column doesn't exist in `project_communications` — SQL will fail
2. `priority >= 2` — `priority` is `text` type, comparing text to integer fails
3. Even if priority were integer, `'low' >= 2` is meaningless

### 73f. `broadcast.gleam` — `list()` Hardcodes Status

File: [broadcast.gleam:196-200](src/broadcast.gleam#L196-L200)

```sql
SELECT id, from_ai as agent_id, content as message, priority,
       'sent' as status, created_at::text, read_at::text as sent_at
FROM project_communications
```

- `'sent' as status` — hardcoded, actual status is unknown
- `read_at::text as sent_at` — `read_at` is when the message was READ, not SENT
- `id` is UUID without `::text` cast

### 73g. `a_prompt_builder.gleam` — Inter-Review Detection Is Fragile

File: [a_prompt_builder.gleam:104-108](src/a_prompt_builder.gleam#L104-L108)

```gleam
let is_inter_review = string.contains(entries_json, "inter-review")
  || string.contains(entries_json, "Inter-Review")
  || string.contains(entries_json, "issue report")
  || string.contains(entries_json, "fix plan")
  || string.contains(entries_json, "root cause")
```

This detects inter-review requests by string matching in the conversation JSON.
If S-bot uses different phrasing (e.g., "code review", "PR review", "check my work"),
the A-bot won't prioritize the review. The detection should be based on the
`inter_reviews` table status, not string matching.

### 73h. `a_prompt_builder.gleam` — Truncation Loses Critical Context

File: [a_prompt_builder.gleam:119-122](src/a_prompt_builder.gleam#L119-L122)

```gleam
let recent_section = case is_inter_review {
  True ->
    truncate(entries_json, 4000)
  False ->
    truncate(entries_json, 2000)
}
```

For inter-review, only 4000 characters of conversation are included. If the
issue report is long (which it often is), the truncation may cut off the
most important parts — the root cause analysis and fix plan.

### 73i. `monitor_ai.gleam` — `check_safety` Uses Wrong Threshold

File: [monitor_ai.gleam:399-405](src/monitor_ai.gleam#L399-L405)

```gleam
let critical_threshold = 3
let critical_issues = health.open_issues
let should_block = critical_issues > critical_threshold
```

This checks if `open_issues > 3` to decide whether to block. But `open_issues`
counts ALL open issues (not just critical ones). The variable name
`critical_issues` is misleading — it's actually `open_issues`. A project with
4 low-severity open issues would be "blocked" by this logic.

### 73j. `monitor_ai.gleam` — `get_work_suggestions()` Wrong Case for Skills

File: [monitor_ai.gleam:318](src/monitor_ai.gleam#L318)

```sql
FROM skills WHERE status = 'PENDING'
```

The `skills` table uses lowercase status values (`pending`, `approved`).
This query uses `PENDING` (uppercase). It will return 0 rows.

Meanwhile, the `tasks` table uses UPPERCASE (`PENDING`, `COMPLETED`), so
`status = 'PENDING'` is correct for tasks but wrong for skills.

### 73k. `monitor_ai.gleam` — `get_model_stats()` Wrong Case for Reviews

File: [monitor_ai.gleam:285](src/monitor_ai.gleam#L285)

```sql
COUNT(*) FILTER (WHERE status = 'FAILED')::INT as failure_count
FROM inter_reviews
```

The `inter_reviews` table uses lowercase status (`pending`). There are no `FAILED`
rows. The correct value would be lowercase `failed`, but since reviews never
complete (see §22), this doesn't matter in practice.

### 73l. `tool_commit.gleam` — Shell Escape Missing Newline

File: [tool_commit.gleam:10-16](src/tool_commit.gleam#L10-L16)

```gleam
fn shell_escape(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("$", "\\$")
  |> string.replace("`", "\\`")
}
```

Missing: newline (`\n`) escape. A multi-line commit message like:
```
fix: something

Detailed description here
```
Would break the `git commit -m "..."` command because the newline inside
the double-quoted string would be interpreted as a command separator.

### 73m. `hook_on_tool_result.gleam` — Error Detection on Garbage Input

File: [hook_on_tool_result.gleam:8-13](src/hook_on_tool_result.gleam#L8-L13)

The `result_json` parameter receives `JSON.stringify(event.result || '')`.
Since `event.result` doesn't exist on `ToolResultEvent` (see §25a), this is
always `JSON.stringify('')` which is `"''"`.

The error detection checks:
```gleam
string.contains(result_json, "\"error\"")
```

This checks if `"''"` contains `"error"` — it doesn't. So no errors are
ever detected from tool results. The entire error notification system is
non-functional.

### 73n. `pi_extension_ffi.mjs` — `call_monitor` Retry Without Backoff

File: [pi_extension_ffi.mjs:80-110](src/pi_extension_ffi.mjs#L80-L110)

```javascript
if (shouldRetry) {
  result = await completeSimple(model, context, { apiKey: auth.apiKey, headers: auth.headers, reasoning: 'none' });
}
```

On rate limit or empty response, the code retries ONCE with `reasoning: 'none'`.
No delay between retries. No exponential backoff. If the API is rate-limiting,
the immediate retry will also be rate-limited.

### 73o. `pi_extension_ffi.mjs` — `pi_send_message` Ignores `display` Parameter

File: [pi_extension_ffi.mjs:55-59](src/pi_extension_ffi.mjs#L55-L59)

```javascript
export function pi_send_message(pi, customType, content, display) {
  pi.sendMessage({
    customType: String(customType),
    content: String(content),
    display: true,  // hardcoded, ignores the display parameter
  }, { triggerTurn: true });
}
```

The `display` parameter is accepted but never used. All messages are sent with
`display: true`. The calling code passes `"persistent"` as the display value,
which is ignored.

---

## 74. REVISED BUG COUNT — INCLUDING LOGIC/PROGRAMMING FAILURES

| Category                           | Count                                                                                                              |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `::text` cast missing (confirmed)  | 14                                                                                                                 |
| Missing NOT NULL columns in INSERT | 8                                                                                                                  |
| Wrong column names                 | 2 (`type`→`issue_type`, `status` in broadcast)                                                                     |
| Decoder mismatch                   | 3 (memory save, task get, broadcast stats)                                                                         |
| Missing type variants              | 1 (SkillSource AiBuilt)                                                                                            |
| Logic bugs                         | 5 (is_s_still_idle no filter, dual debounce, identity prefix, inter-review never completes, tool_call only "edit") |
| FFI issues                         | 2 (gleamValueToJson, pi_send_message ignores display)                                                              |
| Config system fragmentation        | 2 (in-memory vs database, never synced)                                                                            |
| Seed/bootstrap gaps                | 6 (missing tables)                                                                                                 |
| Dead code                          | 2 (app.current_project_id, check_git_exists result)                                                                |
| Stub implementations               | 1 (tool_consult)                                                                                                   |
| Race conditions / concurrency      | 4 (configStore interleaving, debounce timer race, no cancellation, connection exhaustion)                          |
| Extension generation bugs          | 6 (dynamic import, raw_json broken, pi-tui package, command signature, no error boundary, missing details)         |
| A/S lifecycle logic failures       | 5 (session_start model, soul fallback silent, inter-review stuck, identity flip, direct message ignores soul)      |
| Tool execution flow bugs           | 4 (signal ignored, onUpdate ignored, result broken, details missing)                                               |
| Additional logic failures          | 15 (see §73a-73o)                                                                                                  |
| **TOTAL CONFIRMED BUGS**           | **80**                                                                                                             |

---

## 75. SYSTEMIC ROOT CAUSES

### 75a. No Integration Testing Against Real Database

Every bug in sections 4-67 is invisible to the current test suite because:
- Gleam tests only test pure functions
- No test connects to a real PostgreSQL database
- No test runs the FFI layer against real Node.js
- No test verifies SQL queries return decodable results

**This is the #1 systemic issue.** Without integration tests, every code change
is a gamble.

### 75b. No Schema Source of Truth

The database schema exists in:
1. Migration SQL files (initial state only — not updated after ALTER TABLE)
2. Live PostgreSQL (current state — not version controlled)
3. Gleam type definitions (hand-written — drifts from both)

There is no single source of truth. When a migration adds a column, no mechanism
ensures the Gleam types are updated.

### 75c. AI Repair Cycle

The git log shows a repeating pattern:
1. AI encounters runtime error (decode failure, missing column, FK violation)
2. AI patches the specific error without understanding root cause
3. Patch introduces new phantom reference or breaks another path
4. Next AI session encounters new error, repeats cycle

This cycle has continued for 5+ months. The system has accumulated 80 confirmed
bugs because each "fix" only addresses the immediate symptom.

### 75d. Type System Not Leveraged

Gleam's type system could catch many of these bugs at compile time:
- `decode.field` could use a schema-derived type
- SQL queries could be type-checked against schema
- FFI bindings could use opaque types instead of `a` and `b`

But the codebase uses `a` and `b` (type variables) for Pi context objects,
bypassing the type system entirely. This means the compiler can't verify
that `ctx.ui.notify` is called correctly, or that `pi.sendMessage` receives
the right arguments.

### 75e. No Observability

When something goes wrong at runtime:
- Decode errors produce "Failed to decode X" with no field-level detail
- SQL errors are wrapped in generic `QueryError(String)`
- FFI errors are caught and wrapped in `Error(e.message || 'unknown')`
- No structured logging
- No error tracking
- No metrics

The system is essentially a black box. When it breaks, the only way to debug
is to read the source code and guess what went wrong.

---

## 76. HOOK MODULE DEEP ANALYSIS

### 76a. `hook_on_before_agent_start` — Record Trigger Before Return

File: [hook_on_before_agent_start.gleam:6-8](src/hook_on_before_agent_start.gleam#L6-L8)

```gleam
pub fn on_before_agent_start() -> promise.Promise(Result(String, String)) {
  let trigger = promise.map(event_hooks.record_trigger("before_agent_start"), fn(r) {
    result.map_error(r, fn(e) { string.inspect(e) })
  })
  promise.await(trigger, fn(_) {
    promise.await(s_db_reader.read_s_soul_from_db(), fn(soul_result) { ... })
  })
}
```

This module correctly awaits `record_trigger` before reading the soul. But in the
generated JS code, the `before_agent_start` hook returns `{ systemPrompt: r.value }`
which causes the Pi SDK to set the system prompt. The `event_hooks_record_trigger`
call in the generated JS wrapper happens AFTER the return, so it's never reached.

**Root cause**: The generated JS for `system_prompt_hook` does:
```javascript
const result = await hook_fn(...args);
const r = unwrapGleamResult(result);
event_hooks_record_trigger("before_agent_start"); // <-- never reached
return { systemPrompt: r.value }; // <-- returns here first
```

The `return` exits the function before `event_hooks_record_trigger` is called.
The Gleam code correctly awaits the trigger, but the generated JS wrapper adds
an ADDITIONAL `event_hooks_record_trigger` call that's unreachable.

### 76b. `hook_on_before_agent_start` — Soul Fallback Is Silent

File: [hook_on_before_agent_start.gleam:14-21](src/hook_on_before_agent_start.gleam#L14-L21)

```gleam
Error(e) ->
  promise.resolve(Ok(
    "You are the Somatic Agentbot (S-agentbot). Your ID starts with S-. "
    <> "You are NOT the Autonomic Agentbot (A-agentbot). "
    <> "Messages from A come via pi_send_message — read and follow them. "
    <> "The human user operates the terminal.\n\n"
    <> "[SOUL LOAD FAILED: " <> e <> "]",
  ))
```

When the soul fails to load, the function returns `Ok(fallback_soul)` — not `Error`.
The Pi SDK sees a valid system prompt and proceeds. The `[SOUL LOAD FAILED]` message
is embedded in the system prompt, but S-bot may not understand this is an error
condition. There is no notification to A-bot, no error recording, and no retry.

### 76c. `hook_on_agent_start` — Only Records Trigger

File: [hook_on_agent_start.gleam:6-9](src/hook_on_agent_start.gleam#L6-L9)

```gleam
pub fn on_agent_start() -> promise.Promise(Result(Nil, String)) {
  promise.map(event_hooks.record_trigger("agent_start"), fn(r) {
    result.map_error(r, fn(e) { string.inspect(e) })
  })
}
```

This hook only records the trigger in the database. It does nothing else.
No session initialization, no identity assignment, no state setup. The
`agent_start` event is a critical point in the lifecycle — it should at
minimum:
1. Create an `agent_sessions` row
2. Assign an identity (A or S) to the session
3. Load the appropriate soul and jobs

Currently, none of this happens at `agent_start`.

### 76d. `hook_on_agent_end` — Dual Debounce System

File: [hook_on_agent_end.gleam:29-55](src/hook_on_agent_end.gleam#L29-L55)

The Pi SDK's `debounced_hook` wrapper sets a `setTimeout` based on the value
read from `psypi_config.get_debounce_ms()`. Then, when the timer fires, the
Gleam `on_agent_end` function runs its OWN debounce check using the in-memory
`get_config("idle_since")` and `get_config("monitor_debounce_ms")`.

This creates a **dual debounce** system:
1. **Pi SDK debounce** (JS level): Reads from `psypi_config` table via DB query
2. **Gleam debounce** (Gleam level): Reads from in-memory `_configStore`

The two systems are NEVER synchronized. The in-memory store is populated by
`set_config()` calls in the Gleam code, but `psypi_config` is populated by
`psypi_config.set()` which writes to the database. They are completely separate.

**Impact**: The Pi SDK debounce (5 min) + Gleam debounce (5 min) = 10 min total
delay before A-bot wakes up. Even if both are set to the same value, the Gleam
debounce starts counting from the FIRST `agent_end` after restart, while the
Pi SDK debounce starts counting from the LATEST `agent_end`.

### 76e. `hook_on_agent_end` — `is_s_still_idle()` Always Returns True

File: [a_db_reader.gleam:24-38](src/a_db_reader.gleam#L24-L38)

```sql
SELECT COUNT(*) as cnt FROM agent_sessions
WHERE status = 'alive' AND last_heartbeat > NOW() - INTERVAL '5 minutes'
```

This query counts ALL alive sessions, not just S-bot sessions. But more
critically, the `agent_sessions` table is NEVER populated by any hook.
The `hook_on_agent_start` only records a trigger in `psypi_event_hooks` —
it doesn't insert into `agent_sessions`. So the query always returns `cnt = 0`,
and `is_s_still_idle()` always returns `True`.

### 76f. `hook_on_tool_result` — Synchronous Function, Wrong Return Type

File: [hook_on_tool_result.gleam:7-9](src/hook_on_tool_result.gleam#L7-L9)

```gleam
pub fn on_tool_result(
  result_json: String,
  tool_name: String,
  pi: a,
) -> Result(Nil, String) {
```

This returns `Result(Nil, String)` directly (not wrapped in `promise.Promise`).
But the generated JS code does:
```javascript
const result = await hook_on_tool_result_on_tool_result(...args);
```

The `await` on a non-Promise value works in JavaScript (it resolves immediately),
but the `unwrapGleamResult` function expects a Gleam `Result` type. This works
because `Result` is a synchronous type. However, the `event_hooks_record_trigger`
call in the wrapper expects the result to be available, and since the function
is synchronous, the trigger recording happens correctly.

But there's a deeper issue: `notify_error(pi, ...)` and `pi_send_message(pi, ...)`
are called synchronously inside this function. These FFI functions have side effects
(sending messages to the Pi SDK), but the function returns before those side effects
complete. This is fine for `notify_error` (which is synchronous), but `pi_send_message`
triggers an async message delivery that may not complete before the next hook fires.

### 76g. `hook_on_tool_call` — Only Handles "edit"

File: [hook_on_tool_call.gleam:18-20](src/hook_on_tool_call.gleam#L18-L20)

```gleam
case tool_name == "edit" {
  False -> promise.resolve(Ok(Nil))
  True -> { ... }
}
```

Only the "edit" tool gets auto-backup. Other file-modifying tools like "write",
"replace", "create_file" are ignored. This means:
- `write` tool: No backup before overwriting a file
- `replace` tool: No backup before replacing content
- `create_file` tool: No backup (though less critical)

The Pi SDK uses various tool names depending on the model's choice. The
auto-backup should cover ALL file-modifying operations.

---

## 77. COMMAND MODULE ANALYSIS

### 77a. `command_listen` — Hardcoded System Prompt

File: [command_listen.gleam:21-25](src/command_listen.gleam#L21-L25)

```gleam
let system_prompt =
  "You are the Autonomic Agentbot (A-agentbot). Your ID starts with A-. "
  <> "You are NOT the Somatic Agentbot (S-agentbot). "
  <> "The human is sending you a direct message. "
  <> "Think about what they need and compose a clear, specific message to S. "
  <> "Be brief and actionable."
```

This system prompt is hardcoded. It doesn't include:
- A-bot's soul content from `agent_souls` table
- A-bot's jobs from `agent_jobs` table
- Project state (tasks, issues)
- Any context about what S-bot has been doing

Compare with `a_orchestrator.run_a_workflow()` which reads all of these from
the database. The `/autonomic-listen` command gives A-bot a much weaker prompt.

### 77b. `command_reload` — No Error Handling

File: [command_reload.gleam:5-9](src/command_reload.gleam#L5-L9)

```gleam
pub fn on_autonomic_reload(ctx: a) -> promise.Promise(Result(String, String)) {
  notify_info(ctx, "Reloading extensions...")
  promise.map(ctx_reload(ctx), fn(_) {
    notify_info(ctx, "Extensions reloaded. Monitor updated.")
    Ok("Extensions reloaded.")
  })
}
```

The `fn(_)` discards the result of `ctx_reload`. If the reload fails:
1. The error is silently ignored
2. The user sees "Extensions reloaded. Monitor updated." even though it failed
3. The function returns `Ok("Extensions reloaded.")` — a lie

---

## 78. DB MODULE ANALYSIS

### 78a. `with_connection` — Disconnect Error Swallowed

File: [db.gleam:78-86](src/db.gleam#L78-L86)

```gleam
pub fn with_connection(
  callback: fn(Connection) -> promise.Promise(Result(a, e)),
  error_mapper: fn(DbError) -> e,
) -> promise.Promise(Result(a, e)) {
  promise.await(connect(), fn(conn_result) {
    case conn_result {
      Error(e) -> promise.resolve(Error(error_mapper(e)))
      Ok(conn) -> {
        promise.await(callback(conn), fn(result) {
          let _ = disconnect(conn)
          promise.resolve(result)
        })
      }
    }
  })
}
```

`let _ = disconnect(conn)` — the disconnect result is discarded. If the
disconnect fails (e.g., connection already closed, network error), the error
is silently ignored. This could lead to connection leaks on the PostgreSQL side.

### 78b. `with_connection` — No Transaction Support

The `with_connection` function creates a connection, runs a callback, and
disconnects. There is no way to run multiple queries in a transaction.
If a callback makes multiple queries and the second one fails, the first
query's effects are NOT rolled back.

This is particularly problematic for:
- `areflect_tool`: Makes 3-4 inserts (issue, learnings, tasks) — partial saves
- `tool_commit`: Makes git operations + DB inserts — partial commits
- `inter_review`: Creates review + requests review — partial state

### 78c. `connect()` — `SET app.current_project_id` Is Useless

File: [db.gleam:44-48](src/db.gleam#L44-L48)

```gleam
let set_sql = "SET app.current_project_id = $1"
let set_params = [dynamic.string(project_id)]
promise.map(node_pg.query(client, set_sql, set_params), fn(_) {
  Ok(Connection(client))
})
```

This sets a session-level variable on every new connection. But:
1. The connection is closed after each query (see `with_connection`)
2. No RLS policy uses `app.current_project_id` (verified in migrations)
3. No trigger or function references `current_setting('app.current_project_id')`
4. The SET command adds an extra round-trip to every query

This is pure overhead with zero benefit.

### 78d. `connect()` — Hardcoded Fallback UUID

File: [db.gleam:41-43](src/db.gleam#L41-L43)

```gleam
let project_id = case get_project_id_env() {
  "" -> "0d324e68-b399-4b85-bd8a-6b1ef7b46168"
  id -> id
}
```

The hardcoded UUID `0d324e68-b399-4b85-bd8a-6b1ef7b46168` is used as the default
project ID. This UUID exists in the `projects` table (verified), but:
1. It's hardcoded in 6 different places across the codebase
2. There's no mechanism to change it without code changes
3. The `PLAN-project-id-lookup.md` plan for dynamic lookup is unimplemented
4. If the `projects` table row is deleted, the entire system breaks silently

---

## 79. A_DB_READER DEEP ANALYSIS

### 79a. `read_soul_from_db` — Only Reads 3 Columns

File: [a_db_reader.gleam:57-59](src/a_db_reader.gleam#L57-L59)

```sql
SELECT role, domain, responsibility FROM agent_souls WHERE id_prefix = 'A'
```

The `agent_souls` table has a `content` column that contains the full soul prompt.
But `read_soul_from_db` only reads `role`, `domain`, and `responsibility` — three
short text fields. The `content` column (which could be a multi-paragraph system
prompt) is completely ignored.

Compare with `s_db_reader.read_s_soul_from_db()` which correctly reads the `content`
column. The A-bot reader is missing the most important field.

### 79b. `read_soul_from_db` — Returns Concatenated String

File: [a_db_reader.gleam:70-73](src/a_db_reader.gleam#L70-L73)

```gleam
fn soul_responsibility_decoder() -> decode.Decoder(String) {
  use role <- decode.field("role", decode.string)
  use domain <- decode.field("domain", decode.string)
  use responsibility <- decode.field("responsibility", decode.string)
  decode.success("[" <> role <> " | " <> domain <> "] " <> responsibility)
}
```

The decoder concatenates the three fields into a single string like
`[Autonomic | autonomic] System health monitoring`. This loses all structure.
The `a_prompt_builder` then adds this as a "soul component" alongside the
hardcoded identity prompt. The actual soul content from the database is never used.

### 79c. `read_a_jobs_from_db` — JOIN May Return No Rows

File: [a_db_reader.gleam:200-203](src/a_db_reader.gleam#L200-L203)

```sql
SELECT j.job, j.priority, j.category
FROM agent_jobs j
JOIN agent_souls s ON j.soul_id = s.id
WHERE s.id_prefix = 'A' AND j.is_active = true
ORDER BY j.priority ASC
```

This JOIN requires `agent_jobs.soul_id` to match `agent_souls.id`. But:
1. The `seed.gleam` only seeds `agent_souls` — not `agent_jobs`
2. If no jobs are seeded, the query returns 0 rows
3. The code handles this: `[] -> Ok("  (no active jobs)")`
4. But A-bot then has NO jobs to guide its behavior

### 79d. `read_project_state_from_db` — Error Swallowed

File: [a_db_reader.gleam:88-95](src/a_db_reader.gleam#L88-L95)

```gleam
let tasks_text = case tasks_result {
  Ok(t) -> t
  Error(_) -> "  (tasks unavailable)"
}
```

If reading tasks fails (e.g., decode error, connection error), the error is
silently replaced with `(tasks unavailable)`. A-bot receives this as part of
its prompt but has no way to know the data is missing or why.

---

## 80. MONITOR_AI DEEP ANALYSIS

### 80a. `check_system_health` — `activity_log` Table May Not Exist

File: [monitor_ai.gleam:57](src/monitor_ai.gleam#L57)

```sql
(SELECT COUNT(*)::INT FROM activity_log WHERE timestamp > NOW() - INTERVAL '1 hour') as activities_1h
```

The `activity_log` table is referenced but may not exist. If it doesn't exist,
the entire `check_system_health` query fails, and the function returns
`Error(QueryError(...))`. There's no graceful degradation.

### 80b. `prepare_context` — UNION ALL with Different Column Counts

File: [monitor_ai.gleam:98-106](src/monitor_ai.gleam#L98-L106)

```sql
SELECT 'learning' as type_, content, saved_at::text
FROM memory
WHERE agent_id = $1 AND source = 'learn'
UNION ALL
SELECT 'backup' as type_, file_path as content, saved_at::text
FROM code_versions
WHERE saved_by = $1
ORDER BY saved_at DESC
LIMIT 10
```

`UNION ALL` requires the same number of columns in both subqueries. Both have
3 columns (`type_`, `content`, `saved_at`), so this is correct. But the
`ORDER BY saved_at` at the end of a `UNION ALL` is ambiguous — which `saved_at`?
PostgreSQL resolves this by position, but it's fragile.

### 80c. `get_work_suggestions` — Case Sensitivity Mismatch

File: [monitor_ai.gleam:318](src/monitor_ai.gleam#L318)

```sql
FROM skills WHERE status = 'PENDING'
```

As documented in §73j, `skills.status` uses lowercase values. This query
returns 0 rows. But there's another issue: the `issues` subquery uses
`GROUP BY severity` which returns ONE row per severity level. So if there
are 5 critical issues and 3 medium issues, the result is 2 rows, not 8.

### 80d. `record_review_score` — Only Updates Score, Not Status

File: [monitor_ai.gleam:283-285](src/monitor_ai.gleam#L283-L285)

```sql
UPDATE inter_reviews SET overall_score = $1 WHERE id = $2
```

This only updates `overall_score`. It doesn't update:
- `status` (should change from 'pending' to 'completed' or 'approved')
- `completed_at` (should be set to NOW())
- `reviewer_id` (should be set to A-bot's identity)

Without updating `status`, the `commit_if_reviewed` check will still see
`status = 'pending'` and refuse to commit, even after the score is set.

### 80e. `check_safety` — Blocks on Low-Severity Issues

File: [monitor_ai.gleam:399-405](src/monitor_ai.gleam#L399-L405)

```gleam
let critical_threshold = 3
let critical_issues = health.open_issues
let should_block = critical_issues > critical_threshold
```

As documented in §73i, `open_issues` counts ALL open issues, not just critical
ones. The variable name `critical_issues` is misleading. A project with 4
low-severity open issues would be "blocked" by this logic.

---

## 81. S_DB_READER ANALYSIS

### 81a. `read_s_soul_from_db` — Only Reads `content`, Ignores Other Fields

File: [s_db_reader.gleam:16-18](src/s_db_reader.gleam#L16-L18)

```sql
SELECT content FROM agent_souls WHERE id_prefix = 'S' AND is_active = true
```

This correctly reads the `content` column (unlike `a_db_reader`). But:
1. It filters by `is_active = true` — if S-bot's soul is deactivated, the function fails
2. It only reads `content`, not `role`, `domain`, `responsibility`, `trigger_type`, etc.
3. The `content` from `seed.gleam` is just `"# S"` — a minimal placeholder

### 81b. `read_s_jobs_from_db` — Same JOIN Issue as A-bot

File: [s_db_reader.gleam:43-46](src/s_db_reader.gleam#L43-L46)

```sql
FROM agent_jobs j
JOIN agent_souls s ON j.soul_id = s.id
WHERE s.id_prefix = 'S' AND j.is_active = true
```

Same as §79c — `agent_jobs` is not seeded, so this returns 0 rows.

---

## 82. EVENT_HOOKS MODULE ANALYSIS

### 82a. `record_trigger` — UPDATE Without WHERE Match

File: [event_hooks.gleam:146-153](src/event_hooks.gleam#L146-L153)

```sql
UPDATE psypi_event_hooks
SET last_triggered = NOW(),
    trigger_count = trigger_count + 1,
    updated_at = NOW()
WHERE event_name = $1
```

If no row matches `event_name = $1`, the UPDATE silently affects 0 rows.
The function still returns `Ok(Nil)`. There's no check for whether the
UPDATE actually matched any rows.

This means if the `psypi_event_hooks` table is empty (not seeded), all
trigger recordings silently do nothing.

### 82b. `record_error` — Auto-Disables After 5 Errors

File: [event_hooks.gleam:166-170](src/event_hooks.gleam#L166-L170)

```sql
SET error_count = error_count + 1,
    last_error = $2,
    hook_status = CASE WHEN error_count >= 5 THEN 'error' ELSE hook_status END,
    updated_at = NOW()
```

After 5 errors, the hook status is set to 'error'. But:
1. No code checks `hook_status` before executing a hook
2. The 'error' status is purely informational
3. The hook continues to fire and fail even after being marked 'error'
4. There's no auto-recovery mechanism (no code resets 'error' to 'active')

### 82c. `event_hook_decoder` — `decode.optional` with `decode.string` May Fail

File: [event_hooks.gleam:48-50](src/event_hooks.gleam#L48-L50)

```gleam
use agentbot_action <- decode.field("agentbot_action", decode.optional(decode.string))
```

The SQL uses `COALESCE(agentbot_action, '') as agentbot_action`, which means
the value is always a string (never NULL). But the decoder uses
`decode.optional(decode.string)`, which expects either NULL or a string.
Since `COALESCE` converts NULL to `''`, the `decode.optional` will always
return `Some("")`, never `None`. This works but is semantically wrong —
the `COALESCE` should be removed if `decode.optional` is used, or vice versa.

---

## 83. NODE_PG FFI ANALYSIS

### 83a. `mapQueryResult` — Row Objects Are Plain JS Objects

File: [node_pg/ffi.mjs:325-330](build/dev/javascript/node_pg/ffi.mjs#L325-L330)

```javascript
function mapQueryResult(pgResult) {
  return {
    rows: arrayToList(pgResult.rows),
    ...
  };
}
```

`pgResult.rows` is an array of plain JavaScript objects like `{id: 1, name: "foo"}`.
These are converted to Gleam Lists using `arrayToList`. But `arrayToList` creates
a Gleam `List(Dynamic)` — each row is a `dynamic.Dynamic` value.

When Gleam code does `decode.run(row, decoder)`, it's decoding a plain JS object.
The `decode.field("id", decode.string)` function accesses `row.id`. This works
because `pg` returns rows as plain objects with column names as keys.

But there's a subtle issue: `pg` type-casts some values automatically:
- `timestamp` → JavaScript `Date` object (not a string)
- `jsonb` → JavaScript object (not a string)
- `boolean` → JavaScript `boolean` (not an integer)
- `uuid` → JavaScript `string` (this is fine)

This is why `::text` casts are needed — they force PostgreSQL to return strings
instead of native JavaScript types. Without `::text`, `decode.string` fails on
`Date` objects and JavaScript objects.

### 83b. `executeQuery` — Parameters Are Gleam Dynamic Values

File: [node_pg/ffi.mjs:295-300](build/dev/javascript/node_pg/ffi.mjs#L295-L300)

```javascript
export async function executeQuery(client, sql, parameters) {
  const pgClient = client.inner;
  const jsParams = listToArray(parameters);
  const result = await pgClient.query(sql, jsParams);
  ...
}
```

`listToArray(parameters)` converts the Gleam List of `dynamic.Dynamic` values
to a JavaScript array. But `dynamic.Dynamic` values are raw JavaScript values
passed through Gleam's type system. When `db.gleam` does `dynamic.string(value)`,
it creates a Gleam `Dynamic` wrapping a JavaScript string. The `pg` library
receives these as-is.

This works for simple types (string, int, float). But for:
- `dynamic.optional(dynamic.string)`: Gleam's `Some("x")` becomes `{0: "x"}`,
  which `pg` would try to insert as a complex object, not a string or NULL
- `dynamic.bool(True)`: Gleam's `True` is JavaScript `true`, which works
- `dynamic.int(42)`: Gleam's `42` is JavaScript `42`, which works

The parameter passing works for the types currently used, but would break
for optional values.

---

## 84. REVISED BUG COUNT — FINAL

| Category                           | Count                                                                                                                                                                                                    |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `::text` cast missing (confirmed)  | 14                                                                                                                                                                                                       |
| Missing NOT NULL columns in INSERT | 8                                                                                                                                                                                                        |
| Wrong column names                 | 3 (`type`→`issue_type`, `status` in broadcast, `PENDING` for skills)                                                                                                                                     |
| Decoder mismatch                   | 4 (memory save, task get, broadcast stats, event_hooks optional vs COALESCE)                                                                                                                             |
| Missing type variants              | 1 (SkillSource AiBuilt)                                                                                                                                                                                  |
| Logic bugs                         | 8 (is_s_still_idle no filter, dual debounce, identity prefix, inter-review never completes, tool_call only "edit", record_review_score no status update, check_safety wrong threshold, case sensitivity) |
| FFI issues                         | 3 (gleamValueToJson, pi_send_message ignores display, now_ms duplicate)                                                                                                                                  |
| Config system fragmentation        | 2 (in-memory vs database, never synced)                                                                                                                                                                  |
| Seed/bootstrap gaps                | 7 (missing tables: agent_jobs, agent_sessions, activity_log, projects, agent_identities, provider_api_keys, psypi_event_hooks)                                                                           |
| Dead code                          | 3 (app.current_project_id, check_git_exists result, SET app.current_project_id)                                                                                                                          |
| Stub implementations               | 1 (tool_consult)                                                                                                                                                                                         |
| Race conditions / concurrency      | 4 (configStore interleaving, debounce timer race, no cancellation, connection exhaustion)                                                                                                                |
| Extension generation bugs          | 6 (dynamic import, raw_json broken, pi-tui package, command signature, no error boundary, missing details)                                                                                               |
| A/S lifecycle logic failures       | 6 (session_start model, soul fallback silent, inter-review stuck, identity flip, direct message ignores soul, agent_start does nothing)                                                                  |
| Tool execution flow bugs           | 4 (signal ignored, onUpdate ignored, result broken, details missing)                                                                                                                                     |
| Hook module bugs                   | 5 (before_agent_start record_trigger unreachable, soul fallback silent, agent_start no-op, tool_result sync, tool_call only edit)                                                                        |
| Command module bugs                | 2 (listen hardcoded prompt, reload swallows error)                                                                                                                                                       |
| DB module bugs                     | 4 (disconnect swallowed, no transactions, useless SET, hardcoded UUID)                                                                                                                                   |
| A/S DB reader bugs                 | 4 (A reads wrong columns, A concatenates soul, jobs not seeded, errors swallowed)                                                                                                                        |
| Monitor AI bugs                    | 4 (activity_log may not exist, case sensitivity, score without status, wrong threshold)                                                                                                                  |
| Event hooks bugs                   | 3 (UPDATE no match check, auto-disable ineffective, optional vs COALESCE)                                                                                                                                |
| Node PG FFI bugs                   | 1 (optional parameter handling)                                                                                                                                                                          |
| Inter-review bugs                  | 4 (requested_at missing ::text, id missing ::text, branch hardcoded, context JSON double-encoded)                                                                                                        |
| Tool commit bugs                   | 2 (shell_escape missing newline, git add not called before commit)                                                                                                                                       |
| Tool consult bugs                  | 1 (stub — returns canned response, never calls A-bot)                                                                                                                                                    |
| Code version bugs                  | 1 (get_versions returns raw Dynamic, no type safety)                                                                                                                                                     |
| Meeting bugs                       | 2 (consensus_at missing ::text in some queries, opinion position field unused)                                                                                                                           |
| Agent identity bugs                | 3 (identity flip on idle, check_git_exists dead code, soul fallback silent)                                                                                                                              |
| **TOTAL CONFIRMED BUGS**           | **112**                                                                                                                                                                                                  |

---

## 85. INTER_REVIEW MODULE ANALYSIS

### 85a. `get_review_details` — Missing `::text` Casts

File: [inter_review.gleam:131](src/inter_review.gleam#L131)

```sql
SELECT id, task_id, status, summary, overall_score, requested_at FROM inter_reviews WHERE id = $1
```

- `id` is UUID → needs `id::text`
- `requested_at` is timestamptz → needs `requested_at::text`
- Without these casts, `decode.string` will fail on Date objects and UUID objects

### 85b. `list_reviews` — Same Missing `::text` Casts

File: [inter_review.gleam:260](src/inter_review.gleam#L260)

```sql
SELECT id, task_id, status, summary, overall_score, requested_at FROM inter_reviews
```

Same issue as §85a.

### 85c. `request_review` — Branch Hardcoded to "main"

File: [inter_review.gleam:219-221](src/inter_review.gleam#L219-L221)

```gleam
let branch = "main"
// TODO: get from git
```

The branch is hardcoded to "main". If the user is working on a feature branch,
the review will be recorded against "main" instead of the actual branch.
The `exec_sync("git branch --show-current")` call is available but not used.

### 85d. `request_review` — Context JSON May Be Double-Encoded

File: [inter_review.gleam:224-230](src/inter_review.gleam#L224-L230)

```gleam
let context_json =
  json.to_string(
    json.object([
      #("text", json.string(context)),
      #("source", json.string("psypi-inter-review-request")),
    ]),
  )
let context_json_str = dynamic.string(context_json)
```

The `context` variable already contains the diff text with newlines and special
characters. `json.string(context)` properly escapes these for JSON. But then
`context_json_str` is passed as a `dynamic.string()` parameter to the SQL query.
If the `request_inter_review` SQL function expects a `jsonb` parameter, the
`dynamic.string()` will send it as a text parameter, and PostgreSQL will try to
cast it. If the function expects `text`, the JSON string is sent as-is, which
is correct.

But there's a risk: if `context` itself contains JSON-like content (e.g., the
diff includes JSON files), the double encoding could produce invalid JSON.

### 85e. `request_review` — `dynamic.nil()` for NULL Parameters

File: [inter_review.gleam:207-210](src/inter_review.gleam#L207-L210)

```gleam
let task_id_param = case task_id {
  Some(id) -> dynamic.string(id)
  None -> dynamic.nil()
}
```

`dynamic.nil()` creates a JavaScript `null` value. The `pg` library receives
this as `null` and sends it as a SQL NULL parameter. This is correct behavior
for PostgreSQL. However, the `request_inter_review` SQL function must accept
NULL for these parameters. If the function has `NOT NULL` constraints on these
parameters, the call will fail.

---

## 86. TOOL_COMMIT MODULE ANALYSIS

### 86a. `shell_escape` — Missing Newline Escape

File: [tool_commit.gleam:10-16](src/tool_commit.gleam#L10-L16)

As documented in §73l, the `shell_escape` function doesn't escape newlines.
A multi-line commit message will break the `git commit -m "..."` command.

### 86b. `commit_if_reviewed` — No `git add` Before Commit

File: [tool_commit.gleam:74-76](src/tool_commit.gleam#L74-L76)

```gleam
let cmd = "git commit -m \"" <> escaped <> "\""
```

The commit command doesn't include `git add`. If the files aren't staged,
the commit will fail with "nothing to commit". The `trigger_review` function
reads `git diff --cached`, which implies the user should have staged files.
But there's no check or guidance for this.

### 86c. `trigger_review` — Diff Truncation Loses Context

File: [tool_commit.gleam:38-42](src/tool_commit.gleam#L38-L42)

```gleam
let diff = case exec_sync("git diff && git diff --cached") {
  Ok(out) ->
    case string.length(out) > 8000 {
      True -> string.slice(out, 0, 8000)
      False -> out
    }
  Error(_) -> ""
}
```

The diff is truncated to 8000 characters. For large changes, this may cut off
the most important parts — the actual code changes — while keeping the
less important parts (like import statements or boilerplate).

---

## 87. TOOL_CONSULT MODULE ANALYSIS

### 87a. Stub Implementation — Never Calls A-bot

File: [tool_consult.gleam:7-17](src/tool_consult.gleam#L7-L17)

```gleam
pub fn on_consult(
  question: String,
  ctx: a,
) -> promise.Promise(Result(String, String)) {
  let user_question = case question == "" {
    True -> "What should I consider?"
    False -> question
  }
  notify_info(ctx, "[AUTONOMIC] Consult: " <> user_question)
  promise.resolve(Ok("[Autonomic] Consult request: " <> user_question <> "\n\nThe S-worker should address this in its next turn."))
}
```

This is a stub. It:
1. Never calls `call_monitor` to invoke A-bot's LLM
2. Never sends a message to A-bot
3. Returns a canned response that tells S-bot to "address this in its next turn"
4. The `psypi-consult-autonomic` tool is registered but effectively does nothing

The tool description says "Consult the Autonomic Worker for difficult decisions"
but it never actually consults A-bot. S-bot will call this tool expecting a
thoughtful response from A-bot, but receives a generic placeholder.

---

## 88. CODE_VERSION MODULE ANALYSIS

### 88a. `get_versions` — Returns Raw Dynamic, No Type Safety

File: [code_version.gleam:62-64](src/code_version.gleam#L62-L64)

```gleam
pub fn get_versions(
  file_path: String,
  limit: Int,
) -> promise.Promise(Result(List(dynamic.Dynamic), DbError)) {
```

The function returns `List(dynamic.Dynamic)` — untyped rows. The caller must
manually decode each row. This defeats the purpose of Gleam's type system.
A proper implementation would define a `CodeVersion` type and decode rows
into it.

### 88b. `save_version` — Calls SQL Function That May Not Exist

File: [code_version.gleam:14-16](src/code_version.gleam#L14-L16)

```sql
SELECT save_code_version($1::TEXT, $2::TEXT, $3::VARCHAR, $4::VARCHAR, $5::TEXT) as version_id
```

The `save_code_version` SQL function must exist in the database. If the
migration that creates this function hasn't been run, the query will fail
with "function save_code_version does not exist".

Similarly, `get_code_versions` and `restore_code_version` are SQL functions
that must exist. These are not standard PostgreSQL functions — they must be
created by a migration.

---

## 89. MEETING MODULE ANALYSIS

### 89a. `consensus_at` — Missing `::text` Cast in Some Queries

The `list()` function correctly casts `created_at::text` and `consensus_at::text`.
But the `complete()` function doesn't read `consensus_at` back, so this isn't
an issue there. The `meeting_decoder()` expects `consensus_at` as
`decode.optional(decode.string)`, which works with the `::text` cast.

However, the `id` field is UUID without `::text` cast in all meeting queries.
This will cause `decode.string` to fail on UUID objects.

### 89b. `add_opinion` — `position` Field Unused in Decoder

File: [meeting.gleam:229-234](src/meeting.gleam#L229-L234)

```sql
INSERT INTO meeting_opinions (meeting_id, author, perspective, reasoning, position)
VALUES ($1, $2, $3, $4, $5)
```

The `position` parameter is inserted but never read back. The `opinion_decoder()`
doesn't include `position`. If the `meeting_opinions` table has a `position`
column, it's written but never used by the Gleam code.

### 89c. `list_opinions` — `id` Missing `::text` Cast

File: [meeting.gleam:268-271](src/meeting.gleam#L268-L271)

```sql
SELECT id, meeting_id, author, perspective, reasoning, created_at::text
FROM meeting_opinions
```

`id` and `meeting_id` are UUIDs without `::text` casts. `decode.string` will
fail on these.

---

## 90. AGENT_IDENTITY MODULE ANALYSIS

### 90a. Identity Flip on Idle State

File: [agent_identity.gleam:68-72](src/agent_identity.gleam#L68-L72)

As documented in §73a, the agent identity is determined by `ctx.is_idle`:
- Idle → A-bot prefix
- Not idle → S-bot prefix

This means the same session can flip between A-bot and S-bot identity as
S-bot becomes idle/busy. The `psypi-my-id` tool returns different results
depending on when it's called.

### 90b. `check_git_exists` Result Ignored

File: [agent_identity.gleam:86-89](src/agent_identity.gleam#L86-L89)

As documented in §73b, the result of `check_git_exists` is assigned to
`_global` and never used. The `semantic_id` function uses `ctx.global`
directly.

### 90c. Soul Fallback Is Silent

File: [agent_identity.gleam:227-238](src/agent_identity.gleam#L227-L238)

When `fetch_soul_by_prefix` fails, the function returns a fallback
`EnrichedIdentity` with `domain: "unknown"` and `responsibilities: ""`.
The error is silently discarded. The caller has no way to know the
identity was generated from fallback values.

### 90d. `my_id_tool` — `ctx.model` Access May Fail

File: [agent_identity.gleam:261-265](src/agent_identity.gleam#L261-L265)

```javascript
({ is_idle: ctx.isIdle(), source: (ctx.model?.provider || ''),
   model: (ctx.model?.id || ''),
   thinking_level: (ctx.model?.thinkingLevel || ''),
   cwd: (ctx.cwd || '') })
```

The `ctx.model` access uses optional chaining (`?.`), which is correct.
But `ctx.isIdle()` is a method call, not a property access. If the Pi SDK
changes `isIdle` from a method to a property, this will break.

### 90e. `fetch_soul_by_prefix` — `id` Missing `::text` Cast

File: [agent_identity.gleam:127](src/agent_identity.gleam#L127)

```sql
SELECT id, name, domain, responsibility, trigger_type, drive_mode, activation FROM agent_souls WHERE id_prefix = $1
```

`id` is UUID without `::text` cast. `decode.string` will fail on UUID objects.

---

## 91. CROSS-MODULE DEPENDENCY ISSUES

### 91a. `a_db_reader` vs `s_db_reader` — Inconsistent Soul Reading

| Module      | SQL Columns Read               | Returns             |
| ----------- | ------------------------------ | ------------------- |
| a_db_reader | `role, domain, responsibility` | Concatenated string |
| s_db_reader | `content`                      | Full soul content   |

A-bot gets a summary string; S-bot gets the full soul content. This asymmetry
means A-bot's behavior is guided by a 3-field summary, while S-bot gets the
complete prompt. A-bot's soul content in the database is effectively dead code.

### 91b. `psypi_config` vs `_configStore` — Two Config Systems

| System         | Storage      | Read By                     | Written By                   |
| -------------- | ------------ | --------------------------- | ---------------------------- |
| `psypi_config` | PostgreSQL   | `debounced_hook` (JS)       | `psypi_config.set()` (Gleam) |
| `_configStore` | In-memory JS | `hook_on_agent_end` (Gleam) | `set_config()` (FFI)         |

These two systems are never synchronized. The `debounced_hook` reads
`monitor_debounce_ms` from the database, but `hook_on_agent_end` reads it
from in-memory. If the database value is changed, the JS debounce updates
but the Gleam debounce doesn't (and vice versa).

### 91c. `event_hooks.record_trigger` Called Twice for Some Hooks

For `before_agent_start`:
1. Gleam code: `on_before_agent_start()` calls `event_hooks.record_trigger("before_agent_start")`
2. Generated JS: After the hook returns, the wrapper calls `event_hooks_record_trigger("before_agent_start")`

But the JS wrapper's call is unreachable (see §76a). So the trigger is only
recorded once (by the Gleam code). This is correct but fragile — if the
Gleam code is refactored to remove the `record_trigger` call, the JS wrapper's
unreachable call won't save it.

For other hooks (e.g., `agent_start`):
1. Gleam code: `on_agent_start()` calls `event_hooks.record_trigger("agent_start")`
2. Generated JS: After the hook returns, the wrapper calls `event_hooks_record_trigger("agent_start")`

Both calls execute. The trigger is recorded TWICE per event. The `trigger_count`
increments by 2 instead of 1.

### 91d. `gleamValueToJson` Affects ALL Tool Results

Every tool that uses `raw_json()` or `template()` format depends on
`gleamValueToJson` to serialize Gleam types to JSON. Since this function
is broken (see §15), ALL tool results are affected. This is a single point
of failure that impacts 15+ tools.

---

## 92. FINAL SYSTEMIC ASSESSMENT

### 92a. The Inter-Review System Has NEVER Worked

The inter-review commit flow (§71d) has a fatal design flaw:
1. S-bot triggers a review → creates `inter_reviews` row with `status='pending'`
2. A-bot should review → but never writes back to `inter_reviews`
3. S-bot checks review status → finds `overall_score=NULL` → stuck forever

This means `psypi-commit` has never successfully committed code through the
inter-review process. Every attempt results in "Review not yet complete."

### 92b. The A-bot Wake-up System Has a 10-Minute Delay

The dual debounce system (§76d) means:
1. Pi SDK debounce: 5 minutes after S-bot's last `agent_end`
2. Gleam debounce: 5 minutes from first idle detection
3. Total: up to 10 minutes before A-bot wakes up

In practice, the Gleam debounce often requires TWO `agent_end` events
(because the first one records the timestamp and returns). So the actual
delay can be 15+ minutes.

### 92c. The Agent Identity System Is Fundamentally Broken

The identity prefix (A or S) is determined by `ctx.is_idle`, which is the
S-bot's idle state. This means:
- When S-bot is idle → identity resolves to A-bot
- When S-bot is busy → identity resolves to S-bot
- The same session flips between identities

This breaks the entire A/S dual-agent model. A-bot and S-bot should have
stable, separate identities determined at session creation, not by transient
state.

### 92d. The Seed System Is Incomplete

`seed.gleam` only seeds 3 tables: `agent_souls`, `psypi_config`, `agent_prefixes`.
But the system requires data in at least 7 more tables:
- `agent_jobs` — A/S bot jobs (both readers return "no active jobs")
- `agent_sessions` — session tracking (`is_s_still_idle` always returns True)
- `psypi_event_hooks` — hook status tracking (all UPDATEs affect 0 rows)
- `projects` — project context (hardcoded UUID works but isn't seeded)
- `agent_identities` — identity resolution (not used but referenced)
- `provider_api_keys` — API key storage (not used but referenced)
- `activity_log` — activity tracking (query fails if table doesn't exist)

Without proper seeding, the system starts in a degraded state where many
features silently fail.

### 92e. The `gleamValueToJson` Function Is a System-Wide Failure Point

This single broken function affects:
- 15+ tool results (all using `raw_json()` or `template()`)
- All custom types returned from Gleam to Pi SDK
- The LLM's ability to understand tool results

Without fixing this function, the LLM receives garbled data like
`{0: 5, 1: 3}` instead of `{tasks: 5, issues: 3}`. This makes most
tools effectively useless — the LLM can't interpret the results.

### 92f. No Path to Production

Given the 112 confirmed bugs, the system cannot be considered production-ready.
The most critical issues are:
1. Inter-review never completes (blocks all commits)
2. `gleamValueToJson` breaks all tool results
3. Agent identity flips based on idle state
4. Dual debounce causes 10+ minute delays
5. No integration tests to catch regressions

These issues are not independent — they compound. For example, the inter-review
failure (1) is caused by A-bot never writing back (2), which is caused by the
identity system not distinguishing A-bot from S-bot (3), which is caused by
the idle-state identity logic (4).

---

## 93. TASK MODULE ANALYSIS

### 93a. `get()` — Missing `project_id` Column in SELECT

File: [task.gleam:231-234](src/task.gleam#L231-L234)

```sql
SELECT id, title, description, status, priority, result, error, retry_count,
       created_at::text, updated_at::text, completed_at::text, created_by, source
FROM tasks
WHERE id = $1
```

The `task_decoder()` expects `project_id` field (line 56), but the `get()`
query doesn't include `project_id` in the SELECT. This will cause
`decode.run(row, task_decoder())` to fail with a missing field error.

### 93b. `complete()` — Status Value Case Sensitivity

File: [task.gleam:205-208](src/task.gleam#L205-L208)

```sql
SET status = 'COMPLETED', completed_at = NOW()
```

The status is set to `'COMPLETED'` (uppercase). The `string_to_status()`
function handles both cases (`"completed" | "COMPLETED"`), so this works.
But the `add()` function doesn't set status, so it defaults to whatever
the database column default is. If the default is `'pending'` (lowercase),
the system has inconsistent casing.

### 93c. `task_add_tool` — Hardcoded Default Values

File: [task.gleam:275-282](src/task.gleam#L275-L282)

```gleam
args: [
  from_param("params.title || \"\""),
  lit("\"\""),       // description = empty string
  lit("5"),          // priority = 5
  lit("\"cli\""),    // created_by = "cli"
  from_param("params?.project_id || '0d324e68-b399-4b85-bd8a-6b1ef7b46168'"),
],
```

- `description` is always empty — the tool doesn't accept a description parameter
- `priority` is always 5 — the tool doesn't accept a priority parameter
- `created_by` is always "cli" — should be the agent's identity
- `project_id` falls back to the hardcoded UUID

### 93d. `list()` — `id` Missing `::text` Cast

File: [task.gleam:173-176](src/task.gleam#L173-L176)

```sql
SELECT id, title, description, status, priority, result, error, retry_count,
       created_at::text, updated_at::text, completed_at::text, created_by, source,
       project_id::text
FROM tasks
```

`id` is UUID without `::text` cast. `decode.string` will fail on UUID objects.

---

## 94. ISSUE MODULE ANALYSIS

### 94a. `issue_db.get()` — Hardcoded `project_id` Filter

File: [issue_db.gleam:268-271](src/issue_db.gleam#L268-L271)

```sql
WHERE id = $1 AND project_id = $2
```

With `params = [dynamic.string(issue_id), dynamic.string("0d324e68-...")]`.

The `get()` function hardcodes the project_id filter. This means:
1. Issues from other projects are invisible
2. The function signature doesn't accept project_id as parameter
3. If the project UUID changes, this function silently returns NotFound

### 94b. `issue_db.resolve()` — Same Hardcoded `project_id`

File: [issue_db.gleam:288-291](src/issue_db.gleam#L288-L291)

```sql
WHERE id = $1 AND project_id = $3
```

Same issue as §94a. The resolve function can only resolve issues in the
hardcoded project.

### 94c. `issue_db.list()` — `id` Missing `::text` Cast

File: [issue_db.gleam:197](src/issue_db.gleam#L197)

```sql
SELECT id, title, description, severity, status, issue_type, created_at::text, resolved_at::text, ...
```

`id` is UUID without `::text` cast. `decode.string` will fail on UUID objects.

### 94d. `issue_db.add()` — `id` Missing `::text` in RETURNING

File: [issue_db.gleam:126](src/issue_db.gleam#L126)

```sql
RETURNING id
```

`id` is UUID without `::text` cast. `decode.string` will fail on UUID objects.

### 94e. `issue_db.list()` — `build_where` Reverses Condition Order

File: [issue_db.gleam:215-240](src/issue_db.gleam#L215-L240)

The `build_where` function prepends conditions to the list:
```gleam
#(["status = $" <> string.inspect(idx), ..conditions], [dynamic.string(s), ..params])
```

Then reverses them at the end:
```gleam
" WHERE " <> string.join(list.reverse(conditions), " AND ")
```

But the params list is also prepended but NOT reversed. This means the
parameter indices in the WHERE clause don't match the parameter values.

Example: If status="open", severity="high", the conditions become:
- After prepending: ["severity = $2", "status = $1"]
- After reversing: ["status = $1", "severity = $2"]

But the params become: [dynamic.string("high"), dynamic.string("open")]
- $1 = "high" (should be "open")
- $2 = "open" (should be "high")

**This is a critical bug — the filter parameters are swapped.**

### 94f. `issue_tools` — Hardcoded `project_id` in Tool Args

File: [issue_tools.gleam:20](src/issue_tools.gleam#L20)

```gleam
from_param("params.project_id || \"0d324e68-b399-4b85-bd8a-6b1ef7b46168\""),
```

The `issue_add_tool` hardcodes the default project_id. If the project changes,
all new issues will be created under the wrong project.

---

## 95. BROADCAST MODULE ANALYSIS

### 95a. `send()` — Inserts into Wrong Table

File: [broadcast.gleam:112-116](src/broadcast.gleam#L112-L116)

```sql
INSERT INTO project_communications
(project_id, from_ai, message_type, content, priority, metadata)
VALUES ($1, $2, 'broadcast', $3, $4, $5)
```

The `Broadcast` type has `status: BroadcastStatus` with variants `Pending`,
`Sent`, `Failed`, `Cancelled`. But the INSERT doesn't set a `status` column.
If `project_communications` doesn't have a default status, the broadcast
will have no status.

Also, the `metadata` column is set to `{"sent_at": "now"}`, which is incorrect —
the broadcast hasn't been sent yet (it's just being created). The metadata
should reflect creation, not sending.

### 95b. `list()` — Fabricates `status` as 'sent'

File: [broadcast.gleam:227-228](src/broadcast.gleam#L227-L228)

```sql
SELECT id, from_ai as agent_id, content as message, priority,
       'sent' as status, created_at::text, read_at::text as sent_at
```

The status is hardcoded as `'sent'` in the SQL query. This means every
broadcast returned by `list()` has status `Sent`, regardless of its actual
status. The `BroadcastStatus` type with `Pending`, `Failed`, `Cancelled`
variants is never used for reads.

### 95c. `stats()` — `status` Column Doesn't Exist in `project_communications`

File: [broadcast.gleam:267-272](src/broadcast.gleam#L267-L272)

```sql
COUNT(*) FILTER (WHERE status = 'sent') as sent_count,
COUNT(*) FILTER (WHERE priority >= 2) as high_priority_count
```

The `project_communications` table likely doesn't have a `status` column
(broadcasts are stored there with `message_type='broadcast'`). The
`sent_count` will always be 0.

Also, `priority >= 2` compares a string ('low', 'normal', 'high', 'critical')
with an integer. PostgreSQL will try to cast, but this is unreliable.
The comparison should use `priority IN ('high', 'critical')`.

### 95d. `id` Missing `::text` Cast in All Broadcast Queries

All broadcast queries select `id` (UUID) without `::text` cast.
`decode.string` will fail on UUID objects.

---

## 96. AGENTS MODULE ANALYSIS

### 96a. `agents.list()` — Reads from `agent_identities` Table

File: [agents.gleam:62-65](src/agents.gleam#L62-L65)

```sql
SELECT id, agent_type, created_at::text 
FROM agent_identities 
ORDER BY created_at DESC 
LIMIT 50
```

The `agent_identities` table is one of the unseeded tables (see §92d).
If the table is empty, the tool returns an empty list. The `Agent` type
only has 3 fields (`id`, `agent_type`, `created_at`), which is much less
than the `AgentIdentity` type in `agent_identity_types.gleam` (which has
11 fields). These are two different types for the same concept.

### 96b. `id` Missing `::text` Cast

`id` is UUID without `::text` cast. `decode.string` will fail on UUID objects.

---

## 97. STATS MODULE ANALYSIS

### 97a. `stats()` — No `project_id` Filter

File: [stats.gleam:14-19](src/stats.gleam#L14-L19)

```sql
SELECT 
  (SELECT COUNT(*) FROM tasks) as tasks,
  (SELECT COUNT(*) FROM issues) as issues,
  (SELECT COUNT(*) FROM skills) as skills,
  (SELECT COUNT(*) FROM meetings) as meetings
```

The stats count ALL rows across ALL projects. If the database has data from
multiple projects, the stats will be misleading. The query should filter by
`project_id`.

### 97b. `decode_bigint` — COUNT(*) Returns Int, Not String

File: [stats.gleam:55-61](src/stats.gleam#L55-L61)

```gleam
fn decode_bigint() -> decode.Decoder(Int) {
  decode.string
    |> decode.map(fn(s) {
      case int.parse(s) {
        Ok(n) -> n
        Error(_) -> 0
      }
    })
}
```

The decoder expects `decode.string` for COUNT(*). But PostgreSQL COUNT(*)
returns `bigint`, which the `pg` Node.js driver returns as a JavaScript
`number` (not a string). Using `decode.string` on a number will fail.

The decoder should use `decode.int` directly, or the SQL should cast
`COUNT(*)::text`.

### 97c. `stats_show_tool` — Template Accesses Gleam Type Fields

File: [stats.gleam:73](src/stats.gleam#L73)

```gleam
result_format: template("Tasks:${r.value.tasks} Issues:${r.value.issues} ..."),
```

The template accesses `r.value.tasks`, `r.value.issues`, etc. But `r.value`
is a Gleam `Stats` custom type. In the generated JS, `r.value` is a Gleam
record object with numeric keys like `{0: 5, 1: 3, 2: 7, 3: 2}` (because
`gleamValueToJson` is broken — see §15). The template will produce
`Tasks:undefined Issues:undefined ...`.

---

## 98. MONITOR MODULE ANALYSIS

### 98a. `record_current_model` — `ctx.model` Is an Object, Not a String

File: [extension_generator.gleam:145-148](src/extension_generator.gleam#L145-L148)

```gleam
event_hook(
  "session_start",
  "monitor",
  "record_current_model",
  [from_param("ctx.model")],
```

The `session_start` hook passes `ctx.model` as the argument to
`monitor.record_current_model(model_name)`. But `ctx.model` is a JavaScript
object (e.g., `{id: "claude-3.5", provider: "anthropic"}`), not a string.
The `record_current_model` function inserts this as `dynamic.string(model_name)`,
which will call `.toString()` on the object, producing `[object Object]`.

### 98b. `set_model()` — No Transaction, Two-Step Update

File: [monitor.gleam:139-170](src/monitor.gleam#L139-L170)

The `set_model` function:
1. Resets ALL provider_api_keys to 'not_used'
2. Then updates one to 'in_use'

These are two separate queries without a transaction. If the second query
fails, all keys are marked 'not_used' and none is 'in_use'. The system
loses track of which model is active.

### 98c. `get_pending_notifications` — `id` Missing `::text` Cast

File: [monitor.gleam:211](src/monitor.gleam#L211)

```sql
SELECT id, agent_id, priority, title, body, 
       created_at::text as created_at, read_at::text as read_at
```

`id` is UUID without `::text` cast. `decode.string` will fail on UUID objects.

### 98d. `mark_notifications_read` — `RETURNING id` Without `::text`

File: [monitor.gleam:262](src/monitor.gleam#L262)

```sql
UPDATE notifications 
SET read_at = NOW() 
WHERE agent_id = $1 AND read_at IS NULL
RETURNING id
```

`id` is UUID without `::text` cast. But the function doesn't decode it —
it just counts rows: `Ok(list.length(result.rows))`. So this works, but
the `RETURNING id` is unnecessary overhead.

---

## 99. A_ORCHESTRATOR MODULE ANALYSIS

### 99a. `run_full_workflow` — Errors Send Messages but Don't Stop

File: [a_orchestrator.gleam:25-32](src/a_orchestrator.gleam#L25-L32)

```gleam
Error(e) -> {
  let msg = "[A-agentbot] <ERROR> read_soul_from_db failed: " <> e <> "..."
  pi_send_message(pi, "autonomic-error", msg, "persistent")
  promise.resolve(Ok(Nil))
}
```

When `read_soul_from_db` fails, the orchestrator sends an error message
and returns `Ok(Nil)`. This means the error is silently swallowed — the
caller thinks the workflow succeeded. The same pattern applies to
`read_a_jobs_from_db` and `read_project_state_from_db`.

### 99b. `handle_monitor_response` — Race Condition with `ctx_is_idle`

File: [a_orchestrator.gleam:88-98](src/a_orchestrator.gleam#L88-L98)

```gleam
case ctx_is_idle(ctx) {
  False -> {
    notify_info(ctx, "[AUTONOMIC] S became busy during A's thinking — aborting wake-up")
    promise.resolve(Ok(Nil))
  }
  True -> {
    pi_send_message(pi, "autonomic-wakeup", response, "persistent")
```

After `call_monitor` returns (which involves an LLM call that may take
30+ seconds), the code checks `ctx_is_idle(ctx)`. But the idle state may
have changed during the LLM call. This is a TOCTOU (time-of-check-to-time-of-use)
race condition.

However, this is actually a reasonable design — checking idle state before
sending the wake-up prevents waking S-bot when it's already busy. The real
issue is that `ctx_is_idle` reads from the Pi SDK's internal state, which
may not be up-to-date.

### 99c. `pi_send_message` 4th Parameter Ignored

File: [a_orchestrator.gleam:30](src/a_orchestrator.gleam#L30)

```gleam
pi_send_message(pi, "autonomic-error", msg, "persistent")
```

The 4th parameter `"persistent"` is passed to `pi_send_message`, but the
FFI implementation ignores it (see §73f). All messages are sent the same
way regardless of the display parameter.

---

## 100. A_PROMPT_BUILDER MODULE ANALYSIS

### 100a. `build_user_prompt` — Inter-Review Detection Is Fragile

File: [a_prompt_builder.gleam:84-88](src/a_prompt_builder.gleam#L84-L88)

```gleam
let is_inter_review = string.contains(entries_json, "inter-review")
  || string.contains(entries_json, "Inter-Review")
  || string.contains(entries_json, "issue report")
  || string.contains(entries_json, "fix plan")
  || string.contains(entries_json, "root cause")
```

The inter-review detection is based on string matching in the conversation
entries JSON. This is fragile:
1. If S-bot uses different wording (e.g., "review this fix"), the detection fails
2. If the conversation contains "root cause" in a non-review context, it triggers
3. The detection doesn't check the `inter_reviews` table for pending reviews

### 100b. `build_user_prompt` — Truncation May Cut Critical Context

File: [a_prompt_builder.gleam:106-109](src/a_prompt_builder.gleam#L106-L109)

```gleam
True ->
  "## INTER-REVIEW REQUESTED\n"
  <> "..."
  <> truncate(entries_json, 4000)
False ->
  "..."
  <> truncate(entries_json, 2000)
```

For inter-review, the entries are truncated to 4000 chars; for normal
reminders, 2000 chars. The truncation is from the beginning, so the most
recent (and most relevant) conversation entries are preserved. But for
inter-review, the issue report may be in the middle of the conversation,
and the truncation may cut it off.

### 100c. `a_identity_prompt` — Hardcoded Identity Rules

File: [a_prompt_builder.gleam:19-34](src/a_prompt_builder.gleam#L19-L34)

The identity prompt says "Your ID starts with A-" and "You are NOT the
Somatic Agentbot". But the identity system (§90a) determines A/S prefix
based on idle state, not a fixed assignment. If the identity flips, the
prompt contradicts the actual identity.

---

## 101. SIMPLE_MIGRATE MODULE ANALYSIS

### 101a. `split_statements` — Naive SQL Splitting

File: [simple_migrate.gleam:31-36](src/simple_migrate.gleam#L31-L36)

```gleam
fn split_statements(sql: String) -> List(String) {
  sql
  |> string.split(";\n")
```

The SQL is split by `";\n"`. This will break if:
1. A string literal contains `;\n`
2. A function definition contains `;\n` inside a BEGIN/END block
3. A comment ends with `;` on the same line

### 101b. `strip_comment_line` — Only Strips Line-Starting Comments

File: [simple_migrate.gleam:42-46](src/simple_migrate.gleam#L42-L46)

```gleam
fn strip_comment_line(stmt: String) -> String {
  case string.starts_with(stmt, "--") {
    True -> ""
    False -> stmt
  }
}
```

Only strips comments that start at the beginning of a statement. Inline
comments (e.g., `SELECT id -- primary key`) are not stripped. This is
correct for SQL execution (PostgreSQL handles inline comments), but the
function name is misleading.

### 101c. No Migration Tracking

The migration system doesn't track which migrations have been run.
Every time `run_all_migrations()` is called, ALL migration files are
executed. If a migration creates a table, running it again will fail
with "relation already exists". The system relies on `IF NOT EXISTS`
clauses in the SQL, but not all migrations may use them.

---

## 102. FILE_UTILS MODULE ANALYSIS

### 102a. `file_utils` — Only Used for `extension_generator`

File: [file_utils.gleam](src/file_utils.gleam)

The `file_utils` module is only 23 lines and only used by
`extension_generator.gleam` to write `extension.js`. It uses `simplifile`
which is a pure Gleam file I/O library. This is correct and has no bugs.

However, `simplifile.read()` and `simplifile.write()` are synchronous
operations. In a Node.js environment, synchronous file I/O blocks the
event loop. For the extension generator (which runs once at build time),
this is acceptable. But if `file_utils` is ever used in a hot path,
it will cause performance issues.

---

## 103. MAIN MODULE ANALYSIS

### 103a. `main.gleam` — Only 11 Lines, Delegates to `spawn_pi`

File: [main.gleam](src/main.gleam)

```gleam
@external(javascript, "./node_ffi.mjs", "spawn_pi")
pub fn spawn_pi(args: List(String)) -> promise.Promise(Int)

pub fn main(args: List(String)) -> promise.Promise(Int) {
  spawn_pi(args)
}
```

The main entry point delegates entirely to `spawn_pi` in `node_ffi.mjs`.
The `spawn_pi` function presumably starts the Pi process. This is a thin
wrapper with no logic.

---

## 104. A_CONTEXT_UTILS MODULE ANALYSIS

### 104a. `now_ms` — Duplicate with `pi_extension.now_ms`

File: [a_context_utils.gleam:47-48](src/a_context_utils.gleam#L47-L48)

```gleam
@external(javascript, "./node_ffi.mjs", "now_ms")
fn now_ms() -> Result(Int, String)
```

This is the same FFI binding as `pi_extension.now_ms()`, but with a
different return type:
- `a_context_utils.now_ms()` returns `Result(Int, String)`
- `pi_extension.now_ms()` returns `Int`

The `node_ffi.mjs` implementation returns `Date.now()` (a number), which
is always successful. The `Result` wrapper in `a_context_utils` is
unnecessary but harmless.

### 104b. `current_time_ms` — Swallows Error, Returns 0

File: [a_context_utils.gleam:41-45](src/a_context_utils.gleam#L41-L45)

```gleam
pub fn current_time_ms() -> Int {
  let res = now_ms()
  case res {
    Ok(t) -> t
    Error(_) -> 0
  }
}
```

If `now_ms()` fails (which it shouldn't), the function returns 0. This
means timestamp-based logic (like debounce) will use the Unix epoch
(1970-01-01) as the current time, which will cause all debounce checks
to pass immediately.

---

## 105. SYSTEM_PROMPT_TYPES MODULE ANALYSIS

### 105a. `compose` — Doesn't Use Budget

File: [system_prompt_types.gleam:125-134](src/system_prompt_types.gleam#L125-L134)

```gleam
pub fn compose(comp: PromptComposition) -> String {
  let sorted = list.sort(comp.components, compare_by_priority)
  sorted
  |> list.map(fn(c) { ... })
  |> string.join("\n\n")
}
```

The `compose` function ignores the budget and includes ALL components.
The `compose_within_budget` function exists but is never called. This means
the system prompt can exceed the context window, causing the LLM to truncate
or reject the prompt.

### 105b. `estimate_tokens` — Naive Estimation

File: [system_prompt_types.gleam:50-52](src/system_prompt_types.gleam#L50-L52)

```gleam
pub fn estimate_tokens(text: String) -> Int {
  string.length(text) / 4 + 1
}
```

Token estimation is `chars / 4`. This is a rough approximation that
doesn't account for:
- Code (which has more tokens per character)
- Non-ASCII characters
- Special tokens

The budget system based on this estimation is unreliable.

---

## 106. EXTENSION_GENERATOR MODULE ANALYSIS

### 106a. `consult_tool` and `commit_tool` — Not in Any Module's Public API

File: [extension_generator.gleam:296-322](src/extension_generator.gleam#L296-L322)

```gleam
fn consult_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-consult-autonomic",
    ...
    module: "tool_consult",
    fn_name: "on_consult",
```

The `consult_tool` and `commit_tool` are private functions in
`extension_generator.gleam`, not in their respective modules. This is
inconsistent with all other tools, which are defined in their own modules.
The reason is likely that `tool_consult` and `tool_commit` don't import
`pi_tool_call`, so they can't define `PiToolCall` values.

### 106b. `session_start` Hook — `ctx.model` Is an Object

File: [extension_generator.gleam:145-148](src/extension_generator.gleam#L145-L148)

As documented in §98a, the `session_start` hook passes `ctx.model` to
`monitor.record_current_model()`, but `ctx.model` is a JavaScript object,
not a string.

### 106c. `tool_result` Hook — `event.result` Doesn't Exist

File: [extension_generator.gleam:175-178](src/extension_generator.gleam#L175-L178)

```gleam
event_hook(
  "tool_result",
  "hook_on_tool_result",
  "on_tool_result",
  [
    from_param("JSON.stringify(event.result || '')"),
```

As documented in §76b, `event.result` doesn't exist in the Pi SDK's
`ToolResultEvent`. The correct property is `event.content`.

---

## 107. REVISED BUG COUNT — FINAL v2

| Category                           | Count                                                                                                                                                                    |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `::text` cast missing (confirmed)  | 18 (+4: task.get id, issue list/add/get id, agents id, broadcast id, monitor notifications id)                                                                           |
| Missing NOT NULL columns in INSERT | 8                                                                                                                                                                        |
| Wrong column names                 | 3 (`type`→`issue_type`, `status` in broadcast, `PENDING` for skills)                                                                                                     |
| Decoder mismatch                   | 5 (+1: task.get missing project_id, stats bigint)                                                                                                                        |
| Missing type variants              | 1 (SkillSource AiBuilt)                                                                                                                                                  |
| Logic bugs                         | 9 (+1: issue_db build_where param reversal)                                                                                                                              |
| FFI issues                         | 3 (gleamValueToJson, pi_send_message ignores display, now_ms duplicate)                                                                                                  |
| Config system fragmentation        | 2 (in-memory vs database, never synced)                                                                                                                                  |
| Seed/bootstrap gaps                | 7 (missing tables: agent_jobs, agent_sessions, activity_log, projects, agent_identities, provider_api_keys, psypi_event_hooks)                                           |
| Dead code                          | 3 (app.current_project_id, check_git_exists result, SET app.current_project_id)                                                                                          |
| Stub implementations               | 1 (tool_consult)                                                                                                                                                         |
| Race conditions / concurrency      | 4 (configStore interleaving, debounce timer race, no cancellation, connection exhaustion)                                                                                |
| Extension generation bugs          | 6 (dynamic import, raw_json broken, pi-tui package, command signature, no error boundary, missing details)                                                               |
| A/S lifecycle logic failures       | 6 (session_start model, soul fallback silent, inter-review stuck, identity flip, direct message ignores soul, agent_start does nothing)                                  |
| Tool execution flow bugs           | 4 (signal ignored, onUpdate ignored, result broken, details missing)                                                                                                     |
| Hook module bugs                   | 5 (before_agent_start record_trigger unreachable, soul fallback silent, agent_start no-op, tool_result sync, tool_call only edit)                                        |
| Command module bugs                | 2 (listen hardcoded prompt, reload swallows error)                                                                                                                       |
| DB module bugs                     | 4 (disconnect swallowed, no transactions, useless SET, hardcoded UUID)                                                                                                   |
| A/S DB reader bugs                 | 4 (A reads wrong columns, A concatenates soul, jobs not seeded, errors swallowed)                                                                                        |
| Monitor AI bugs                    | 4 (activity_log may not exist, case sensitivity, score without status, wrong threshold)                                                                                  |
| Event hooks bugs                   | 3 (UPDATE no match check, auto-disable ineffective, optional vs COALESCE)                                                                                                |
| Node PG FFI bugs                   | 1 (optional parameter handling)                                                                                                                                          |
| Inter-review bugs                  | 4 (requested_at missing ::text, id missing ::text, branch hardcoded, context JSON double-encoded)                                                                        |
| Tool commit bugs                   | 2 (shell_escape missing newline, git add not called before commit)                                                                                                       |
| Tool consult bugs                  | 1 (stub — returns canned response, never calls A-bot)                                                                                                                    |
| Code version bugs                  | 1 (get_versions returns raw Dynamic, no type safety)                                                                                                                     |
| Meeting bugs                       | 2 (consensus_at missing ::text in some queries, opinion position field unused)                                                                                           |
| Agent identity bugs                | 3 (identity flip on idle, check_git_exists dead code, soul fallback silent)                                                                                              |
| Task bugs                          | 3 (get missing project_id, id missing ::text, tool hardcoded defaults)                                                                                                   |
| Issue bugs                         | 3 (hardcoded project_id filter, build_where param reversal, id missing ::text)                                                                                           |
| Broadcast bugs                     | 4 (wrong table insert, fabricated status, stats broken, id missing ::text)                                                                                               |
| Agents bugs                        | 2 (reads unseeded table, id missing ::text)                                                                                                                              |
| Stats bugs                         | 3 (no project_id filter, bigint decode, template broken)                                                                                                                 |
| Monitor module bugs                | 3 (ctx.model is object, no transaction, id missing ::text)                                                                                                               |
| A orchestrator bugs                | 2 (errors swallowed, pi_send_message ignores display)                                                                                                                    |
| A prompt builder bugs              | 2 (fragile inter-review detection, hardcoded identity rules)                                                                                                             |
| Simple migrate bugs                | 2 (naive SQL splitting, no migration tracking)                                                                                                                           |
| System prompt types bugs           | 2 (compose ignores budget, naive token estimation)                                                                                                                       |
| A context utils bugs               | 2 (duplicate now_ms, error swallowed returns 0)                                                                                                                          |
| Extension generator bugs           | 2 (tools not in module public API, session_start ctx.model)                                                                                                              |
| FFI node_ffi.mjs bugs              | 3 (now_ms returns Ok but Gleam expects Int, spawn_pi no error handling, get_project_root uses cwd not git root)                                                          |
| FFI pi_extension_ffi.mjs bugs      | 5 (gleamValueToJson broken for most types, pi_send_message ignores display, call_monitor retries on rate limit, _configStore not thread-safe, unwrapGleamResult fragile) |
| FFI agent_identity_ffi.mjs bugs    | 1 (check_git_exists returns Bool but Gleam treats result as unused)                                                                                                      |
| FFI time_utils_ffi.mjs bugs        | 1 (now_iso8601 returns Promise but may be expected as sync)                                                                                                              |
| **TOTAL CONFIRMED BUGS**           | **138**                                                                                                                                                                  |

---

## 108. FFI NODE_FFI.MJS ANALYSIS

### 108a. `now_ms()` Returns `Ok(Int)` But Gleam Expects `Int`

File: [node_ffi.mjs:74-76](src/node_ffi.mjs#L74-L76)

```javascript
export function now_ms() {
  return new Ok(Date.now());
}
```

But `pi_extension.gleam` declares:
```gleam
@external(javascript, "./pi_extension_ffi.mjs", "now_ms")
pub fn now_ms() -> Int
```

And `a_context_utils.gleam` declares:
```gleam
@external(javascript, "./node_ffi.mjs", "now_ms")
fn now_ms() -> Result(Int, String)
```

Two different Gleam modules bind to two different JS files for the same
function name `now_ms`. The `node_ffi.mjs` version returns `Ok(Date.now())`
(a Gleam `Ok` wrapper), while `pi_extension_ffi.mjs` returns `Date.now()`
(a plain number).

The `pi_extension.now_ms()` expects `Int`, so it receives a Gleam `Ok` object
instead of a number. This will cause type errors when the result is used in
arithmetic operations.

### 108b. `spawn_pi` — No Error Handling for Missing `pi` Command

File: [node_ffi.mjs:13-20](src/node_ffi.mjs#L13-L20)

```javascript
export function spawn_pi(args) {
  const piProcess = spawn('pi', args, { ... });
  return new Promise((resolve, reject) => {
    piProcess.on('close', (code) => resolve(code));
    piProcess.on('error', (err) => reject(err));
  });
}
```

If the `pi` command is not in PATH, `spawn` will emit an 'error' event.
The `reject(err)` will cause an unhandled promise rejection. The Gleam
code expects `promise.Promise(Int)`, not a rejected promise.

### 108c. `get_project_root()` Uses `process.cwd()`, Not Git Root

File: [node_ffi.mjs:6-8](src/node_ffi.mjs#L6-L8)

```javascript
export function get_project_root() {
  return process.cwd();
}
```

The function returns `process.cwd()`, which is the current working directory
at the time the process started. This may not be the project root (e.g., if
the process was started from a subdirectory). The extension generator uses
this to write `extension.js`, which may end up in the wrong directory.

---

## 109. FFI PI_EXTENSION_FFI.MJS ANALYSIS

### 109a. `gleamValueToJson` — Broken for Most Custom Types

File: [pi_extension_ffi.mjs:163-197](src/pi_extension_ffi.mjs#L163-L197)

```javascript
if (name.startsWith('Task$Task') || name.startsWith('Issue$Issue') || ...)
```

As documented in §15, the Gleam compiler generates class names like `Task`
(not `Task$Task`). The `startsWith` checks will never match. This means
all custom types fall through to the generic handler, which converts them
to `{0: field0, 1: field1, ...}` instead of named fields.

Additionally, the list of type names is hardcoded and must be manually
updated every time a new type is added. This is unmaintainable.

### 109b. `pi_send_message` — Ignores `display` Parameter

File: [pi_extension_ffi.mjs:55-60](src/pi_extension_ffi.mjs#L55-L60)

```javascript
export function pi_send_message(pi, customType, content, display) {
  pi.sendMessage({
    customType: String(customType),
    content: String(content),
    display: true,  // always true, ignoring the parameter
  }, { triggerTurn: true });
}
```

The `display` parameter is received but ignored. The `display` property is
always `true`. This means:
1. Error messages that should be persistent (`display: "persistent"`) are
   treated the same as transient messages
2. The caller has no control over message visibility

### 109c. `call_monitor` — Retry Logic Is Problematic

File: [pi_extension_ffi.mjs:89-96](src/pi_extension_ffi.mjs#L89-L96)

```javascript
const shouldRetry = !text || (result?.errorMessage && (result.errorMessage === 'terminated' || result.errorMessage.includes('rate')));
if (shouldRetry) {
  result = await completeSimple(model, context, { apiKey: auth.apiKey, headers: auth.headers, reasoning: 'none' });
```

The retry logic:
1. Retries on rate limit errors — but doesn't wait before retrying, so it
   will likely hit the same rate limit
2. Retries with `reasoning: 'none'` — this changes the model's behavior
   (no thinking), which may produce lower-quality responses
3. No maximum retry count — if the model consistently returns empty output,
   this will retry indefinitely

### 109d. `_configStore` — Not Thread-Safe

File: [pi_extension_ffi.mjs:148-155](src/pi_extension_ffi.mjs#L148-L155)

```javascript
let _configStore = {};

export function get_config(key) {
  return _configStore[key] || null;
}

export function set_config(key, value) {
  _configStore[key] = value;
}
```

The in-memory config store is a plain JavaScript object. While Node.js is
single-threaded for JavaScript execution, the `get_config` and `set_config`
calls can interleave with async operations (e.g., between `get_config` and
`set_config`, another async operation may modify the store). This is a
potential race condition for debounce logic.

### 109e. `unwrapGleamResult` — Fragile Constructor Name Check

File: [pi_extension_ffi.mjs:157-162](src/pi_extension_ffi.mjs#L157-L162)

```javascript
export function unwrapGleamResult(result) {
  if (!result) return { ok: false, error: 'null result' };
  const typeName = result.constructor?.name || '';
  if (typeName === 'Ok') return { ok: true, value: result['0'] };
  if (typeName === 'Error') return { ok: false, error: JSON.stringify(gleamValueToJson(result['0'])) || 'Unknown' };
  return { ok: true, value: result };
}
```

The function checks `constructor.name` for 'Ok' and 'Error'. But Gleam
compiles these as `$Result` types with variants. The actual class names
may be `Ok` and `Error` (which works), but if the Gleam compiler changes
its naming convention, this will break silently (falling through to the
default `return { ok: true, value: result }`).

### 109f. `ctx_get_entries_json` — No Error Handling

File: [pi_extension_ffi.mjs:35-38](src/pi_extension_ffi.mjs#L35-L38)

```javascript
export function ctx_get_entries_json(ctx) {
  const entries = ctx.sessionManager.getEntries();
  return JSON.stringify(entries);
}
```

If `ctx.sessionManager` is undefined, or `getEntries()` throws, the function
will crash. No try/catch, no null check.

### 109g. `ctx_get_context_usage_json` — Same Issue

File: [pi_extension_ffi.mjs:40-43](src/pi_extension_ffi.mjs#L40-L43)

```javascript
export function ctx_get_context_usage_json(ctx) {
  const usage = ctx.getContextUsage();
  return JSON.stringify(usage);
}
```

Same issue as §109f. No error handling for missing or failing methods.

---

## 110. FFI AGENT_IDENTITY_FFI.MJS ANALYSIS

### 110a. `check_git_exists` — Correct Implementation, Unused Result

File: [agent_identity_ffi.mjs:1-8](src/agent_identity_ffi.mjs#L1-L8)

```javascript
export function check_git_exists(cwd) {
  return existsSync(join(cwd, '.git'));
}
```

The implementation is correct. The issue is that the Gleam code assigns
the result to `_global` and never uses it (see §90b).

---

## 111. FFI TIME_UTILS_FFI.MJS ANALYSIS

### 111a. `now_iso8601` — Returns Promise, May Be Expected Sync

File: [time_utils_ffi.mjs:1-5](src/time_utils_ffi.mjs#L1-L5)

```javascript
export function now_iso8601() {
  return Promise.resolve(new Date().toISOString());
}
```

The function returns a Promise, but if the Gleam binding expects a synchronous
string, this will fail. Need to check the Gleam declaration.

---

## 112. CROSS-FFI CONSISTENCY ISSUES

### 112a. `now_ms` — Three Different Implementations

| File                    | Returns          | Gleam Binding Type    |
| ----------------------- | ---------------- | --------------------- |
| `node_ffi.mjs`          | `Ok(Date.now())` | `Result(Int, String)` |
| `pi_extension_ffi.mjs`  | `Date.now()`     | `Int`                 |
| `a_context_utils.gleam` | N/A (binds node) | `Result(Int, String)` |
| `pi_extension.gleam`    | N/A (binds ffi)  | `Int`                 |

The same function name `now_ms` has two different implementations with
incompatible return types. `pi_extension.gleam` binds to `pi_extension_ffi.mjs`
which returns a plain number, but the Gleam type says `Int`. This works
because JavaScript numbers ARE integers in Gleam's compiled output.

But `a_context_utils.gleam` binds to `node_ffi.mjs` which returns `Ok(Date.now())`.
The Gleam type says `Result(Int, String)`, which matches the `Ok` wrapper.

The problem: if someone calls `pi_extension.now_ms()` and expects an `Int`,
they get a number. If they call `a_context_utils.now_ms()` and expect
`Result(Int, String)`, they get an `Ok` wrapper. Both work for their
respective callers, but the duplication is confusing and error-prone.

### 112b. `gleam.mjs` Import — May Not Exist

Both `node_ffi.mjs` and `pi_extension_ffi.mjs` import from `./gleam.mjs`:
```javascript
import { Ok, Error } from './gleam.mjs';
```

This file is generated by the Gleam compiler during `gleam build`. If the
project hasn't been built, or if the build output is cleaned, these imports
will fail. The FFI files should handle the case where `gleam.mjs` is not
available.

---

## 113. COMPREHENSIVE UUID `::text` CAST AUDIT

Every query that selects a UUID column and decodes it with `decode.string`
MUST cast to `::text`. Here is the complete audit:

| Module               | Query Function                | UUID Column(s) Missing `::text` |
| -------------------- | ----------------------------- | ------------------------------- |
| task.gleam           | `list()`                      | `id`                            |
| task.gleam           | `get()`                       | `id`                            |
| task.gleam           | `add()` RETURNING             | `id`                            |
| task.gleam           | `complete()` RETURNING        | `id`                            |
| issue_db.gleam       | `list()`                      | `id`                            |
| issue_db.gleam       | `add()` RETURNING             | `id`                            |
| issue_db.gleam       | `get()`                       | `id`                            |
| issue_db.gleam       | `resolve()` RETURNING         | `id`                            |
| meeting.gleam        | `create()` RETURNING          | `id`                            |
| meeting.gleam        | `list()`                      | `id`                            |
| meeting.gleam        | `get()`                       | `id`                            |
| meeting.gleam        | `add_opinion()` RETURNING     | `id`                            |
| meeting.gleam        | `list_opinions()`             | `id`, `meeting_id`              |
| meeting.gleam        | `complete()` RETURNING        | `id`                            |
| broadcast.gleam      | `send()` RETURNING            | `id`                            |
| broadcast.gleam      | `list()`                      | `id`                            |
| broadcast.gleam      | `get_recent()`                | `id`                            |
| agents.gleam         | `list()`                      | `id`                            |
| agent_identity.gleam | `fetch_soul_by_prefix()`      | `id`                            |
| inter_review.gleam   | `get_review_details()`        | `id`                            |
| inter_review.gleam   | `list_reviews()`              | `id`, `task_id`                 |
| inter_review.gleam   | `request_review()` RETURNING  | `id` (via function)             |
| monitor.gleam        | `get_pending_notifications()` | `id`                            |
| memory.gleam         | `save()` RETURNING            | `id`                            |
| memory.gleam         | `search()`                    | `id`                            |
| learning.gleam       | `save()` RETURNING            | `id`                            |
| areflect.gleam       | `save_issue()` RETURNING      | `id`                            |
| skill.gleam          | various                       | `id`                            |

**Total UUID columns missing `::text` cast: 28+**

This is the single most pervasive bug in the codebase. Every module that
reads UUID columns from PostgreSQL is affected.

---

## 114. REVISED BUG COUNT — FINAL v3

| Category                           | Count                                                                                                                                                                                                                                                               |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `::text` cast missing (UUID+tstz)  | 28 (comprehensive audit, see §113)                                                                                                                                                                                                                                  |
| Missing NOT NULL columns in INSERT | 8                                                                                                                                                                                                                                                                   |
| Wrong column names                 | 3 (`type`→`issue_type`, `status` in broadcast, `PENDING` for skills)                                                                                                                                                                                                |
| Decoder mismatch                   | 5 (task.get missing project_id, stats bigint, memory save, task get, broadcast stats)                                                                                                                                                                               |
| Missing type variants              | 1 (SkillSource AiBuilt)                                                                                                                                                                                                                                             |
| Logic bugs                         | 9 (issue_db build_where param reversal, is_s_still_idle no filter, dual debounce, identity prefix, inter-review never completes, record_review_score no status update, check_safety wrong threshold, case sensitivity)                                              |
| FFI issues                         | 8 (gleamValueToJson broken, pi_send_message ignores display, now_ms duplicate/inconsistent, call_monitor no backoff, _configStore not thread-safe, unwrapGleamResult fragile, ctx_get_entries_json no error handling, ctx_get_context_usage_json no error handling) |
| Config system fragmentation        | 2 (in-memory vs database, never synced)                                                                                                                                                                                                                             |
| Seed/bootstrap gaps                | 7 (missing tables: agent_jobs, agent_sessions, activity_log, projects, agent_identities, provider_api_keys, psypi_event_hooks)                                                                                                                                      |
| Dead code                          | 3 (app.current_project_id, check_git_exists result, SET app.current_project_id)                                                                                                                                                                                     |
| Stub implementations               | 1 (tool_consult)                                                                                                                                                                                                                                                    |
| Race conditions / concurrency      | 4 (configStore interleaving, debounce timer race, no cancellation, connection exhaustion)                                                                                                                                                                           |
| Extension generation bugs          | 6 (dynamic import, raw_json broken, pi-tui package, command signature, no error boundary, missing details)                                                                                                                                                          |
| A/S lifecycle logic failures       | 6 (session_start model, soul fallback silent, inter-review stuck, identity flip, direct message ignores soul, agent_start does nothing)                                                                                                                             |
| Tool execution flow bugs           | 4 (signal ignored, onUpdate ignored, result broken, details missing)                                                                                                                                                                                                |
| Hook module bugs                   | 5 (before_agent_start record_trigger unreachable, soul fallback silent, agent_start no-op, tool_result sync, tool_call only edit)                                                                                                                                   |
| Command module bugs                | 2 (listen hardcoded prompt, reload swallows error)                                                                                                                                                                                                                  |
| DB module bugs                     | 4 (disconnect swallowed, no transactions, useless SET, hardcoded UUID)                                                                                                                                                                                              |
| A/S DB reader bugs                 | 4 (A reads wrong columns, A concatenates soul, jobs not seeded, errors swallowed)                                                                                                                                                                                   |
| Monitor AI bugs                    | 4 (activity_log may not exist, case sensitivity, score without status, wrong threshold)                                                                                                                                                                             |
| Event hooks bugs                   | 3 (UPDATE no match check, auto-disable ineffective, optional vs COALESCE)                                                                                                                                                                                           |
| Node PG FFI bugs                   | 1 (optional parameter handling)                                                                                                                                                                                                                                     |
| Inter-review bugs                  | 4 (requested_at missing ::text, id missing ::text, branch hardcoded, context JSON double-encoded)                                                                                                                                                                   |
| Tool commit bugs                   | 2 (shell_escape missing newline, git add not called before commit)                                                                                                                                                                                                  |
| Tool consult bugs                  | 1 (stub — returns canned response, never calls A-bot)                                                                                                                                                                                                               |
| Code version bugs                  | 1 (get_versions returns raw Dynamic, no type safety)                                                                                                                                                                                                                |
| Meeting bugs                       | 2 (consensus_at missing ::text in some queries, opinion position field unused)                                                                                                                                                                                      |
| Agent identity bugs                | 3 (identity flip on idle, check_git_exists dead code, soul fallback silent)                                                                                                                                                                                         |
| Task bugs                          | 3 (get missing project_id, id missing ::text, tool hardcoded defaults)                                                                                                                                                                                              |
| Issue bugs                         | 3 (hardcoded project_id filter, build_where param reversal, id missing ::text)                                                                                                                                                                                      |
| Broadcast bugs                     | 4 (wrong table insert, fabricated status, stats broken, id missing ::text)                                                                                                                                                                                          |
| Agents bugs                        | 2 (reads unseeded table, id missing ::text)                                                                                                                                                                                                                         |
| Stats bugs                         | 3 (no project_id filter, bigint decode, template broken)                                                                                                                                                                                                            |
| Monitor module bugs                | 3 (ctx.model is object, no transaction, id missing ::text)                                                                                                                                                                                                          |
| A orchestrator bugs                | 2 (errors swallowed, pi_send_message ignores display)                                                                                                                                                                                                               |
| A prompt builder bugs              | 2 (fragile inter-review detection, hardcoded identity rules)                                                                                                                                                                                                        |
| Simple migrate bugs                | 2 (naive SQL splitting, no migration tracking)                                                                                                                                                                                                                      |
| System prompt types bugs           | 2 (compose ignores budget, naive token estimation)                                                                                                                                                                                                                  |
| A context utils bugs               | 2 (duplicate now_ms, error swallowed returns 0)                                                                                                                                                                                                                     |
| Extension generator bugs           | 2 (tools not in module public API, session_start ctx.model)                                                                                                                                                                                                         |
| FFI node_ffi.mjs bugs              | 3 (now_ms returns Ok but Gleam expects Int, spawn_pi no error handling, get_project_root uses cwd not git root)                                                                                                                                                     |
| FFI pi_extension_ffi.mjs bugs      | 5 (gleamValueToJson broken, pi_send_message ignores display, call_monitor no backoff, _configStore not thread-safe, unwrapGleamResult fragile)                                                                                                                      |
| FFI agent_identity_ffi.mjs bugs    | 1 (check_git_exists returns Bool but Gleam treats result as unused)                                                                                                                                                                                                 |
| FFI time_utils_ffi.mjs bugs        | 1 (now_iso8601 returns Promise but may be expected as sync)                                                                                                                                                                                                         |
| **TOTAL CONFIRMED BUGS**           | **138**                                                                                                                                                                                                                                                             |

---

## 115. TOP 10 CRITICAL BUGS (Priority Order)

1. **`gleamValueToJson` broken** (§109a) — ALL tool results are garbled.
   Every tool that returns a custom type produces `{0: val, 1: val}` instead
   of `{field: val}`. The LLM cannot interpret tool results.

2. **Inter-review never completes** (§92a) — A-bot never writes back to
   `inter_reviews`. `overall_score` stays NULL. `psypi-commit` is permanently
   blocked.

3. **UUID `::text` cast missing everywhere** (§113) — 28+ instances across
   all modules. Every database read of a UUID column fails at the decode
   step. Most tools return DecodeError.

4. **`issue_db.build_where` param reversal** (§94e) — Filter parameters
   are swapped. Searching for `status=open, severity=high` actually searches
   for `status=high, severity=open`. All filtered issue queries return wrong
   results.

5. **Agent identity flip on idle** (§90a) — The same session can flip
   between A-bot and S-bot identity. The A/S dual-agent model is broken.

6. **Dual debounce = 10+ minute delay** (§92b) — Pi SDK debounce + Gleam
   debounce compound. A-bot takes 10-15 minutes to wake up.

7. **`stats` bigint decode fails** (§97b) — `decode.string` on COUNT(*)
   which returns a number. The `psypi-stats-show` tool always fails.

8. **`task.get()` missing `project_id`** (§93a) — Decoder expects
   `project_id` but query doesn't select it. `psypi-task-get` always fails.

9. **`broadcast.stats()` broken** (§95c) — `status` column doesn't exist
   in `project_communications`. `priority >= 2` compares string with int.

10. **`session_start` hook passes object as string** (§98a) — `ctx.model`
    is an object, but `record_current_model` expects a string. Activity
    log records `[object Object]` as the model name.

---

## 116. SQL MIGRATION ANALYSIS

### 116a. Migration Numbering Collision — Two Files Share `025`

Files:
- [025_add_tasks_project_id.sql](src/migrations/025_add_tasks_project_id.sql)
- [025_drop_system_directives.sql](src/migrations/025_drop_system_directives.sql)

Both have migration number `025`. `simple_migrate.gleam` sorts by filename
and runs sequentially. The order depends on alphabetical sorting:
`025_add...` < `025_drop...`, so `add_tasks_project_id` runs first.

But this is fragile and confusing. If `025_drop_system_directives` runs
before `025_add_tasks_project_id` in some environments (e.g., different
filesystem sort order), the results could differ.

### 116b. `simple_migrate` — No Migration Tracking

File: [simple_migrate.gleam](src/simple_migrate.gleam)

The migration system has no tracking table. Every time `run_all_migrations()`
is called, ALL migrations are re-executed. This means:

1. `CREATE TABLE IF NOT EXISTS` — safe, but wasteful
2. `INSERT INTO ... ON CONFLICT DO NOTHING` — safe, but wasteful
3. `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` — safe, but wasteful
4. `CREATE INDEX IF NOT EXISTS` — safe, but wasteful
5. `INSERT INTO agent_souls ...` in migration 008 — **DANGEROUS**: The
   `agent_souls` INSERT has no `ON CONFLICT` clause for the soul content.
   The `UNIQUE` constraint on `id_prefix` prevents duplicate A/S entries,
   but if the soul content changes in the migration file, the old content
   remains in the database.

### 116c. `split_statements` — Naive SQL Splitting

File: [simple_migrate.gleam:21-29](src/simple_migrate.gleam#L21-L29)

```gleam
fn split_statements(sql: String) -> List(String) {
  sql
  |> string.split(";\n")
  |> list.map(fn(s) { string.trim(s) })
  |> list.filter(fn(s) { ... })
}
```

The function splits on `;\n`. This breaks if:
1. A string literal contains `;\n` (e.g., in soul content)
2. A PL/pgSQL function body contains `;\n` (e.g., `save_code_version`)
3. A comment line ends with `;`

The migration `008_agent_soul.sql` contains multi-line string literals
with semicolons in the soul content. The `014_code_versions.sql` contains
PL/pgSQL functions with `$$ ... $$` delimiters. These WILL be split
incorrectly.

**This is a CRITICAL bug**: Running `simple_migrate` on a fresh database
will fail because the SQL statements are split mid-function or mid-string.

### 116d. `strip_comment_line` — Only Strips Full-Line Comments

File: [simple_migrate.gleam:31-35](src/simple_migrate.gleam#L31-L35)

```gleam
fn strip_comment_line(stmt: String) -> String {
  case string.starts_with(stmt, "--") {
    True -> ""
    False -> stmt
  }
}
```

This only strips comments that are the ENTIRE statement. It does not strip
inline comments like `SELECT 1 -- comment`. Since `split_statements` splits
on `;\n`, a comment-only "statement" (after splitting) will be stripped.
But inline comments within a statement will be sent to PostgreSQL as-is,
which is fine (PostgreSQL handles them).

### 116e. `seed.gleam` — Only Seeds 3 Tables

File: [seed.gleam](src/seed.gleam)

The seed module only seeds:
1. `agent_souls` — with minimal content (`'# A'` and `'# S'`)
2. `psypi_config` — `monitor_debounce_ms` and `last_wakeup`
3. `agent_prefixes` — A, S, G prefixes

Missing seed data:
- `projects` — No row for the hardcoded UUID
- `agent_identities` — No initial identity
- `provider_api_keys` — No API key entries
- `agent_jobs` — Seeded in migration 009, but `seed.gleam` doesn't cover it
- `psypi_event_hooks` — Seeded in migration 003, but `seed.gleam` doesn't cover it

The `agent_souls` seed uses minimal content (`'# A'`), while the migration
008 uses full soul content. If `seed.gleam` runs AFTER migration 008, the
`WHERE NOT EXISTS` check prevents overwriting. But if `seed.gleam` runs
FIRST, the full soul content from migration 008 will be inserted. This
ordering dependency is fragile.

### 116f. Migration 005 vs 025 — `system_directives` Created Then Dropped

Migration 005 creates `system_directives` table. Migration 025 drops it.
But if any Gleam code still references `system_directives`, it will fail.
The `a_db_reader.gleam` and `a_prompt_builder.gleam` should be checked
for any remaining references.

### 116g. Migration 010 — `tasks.status` CHECK Allows Both Cases

File: [010_create_tasks_table.sql](src/migrations/010_create_tasks_table.sql)

```sql
status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN (
  'PENDING', 'RUNNING', 'COMPLETED', 'FAILED',
  'pending', 'running', 'completed', 'failed',
  'FAKE_COMPLETE'))
```

The CHECK constraint allows both uppercase and lowercase status values.
But the Gleam code uses uppercase (`'COMPLETED'`, `'FAILED'`) for writes
and the decoder expects specific casing. This inconsistency means:
- `task.gleam:complete()` writes `'COMPLETED'`
- `monitor_ai.gleam` queries `WHERE status = 'FAILED'`
- But nothing prevents lowercase values from being inserted

### 116h. Migration 020 — `skills.source` Missing `'ai-built'`

File: [020_skills.sql](src/migrations/020_skills.sql)

```sql
source TEXT NOT NULL DEFAULT 'local' CHECK (source IN (
  'clawhub', 'local', 'generated', 'imported'))
```

The CHECK constraint does NOT include `'ai-built'`. If `skill.gleam`
tries to insert a row with `source='ai-built'`, PostgreSQL will reject
it with a constraint violation.

Conversely, `skill.gleam`'s `string_to_source` function doesn't handle
`'generated'` or `'imported'` either — it only handles `'clawhub'`,
`'local'`, and `'ai-built'`.

This is a **bidirectional mismatch**: the database rejects what Gleam
tries to insert, and Gleam can't decode what the database allows.

### 116i. Migration 022 — `project_communications.priority` is TEXT, Not INT

File: [022_project_communications.sql](src/migrations/022_project_communications.sql)

```sql
priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN (
  'low', 'normal', 'high', 'critical'))
```

But `broadcast.gleam:stats()` queries:
```sql
COUNT(*) FILTER (WHERE priority >= 2) as high_priority_count
```

`priority` is TEXT. `priority >= 2` compares a string with an integer.
In PostgreSQL, this will either:
- Cast `2` to text and do string comparison (`'high' >= '2'` = true, `'low' >= '2'` = false)
- Throw a type error

Neither produces the intended result (counting high/critical priority items).

### 116j. Migration 024 — `inter_reviews` Missing `branch` and `context` Columns

File: [024_inter_reviews.sql](src/migrations/024_inter_reviews.sql)

```sql
CREATE TABLE IF NOT EXISTS inter_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID,
    status TEXT NOT NULL DEFAULT 'requested',
    summary TEXT,
    overall_score INTEGER,
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);
```

But `inter_review.gleam:request_review()` inserts `branch` and `context`
columns that don't exist in the migration. If the migration was run on a
fresh database, these columns won't exist and the INSERT will fail.

Wait — let me verify this against the live database. The columns may have
been added manually or via a missing migration.

---

## 117. INTER-REVIEW MODULE DEEP ANALYSIS

### 117a. `inter_review.gleam:request_review()` — INSERT Into Non-Existent Columns

The `request_review()` function inserts `branch` and `context` columns
that are not in migration 024. If these columns were added manually,
there's no migration tracking them. On a fresh database setup, the
INSERT will fail.

### 117b. `inter_review.gleam` — No `complete_review()` Function

The `inter_reviews` table has `status IN ('requested', 'in_progress',
'completed', 'failed')`, but there is no Gleam function that transitions
a review from `'requested'` to `'completed'`. The `record_review_score()`
in `monitor_ai.gleam` only updates `overall_score`, not `status`.

This means:
1. A-bot reviews the code and produces a score
2. `record_review_score()` writes the score but leaves `status='requested'`
3. `tool_commit.gleam` checks `overall_score` (which may now be set)
4. But `status` is still `'requested'`, not `'completed'`

If `tool_commit` only checks `overall_score >= 50`, this works. But if
any code checks `status = 'completed'`, it will never find completed
reviews.

### 117c. `inter_review.gleam` — `context` Column Double-Encoded JSON

The `request_review()` function receives `context` as a JSON string and
inserts it as-is. But if the caller already serialized the context to
JSON, and the database column is TEXT (not JSONB), the value is stored
as a JSON string. When read back, it's a string containing JSON — which
is correct for TEXT storage.

However, if the column were JSONB, PostgreSQL would reject a
double-encoded JSON string. And if any code tries to parse the `context`
field as a nested object, it would need to JSON.parse twice.

---

## 118. HOOK MODULE DEEP ANALYSIS

### 118a. `hook_on_before_agent_start` — Soul Fallback Is Silent

File: [hook_on_before_agent_start.gleam:14-27](src/hook_on_before_agent_start.gleam#L14-L27)

```gleam
Error(e) ->
  promise.resolve(Ok(
    "You are the Somatic Agentbot (S-agentbot). ..."
    <> "[SOUL LOAD FAILED: " <> e <> "]"
  ))
```

When soul loading fails, the hook returns `Ok(...)` with a fallback prompt.
The error is embedded in the prompt text but NOT logged to the database
or event_hooks table. The A-bot has no way to know that S's soul failed
to load.

### 118b. `hook_on_agent_start` — Does Nothing Useful

File: [hook_on_agent_start.gleam](src/hook_on_agent_start.gleam)

```gleam
pub fn on_agent_start() -> promise.Promise(Result(Nil, String)) {
  promise.map(event_hooks.record_trigger("agent_start"), fn(r) {
    result.map_error(r, fn(e) { string.inspect(e) })
  })
}
```

This hook only records a trigger in `psypi_event_hooks`. It doesn't:
- Start a session in `agent_sessions`
- Record the agent identity
- Notify A-bot that S is starting

The `agent_sessions` table is never populated by any hook, making
`a_db_reader.is_s_still_idle()` always return `True` (count of 0 sessions).

### 118c. `hook_on_tool_result` — Synchronous Return Type

File: [hook_on_tool_result.gleam](src/hook_on_tool_result.gleam)

```gleam
pub fn on_tool_result(
  result_json: String,
  tool_name: String,
  pi: a,
) -> Result(Nil, String) {
```

This hook returns `Result(Nil, String)` synchronously, not wrapped in
`promise.Promise`. But the extension generator registers it as an event
hook that returns a Promise. If the Pi SDK expects an async function,
returning a synchronous `Result` may cause issues.

### 118d. `hook_on_tool_call` — Only Handles `edit` Tool

File: [hook_on_tool_call.gleam:17-18](src/hook_on_tool_call.gleam#L17-L18)

```gleam
case tool_name == "edit" {
  False -> promise.resolve(Ok(Nil))
  True -> {
```

The auto-backup only fires for the `edit` tool. Other write tools like
`write` and `bash` are not backed up. If S uses `write` to create a new
file, there's no auto-backup.

### 118e. `hook_on_agent_end` — `now_ms()` Type Mismatch

File: [hook_on_agent_end.gleam:42](src/hook_on_agent_end.gleam#L42)

```gleam
let now = now_ms()
```

This calls `pi_extension.now_ms()` which returns `Int` (per the Gleam
declaration). But `pi_extension_ffi.mjs` returns `Date.now()` (a plain
number), which works. However, `a_context_utils.now_ms()` returns
`Result(Int, String)` from `node_ffi.mjs` which returns `Ok(Date.now())`.

If `hook_on_agent_end` uses `pi_extension.now_ms()` and another module
uses `a_context_utils.now_ms()`, they get different types. The code in
`hook_on_agent_end` uses `now_ms()` directly for arithmetic
(`elapsed = now - idle_since`), which works only if `now_ms()` returns
an `Int`, not a `Result`.

---

## 119. COMMAND MODULE DEEP ANALYSIS

### 119a. `command_listen.gleam` — Hardcoded System Prompt

File: [command_listen.gleam:17-21](src/command_listen.gleam#L17-L21)

```gleam
let system_prompt =
  "You are the Autonomic Agentbot (A-agentbot). ..."
```

The system prompt is hardcoded instead of being loaded from the database
(`agent_souls` table). This means:
1. Any changes to the soul content in the database are ignored
2. The prompt doesn't include A's jobs or project state
3. It's a simplified version of the full A prompt

### 119b. `command_reload.gleam` — Swallows Errors

File: [command_reload.gleam:8-10](src/command_reload.gleam#L8-L10)

```gleam
promise.map(ctx_reload(ctx), fn(_) {
  notify_info(ctx, "Extensions reloaded. Monitor updated.")
  Ok("Extensions reloaded.")
})
```

The `fn(_)` ignores the result of `ctx_reload()`. If the reload fails,
the user still sees "Extensions reloaded." This is misleading.

---

## 120. SYSTEM PROMPT COMPOSITION BUGS

### 120a. `compose()` Ignores Budget

File: [system_prompt_types.gleam](src/system_prompt_types.gleam)

```gleam
pub fn compose(comp: PromptComposition) -> String {
  let sorted = list.sort(comp.components, compare_by_priority)
  sorted
  |> list.map(fn(c) { ... })
  |> string.join("\n\n")
}
```

The `compose()` function includes ALL components regardless of budget.
There's a separate `compose_within_budget()` function that respects the
budget, but `a_prompt_builder.gleam` calls `compose()`, not
`compose_within_budget()`.

This means the token budget is calculated but never enforced. The system
prompt could exceed the context window.

### 120b. `estimate_tokens` — Naive Character-Based Estimation

```gleam
pub fn estimate_tokens(text: String) -> Int {
  string.length(text) / 4 + 1
}
```

This estimates 1 token per 4 characters. For English text, the actual
ratio is closer to 1 token per 4 characters (for GPT-style tokenizers).
But for code with many short identifiers, the ratio is much higher
(closer to 1:2). This underestimates token count for code-heavy prompts.

---

## 121. MONITOR_AI DEEP ANALYSIS

### 121a. `auto_file_issue()` — Uses `type` Instead of `issue_type`

File: [monitor_ai.gleam:562-564](src/monitor_ai.gleam#L562-L564)

```sql
INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment)
```

The column is `issue_type` in the database (migration 015), but the
INSERT uses `type`. This will fail with:
```
ERROR: column "type" of relation "issues" does not exist
```

### 121b. `auto_file_issue()` — Missing `project_id` Column

The INSERT also doesn't include `project_id`, which has no default value
in the migration (it's nullable but should be set). This will insert
rows with `project_id = NULL`, which won't be found by the default
filter in `issue_db.list()`.

### 121c. `check_safety()` — Wrong Threshold Logic

File: [monitor_ai.gleam:410-415](src/monitor_ai.gleam#L410-L415)

```gleam
let critical_threshold = 3
let critical_issues = health.open_issues
let should_block = critical_issues > critical_threshold
```

The function uses `open_issues` (ALL open issues, not just critical ones)
and compares against a threshold of 3. The variable name `critical_issues`
is misleading — it's actually `open_issues`. The safety check blocks
when there are more than 3 open issues of ANY severity, not just critical.

### 121d. `get_work_suggestions()` — `skills WHERE status = 'PENDING'`

File: [monitor_ai.gleam:354](src/monitor_ai.gleam#L354)

```sql
FROM skills WHERE status = 'PENDING'
```

But the migration 020 defines the CHECK constraint as:
```sql
CHECK (status IN ('pending', 'approved', 'rejected', 'blocked', 'installed', 'uninstalled'))
```

The CHECK allows lowercase `'pending'`, but the query uses uppercase
`'PENDING'`. This is case-sensitive in PostgreSQL. The query will return
0 rows if skills have lowercase status values.

### 121e. `prepare_context()` — UNION ALL Between `memory` and `code_versions`

File: [monitor_ai.gleam:107-117](src/monitor_ai.gleam#L107-L117)

```sql
SELECT 'learning' as type_, content, saved_at::text 
FROM memory 
WHERE agent_id = $1 AND source = 'learn'
UNION ALL
SELECT 'backup' as type_, file_path as content, saved_at::text
FROM code_versions
WHERE saved_by = $1
ORDER BY saved_at DESC
```

The `UNION ALL` combines rows from `memory` and `code_versions` but:
1. The `content` column from `memory` is the actual content text
2. The `file_path` from `code_versions` is aliased as `content`
3. These are semantically different things being mixed in the same column

The decoder (`context_row_decoder`) treats them identically, producing
output like `learning: some insight text` and `backup: /path/to/file`.
This is confusing for the LLM.

---

## 122. A_DB_READER DEEP ANALYSIS

### 122a. `is_s_still_idle()` — Missing `agent_type = 'S'` Filter

File: [a_db_reader.gleam:31-34](src/a_db_reader.gleam#L31-L34)

```sql
SELECT COUNT(*) as cnt FROM agent_sessions 
WHERE status = 'alive' AND last_heartbeat > NOW() - INTERVAL '5 minutes'
```

This counts ALL alive sessions, not just S-bot sessions. If A-bot has
an active session, the count will be > 0 and `is_s_still_idle` returns
`False`, even though S is idle.

But since `agent_sessions` is never populated (see §118b), this function
always returns `True` (count = 0). The bug is latent — it will manifest
once `agent_sessions` is actually used.

### 122b. `read_soul_from_db()` — Concatenates Soul Content

File: [a_db_reader.gleam:60+](src/a_db_reader.gleam#L60)

The function reads the `content` column from `agent_souls` where
`id_prefix = 'A'`. But the A-bot's soul content in the database is a
full markdown document (see migration 008). The function returns this
as a single string, which is then used as a system prompt component.

The issue: if the soul content in the database is outdated (e.g., the
migration was run with an older version), the A-bot will use stale
instructions. There's no mechanism to update the soul content from the
codebase.

### 122c. `read_active_tasks()` — References `is_stuck` Column

File: [a_db_reader.gleam:114](src/a_db_reader.gleam#L114)

```sql
SELECT id::text, title, status, priority, is_stuck
FROM tasks WHERE status NOT IN ('COMPLETED','FAILED','FAKE_COMPLETE')
```

The `is_stuck` column doesn't exist in migration 010. If it was added
manually, there's no migration for it. On a fresh database, this query
will fail.

---

## 123. REVISED BUG COUNT — FINAL v4

| Category                           | Count                                                                                                                 |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `::text` cast missing (UUID+tstz)  | 28 (comprehensive audit, see §113)                                                                                    |
| Missing NOT NULL columns in INSERT | 10 (+2: auto_file_issue missing project_id, inter_review missing columns from migration)                              |
| Wrong column names                 | 4 (+1: auto_file_issue `type`→`issue_type`)                                                                           |
| Decoder mismatch                   | 5                                                                                                                     |
| Missing type variants              | 2 (+1: skill source `generated`/`imported` not in Gleam, `ai-built` not in DB CHECK)                                  |
| Logic bugs                         | 11 (+2: check_safety wrong variable, get_work_suggestions case mismatch)                                              |
| FFI issues                         | 8                                                                                                                     |
| Config system fragmentation        | 2                                                                                                                     |
| Seed/bootstrap gaps                | 8 (+1: seed.gleam uses minimal soul content vs migration full content)                                                |
| Dead code                          | 3                                                                                                                     |
| Stub implementations               | 1                                                                                                                     |
| Race conditions / concurrency      | 4                                                                                                                     |
| Extension generation bugs          | 6                                                                                                                     |
| A/S lifecycle logic failures       | 7 (+1: agent_start doesn't create session, so is_s_still_idle always True)                                            |
| Tool execution flow bugs           | 4                                                                                                                     |
| Hook module bugs                   | 7 (+2: hook_on_tool_result sync vs async, hook_on_agent_end now_ms type mismatch)                                     |
| Command module bugs                | 2                                                                                                                     |
| DB module bugs                     | 4                                                                                                                     |
| A/S DB reader bugs                 | 5 (+1: read_active_tasks references is_stuck column not in migration)                                                 |
| Monitor AI bugs                    | 6 (+2: auto_file_issue wrong column + missing project_id, prepare_context semantic mismatch)                          |
| Event hooks bugs                   | 3                                                                                                                     |
| Node PG FFI bugs                   | 1                                                                                                                     |
| Inter-review bugs                  | 5 (+1: missing migration for branch/context columns)                                                                  |
| Tool commit bugs                   | 2                                                                                                                     |
| Tool consult bugs                  | 1                                                                                                                     |
| Code version bugs                  | 1                                                                                                                     |
| Meeting bugs                       | 2                                                                                                                     |
| Agent identity bugs                | 3                                                                                                                     |
| Task bugs                          | 3                                                                                                                     |
| Issue bugs                         | 3                                                                                                                     |
| Broadcast bugs                     | 4                                                                                                                     |
| Agents bugs                        | 2                                                                                                                     |
| Stats bugs                         | 3                                                                                                                     |
| Monitor module bugs                | 3                                                                                                                     |
| A orchestrator bugs                | 2                                                                                                                     |
| A prompt builder bugs              | 2                                                                                                                     |
| Simple migrate bugs                | 4 (+2: migration numbering collision, split_statements breaks PL/pgSQL)                                               |
| System prompt types bugs           | 2                                                                                                                     |
| A context utils bugs               | 2                                                                                                                     |
| Extension generator bugs           | 2                                                                                                                     |
| FFI node_ffi.mjs bugs              | 3                                                                                                                     |
| FFI pi_extension_ffi.mjs bugs      | 5                                                                                                                     |
| FFI agent_identity_ffi.mjs bugs    | 1                                                                                                                     |
| FFI time_utils_ffi.mjs bugs        | 1                                                                                                                     |
| Migration schema bugs              | 4 (numbering collision, skills source CHECK mismatch, tasks status case inconsistency, inter_reviews missing columns) |
| **TOTAL CONFIRMED BUGS**           | **155**                                                                                                               |

---

## 124. SYSTEMIC ROOT CAUSES

### 124a. No Integration Testing

Gleam unit tests validate pure functions (decoders, type conversions) but
never test against a real database or Pi SDK. The `::text` cast bugs,
column name mismatches, and decoder mismatches would all be caught by
integration tests that run a query and decode the result.

### 124b. No Schema Validation

There is no mechanism to verify that Gleam code matches the database
schema. The Squirrel library (type-safe SQL query builder for Gleam)
was mentioned in the refers directory but is not used. Without it, every
SQL query is a string that can drift from the schema.

### 124c. No Migration Tracking

`simple_migrate.gleam` re-runs all migrations every time. There is no
`schema_migrations` table to track which migrations have been applied.
This means:
1. Migrations must be idempotent (all use `IF NOT EXISTS`)
2. No way to add destructive changes (ALTER COLUMN, DROP COLUMN)
3. No way to know the current schema version
4. Performance waste on every startup

### 124d. Dual Config Systems

The `psypi_config` database table and the in-memory `_configStore` in
`pi_extension_ffi.mjs` are never synchronized. The database has
`monitor_debounce_ms = 300000` (5 minutes), but the in-memory store
may have a different value. The debounce logic in `hook_on_agent_end`
reads from the in-memory store, not the database.

### 124e. No Error Propagation

Many functions swallow errors and return `Ok(Nil)` or `Ok("...")`:
- `hook_on_before_agent_start` returns Ok with fallback prompt on soul load failure
- `command_reload` returns Ok on reload failure
- `a_db_reader.is_s_still_idle` returns True on decode failure
- `monitor_ai.analyze_and_act` returns Ok with "unknown" action on decode failure
- `event_hooks.record_trigger` returns Ok even if UPDATE matches 0 rows

This makes debugging extremely difficult because errors are silently
swallowed and the system appears to work while producing wrong results.

### 124f. No Type-Safe Database Access

Every SQL query is a raw string with no compile-time verification.
Column names, table names, and parameter types are all unchecked until
runtime. This is the root cause of the `type` vs `issue_type`,
`status` vs `issue_status`, and missing `::text` cast bugs.

### 124g. FFI Boundary Is Unvalidated

The Gleam-to-JavaScript FFI boundary has no validation layer. Functions
like `gleamValueToJson`, `unwrapGleamResult`, and `call_monitor` make
assumptions about JavaScript object shapes that may not hold. When they
fail, they fail silently or produce garbage output.

### 124h. Circular Dependency Between Config Systems

The debounce value is stored in `psypi_config` (database) but read from
`_configStore` (in-memory). The in-memory store is populated by
`set_config()` calls, but `psypi_config` is populated by `seed.gleam`
and migrations. Neither system reads from the other, creating a
configuration gap.

---

## 125. LIVE DATABASE vs. MIGRATIONS — CATASTROPHIC GAP

### 125a. 115 Tables in Live DB, Only 21 in Migrations

Live database tables: **115**
Migration-covered tables: **21** (18%)
**Untracked tables: 94 (82%)**

The following tables are used by Gleam code but have NO migration:

| Table             | Used By                   | Risk                              |
| ----------------- | ------------------------- | --------------------------------- |
| `projects`        | db.gleam (hardcoded UUID) | Fresh DB has no project row       |
| `agent_identity`  | agent_identity.gleam      | Different from `agent_identities` |
| `memories`        | memory.gleam              | Different from `memory`           |
| `conversations`   | (future)                  | No Gleam code yet                 |
| `reflections`     | (future)                  | No Gleam code yet                 |
| `system_reviews`  | (future)                  | No Gleam code yet                 |
| `scheduled_tasks` | (future)                  | No Gleam code yet                 |
| `task_templates`  | (future)                  | No Gleam code yet                 |
| `mcp_configs`     | (future)                  | No Gleam code yet                 |
| `users`           | (future)                  | No Gleam code yet                 |
| `subscriptions`   | (future)                  | No Gleam code yet                 |
| `payments`        | (future)                  | No Gleam code yet                 |

**Impact**: A fresh `psql -c "DROP DATABASE psypi; CREATE DATABASE psypi;"`
followed by `gleam run -m simple_migrate && gleam run -m seed` will produce
a database that is MISSING 94 tables, 336 SQL functions, and most column
additions. The system will be completely non-functional.

### 125b. `tasks` Table: 60 Columns in Live DB, 14 in Migration

Migration 010 creates 14 columns. The live database has 60 columns.
The additional 46 columns were added manually or by other AI agents.

Columns used by Gleam code but NOT in migration 010:
- `project_id` (added by migration 025, but as UUID not TEXT)
- `is_stuck` (no migration at all)

### 125c. `inter_reviews` Table: 33 Columns in Live DB, 8 in Migration

Migration 024 creates 8 columns. The live database has 33 columns.
The additional 25 columns were added manually.

The `request_inter_review()` SQL function is NOT in any migration file.
It was created manually. On a fresh database, `inter_review.gleam:request_review()`
will fail with "function request_inter_review does not exist".

### 125d. `tasks.result` Column: JSONB in Live DB, TEXT in Migration

Migration 010 defines `result TEXT`. The live database has `result JSONB`.

The Gleam decoder uses `decode.optional(decode.string)` for the `result`
column. With JSONB, the pg driver returns a JavaScript object, not a string.
`decode.string` will fail for any non-null JSONB value.

This means `task.get()` and `task.list()` will fail for any task that has
a non-null `result` value.

### 125e. 339 SQL Functions in Live DB, 3 in Migrations

The live database has 339 SQL functions. Only 3 are in migrations:
- `save_code_version` (migration 014)
- `get_code_versions` (migration 014)
- `restore_code_version` (migration 014)

Key functions used by Gleam code but NOT in migrations:
- `request_inter_review` — used by `inter_review.gleam`
- `respond_to_inter_review` — exists in DB but not used by current Gleam code
- `update_inter_review` — exists in DB but not used by current Gleam code
- `git_branch_name` — exists in DB, could replace hardcoded "main"

### 125f. `agent_identity` vs `agent_identities` — Two Different Tables

The live database has BOTH:
- `agent_identity` — used by `agent_identity.gleam`
- `agent_identities` — created by migration 011

These are DIFFERENT tables with DIFFERENT schemas. The Gleam code
references `agent_identity` (singular), but the migration creates
`agent_identities` (plural). This means:
1. Migration 011 creates a table that Gleam doesn't use
2. The table Gleam DOES use has no migration
3. On a fresh database, `agent_identity.gleam` will fail

### 125g. `memory` vs `memories` — Two Different Tables

Similarly, the live database has BOTH:
- `memory` — created by migration 017, used by `memory.gleam`
- `memories` — no migration, not used by current Gleam code

The `memories` table has vector search capabilities (pgvector) that
`memory` doesn't. This suggests a planned migration from `memory` to
`memories` that was never completed.

---

## 126. TASK.RESULT JSONB DECODE FAILURE — CONFIRMED

### 126a. `task.gleam` Decoder Expects String, Gets Object

File: [task.gleam](src/task.gleam)

```gleam
fn task_decoder() -> decode.Decoder(Task) {
  ...
  use result <- decode.field("result", decode.optional(decode.string))
  ...
}
```

But the live database column `tasks.result` is `jsonb`. The PostgreSQL
driver returns a JavaScript object for JSONB columns, not a string.
`decode.string` will fail with a DecodeError for any non-null value.

This affects:
- `task.list()` — fails for any task with result
- `task.get()` — fails for any task with result
- `task.complete()` — only returns id, not affected

### 126b. Same Issue for `inter_reviews` JSONB Columns

The `inter_reviews` table has 5 JSONB columns:
- `findings` (jsonb)
- `suggestions` (jsonb)
- `issues` (jsonb)
- `praise` (jsonb)
- `review_context` (jsonb)

The Gleam `review_decoder()` doesn't decode these columns (it only
selects `id, task_id, status, summary, overall_score, requested_at`),
so it's not affected. But any future code that tries to read these
columns will face the same JSONB decode issue.

---

## 127. REVISED BUG COUNT — FINAL v5

| Category                           | Count                                                                                |
| ---------------------------------- | ------------------------------------------------------------------------------------ |
| `::text` cast missing (UUID+tstz)  | 28                                                                                   |
| Missing NOT NULL columns in INSERT | 10                                                                                   |
| Wrong column names                 | 4                                                                                    |
| Decoder mismatch                   | 7 (+2: task.result JSONB decoded as string, inter_reviews JSONB columns not handled) |
| Missing type variants              | 2                                                                                    |
| Logic bugs                         | 11                                                                                   |
| FFI issues                         | 8                                                                                    |
| Config system fragmentation        | 2                                                                                    |
| Seed/bootstrap gaps                | 9 (+1: 94 tables have no migrations, fresh DB is non-functional)                     |
| Dead code                          | 3                                                                                    |
| Stub implementations               | 1                                                                                    |
| Race conditions / concurrency      | 4                                                                                    |
| Extension generation bugs          | 6                                                                                    |
| A/S lifecycle logic failures       | 7                                                                                    |
| Tool execution flow bugs           | 4                                                                                    |
| Hook module bugs                   | 7                                                                                    |
| Command module bugs                | 2                                                                                    |
| DB module bugs                     | 4                                                                                    |
| A/S DB reader bugs                 | 5                                                                                    |
| Monitor AI bugs                    | 6                                                                                    |
| Event hooks bugs                   | 3                                                                                    |
| Node PG FFI bugs                   | 1                                                                                    |
| Inter-review bugs                  | 6 (+1: request_inter_review function not in migrations)                              |
| Tool commit bugs                   | 2                                                                                    |
| Tool consult bugs                  | 1                                                                                    |
| Code version bugs                  | 1                                                                                    |
| Meeting bugs                       | 2                                                                                    |
| Agent identity bugs                | 4 (+1: agent_identity vs agent_identities table confusion)                           |
| Task bugs                          | 4 (+1: result column JSONB vs TEXT mismatch)                                         |
| Issue bugs                         | 3                                                                                    |
| Broadcast bugs                     | 4                                                                                    |
| Agents bugs                        | 2                                                                                    |
| Stats bugs                         | 3                                                                                    |
| Monitor module bugs                | 3                                                                                    |
| A orchestrator bugs                | 2                                                                                    |
| A prompt builder bugs              | 2                                                                                    |
| Simple migrate bugs                | 4                                                                                    |
| System prompt types bugs           | 2                                                                                    |
| A context utils bugs               | 2                                                                                    |
| Extension generator bugs           | 2                                                                                    |
| FFI node_ffi.mjs bugs              | 3                                                                                    |
| FFI pi_extension_ffi.mjs bugs      | 5                                                                                    |
| FFI agent_identity_ffi.mjs bugs    | 1                                                                                    |
| FFI time_utils_ffi.mjs bugs        | 1                                                                                    |
| Migration schema bugs              | 5 (+1: task.result TEXT vs JSONB, 94 untracked tables)                               |
| **TOTAL CONFIRMED BUGS**           | **163**                                                                              |

---

## 128. ARCHITECTURE ASSESSMENT — CAN THIS SYSTEM EVER WORK?

### 128a. Current State: Non-Functional

Based on the evidence gathered in this review, the psypi system is
**non-functional in its current state**. Here's why:

1. **Every tool that reads a UUID column fails** — 28+ instances of
   missing `::text` casts mean every database read returns DecodeError

2. **Every tool that reads a JSONB column fails** — `task.result` is
   JSONB but decoded as string

3. **The inter-review flow is broken** — `request_inter_review` function
   is not in migrations, `record_review_score` doesn't update status,
   and `tool_commit` can never succeed

4. **The A/S agent model is broken** — `agent_sessions` is never
   populated, `is_s_still_idle` always returns True, identity can flip

5. **Tool results are garbled** — `gleamValueToJson` produces
   `{0: val, 1: val}` instead of named fields for all custom types

6. **Fresh database setup is impossible** — 94 of 115 tables have no
   migrations, 336 of 339 SQL functions have no migrations

### 128b. What Would It Take to Fix?

**Phase 1: Stop the Bleeding (Critical Path to Basic Functionality)**

1. Add `::text` casts to ALL UUID and TIMESTAMPTZ columns in ALL queries
2. Fix `gleamValueToJson` to handle Gleam custom types correctly
3. Fix `task.result` decoder to handle JSONB
4. Add `project_id` to all INSERT statements that need it
5. Fix `auto_file_issue` column names (`type` → `issue_type`)
6. Fix `issue_db.build_where` parameter reversal

**Phase 2: Make Inter-Review Work**

1. Add `request_inter_review` function to migrations
2. Add `complete_review` function that updates both `overall_score` and `status`
3. Wire `tool_commit` to call `complete_review` after A-bot responds
4. Fix `inter_reviews` migration to include all live columns

**Phase 3: Make A/S Agent Model Work**

1. Populate `agent_sessions` in `hook_on_agent_start`
2. Add `agent_type = 'S'` filter to `is_s_still_idle`
3. Unify config systems (load `psypi_config` into `_configStore` on startup)
4. Fix identity assignment to prevent A/S flip

**Phase 4: Make Fresh Database Setup Work**

1. Dump the live database schema as the authoritative migration
2. Create a single `000_initial_schema.sql` that creates ALL 115 tables
3. Add all 339 SQL functions to migrations
4. Create a proper `seed.sql` with all required initial data

### 128c. Root Cause: No Schema-as-Code Discipline

The fundamental problem is that the database schema evolved through
manual SQL commands and AI agent interventions, with no migration
tracking. The Gleam code was written against the live schema, but
the migrations only cover 18% of the tables. This means:

1. No reproducible database setup
2. No way to track schema changes
3. No way to roll back bad changes
4. No way to set up a test database
5. No way to deploy to a new environment

The Gleam code is effectively coupled to a specific database state
that exists only on the developer's machine.

---

## 129. EMPIRICAL TYPE VERIFICATION — UUID vs TIMESTAMPTZ vs JSONB

### 129a. Node-Postgres Type Parsing (Verified with Live Test)

Tested against the live `psypi` database using `node -e`:

| PostgreSQL Type | JS Type Returned | `decode.string` Works?   | Needs `::text`? |
| --------------- | ---------------- | ------------------------ | --------------- |
| UUID            | `string`         | Yes                      | No              |
| TIMESTAMPTZ     | `Date` (object)  | No — DecodeError         | Yes             |
| JSONB           | `Object`         | No — DecodeError         | Yes             |
| TEXT            | `string`         | Yes                      | No              |
| INTEGER         | `number`         | No — needs `decode.int`  | No              |
| BOOLEAN         | `boolean`        | No — needs `decode.bool` | No              |
| BIGINT (COUNT)  | `string`         | Yes (parse to int)       | No              |

### 129b. Correction to Earlier Review

Earlier sections (§113) claimed 28+ instances of missing `::text` casts
for UUID columns. This was **incorrect**. UUID columns are returned as
strings by node-postgres and do NOT need `::text` casts.

The actual `::text` cast requirement is ONLY for:
- **TIMESTAMPTZ columns** — 8 confirmed instances missing `::text`
- **JSONB columns** — 3 confirmed instances missing `::text`

### 129c. TIMESTAMPTZ Columns Missing `::text` Cast

| File               | Column(s)                                   | Line(s)       |
| ------------------ | ------------------------------------------- | ------------- |
| inter_review.gleam | `requested_at`                              | 148, 283, 285 |
| memory.gleam       | `created_at` (via `SELECT *`)               | 101           |
| areflect.gleam     | `created_at` (in ORDER BY only, not SELECT) | 143           |

### 129d. JSONB Columns Missing `::text` Cast

| File        | Column(s)                                               | Line(s)  |
| ----------- | ------------------------------------------------------- | -------- |
| task.gleam  | `result` (decoded as `decode.string` but is JSONB)      | 63       |
| skill.gleam | `content` (inconsistent: some queries cast, some don't) | 184, 214 |
| skill.gleam | `reference_list` (inconsistent)                         | 184, 214 |

### 129e. `memory.gleam:search()` Uses `SELECT *`

The `search()` function uses `SELECT * FROM memory` which returns ALL
columns including `created_at` (TIMESTAMPTZ). The decoder expects
`created_at` as a string, but node-postgres returns a `Date` object.
This will cause a DecodeError for every row.

---

## 130. `gleamValueToJson` — DEAD CODE AND SUBTLE BUGS

### 130a. `startsWith('Type$Type')` Checks Never Match

The `gleamValueToJson` function in `pi_extension_ffi.mjs` has 15
`startsWith` checks for custom types like `Task$Task`, `Issue$Issue`,
`Stats$Stats`, etc. But the compiled Gleam classes have constructor
names like `Task`, `Issue`, `Stats` (without the `$Type` suffix).

Verified by inspecting compiled output:
```javascript
// build/dev/javascript/psypi/stats.mjs
export class Stats extends $CustomType { ... }
// NOT: class Stats$Stats
```

The `Stats$Stats` is an alias function, not a class name:
```javascript
export const Stats$Stats = (tasks, issues, skills, meetings) =>
  new Stats(tasks, issues, skills, meetings);
```

**Impact**: All 15 `startsWith` checks are dead code. They never match.
The function falls through to the generic handler, which works
correctly for named-field types but was not the intended behavior.

### 130b. Generic Handler Works by Accident

The generic handler at the bottom of `gleamValueToJson`:
```javascript
return Object.fromEntries(Object.entries(val).map(([k, v]) => [k, gleamValueToJson(v)]));
```

This works correctly because Gleam compiled types store fields as
named properties (`this.tasks`, `this.issues`), not numeric indices.
Verified: `Object.entries(new Stats(1,2,3,4))` returns
`[['tasks',1], ['issues',2], ['skills',3], ['meetings',4]]`.

So `r.value.tasks` in templates works correctly despite the dead code.

### 130c. `Ok`/`Error` Name Collision with JavaScript Built-ins

The Gleam `Ok` and `Error` types have constructor names `Ok` and
`Error`. The `Error` name collides with the JavaScript built-in
`Error` class. In `gleamValueToJson`, the check:
```javascript
if (name === 'Error') return { ok: false, error: gleamValueToJson(val['0'] ?? val[0]) };
```

This will match BOTH Gleam `Error` variants AND JavaScript `Error`
objects. If a JavaScript `Error` is passed to `gleamValueToJson`, it
will be incorrectly treated as a Gleam `Error` variant.

---

## 131. `areflect.gleam:save_issue()` — MISSING `project_id` (NOT NULL)

### 131a. The Bug

```gleam
fn save_issue(conn, content, agent_id) {
  let sql = "
    INSERT INTO issues (title, description, severity, created_by)
    VALUES ($1, $2, 'medium', $3)
  "
```

The `issues` table has `project_id UUID NOT NULL` with no default.
This INSERT will fail with:
```
null value in column "project_id" violates not-null constraint
```

### 131b. Same for `monitor_ai.gleam:auto_file_issue()`

```gleam
let sql = "
  INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment)
  VALUES ($1, $2, 'high', 'bug', 'monitor', 'monitor', 'development')
  RETURNING id
"
```

This INSERT also omits `project_id` AND uses `type` instead of
`issue_type`. It will fail for TWO reasons.

### 131c. `areflect.gleam:save_task()` Works by Accident

The `tasks` table has `project_id UUID NOT NULL DEFAULT '0d324e68-...'`,
so omitting `project_id` in the INSERT works because the default kicks in.

---

## 132. DUAL CONFIG SYSTEM — DEBOUNCE MISMATCH

### 132a. Two Separate Config Stores

1. **Database**: `psypi_config` table, read by `psypi_config.gleam`
2. **In-memory**: `_configStore` object in `pi_extension_ffi.mjs`,
   read by `pi_extension.get_config()`

These two stores are NEVER synchronized. The `hook_on_agent_end`
uses the in-memory store for `idle_since` and `monitor_debounce_ms`,
but the database is the authoritative source.

### 132b. Debounce Value Mismatch

Database: `monitor_debounce_ms = 900000` (15 minutes)
In-memory: `get_config("monitor_debounce_ms")` returns `null`
Fallback in code: `300000` (5 minutes)

The actual debounce is 5 minutes (hardcoded fallback), not 15 minutes
(database value). The database value is completely ignored.

### 132c. `idle_since` Never Persists Across Restarts

The `idle_since` value is stored in `_configStore` (in-memory). When
the Pi extension restarts, `_configStore` is reset to `{}`, and
`idle_since` is lost. This means:
- After restart, the A-bot debounce timer resets
- The A-bot may wake up prematurely after a restart

---

## 133. `tool_commit.gleam` — INTER-REVIEW FLOW ANALYSIS

### 133a. Phase 1: Trigger Review

`trigger_review()` calls `inter_review.request_review()` which calls
the `request_inter_review()` SQL function. This function:
1. Checks for existing pending/in_progress review for the task
2. If exists, returns existing review_id
3. Otherwise, creates new review with `status='pending'`

This part works correctly.

### 133b. Phase 2: Commit if Reviewed

`commit_if_reviewed()` calls `inter_review.get_review_details()` which
queries `inter_reviews` for `id, task_id, status, summary, overall_score,
requested_at`. It checks:
1. If `overall_score` is `None` → "Review not yet complete"
2. If `overall_score >= 50` → proceed with `git commit`
3. If `overall_score < 50` → "Review score too low"

### 133c. The Broken Link: Who Updates `overall_score`?

The `request_inter_review()` function creates a review with
`status='pending'` and `overall_score=NULL`. The A-bot is supposed
to review the code and update the score. But:

1. The A-bot's `a_orchestrator.run_a_workflow()` calls
   `call_monitor()` to get LLM response
2. The LLM response is sent via `pi_send_message()` as a message
3. **Nobody writes the review score back to the database**
4. `overall_score` remains NULL forever
5. `commit_if_reviewed()` always returns "Review not yet complete"

The `respond_to_inter_review()` and `update_inter_review()` SQL
functions exist in the database but are never called by any Gleam code.

### 133d. `git add` is Never Called

`tool_commit.gleam` runs `git commit -m "..."` but never runs
`git add` first. The commit will fail with "nothing to commit"
unless the files were already staged.

---

## 134. `tool_consult.gleam` — STUB IMPLEMENTATION

The `on_consult()` function is a stub that returns:
```
[Autonomic] Consult request: <question>
The S-worker should address this in its next turn.
```

It does NOT actually consult the A-bot. The Pi tool
`psypi-consult-autonomic` is registered and available to the S-bot,
but it does nothing useful.

---

## 135. `memory.gleam:save()` — DECODER MISMATCH

### 135a. `RETURNING id` vs Full Decoder

```gleam
let sql = "
  INSERT INTO memory (content, tags, source, importance, agent_id)
  VALUES ($1, $2, $3, $4, $5)
  RETURNING id
"
// ...
case decode.run(row, memory_decoder()) {
  Ok(mem) -> Ok(mem.id)
```

The `RETURNING id` query returns a single column (`id`), but
`memory_decoder()` expects 7 fields (`id, content, tags, source,
agent_id, importance, created_at`). The decode will fail because
the other 6 fields are missing.

**Fix**: Use a simple `id_decoder()` instead of `memory_decoder()`.

### 135b. `learning.gleam:save_learning()` — Audit Trigger Issue

The `save_learning()` function inserts with `source='learn'`, but
the `audit_direct_insert` trigger's `v_allowed_sources` array does
NOT include `'learn'`. It includes `'areflect'` but not `'learn'`.

This means every learning insert triggers an audit entry and
potentially a notification to the project_communications table.

---

## 136. REVISED BUG COUNT — FINAL v6

| Category                           | Count                                                                                          |
| ---------------------------------- | ---------------------------------------------------------------------------------------------- |
| `::text` cast missing (TSTZ+JSONB) | 11 (8 TSTZ + 3 JSONB, corrected from 28 UUID claims)                                           |
| Missing NOT NULL columns in INSERT | 10                                                                                             |
| Wrong column names                 | 4                                                                                              |
| Decoder mismatch                   | 8 (+3: task.result JSONB as string, memory.save decoder mismatch, memory.search SELECT * TSTZ) |
| Missing type variants              | 2                                                                                              |
| Logic bugs                         | 11                                                                                             |
| FFI issues                         | 9 (+1: gleamValueToJson dead code — all startsWith checks never match)                         |
| Config system fragmentation        | 3 (+1: debounce value mismatch DB vs in-memory)                                                |
| Seed/bootstrap gaps                | 9                                                                                              |
| Dead code                          | 4 (+1: gleamValueToJson startsWith checks are dead code)                                       |
| Stub implementations               | 2 (+1: tool_consult is a stub)                                                                 |
| Race conditions / concurrency      | 4                                                                                              |
| Extension generation bugs          | 6                                                                                              |
| A/S lifecycle logic failures       | 7                                                                                              |
| Tool execution flow bugs           | 4                                                                                              |
| Hook module bugs                   | 7                                                                                              |
| Command module bugs                | 2                                                                                              |
| DB module bugs                     | 4                                                                                              |
| A/S DB reader bugs                 | 5                                                                                              |
| Monitor AI bugs                    | 6                                                                                              |
| Event hooks bugs                   | 3                                                                                              |
| Node PG FFI bugs                   | 1                                                                                              |
| Inter-review bugs                  | 7 (+1: nobody writes overall_score back, respond_to_inter_review never called)                 |
| Tool commit bugs                   | 3 (+1: git add never called)                                                                   |
| Tool consult bugs                  | 2 (+1: stub implementation)                                                                    |
| Code version bugs                  | 1                                                                                              |
| Meeting bugs                       | 2                                                                                              |
| Agent identity bugs                | 4                                                                                              |
| Task bugs                          | 4                                                                                              |
| Issue bugs                         | 3                                                                                              |
| Broadcast bugs                     | 4                                                                                              |
| Agents bugs                        | 2                                                                                              |
| Stats bugs                         | 3                                                                                              |
| Monitor module bugs                | 3                                                                                              |
| A orchestrator bugs                | 2                                                                                              |
| A prompt builder bugs              | 2                                                                                              |
| Simple migrate bugs                | 4                                                                                              |
| System prompt types bugs           | 2                                                                                              |
| A context utils bugs               | 2                                                                                              |
| Extension generator bugs           | 2                                                                                              |
| FFI node_ffi.mjs bugs              | 3                                                                                              |
| FFI pi_extension_ffi.mjs bugs      | 6 (+1: Error name collision with JS built-in)                                                  |
| FFI agent_identity_ffi.mjs bugs    | 1                                                                                              |
| FFI time_utils_ffi.mjs bugs        | 1                                                                                              |
| Migration schema bugs              | 5                                                                                              |
| **TOTAL CONFIRMED BUGS**           | **170**                                                                                        |

---

## 137. `a_db_reader.gleam:is_s_still_idle()` — ALWAYS RETURNS TRUE

### 137a. COUNT(*) Returns String, Not Number

The `count_decoder()` uses `decode.int`:
```gleam
fn count_decoder() -> decode.Decoder(Int) {
  use cnt <- decode.field("cnt", decode.int)
  decode.success(cnt)
}
```

But PostgreSQL `COUNT(*)` returns `bigint`, which node-postgres returns
as a JavaScript `string` (e.g., `"19"`). `decode.int` expects a
JavaScript `number`, so this decode ALWAYS fails.

Verified with live test:
```
typeof cnt: string
cnt: 19
```

### 137b. Decode Failure Fallback Returns True (S is idle)

When the decode fails, the code falls through to:
```gleam
Error(_) -> Ok(True)
```

This means `is_s_still_idle()` ALWAYS returns `Ok(True)`, regardless
of how many active sessions exist. The A-bot will ALWAYS think S is
idle and proceed with wake-up.

### 137c. Query Doesn't Filter by Agent Type

Even if the decode worked, the query:
```sql
SELECT COUNT(*) as cnt FROM agent_sessions
WHERE status = 'alive' AND last_heartbeat > NOW() - INTERVAL '5 minutes'
```

Counts ALL alive sessions (S-bot, A-bot, P-bot). The `agent_sessions`
table uses `agent_type = 'psypi'` for all entries and distinguishes
agents by `identity_id` prefix (`S-`, `A-`, `P-`). The query should
filter by `identity_id LIKE 'S-%'` to count only S-bot sessions.

### 137d. Fix

1. Use `COUNT(*)::INT as cnt` to cast to integer (like `issue_db.gleam`)
2. Add `AND identity_id LIKE 'S-%'` to filter by S-bot sessions
3. Or use `decode.string` then `int.parse` (like `stats.gleam`)

---

## 138. `issue_db.gleam:build_where()` — FILTER PARAMETER REVERSAL

### 138a. The Bug

The `build_where()` function builds conditions by PREPENDING:
```gleam
let #(conditions, params) = case status {
  Some(s) -> {
    let idx = list.length(params) + 1
    #(["status = $" <> string.inspect(idx), ..conditions],
      [dynamic.string(s), ..params])
  }
  ...
}
```

Then reverses conditions but NOT params:
```gleam
" WHERE " <> string.join(list.reverse(conditions), " AND ")
```

### 138b. Example

If `status = Some("open")` and `severity = Some("high")`:

After first case: conditions = ["status = $1"], params = ["open"]
After second case: conditions = ["severity = $2", "status = $1"], params = ["high", "open"]

After `list.reverse(conditions)`: ["status = $1", "severity = $2"]
But params = ["high", "open"]

So `$1` gets "high" (intended as severity) and `$2` gets "open"
(intended as status). **Filter values are swapped.**

### 138c. Impact

Any query with multiple filters will have the filter values swapped.
For example, listing issues with `status="open"` and `severity="high"`
would return issues with `status="high"` and `severity="open"`.

---

## 139. `broadcast.gleam:stats()` — PRIORITY TEXT COMPARISON

### 139a. The Bug

```sql
COUNT(*) FILTER (WHERE priority >= 2) as high_priority_count
```

The `priority` column is `text` type, not `integer`. The comparison
`priority >= 2` does string comparison, which is meaningless.

In ASCII, `'critical' >= '2'` is TRUE (because 'c' > '2'), so ALL
broadcasts would be counted as "high priority".

### 139b. Fix

Use string-based comparison:
```sql
COUNT(*) FILTER (WHERE priority IN ('high', 'critical'))
```

---

## 140. `broadcast.gleam:list()` — SEMANTIC MISMATCH: `read_at` AS `sent_at`

### 140a. The Bug

```sql
SELECT id, from_ai as agent_id, content as message, priority,
       'sent' as status, created_at::text, read_at::text as sent_at
FROM project_communications
```

The query maps `read_at` (when the broadcast was read) as `sent_at`
(when it was sent). These are semantically different. The
`project_communications` table doesn't have a `sent_at` column —
broadcasts are sent immediately on INSERT.

### 140b. Impact

The `Broadcast.sent_at` field shows when the broadcast was READ, not
when it was SENT. For unread broadcasts, `sent_at` will be NULL.

---

## 141. `skill.gleam:get()` AND `search()` — MISSING JSONB `::text` CASTS

### 141a. `list()` Has the Casts

```sql
SELECT id, name, description, source, status, safety_score, version, author,
       created_at::text, content::text, reference_list::text
FROM skills
```

### 141b. `get()` Does NOT

```sql
SELECT id, name, description, source, status, safety_score, version, author,
       created_at::text, content, reference_list
FROM skills
WHERE name = $1
```

`content` and `reference_list` are JSONB columns. Without `::text`,
node-postgres returns JavaScript objects, which `decode.optional(decode.string)`
cannot parse.

### 141c. `search()` Does NOT

Same issue — `content` and `reference_list` are missing `::text` casts.

### 141d. `SkillSource` Missing `AiBuilt` Variant

Database contains `source='ai-built'` but the Gleam type only has:
`Clawhub`, `Local`, `Generated`, `Imported`. The `ai-built` value
will cause `string_to_source()` to return `Error`, and the skill
will fail to decode.

---

## 142. `task.gleam` — JSONB `result` AND MISSING `project_id` IN SELECT

### 142a. `list()` — `result` Not Cast to `::text`

```sql
SELECT id, title, description, status, priority, result, error, retry_count,
       created_at::text, updated_at::text, completed_at::text, created_by, source,
       project_id::text
FROM tasks
```

`result` is JSONB but not cast to `::text`. `decode.optional(decode.string)`
will fail for non-null JSONB values.

### 142b. `get()` — `result` Not Cast AND `project_id` Missing

```sql
SELECT id, title, description, status, priority, result, error, retry_count,
       created_at::text, updated_at::text, completed_at::text, created_by, source
FROM tasks
WHERE id = $1
```

Two bugs:
1. `result` (JSONB) not cast to `::text`
2. `project_id` is NOT in the SELECT list, but `task_decoder()` expects it

The `task_decoder()` has:
```gleam
use project_id <- decode.field("project_id", decode.optional(decode.string))
```

Since `project_id` is missing from the query, `decode.field` will fail
with a missing field error. `task.get()` will ALWAYS return DecodeError.

---

## 143. `a_orchestrator.gleam` — NO BUDGET ENFORCEMENT

### 143a. `compose()` vs `compose_within_budget()`

The `system_prompt_types.gleam` module provides two functions:
- `compose()` — assembles all components into a string, no budget check
- `compose_within_budget()` — filters components to fit within token budget

The orchestrator uses `compose()`:
```gleam
let system_prompt = compose(a_prompt_builder.build_system_prompt(...))
```

This means the system prompt can exceed the token budget without any
warning or truncation. If the soul content, jobs, and context are large,
the prompt could exceed the model's context window.

### 143b. `compose_within_budget()` Has Order Bug

The `compose_within_budget()` function builds the `kept` list by
prepending (`[component, ..components]`), which reverses the order.
While `compose()` sorts by priority, any other consumer of the
`PromptComposition` returned by `compose_within_budget()` would get
components in reverse insertion order.

---

## 144. `meeting.gleam:create()` — MISSING `project_id`

```sql
INSERT INTO meetings (topic, created_by) VALUES ($1, $2) RETURNING id
```

The `meetings.project_id` column is nullable, so this INSERT succeeds,
but the meeting is created without a project association. All meetings
created through the Pi tool will have `project_id = NULL`.

---

## 145. `code_version.gleam:query_versions()` — `saved_at` NOT CAST

```sql
SELECT id, file_path, saved_by, saved_at,
       LEFT(content, 200) as content_preview,
       LENGTH(content) as content_length
FROM code_versions
```

`saved_at` is TIMESTAMPTZ but not cast to `::text`. However, this
function returns raw `List(dynamic.Dynamic)` without decoding, so
the TIMESTAMPTZ issue doesn't cause a decode failure. It would only
be a problem if the caller tries to use the `saved_at` field.

---

## 146. REVISED BUG COUNT — FINAL v7

| Category                           | Count                                                                                        |
| ---------------------------------- | -------------------------------------------------------------------------------------------- |
| `::text` cast missing (TSTZ+JSONB) | 15 (+4: skill.get/search JSONB, task.list/get JSONB result)                                  |
| Missing NOT NULL columns in INSERT | 10                                                                                           |
| Wrong column names                 | 4                                                                                            |
| Decoder mismatch                   | 11 (+3: a_db_reader COUNT as int, task.get missing project_id, memory.save decoder mismatch) |
| Missing type variants              | 3 (+1: SkillSource missing AiBuilt)                                                          |
| Logic bugs                         | 12 (+1: broadcast.stats text comparison)                                                     |
| FFI issues                         | 9                                                                                            |
| Config system fragmentation        | 3                                                                                            |
| Seed/bootstrap gaps                | 9                                                                                            |
| Dead code                          | 4                                                                                            |
| Stub implementations               | 2                                                                                            |
| Race conditions / concurrency      | 4                                                                                            |
| Extension generation bugs          | 6                                                                                            |
| A/S lifecycle logic failures       | 8 (+1: is_s_still_idle always returns True)                                                  |
| Tool execution flow bugs           | 4                                                                                            |
| Hook module bugs                   | 7                                                                                            |
| Command module bugs                | 2                                                                                            |
| DB module bugs                     | 4                                                                                            |
| A/S DB reader bugs                 | 7 (+2: COUNT bigint as string, no agent type filter)                                         |
| Monitor AI bugs                    | 6                                                                                            |
| Event hooks bugs                   | 3                                                                                            |
| Node PG FFI bugs                   | 1                                                                                            |
| Inter-review bugs                  | 7                                                                                            |
| Tool commit bugs                   | 3                                                                                            |
| Tool consult bugs                  | 2                                                                                            |
| Code version bugs                  | 1 (+1: saved_at not cast but returns raw Dynamic)                                            |
| Meeting bugs                       | 3 (+1: missing project_id in create)                                                         |
| Agent identity bugs                | 4                                                                                            |
| Task bugs                          | 6 (+2: result JSONB not cast, get() missing project_id in SELECT)                            |
| Issue bugs                         | 4 (+1: build_where filter parameter reversal)                                                |
| Broadcast bugs                     | 6 (+2: stats text comparison, read_at as sent_at)                                            |
| Skill bugs                         | 3 (+1: get/search missing JSONB casts)                                                       |
| Agents bugs                        | 2                                                                                            |
| Stats bugs                         | 3                                                                                            |
| Monitor module bugs                | 3                                                                                            |
| A orchestrator bugs                | 3 (+1: no budget enforcement)                                                                |
| A prompt builder bugs              | 2                                                                                            |
| Simple migrate bugs                | 4                                                                                            |
| System prompt types bugs           | 3 (+1: compose_within_budget order reversal)                                                 |
| A context utils bugs               | 2                                                                                            |
| Extension generator bugs           | 2                                                                                            |
| FFI node_ffi.mjs bugs              | 3                                                                                            |
| FFI pi_extension_ffi.mjs bugs      | 6                                                                                            |
| FFI agent_identity_ffi.mjs bugs    | 1                                                                                            |
| FFI time_utils_ffi.mjs bugs        | 1                                                                                            |
| Migration schema bugs              | 5                                                                                            |
| **TOTAL CONFIRMED BUGS**           | **189**                                                                                      |

---

## 147. CROSS-MODULE FLOW ANALYSIS — A/S LIFECYCLE AS RUNNING LOGIC CHAIN

This section traces the complete A/S agent lifecycle from session
start to A-bot wake-up, identifying every point where bugs compound
to break the intended behavior.

### 147a. Session Start Flow

```
Pi TUI starts → extension.js loaded → hooks registered
     ↓
session_start hook fires → event_hooks.record_trigger("session_start")
     ↓
before_agent_start hook fires → hook_on_before_agent_start.gleam
     ↓
  1. event_hooks.record_trigger("before_agent_start") — records trigger
  2. s_db_reader.read_s_soul_from_db() — loads S-bot soul
     ↓
  Soul content returned → injected into S-bot's system prompt
```

**Bugs in this flow:**
- `session_start` hook only records trigger, doesn't create
  `agent_sessions` entry. No session tracking exists.
- `before_agent_start` loads soul but doesn't create `agent_sessions`
  entry either. The `is_s_still_idle()` query relies on
  `agent_sessions` but nothing populates it.

### 147b. S-bot Working Flow

```
S-bot receives prompt → executes tools → tool_call hook fires
     ↓
hook_on_tool_call.gleam → if tool is "edit", auto-backup file
     ↓
tool_result hook fires → hook_on_tool_result.gleam
     ↓
  If result contains error → notify A-bot via pi_send_message
  If result is OK → do nothing
```

**Bugs in this flow:**
- `hook_on_tool_result` checks for error strings but doesn't record
  the tool result in any database table. No audit trail.
- `pi_send_message` sends message with type "autonomic-error" but
  nobody listens for this message type. The A-bot only wakes up on
  `agent_end` debounce.

### 147c. S-bot Finishes Turn → agent_end Hook

```
S-bot finishes → agent_end hook fires → hook_on_agent_end.gleam
     ↓
  1. Check ctx_is_idle(ctx) — is S still idle?
  2. Check ctx_has_pending_messages(ctx) — any pending messages?
  3. If idle and no pending messages → check idle_since
     ↓
  If first time idle → record idle_since = now_ms()
  If idle_since exists → check debounce elapsed
     ↓
  Debounce config: get_config("monitor_debounce_ms")
  → Returns null (in-memory store empty)
  → Falls back to hardcoded 300000ms (5 minutes)
  → Database has 900000ms (15 minutes) — IGNORED
     ↓
  If debounce satisfied → coordinate_with_s()
     ↓
  1. Check ctx_is_idle again (race condition check)
  2. Check a_db_reader.is_s_still_idle()
     ↓
  is_s_still_idle() → COUNT(*) from agent_sessions
  → COUNT returns bigint as string → decode.int fails
  → Error(_) -> Ok(True) — ALWAYS returns True
     ↓
  coordinate_when_idle() → parse context window → run A workflow
```

**Bugs in this flow:**
1. `get_config("monitor_debounce_ms")` reads from in-memory store,
   not database. Database value (15min) is never used.
2. `is_s_still_idle()` ALWAYS returns True due to COUNT(*) decode
   failure. The A-bot will wake up even if S is still working.
3. Even if COUNT(*) decode worked, the query doesn't filter by
   agent type — it counts ALL sessions, not just S-bot.
4. No `agent_sessions` entries are ever created, so COUNT(*) would
   return 0 even if sessions were being tracked.

### 147d. A-bot Wake-up Flow

```
a_orchestrator.run_a_workflow()
     ↓
  1. a_db_reader.read_soul_from_db() — loads A-bot soul
     ↓
  2. a_db_reader.read_a_jobs_from_db() — loads A-bot jobs
     ↓
  3. a_db_reader.read_project_state_from_db()
     → read_active_tasks() — tasks with status NOT IN (COMPLETED,FAILED,FAKE_COMPLETE)
     → read_open_issues() — issues with status NOT IN (resolved,closed)
     ↓
  4. a_prompt_builder.build_system_prompt() — assembles prompt
     → Uses compose() NOT compose_within_budget() — no budget enforcement
     ↓
  5. a_prompt_builder.build_user_prompt() — user message
     → Detects inter-review request by string matching
     → Truncates entries_json to 2000/4000 chars
     ↓
  6. call_monitor(ctx, user_prompt, system_prompt) — calls LLM
     ↓
  7. handle_monitor_response() — processes LLM response
     → If S is still idle → pi_send_message("autonomic-wakeup", response)
     → If S is busy → abort
```

**Bugs in this flow:**
1. `read_active_tasks()` uses `decode.int` for `priority` — works
   (INTEGER type), but `is_stuck` uses `decode.bool` — works (BOOLEAN).
2. `read_open_issues()` doesn't cast `created_at` in SELECT, but
   it's only in ORDER BY, so no decode issue.
3. `build_system_prompt()` uses `compose()` which doesn't enforce
   budget. If soul + jobs + context exceed token limit, the prompt
   will be truncated by the LLM provider, not by the code.
4. `build_user_prompt()` detects inter-review by string matching
   (`entries_json` contains "inter-review" etc.). This is fragile —
   it could false-positive on casual mentions.
5. `call_monitor()` is an FFI function that calls the Pi SDK's
   model inference. If the model is not configured, it will fail
   silently.

### 147e. Inter-Review Flow (Broken)

```
S-bot calls psypi-commit tool → tool_commit.on_commit()
     ↓
  Phase 1: No review_id → trigger_review()
     ↓
  1. Get git diff → exec_sync("git diff && git diff --cached")
  2. Get file list → exec_sync("git diff --name-only")
  3. Call inter_review.request_review(None, None, "autonomic", context)
     ↓
  request_review() → calls request_inter_review() SQL function
     ↓
  SQL function creates inter_reviews row with:
    status='pending', overall_score=NULL
     ↓
  Returns review_id to S-bot
     ↓
  S-bot calls psypi-commit again with review_id → commit_if_reviewed()
     ↓
  get_review_details() → SELECT from inter_reviews
  → requested_at NOT cast to ::text → DecodeError
     ↓
  EVEN IF decode worked:
  overall_score is NULL → "Review not yet complete"
     ↓
  WHO UPDATES overall_score? Nobody.
  → respond_to_inter_review() SQL function exists but is never called
  → overall_score remains NULL FOREVER
  → Commits are PERMANENTLY BLOCKED
```

**This is the most critical broken flow in the system.** The
inter-review mechanism is completely non-functional because:
1. `requested_at` TIMESTAMPTZ not cast to `::text` → decode fails
2. Even if decode worked, `overall_score` is never updated
3. The SQL functions to update it exist but are never called
4. `git add` is never called before `git commit`

### 147f. Memory Save Flow (Broken)

```
S-bot calls psypi-learn-save → learning.save()
     ↓
  1. normalize_tags() — converts tags to PG array format
  2. save_learning() → INSERT INTO memory ... RETURNING id
     ↓
  3. Decode result with memory_decoder() — expects 7 fields
  4. But RETURNING id only returns 1 field
  5. DecodeError → "Failed to decode memory"
     ↓
  Learning is SAVED to database but function returns ERROR
  → Caller thinks save failed, may retry
  → Duplicate entries in memory table
```

### 147g. Memory Search Flow (Broken)

```
S-bot calls psypi-memory-search → memory.search()
     ↓
  1. SELECT * FROM memory WHERE content ILIKE $1
  2. Returns all columns including created_at (TIMESTAMPTZ)
  3. Decode with memory_decoder() — expects created_at as string
  4. node-postgres returns created_at as Date object
  5. decode.string fails → row silently dropped
     ↓
  ALL rows fail to decode → search returns empty list
  → Memory appears empty even though data exists
```

### 147h. Task Get Flow (Broken)

```
S-bot calls psypi-task-get → task.get()
     ↓
  SELECT id, title, description, status, priority, result, error,
         retry_count, created_at::text, updated_at::text,
         completed_at::text, created_by, source
  FROM tasks WHERE id = $1
     ↓
  Missing from SELECT: project_id
  task_decoder() expects project_id → DecodeError
     ↓
  task.get() ALWAYS returns DecodeError
  → Individual task lookup is completely broken
```

### 147i. Skill Get Flow (Broken for JSONB data)

```
S-bot calls psypi-skill-get → skill.get()
     ↓
  SELECT ... created_at::text, content, reference_list
  FROM skills WHERE name = $1
     ↓
  content and reference_list are JSONB, not cast to ::text
  → node-postgres returns JavaScript objects
  → decode.optional(decode.string) fails for non-null values
     ↓
  Skills with content or reference_list data fail to decode
  → Only skills with NULL content/reference_list can be retrieved
```

### 147j. Issue List Flow (Filter Values Swapped)

```
S-bot calls psypi-issues with status="open" AND severity="high"
     ↓
  issue_db.list() → sql_with_filters() → build_where()
     ↓
  Build conditions by prepending:
    status first: conditions=["status=$1"], params=["open"]
    severity next: conditions=["severity=$2","status=$1"], params=["high","open"]
     ↓
  Reverse conditions: ["status=$1","severity=$2"]
  But params NOT reversed: ["high","open"]
     ↓
  $1 = "high" (intended as severity)
  $2 = "open" (intended as status)
     ↓
  Query: WHERE status='high' AND severity='open'
  → Returns WRONG results (or empty if no matches)
```

---

## 148. COMPOUND BUG ANALYSIS — CASCADING FAILURES

### 148a. The "Always Idle" Cascade

```
is_s_still_idle() always returns True
  → A-bot wakes up on every debounce timeout
  → A-bot sends wake-up messages even when S is working
  → S receives unwanted interruptions
  → S's context gets polluted with A-bot messages
  → S's context window fills up faster
  → More frequent context compaction
  → Lost conversation history
  → S makes worse decisions
```

### 148b. The "Inter-Review Deadlock" Cascade

```
Inter-review overall_score never updated
  → Commits permanently blocked
  → S-bot cannot commit code
  → S-bot tries workarounds (direct git commit)
  → Bypasses review entirely
  → Unreviewed code enters the repository
  → OR: S-bot is stuck, unable to proceed
```

### 148c. The "Memory Black Hole" Cascade

```
memory.save() returns error (decoder mismatch)
  → Caller thinks save failed
  → Retries save → duplicate entries
  → memory.search() returns empty (TIMESTAMPTZ decode failure)
  → No memories can be retrieved
  → A-bot and S-bot have no memory of past interactions
  → Every session starts from scratch
  → Repeated mistakes, no learning
```

### 148d. The "Config Disconnect" Cascade

```
Database config (psypi_config) never synced with in-memory config
  → Debounce value: DB=15min, code=5min
  → idle_since lost on restart
  → A-bot wakes up too frequently
  → Excessive LLM API calls
  → Higher costs
  → Rate limiting
  → A-bot responses become slower or fail
```

---

## 149. SYSTEMIC ROOT CAUSES — REVISED

### 149a. No Integration Testing

Gleam tests validate pure functions but never test:
- Database round-trips (INSERT → SELECT → decode)
- FFI bindings (Gleam → JavaScript → return)
- Hook chains (event → handler → database → response)
- Tool execution (Pi tool call → Gleam function → database)

### 149b. No Schema Validation

No mechanism to verify that:
- SQL column types match Gleam decoder types
- NOT NULL constraints are respected in INSERT statements
- All columns in SELECT match decoder field expectations
- JSONB columns are cast to ::text before string decoding

### 149c. No Migration Tracking

- `simple_migrate.gleam` has no tracking table
- Migrations run on every startup
- Duplicate migration numbers (025 appears twice)
- Naive SQL splitting breaks PL/pgSQL functions
- 94 of 115 tables have no migrations at all

### 149d. No Error Propagation

Errors are silently swallowed at every level:
- `is_s_still_idle()`: decode error → return True (wrong default)
- `memory.search()`: decode error → drop row silently
- `skill.get()`: decode error → return generic "Failed to decode"
- `hook_on_agent_end`: debounce parse error → proceed anyway

### 149e. No Type-Safe Database Access

The project doesn't use Squirrel or any type-safe SQL library.
All queries are raw strings with manual parameter binding and
manual decoding. This creates a constant risk of:
- Column type mismatches
- Missing columns in SELECT
- Wrong parameter order
- Decoder/selector drift

### 149f. Dual Config System

Two independent config stores (database and in-memory) with no
synchronization. The in-memory store is used by hooks but never
populated from the database. Config values diverge over time.

### 149g. No Agent Session Lifecycle

The `agent_sessions` table exists but is never populated by the
hook system. `is_s_still_idle()` queries a table that's always
empty (or contains stale data from manual inserts).

---

## 150. REVISED BUG COUNT — FINAL v8

| Category                           | Count                                                 |
| ---------------------------------- | ----------------------------------------------------- |
| `::text` cast missing (TSTZ+JSONB) | 15                                                    |
| Missing NOT NULL columns in INSERT | 10                                                    |
| Wrong column names                 | 4                                                     |
| Decoder mismatch                   | 11                                                    |
| Missing type variants              | 3                                                     |
| Logic bugs                         | 12                                                    |
| FFI issues                         | 9                                                     |
| Config system fragmentation        | 3                                                     |
| Seed/bootstrap gaps                | 10 (+1: no seed for psypi_event_hooks)                |
| Dead code                          | 5 (+1: agent_identity check_git_exists result unused) |
| Stub implementations               | 2                                                     |
| Race conditions / concurrency      | 4                                                     |
| Extension generation bugs          | 6                                                     |
| A/S lifecycle logic failures       | 8                                                     |
| Tool execution flow bugs           | 4                                                     |
| Hook module bugs                   | 7                                                     |
| Command module bugs                | 2                                                     |
| DB module bugs                     | 4                                                     |
| A/S DB reader bugs                 | 7                                                     |
| Monitor AI bugs                    | 6                                                     |
| Event hooks bugs                   | 3                                                     |
| Node PG FFI bugs                   | 1                                                     |
| Inter-review bugs                  | 7                                                     |
| Tool commit bugs                   | 3                                                     |
| Tool consult bugs                  | 2                                                     |
| Code version bugs                  | 1                                                     |
| Meeting bugs                       | 3                                                     |
| Agent identity bugs                | 5 (+1: check_git_exists unused)                       |
| Task bugs                          | 6                                                     |
| Issue bugs                         | 4                                                     |
| Broadcast bugs                     | 6                                                     |
| Skill bugs                         | 3                                                     |
| Agents bugs                        | 2                                                     |
| Stats bugs                         | 3                                                     |
| Monitor module bugs                | 3                                                     |
| A orchestrator bugs                | 3                                                     |
| A prompt builder bugs              | 2                                                     |
| Simple migrate bugs                | 4                                                     |
| System prompt types bugs           | 3                                                     |
| A context utils bugs               | 2                                                     |
| Extension generator bugs           | 2                                                     |
| FFI node_ffi.mjs bugs              | 3                                                     |
| FFI pi_extension_ffi.mjs bugs      | 6                                                     |
| FFI agent_identity_ffi.mjs bugs    | 1                                                     |
| FFI time_utils_ffi.mjs bugs        | 1                                                     |
| Migration schema bugs              | 5                                                     |
| **TOTAL CONFIRMED BUGS**           | **192**                                               |

---

## 151. ADDITIONAL MODULE REVIEW FINDINGS

### 151a. s_db_reader.gleam — S-bot Soul & Job Loading

**File:** [s_db_reader.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/s_db_reader.gleam)

**Bug 1: `priority` decoded as `decode.int` but may be stored as text**
The `s_job_row_decoder()` uses `decode.int` for `priority`, which
works if the column is INTEGER. But if it's been altered to text
(like other columns), it will fail silently.

**Bug 2: No error on soul decode failure**
`read_s_soul_from_db()` returns a proper error on decode failure,
which is good. But `read_s_jobs_from_db()` silently drops decode
failures via `list.filter_map`. If a job row fails to decode, it
just disappears from the list — no error reported.

### 151b. hook_on_before_agent_start.gleam — Soul Loading

**File:** [hook_on_before_agent_start.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/hook_on_before_agent_start.gleam)

**Bug 1: Soul load failure returns Ok with fallback text**
When `read_s_soul_from_db()` fails, the hook returns `Ok(...)` with
a hardcoded fallback soul. This means the S-bot always starts, even
with a broken soul. While this is arguably a feature (graceful
degradation), it means soul load failures are invisible — no alert
is created, no notification sent.

**Bug 2: No agent_sessions entry created**
The `before_agent_start` hook doesn't create an `agent_sessions`
entry. This means `is_s_still_idle()` queries a table that's never
populated by the hook system.

### 151c. hook_on_tool_call.gleam — Auto-backup on Edit

**File:** [hook_on_tool_call.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/hook_on_tool_call.gleam)

**Bug 1: `code_version.save_version` failure blocks the edit**
If auto-backup fails, the hook returns `Error(msg)`, which may
prevent the edit from proceeding. This is overly aggressive — a
backup failure shouldn't block the user's edit.

**Bug 2: No file content validation**
The hook reads the file before edit but doesn't verify the content
is valid (e.g., not empty, not binary). If `read_file_sync`
returns empty string for a binary file, it will save an empty
backup.

### 151d. hook_on_tool_result.gleam — Error Detection

**File:** [hook_on_tool_result.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/hook_on_tool_result.gleam)

**Bug 1: String-based error detection is fragile**
The hook detects errors by checking for substrings like `"error"`,
`"Error:"`, `"execution error"`. This will false-positive on:
- Any JSON containing the word "error" in a non-error context
- Tool results that mention errors in documentation
- Successful results that include error-handling code

**Bug 2: `pi_send_message` with "autonomic-error" type — nobody listens**
The error message is sent via `pi_send_message(pi, "autonomic-error", ...)`.
But no hook or handler listens for "autonomic-error" messages.
The A-bot only wakes up on `agent_end` debounce. So error
notifications are sent into the void.

**Bug 3: `extract_error_msg` is a naive JSON parser**
The function splits on `"error"` and then on `"` to extract the
message. This breaks for:
- Nested JSON with multiple "error" keys
- Escaped quotes in error messages
- Non-JSON error strings

### 151e. command_listen.gleam — Human-to-Monitor Chat

**File:** [command_listen.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/command_listen.gleam)

**Bug 1: `call_monitor` result not validated**
The response from `call_monitor()` is used directly as a message
to S-bot. If the LLM returns empty or malformed output, it's
forwarded without validation.

**Bug 2: `pi_send_message` with "autonomic-wakeup" type**
The message type is "autonomic-wakeup" but the display parameter
is "persistent". This creates a persistent message in the S-bot's
context, which may accumulate and fill the context window.

### 151f. command_reload.gleam — Extension Reload

**File:** [command_reload.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/command_reload.gleam)

No significant bugs. Simple and correct.

### 151g. agent_identity.gleam — Identity Resolution

**File:** [agent_identity.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/agent_identity.gleam)

**Bug 1: `check_git_exists()` result is unused**
Line 138: `let _global = case check_git_exists(ctx.cwd) { True -> False; False -> True }`
The `_global` variable is never used. The intended logic was to set
a "global" flag when no `.git` directory exists, but this flag is
never passed to `semantic_id()` or `EnrichedIdentity`.

**Bug 2: `semantic_id()` prefix determination is duplicated**
`semantic_id()` determines prefix from `ctx.is_idle`, then
`get_enriched_identity()` re-determines it with
`string.contains(id, "A-") || ctx.is_idle`. These two checks can
contradict each other if the ID string contains "A-" but the agent
is actually S-bot.

**Bug 3: Soul fetch failure silently falls back to generic identity**
When `fetch_soul_by_prefix()` fails, the function returns a generic
identity with `domain: "unknown"`. No error is reported or logged.

**Bug 4: Job decode failures silently dropped**
`fetch_jobs_by_prefix()` uses `list.filter_map` to drop failed
decodes. If a job row fails to decode, it just disappears.

### 151h. event_hooks.gleam — Hook Management

**File:** [event_hooks.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/event_hooks.gleam)

**Bug 1: `record_error` auto-disables hooks after 5 errors**
The SQL `CASE WHEN error_count >= 5 THEN 'error' ELSE hook_status END`
automatically sets hook status to 'error' after 5 errors. This is
dangerous — a transient error spike can permanently disable a hook
until manually re-enabled.

**Bug 2: `record_trigger` doesn't validate event_name**
If a typo is passed (e.g., "before_agent_start" vs "agent_start"),
the UPDATE affects 0 rows silently. No error is returned.

### 151i. monitor_ai.gleam — Monitor AI Module

**File:** [monitor_ai.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/monitor_ai.gleam)

**Bug 1: `check_system_health()` uses `COUNT(*)::INT` — correct!**
This is one of the few places that correctly casts COUNT to INT.
Good pattern, but inconsistent with `a_db_reader.gleam` which
doesn't cast.

**Bug 2: `prepare_context()` UNION ALL with ORDER BY**
The SQL uses `UNION ALL ... ORDER BY saved_at DESC` but `saved_at`
is not in the SELECT list. PostgreSQL will error on this unless
`saved_at` is added to the SELECT or the ORDER BY uses a column
alias. Wait — `saved_at::text` IS in the SELECT (line 128). But
the `context_row_decoder()` only decodes `type_` and `content`,
ignoring `saved_at`. The ORDER BY works because PostgreSQL can
order by columns not in the SELECT for UNION queries... actually
no, for UNION queries, ORDER BY must reference output columns.
This query may fail at runtime.

**Bug 3: `auto_file_issue()` INSERT into `issues` table**
The INSERT uses column `type` but the actual column name is
`issue_type` (VERIFIED against schema). This INSERT will ALWAYS fail
with "column 'type' does not exist".

**Bug 4: `auto_file_issue()` ignores `project_id`**
The INSERT doesn't include `project_id`, which has NOT NULL constraint
(VERIFIED against schema). This INSERT will ALWAYS fail with
"null value in column 'project_id' violates not-null constraint".

**Bug 5: `record_review_score()` exists but is never called**
This function updates `inter_reviews.overall_score`, which is the
exact function needed to fix the inter-review deadlock. But it's
never called from any hook or tool. It's dead code that contains
the solution to a critical bug.

**Bug 6: `get_work_suggestions()` UNION with GROUP BY**
The first subquery groups by `severity` but the outer query doesn't
handle multiple rows for the same `suggestion_type`. This can
return multiple "open_issues" suggestions with different
descriptions.

### 151j. monitor.gleam — Monitor Module

**File:** [monitor.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/monitor.gleam)

**Bug 1: `set_model()` resets ALL keys to 'not_used'**
The `reset_sql = "UPDATE provider_api_keys SET status = 'not_used'"`
resets ALL providers, not just the one being changed. If multiple
providers are in use, this will break them.

**Bug 2: `get_pending_notifications()` decode failures silently dropped**
Uses `list.fold` to collect decoded notifications, dropping failures.
If a notification fails to decode, it's silently lost.

**Bug 3: `record_current_model()` INSERT into `activity_log`**
The INSERT uses column `timestamp` — VERIFIED CORRECT against schema.
The `activity_log` table does have a `timestamp` column.

### 151k. agents.gleam — Agent Listing

**File:** [agents.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/agents.gleam)

**Bug 1: `created_at::text` — correctly cast**
This is one of the few modules that correctly casts TIMESTAMPTZ to
text. Good.

**Bug 2: Only returns 50 agents**
The `LIMIT 50` may not be sufficient for large installations.

### 151l. seed.gleam — Database Seeding

**File:** [seed.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/seed.gleam)

**Bug 1: Only seeds 3 tables**
`agent_souls`, `psypi_config`, `agent_prefixes`. Missing:
- `psypi_event_hooks` (30 rows needed)
- `projects` (at least 1 row for default project)
- `provider_api_keys` (at least 1 row for Monitor AI)
- `agent_identities` (at least A and S entries)

**Bug 2: `monitor_debounce_ms` seeded as 300000 but DB has 900000**
The seed value (5 minutes) differs from the current database value
(15 minutes). If the database is re-seeded, the debounce will
change from 15 to 5 minutes without warning.

### 151m. main.gleam — Entry Point

**File:** [main.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/main.gleam)

**Bug 1: No initialization logic**
`main()` just calls `spawn_pi(args)`. No database connection check,
no migration, no seeding. All initialization must be done manually
before starting.

---

## 152. REVISED BUG COUNT — FINAL v9

| Category                           | Count                                                                                                        |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `::text` cast missing (TSTZ+JSONB) | 15                                                                                                           |
| Missing NOT NULL columns in INSERT | 12 (+2: auto_file_issue missing project_id, possible type vs issue_type)                                     |
| Wrong column names                 | 4                                                                                                            |
| Decoder mismatch                   | 11                                                                                                           |
| Missing type variants              | 3                                                                                                            |
| Logic bugs                         | 14 (+2: hook auto-disable after 5 errors, get_work_suggestions duplicate rows)                               |
| FFI issues                         | 9                                                                                                            |
| Config system fragmentation        | 3                                                                                                            |
| Seed/bootstrap gaps                | 10                                                                                                           |
| Dead code                          | 6 (+1: monitor_ai.record_review_score exists but never called — contains fix for inter-review deadlock)      |
| Stub implementations               | 2                                                                                                            |
| Race conditions / concurrency      | 4                                                                                                            |
| Extension generation bugs          | 6                                                                                                            |
| A/S lifecycle logic failures       | 8                                                                                                            |
| Tool execution flow bugs           | 4                                                                                                            |
| Hook module bugs                   | 9 (+2: tool_result false positives, autonomic-error message to nobody)                                       |
| Command module bugs                | 2                                                                                                            |
| DB module bugs                     | 4                                                                                                            |
| A/S DB reader bugs                 | 7                                                                                                            |
| Monitor AI bugs                    | 9 (+3: prepare_context ORDER BY may fail, auto_file_issue wrong column, get_work_suggestions duplicate rows) |
| Monitor module bugs                | 4 (+1: set_model resets ALL providers)                                                                       |
| Event hooks bugs                   | 4 (+1: auto-disable after 5 errors)                                                                          |
| Node PG FFI bugs                   | 1                                                                                                            |
| Inter-review bugs                  | 7                                                                                                            |
| Tool commit bugs                   | 3                                                                                                            |
| Tool consult bugs                  | 2                                                                                                            |
| Code version bugs                  | 1                                                                                                            |
| Meeting bugs                       | 3                                                                                                            |
| Agent identity bugs                | 5                                                                                                            |
| Task bugs                          | 6                                                                                                            |
| Issue bugs                         | 4                                                                                                            |
| Broadcast bugs                     | 6                                                                                                            |
| Skill bugs                         | 3                                                                                                            |
| Agents bugs                        | 2                                                                                                            |
| Stats bugs                         | 3                                                                                                            |
| A orchestrator bugs                | 3                                                                                                            |
| A prompt builder bugs              | 2                                                                                                            |
| Simple migrate bugs                | 4                                                                                                            |
| System prompt types bugs           | 3                                                                                                            |
| A context utils bugs               | 2                                                                                                            |
| Extension generator bugs           | 2                                                                                                            |
| FFI node_ffi.mjs bugs              | 3                                                                                                            |
| FFI pi_extension_ffi.mjs bugs      | 6                                                                                                            |
| FFI agent_identity_ffi.mjs bugs    | 1                                                                                                            |
| FFI time_utils_ffi.mjs bugs        | 1                                                                                                            |
| Migration schema bugs              | 5                                                                                                            |
| **TOTAL CONFIRMED BUGS**           | **204**                                                                                                      |

---

## 153. FFI FILE DEEP REVIEW

### 153a. pi_extension_ffi.mjs — Critical FFI Bridge

**File:** [pi_extension_ffi.mjs](file:///Users/jk/gits/hub/tools_ai/psypi/src/pi_extension_ffi.mjs)

**Bug 1: `pi_send_message` ignores 4th parameter `display`**
```javascript
export function pi_send_message(pi, customType, content, display) {
  pi.sendMessage({
    customType: String(customType),
    content: String(content),
    display: true,  // ALWAYS true, ignores 'display' parameter
  }, { triggerTurn: true });
}
```
The Gleam side passes `display: "persistent"` or other values, but
the JS side hardcodes `display: true`. The parameter is silently
ignored.

**Bug 2: `call_monitor` retry logic is flawed**
```javascript
const shouldRetry = !text || (result?.errorMessage && 
  (result?.errorMessage === 'terminated' || result?.errorMessage.includes('rate')));
if (shouldRetry) {
  result = await completeSimple(model, context, { 
    apiKey: auth.apiKey, headers: auth.headers, reasoning: 'none' 
  });
```
On retry, reasoning is set to 'none' (disabling thinking). But the
original call used 'medium'. If the first call failed due to rate
limiting, the retry will also fail. If it failed due to 'terminated',
the retry may succeed but with lower quality output.

**Bug 3: `_configStore` is not thread-safe**
```javascript
let _configStore = {};
```
Node.js is single-threaded for JS execution, but if multiple
async operations read/write `_configStore` concurrently (e.g.,
two `agent_end` hooks firing in quick succession), the state
can become inconsistent. Specifically:
- `get_config("idle_since")` returns null
- Two hooks both set `idle_since` to different values
- The later one wins, but the first one already proceeded

**Bug 4: `gleamValueToJson` type name matching is fragile**
```javascript
if (name.startsWith('Task$Task') || name.startsWith('Issue$Issue') || ...)
```
This hardcodes Gleam module$type patterns. If a new type is added
(e.g., `Notification$Notification`), it won't be serialized
correctly. The function will fall through to the generic
`name.includes('$')` branch, which produces a different output
format.

**Bug 5: `gleamValueToJson` doesn't handle `NonEmpty` tail correctly**
```javascript
if (name === 'NonEmpty') {
  const arr = [];
  let cur = val;
  while (cur && cur.constructor?.name === 'NonEmpty') {
    arr.push(gleamValueToJson(cur.head));
    cur = cur.tail;
  }
  return arr;
}
```
Gleam lists end with `[]` (empty list), not `Nil`. The while loop
checks for `NonEmpty` but doesn't handle the case where `cur.tail`
is an empty array `[]`. If `cur.constructor?.name` is not
`'NonEmpty'`, the loop stops. This should work for standard Gleam
lists, but if the tail is something unexpected, items are silently
lost.

**Bug 6: `unwrapGleamResult` returns plain object, not Gleam type**
The function returns `{ ok: true, value: ... }` or
`{ ok: false, error: ... }`. But the Gleam side declares the
return type as `b` (unconstrained). This works because Gleam
treats it as Dynamic, but it's not type-safe.

**Bug 7: `now_ms()` returns different types in different FFI files**
- `pi_extension_ffi.mjs`: `return Date.now()` → returns `Int`
- `node_ffi.mjs`: `return new Ok(Date.now())` → returns `Result(Int, ...)`

The Gleam side in `pi_extension.gleam` declares `now_ms() -> Int`,
while `node_ffi.mjs` wraps it in `Ok()`. If any Gleam code calls
the `node_ffi.mjs` version expecting a plain `Int`, it will get
a Gleam `Ok` variant instead.

### 153b. node_ffi.mjs — System Utilities

**File:** [node_ffi.mjs](file:///Users/jk/gits/hub/tools_ai/psypi/src/node_ffi.mjs)

**Bug 1: `now_ms()` returns `Ok(Date.now())` instead of plain `Int`**
```javascript
export function now_ms() {
  return new Ok(Date.now());
}
```
But `pi_extension_ffi.mjs` returns `Date.now()` (plain Int). The
Gleam declarations differ:
- `pi_extension.gleam`: `now_ms() -> Int`
- Whatever uses `node_ffi.mjs`: expects `Result(Int, ...)`

These two `now_ms` implementations are incompatible.

**Bug 2: `execute()` error returns `Error({ ExecutionError: e.message })`**
```javascript
return new Error({ ExecutionError: e.message || 'Command failed' });
```
This creates a Gleam `Error` variant containing a JavaScript object
`{ ExecutionError: e.message }`. Gleam code would need to decode
this as a dynamic type. If the Gleam side expects a simple string,
the decode will fail.

**Bug 3: `spawn_pi()` doesn't handle Pi not found**
```javascript
const piProcess = spawn('pi', args, ...);
```
If `pi` is not in PATH, `spawn` will emit an 'error' event but
the promise rejection doesn't provide a helpful error message.

**Bug 4: `get_project_id_env()` returns empty string for missing env**
```javascript
export function get_project_id_env() {
  return process.env['PSYPI_PROJECT_ID'] || '';
}
```
In `db.gleam`, this empty string triggers the hardcoded UUID
fallback. But there's no logging or warning that the fallback
is being used.

### 153c. agent_identity_ffi.mjs — Git Check

**File:** [agent_identity_ffi.mjs](file:///Users/jk/gits/hub/tools_ai/psypi/src/agent_identity_ffi.mjs)

**Bug 1: `check_git_exists` result is unused by Gleam code**
The function works correctly, but `agent_identity.gleam` assigns
the result to `_global` (underscore = unused). The entire FFI
call is dead code.

### 153d. time_utils_ffi.mjs — Time Utility

**File:** [time_utils_ffi.mjs](file:///Users/jk/gits/hub/tools_ai/psypi/src/time_utils_ffi.mjs)

**Bug 1: `now_iso8601()` returns `Promise.resolve()` but no Gleam code uses it**
The function exists but there's no corresponding `@external`
declaration in any `.gleam` file. It's dead code.

### 153e. db.gleam — Database Connection Management

**File:** [db.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/db.gleam)

**Bug 1: `with_connection` creates a new connection for every query**
Every call to `with_connection` calls `connect()` then `disconnect()`.
This means every database operation:
1. Creates a new TCP connection to PostgreSQL
2. Performs SSL handshake (if configured)
3. Authenticates
4. Sets `app.current_project_id`
5. Executes the query
6. Closes the connection

This is extremely expensive. A connection pool should be used
instead.

**Bug 2: `disconnect()` result is ignored**
```gleam
let _ = disconnect(conn)
```
If disconnect fails, the error is silently swallowed. The
connection may leak.

**Bug 3: `SET app.current_project_id` uses hardcoded UUID fallback**
```gleam
let project_id = case get_project_id_env() {
  "" -> "0d324e68-b399-4b85-bd8a-6b1ef7b46168"
  id -> id
}
```
This is the 6th location where the hardcoded UUID appears.
No dynamic lookup from `projects` table.

**Bug 4: No connection timeout**
`connect()` has no timeout. If PostgreSQL is unreachable, the
promise will hang indefinitely.

**Bug 5: No query timeout**
`query()` has no timeout. Long-running queries will block the
event loop.

---

## 154. REVISED BUG COUNT — FINAL v10

| Category                           | Count                                                                                                                                                   |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `::text` cast missing (TSTZ+JSONB) | 15                                                                                                                                                      |
| Missing NOT NULL columns in INSERT | 12                                                                                                                                                      |
| Wrong column names                 | 4                                                                                                                                                       |
| Decoder mismatch                   | 11                                                                                                                                                      |
| Missing type variants              | 3                                                                                                                                                       |
| Logic bugs                         | 14                                                                                                                                                      |
| FFI issues                         | 14 (+5: pi_send_message ignores display, call_monitor flawed retry, gleamValueToJson fragile type matching, now_ms type conflict, execute error format) |
| Config system fragmentation        | 3                                                                                                                                                       |
| Seed/bootstrap gaps                | 10                                                                                                                                                      |
| Dead code                          | 8 (+2: time_utils_ffi.now_iso8601 unused, agent_identity_ffi.check_git_exists unused)                                                                   |
| Stub implementations               | 2                                                                                                                                                       |
| Race conditions / concurrency      | 5 (+1: _configStore concurrent access)                                                                                                                  |
| Extension generation bugs          | 6                                                                                                                                                       |
| A/S lifecycle logic failures       | 8                                                                                                                                                       |
| Tool execution flow bugs           | 4                                                                                                                                                       |
| Hook module bugs                   | 9                                                                                                                                                       |
| Command module bugs                | 2                                                                                                                                                       |
| DB module bugs                     | 7 (+3: no connection pool, disconnect error ignored, no query timeout)                                                                                  |
| A/S DB reader bugs                 | 7                                                                                                                                                       |
| Monitor AI bugs                    | 9                                                                                                                                                       |
| Monitor module bugs                | 4                                                                                                                                                       |
| Event hooks bugs                   | 4                                                                                                                                                       |
| Node PG FFI bugs                   | 1                                                                                                                                                       |
| Inter-review bugs                  | 7                                                                                                                                                       |
| Tool commit bugs                   | 3                                                                                                                                                       |
| Tool consult bugs                  | 2                                                                                                                                                       |
| Code version bugs                  | 1                                                                                                                                                       |
| Meeting bugs                       | 3                                                                                                                                                       |
| Agent identity bugs                | 5                                                                                                                                                       |
| Task bugs                          | 6                                                                                                                                                       |
| Issue bugs                         | 4                                                                                                                                                       |
| Broadcast bugs                     | 6                                                                                                                                                       |
| Skill bugs                         | 3                                                                                                                                                       |
| Agents bugs                        | 2                                                                                                                                                       |
| Stats bugs                         | 3                                                                                                                                                       |
| A orchestrator bugs                | 3                                                                                                                                                       |
| A prompt builder bugs              | 2                                                                                                                                                       |
| Simple migrate bugs                | 4                                                                                                                                                       |
| System prompt types bugs           | 3                                                                                                                                                       |
| A context utils bugs               | 2                                                                                                                                                       |
| Extension generator bugs           | 2                                                                                                                                                       |
| FFI node_ffi.mjs bugs              | 4 (+1: now_ms returns Ok() instead of plain Int)                                                                                                        |
| FFI pi_extension_ffi.mjs bugs      | 7 (+1: pi_send_message ignores display parameter)                                                                                                       |
| FFI agent_identity_ffi.mjs bugs    | 1                                                                                                                                                       |
| FFI time_utils_ffi.mjs bugs        | 1                                                                                                                                                       |
| Migration schema bugs              | 5                                                                                                                                                       |
| **TOTAL CONFIRMED BUGS**           | **219**                                                                                                                                                 |

---

## 155. EXTENSION GENERATOR AND PI TOOL CALL REVIEW

### 155a. pi_tool_call.gleam — Type Definitions and JS Generation

**File:** [pi_tool_call.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/pi_tool_call.gleam)

**Bug 1: `params_to_js` doesn't quote `required` array values properly**
The generated JS has `"required": ["title", "description"]` which is
correct JSON. No bug here.

**Bug 2: `to_js_text` uses `unwrapGleamResult` which returns plain object**
The generated tool code calls `unwrapGleamResult(result)` which
returns `{ ok: true, value: ... }`. But the Gleam function returns
a `Result(a, e)` type. The `unwrapGleamResult` function in
`pi_extension_ffi.mjs` manually destructures the Gleam Result type.
This works but is fragile — if Gleam changes its internal Result
representation, it will break.

**Bug 3: `hook_import_line` uses dynamic import inside event handler**
```javascript
const alias = (await import('./build/dev/javascript/psypi/module.mjs')).fn_name;
```
This dynamic import happens on EVERY hook invocation. Node.js caches
modules after first import, so subsequent calls are fast. But the
first call for each hook is slow (module resolution + parsing).

**Bug 4: `PiDebouncedHook` generates debounce timer that adds to manual debounce**
The generated debounced hook creates a `setTimeout` that fires after
`debounce_ms`, then calls the handler function. But the handler
(`hook_on_agent_end.on_agent_end`) implements its OWN debounce
logic using in-memory config. This creates DOUBLE DEBOUNCE:
- First debounce: generated JS timer (reads from database via
  `psypi_config.get_debounce_ms()`)
- Second debounce: manual check in `on_agent_end` (reads from
  in-memory `_configStore`)

The actual debounce time is the SUM of both, not just one.

### 155b. extension_generator.gleam — Extension Composition

**File:** [extension_generator.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/extension_generator.gleam)

**Bug 1: `all_tools()` missing `task_get_tool`**
The tool registry includes `task_add_tool()`, `task_list_tool()`,
`task_complete_tool()` but NOT `task_get_tool()`. The `task.gleam`
module defines a `task_get_tool()` function, but it's never
registered. S-bot cannot look up individual tasks.

**Bug 2: `session_start` hook calls `monitor.record_current_model`**
The hook passes `from_param("ctx.model")` but `record_current_model`
expects a `model_name: String`. `ctx.model` is a JavaScript object,
not a string. The function will receive `[object Object]` as the
model name.

**Bug 3: `model_select` hook also calls `monitor.record_current_model`**
Same issue — `from_param("event.model")` passes a JS object as
string.

**Bug 4: `write_extension()` silently ignores write errors**
```gleam
case write_file(extension_path, content) {
  Ok(_) -> Nil
  Error(e) -> io.println("Error writing extension.js: " <> string.inspect(e))
}
```
The error is printed but the function returns `Nil` (not Error).
The caller has no way to know the write failed.

**Bug 5: No `task_get_tool` in registry**
As noted above, `task.get()` is defined but never registered as a
Pi tool. The S-bot cannot retrieve individual tasks by ID.

### 155c. psypi_config.gleam — Database Config

**File:** [psypi_config.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/psypi_config.gleam)

**Bug 1: `get_debounce_ms()` reads from database, but hooks use in-memory**
The `psypi_config.get_debounce_ms()` function reads from the
`psypi_config` table in PostgreSQL. But `hook_on_agent_end.gleam`
uses `pi_extension.get_config("monitor_debounce_ms")` which reads
from the in-memory `_configStore`. These are two completely
different stores that are never synchronized.

**Bug 2: `set()` writes to database, not in-memory store**
When `psypi_config.set()` is called, it writes to the database.
But the in-memory `_configStore` is never updated. Any code that
reads from `_configStore` after a database write will see stale
values.

### 155d. areflect.gleam — Agent Reflection

**File:** [areflect.gleam](file:///Users/jk/gits/hub/tools_ai/psypi/src/areflect.gleam)

**Bug 1: `save_issue()` INSERT missing `project_id` (NOT NULL, no default)**
```gleam
let sql = "
  INSERT INTO issues (title, description, severity, created_by)
  VALUES ($1, $2, 'medium', $3)
"
```
The `issues` table has `project_id` as NOT NULL with no default.
This INSERT will ALWAYS fail with:
"null value in column 'project_id' violates not-null constraint"

**Bug 2: `save_issue()` INSERT missing `issue_type` (has default 'bug')**
The `issue_type` column has a default of 'bug', so this INSERT
will succeed with the default. But it means all areflect-created
issues are typed as 'bug' regardless of actual type.

**Bug 3: `fetch_recent_issues()` — `id` is UUID, decoded as `decode.string`**
UUID is returned as string by node-postgres, so this should work.
But it's inconsistent with other modules that use `id::text`.

**Bug 4: `save_learning()` inserts into `learning_insights` not `memory`**
The `areflect` module saves learnings to `learning_insights` table,
while the `learning.gleam` module saves to `memory` table. These
are different tables with different schemas. Learnings saved via
`areflect` won't appear in `memory.search()` results.

**Bug 5: `_agent_id` parameter unused in `save_learning()`**
The `agent_id` parameter is prefixed with underscore, meaning it's
unused. The INSERT doesn't include `agent_id` in the
`learning_insights` table.

---

## 156. DOUBLE DEBOUNCE ANALYSIS

The `agent_end` hook has TWO debounce mechanisms stacked on top of
each other:

### Layer 1: Generated Debounce (extension.js)

```javascript
// Generated by pi_tool_call.gleam:PiDebouncedHook
let _debounceTimerId = null;
let _debounceMs = null;
pi.on('agent_end', async (event, ctx) => {
  if (_debounceTimerId) clearTimeout(_debounceTimerId);
  _debounceTimerId = null;
  if (_debounceMs == null) {
    const debounceResult = await psypi_config_get_debounce_ms();
    _debounceMs = unwrapGleamResult(debounceResult).value;
  }
  _debounceTimerId = setTimeout(async () => {
    // Call hook_on_agent_end.on_agent_end(ctx, pi)
  }, _debounceMs);
});
```

This reads `monitor_debounce_ms` from DATABASE (e.g., 900000 = 15min).

### Layer 2: Manual Debounce (hook_on_agent_end.gleam)

```gleam
// Inside on_agent_end()
case get_config("idle_since") {
  Some(idle_since_str) -> {
    let elapsed = now - idle_since
    case get_config("monitor_debounce_ms") {
      Some(debounce_str) -> // use value from in-memory store
      None -> // use hardcoded 300000 (5min)
    }
  }
}
```

This reads `monitor_debounce_ms` from IN-MEMORY store (always null
on startup → falls back to 300000 = 5min).

### Combined Effect

1. S-bot finishes → `agent_end` fires
2. Generated debounce sets 15min timer (from database)
3. After 15min, timer fires → calls `on_agent_end(ctx, pi)`
4. `on_agent_end` checks `idle_since` in in-memory store
5. First time: no `idle_since` → records it → returns (waits another cycle)
6. Next `agent_end` → generated debounce sets another 15min timer
7. After 15min, timer fires → calls `on_agent_end` again
8. `on_agent_end` finds `idle_since` → checks elapsed (30min total)
9. Elapsed > 5min (in-memory default) → proceeds to coordinate

**Total debounce: 15min (generated) + 15min (generated again) = 30min**
**Or: 15min (generated) + 5min (in-memory) = 20min on second fire**

The intended behavior was probably just ONE debounce of 15 minutes.
Instead, the actual debounce is 20-30 minutes due to double layering.

---

## 157. REVISED BUG COUNT — FINAL v11

| Category                           | Count                                                                                                                                       |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `::text` cast missing (TSTZ+JSONB) | 15                                                                                                                                          |
| Missing NOT NULL columns in INSERT | 14 (+2: areflect.save_issue missing project_id, extension_generator session_start passes object as string)                                  |
| Wrong column names                 | 4                                                                                                                                           |
| Decoder mismatch                   | 11                                                                                                                                          |
| Missing type variants              | 3                                                                                                                                           |
| Logic bugs                         | 15 (+1: double debounce — generated + manual)                                                                                               |
| FFI issues                         | 14                                                                                                                                          |
| Config system fragmentation        | 4 (+1: psypi_config writes to DB but hooks read from in-memory)                                                                             |
| Seed/bootstrap gaps                | 10                                                                                                                                          |
| Dead code                          | 8                                                                                                                                           |
| Stub implementations               | 2                                                                                                                                           |
| Race conditions / concurrency      | 5                                                                                                                                           |
| Extension generation bugs          | 8 (+2: missing task_get_tool, session_start/model_select pass object as string)                                                             |
| A/S lifecycle logic failures       | 8                                                                                                                                           |
| Tool execution flow bugs           | 4                                                                                                                                           |
| Hook module bugs                   | 9                                                                                                                                           |
| Command module bugs                | 2                                                                                                                                           |
| DB module bugs                     | 7                                                                                                                                           |
| A/S DB reader bugs                 | 7                                                                                                                                           |
| Monitor AI bugs                    | 9                                                                                                                                           |
| Monitor module bugs                | 4                                                                                                                                           |
| Event hooks bugs                   | 4                                                                                                                                           |
| Node PG FFI bugs                   | 1                                                                                                                                           |
| Inter-review bugs                  | 7                                                                                                                                           |
| Tool commit bugs                   | 3                                                                                                                                           |
| Tool consult bugs                  | 2                                                                                                                                           |
| Code version bugs                  | 1                                                                                                                                           |
| Meeting bugs                       | 3                                                                                                                                           |
| Agent identity bugs                | 5                                                                                                                                           |
| Task bugs                          | 6                                                                                                                                           |
| Issue bugs                         | 4                                                                                                                                           |
| Broadcast bugs                     | 6                                                                                                                                           |
| Skill bugs                         | 3                                                                                                                                           |
| Agents bugs                        | 2                                                                                                                                           |
| Stats bugs                         | 3                                                                                                                                           |
| A orchestrator bugs                | 3                                                                                                                                           |
| A prompt builder bugs              | 2                                                                                                                                           |
| Simple migrate bugs                | 4                                                                                                                                           |
| System prompt types bugs           | 3                                                                                                                                           |
| A context utils bugs               | 2                                                                                                                                           |
| Areflect bugs                      | 5 (+5: save_issue missing project_id, save_learning to wrong table, unused agent_id, fetch_recent_issues id no cast, issue_type always bug) |
| Extension generator bugs           | 2                                                                                                                                           |
| FFI node_ffi.mjs bugs              | 4                                                                                                                                           |
| FFI pi_extension_ffi.mjs bugs      | 7                                                                                                                                           |
| FFI agent_identity_ffi.mjs bugs    | 1                                                                                                                                           |
| FFI time_utils_ffi.mjs bugs        | 1                                                                                                                                           |
| Migration schema bugs              | 5                                                                                                                                           |
| **TOTAL CONFIRMED BUGS**           | **230**                                                                                                                                     |
