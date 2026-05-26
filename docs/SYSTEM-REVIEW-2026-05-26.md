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

### Tables WITH Gleam types (12/115)

| DB Table               | Gleam Type | Module             | Status                                                  |
| ---------------------- | ---------- | ------------------ | ------------------------------------------------------- |
| tasks                  | Task       | task.gleam         | PARTIAL — 60 DB columns, Gleam type covers ~14          |
| issues                 | Issue      | issue_types.gleam  | PARTIAL — 31 DB columns, Gleam type covers ~9           |
| inter_reviews          | Review     | inter_review.gleam | BROKEN — missing `::text` casts on timestamps           |
| memory                 | Memory     | memory.gleam       | PARTIAL — `source='learn'` not in audit allowed_sources |
| skills                 | Skill      | skill.gleam        | PARTIAL — 56 DB columns, Gleam type covers ~11          |
| meetings               | Meeting    | meeting.gleam      | OK — basic columns match                                |
| meeting_opinions       | Opinion    | meeting.gleam      | OK — basic columns match                                |
| project_communications | Broadcast  | broadcast.gleam    | PARTIAL — INSERT works, but Gleam type incomplete       |
| agent_sessions         | Agent      | agents.gleam       | OK — basic columns match                                |
| psypi_config           | (inline)   | psypi_config.gleam | OK — key/value pattern                                  |
| activity_log           | (inline)   | monitor.gleam      | OK — basic columns match                                |
| learning_insights      | (none)     | areflect.gleam     | INSERT only, no read type                               |

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

| File               | Line | Column         | SQL Has Cast?  |
| ------------------ | ---- | -------------- | -------------- |
| inter_review.gleam | 148  | `requested_at` | NO — will fail |
| inter_review.gleam | 283  | `requested_at` | NO — will fail |
| inter_review.gleam | 285  | `requested_at` | NO — will fail |

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
2. It detects `source='learn'` is NOT in `allowed_sources`
3. It logs the INSERT to `direct_insert_audit` table (as a "violation")
4. If `insert_reminders` has an entry for `memory`, it sends a notification via `project_communications`

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

### P0 — Confirmed Runtime Bugs

1. Fix `monitor_ai.gleam:auto_file_issue` — `type` → `issue_type` (INSERT fails)
2. Fix `inter_review.gleam` — add `::text` casts to `requested_at` and other timestamps (decode fails)
3. Fix `skill.gleam` — add `AiBuilt` variant to `SkillSource` (decode fails for `source='ai-built'`)
4. Fix `learning.gleam` — change `source='learn'` to `'areflect'` or add `'learn'` to audit trigger's `allowed_sources`
5. Fix `gleamValueToJson` — replace `constructor.name` checks with `instanceof` or `$CustomType` detection

### P1 — Type Coverage & Architecture

6. Create Gleam type for `projects` table (currently no type, 1 row exists)
7. Implement `PLAN-project-id-lookup.md` for dynamic project_id resolution
8. Add `project_id` to `areflect.gleam` INSERT INTO tasks (inconsistent with task.add)
9. Fix `task.gleam` — add `::text` cast to `result` (JSONB) column in SELECT
10. Create Gleam types for high-value missing tables: `soul`, `system_reviews`, `conversations`

### P2 — Code Quality

11. Extract `decode_all_results` to shared `decode_utils.gleam` module
12. Deduplicate `now_ms` FFI (two different return types)
13. Remove orphan `time_utils_ffi.mjs`
14. Add field names to DecodeError messages
15. Remove error swallowing in `issue_db.gleam` and `a_db_reader.gleam`
16. Update `@mariozechner/pi-tui` → `@earendil-works/pi-tui` in extension_generator.gleam

### P3 — Architecture & Testing

17. Evaluate `squirrel` for type-safe SQL queries (prevents phantom column issues at compile time)
18. Add integration tests that verify SQL queries against real DB
19. Add schema validation at build time
20. Implement missing Pi extension API features (signal/cancellation, streaming, custom rendering)
21. Replace dynamic `await import()` in hooks with static imports

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
