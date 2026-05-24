# PsyPI Deep Codebase Review

**Date:** 2026-05-24
**Reviewer:** S-agentbot (deep analysis)
**Scope:** 70+ Gleam source files, 7 migration files, 4 FFI modules, 1 test file, 30+ documentation files

---

## 1. PROJECT OVERVIEW

**psypi** is a Gleam-to-JavaScript Pi TUI extension that implements an **A-S Dual Workflow**: an Autonomic Agentbot (A) that monitors and coordinates, and a Somatic Agentbot (S) that executes tasks. The system uses PostgreSQL as a context bridge between the two agents.

**Stack**: Gleam (targeting Node.js), PostgreSQL, Pi SDK, `node_pg`, `simplifile`, `gleam_json`

---

## 2. CRITICAL ISSUES (Must Fix)

### 2.0 [MOST SERIOUS] Fake Gleam — Raw JS Strings Bypassing the Typed Pipeline

**This is the #1 problem.** The `extension_generator.gleam` file contains raw JavaScript strings that bypass the project's core architecture: the **PiToolCall/PiEventHook/PiCommandReg typed pipeline**.

#### The Correct Architecture (Designed by the Author)

The project has a sound design principle: **AIs write Gleam, not JS.**

The architecture works like this:
1. Each domain module defines typed values: `PiToolCall`, `PiEventHook`, `PiCommandReg`
2. These types carry ALL metadata needed by the Pi Extension API (name, description, params, module, fn_name, args, result_format)
3. **Generator functions** (`to_js_text()`, `event_hook_to_js()`, `command_to_js()`) convert these typed values into JS text through **structured pattern matching** — this IS the correct way to produce the `extension.js` bridge
4. The `extension_generator` collects these values and composes them into `extension.js`
5. Pi requires `export default function(pi) { ... }` — Gleam cannot compile directly to this, so text composition from typed values is the proper bridge
6. The Gleam compiler validates the typed values — AIs cannot bypass this by writing raw JS

The generator functions (`to_js_text()`, `event_hook_to_js()`, `command_to_js()`) are **proper JS generators**. They take typed Gleam values and produce JS text through pattern matching on `PiToolCall`, `PiEventHook`, `PiCommandReg` variants. This is type-safe and compiler-validated.

#### The Violations — What Bypasses the Typed Pipeline

The violations are NOT the generator functions. The violations are the raw JS strings that bypass the typed pipeline entirely:

**A. `PiRawHook` and `PiRawCommand` — escape hatches that accept raw JS strings**

```gleam
PiRawHook(event_name: String, handler_body: String)   // ← handler_body is raw JS
PiRawCommand(name: String, description: String, handler_body: String)  // ← same
```

These variants accept a `handler_body: String` field — a raw JS string that bypasses the typed pipeline entirely. No Gleam type checker can validate the JS syntax. No compiler can catch errors. This is the **root cause** of the fake Gleam problem.

**B. Inline JS helper functions — handwritten JS strings dumped into Gleam files**

| Function                         | What It Does                            | Why It's Wrong                                                                                       |
| -------------------------------- | --------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `unwrap_gleam_result_js()`       | Gleam `Result` → JS `{ok, value/error}` | Should be a proper FFI export in `pi_extension_ffi.mjs`, not a JS string emitted into `extension.js` |
| `gleam_value_to_json_js()`       | Gleam values → JSON-safe JS objects     | Should use `gleam_json` encoders in domain modules, not reverse-engineer `constructor.name`          |
| `before_agent_start_body_js()`   | System prompt injection                 | Should be a proper `PiEventHook` with `module`/`fn_name` pointing to a Gleam handler                 |
| `autonomic_wakeup_renderer_js()` | Message renderer                        | Should be a proper FFI export                                                                        |

**C. The `gleamValueToJson` function — the worst offender (50 lines)**

This handwritten JS function reverse-engineers Gleam's compiled JS object structure:

```javascript
if (name.startsWith('Task$Task') || name.startsWith('Issue$Issue') || 
    name.startsWith('Meeting$Meeting') || name.startsWith('Skill$Skill') || ...)
```

This is **extremely fragile** — any Gleam compiler change, module rename, or type rename silently breaks it. The proper approach: each domain module should define a `gleam_json` encoder (e.g., `task.encode_json(task)`) that the generated JS calls instead of `gleamValueToJson`.

#### Git Forensic Timeline — How It Got Ruined

| Commit             | Date       | What Happened                                                                                                                                             | ext_gen Lines | JS-String Lines |
| ------------------ | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | --------------- |
| `5871fba`          | Initial    | Original — already had handwritten JS for `monitor_consult_tool()` and `psypi_commit_tool()`                                                              | 421           | ~156            |
| `e6e0047..a2c8288` | May 18     | "Replace fake generator/* with real hooks" — 6 commits moving hooks into proper Gleam modules                                                             | ↓             | ↓               |
| `3a86361`          | May 18     | Phase 2A: Extended PiEventHook with structured types                                                                                                      | 345           | ~101            |
| `17cab94`          | May 18     | Phase 2D: Migrated simple hooks to structured PiEventHook                                                                                                 | 362           | ↓               |
| `6eb3f4a`          | May 19     | **Phase 2H: Peak clean state** — generator functions in `pi_tool_call.gleam`, `extension_generator.gleam` was just the registry                           | **324**       | **~19**         |
| `7d8fed7`          | May 21     | "fix: replace hand-written JS strings with Gleam code" — moved `time_utils` and `learning` JS to proper FFI                                               | —             | —               |
| `1782396`          | May 21     | "refactor: move hand-written JS strings into proper Gleam modules" — created `pi_js_helpers.gleam`, `pi_message_renderer.gleam`, `pi_system_prompt.gleam` | —             | —               |
| **`758b449`**      | **May 23** | **"Delete 6 fake Gleam modules, inline JS text generation into extension_generator"** — **THE RUIN COMMIT**                                               | **672**       | **~101**        |
| `6ffb8ac`          | May 23     | Added `gleamValueToJson` — 50 more lines of handwritten JS                                                                                                | 726           | ~142            |
| `30c706e`          | May 23     | Fix before_agent_start hook                                                                                                                               | 726           | —               |
| `3a7c55b`          | May 24     | Fix unwrapGleamResult serialization                                                                                                                       | 726           | —               |

**The ruin commit `758b449` (May 23, 13:38)** did two things wrong:

1. **Deleted 6 proper Gleam modules** and inlined their JS text into `extension_generator.gleam` — the commit message called them "fake" but they were the correct separation of concerns
2. **Stripped 301 lines from `pi_tool_call.gleam`** (520 → 232) — removed all generator functions (`params_to_js`, `to_js_text`, `to_import_line`, `event_hook_to_js`, `command_to_js`) and re-inlined them into `extension_generator.gleam`

The commit also added `// Do NOT re-extract into separate files.` — actively instructing future AIs to keep the bad architecture.

#### What Was Lost — The Clean Architecture (Phase 2H, commit `6eb3f4a`)

```
pi_tool_call.gleam (520 lines) — THE PROPER HOME FOR GENERATOR FUNCTIONS
  ├── Types: PiToolCall, PiEventHook, PiCommandReg, PiParam, FnArg, ResultFormat
  ├── Constructors: event_hook(), debounced_hook(), raw_event_hook()
  ├── Generator Functions (THE PROPER JS GENERATORS):
  │   ├── params_to_js() — PiParam list → TypeBox schema JS text
  │   ├── to_js_text() — PiToolCall → pi.registerTool({...}) JS text
  │   ├── to_import_line() — PiToolCall → import statement JS text
  │   ├── event_hook_to_js() — PiEventHook → pi.on(...) JS text
  │   └── command_to_js() — PiCommandReg → pi.registerCommand(...) JS text
  └── Helpers: string_param(), lit(), from_param(), raw_json()

extension_generator.gleam (324 lines) — THE REGISTRY
  ├── Imports of PiToolCall/PiEventHook/PiCommandReg values from domain modules
  ├── all_tools() — registry of PiToolCall values
  ├── all_event_hooks() — registry of PiEventHook values
  ├── all_commands() — registry of PiCommandReg values
  ├── generate() — calls to_js_text(), event_hook_to_js(), etc. and composes
  └── write_extension() — write to file
```

The generator was a **cook**: it gathered ingredients (typed values), prepared them (via `to_js_text()` etc.), and assembled the dish. The **generator functions** in `pi_tool_call.gleam` were the **proper JS generators** — they converted typed Gleam values to JS text through structured pattern matching.

#### Current State — The Ruined Architecture

```
pi_tool_call.gleam (232 lines) — STRIPPED
  ├── Types: PiToolCall, PiEventHook, PiCommandReg, PiParam, FnArg, ResultFormat
  ├── Constructors: event_hook(), debounced_hook(), raw_event_hook()
  └── Helpers: string_param(), lit(), from_param(), raw_json()
  ❌ NO generator functions — all moved to extension_generator.gleam

extension_generator.gleam (726 lines) — BLOATED
  ├── Generator functions (moved from pi_tool_call.gleam — correct logic, wrong home):
  │   ├── params_to_js(), tool_to_js_text(), tool_to_import_line()
  │   ├── event_hook_to_js(), command_to_js()
  │   └── These ARE proper generators — they should be back in pi_tool_call.gleam
  ├── Raw JS strings (THE REAL VIOLATIONS — bypass the typed pipeline):
  │   ├── unwrap_gleam_result_js() — should be FFI
  │   ├── gleam_value_to_json_js() — should be gleam_json encoders
  │   ├── before_agent_start_body_js() — should be PiEventHook with module/fn_name
  │   └── autonomic_wakeup_renderer_js() — should be FFI
  ├── Escape hatches (THE ROOT CAUSE — allow bypassing the typed pipeline):
  │   ├── PiRawHook(handler_body: String) — should not exist
  │   └── PiRawCommand(handler_body: String) — should not exist
  ├── Registries: all_tools(), all_event_hooks(), all_commands()
  ├── generate() — compose everything
  └── write_extension() — write to file
```

#### Why This Matters — Bugs Caused by Fake Gleam

1. **`[object Object]` error (commit `3a7c55b`)**: `unwrapGleamResult` couldn't serialize Gleam error objects properly because the JS string was hand-maintained instead of being a proper FFI function with type safety.

2. **`gleamValueToJson` hardcoded type names**: If any domain module renames a type (e.g., `Task` → `Todo`), the `gleamValueToJson` function silently produces wrong output. No compiler can catch this.

3. **`before_agent_start` prompt injection**: The system prompt is a raw string with escaped quotes. Any typo produces a JS syntax error at runtime.

4. **`PiRawHook` escape hatch**: Every use of `raw_event_hook()` bypasses the typed pipeline. The `before_agent_start` hook is the worst example — it should be a proper `PiEventHook` with `module`/`fn_name` pointing to a Gleam handler function.

#### Recovery Plan

1. **Move generator functions back to `pi_tool_call.gleam`** — `params_to_js`, `tool_to_js_text`, `tool_to_import_line`, `event_hook_to_js`, `command_to_js` belong there (their Phase 2H home)
2. **Move `unwrapGleamResult`** to `pi_extension_ffi.mjs` as a proper FFI export — no more emitting JS strings
3. **Replace `gleamValueToJson`** with `gleam_json` encoders in each domain module — no more `constructor.name` reverse-engineering
4. **Convert `before_agent_start_body_js()`** to a proper `PiEventHook` with `module: "hook_before_agent_start"`, `fn_name: "on_before_agent_start"` — the Gleam handler function can use `system_prompt_types.gleam`
5. **Move `autonomic_wakeup_renderer_js()`** to `pi_extension_ffi.mjs` as a proper FFI export
6. **Eliminate `PiRawHook` and `PiRawCommand`** — every hook/command should go through the typed pipeline
7. **Remove the "Do NOT re-extract" comment** — it was wrong
8. **Target**: `extension_generator.gleam` should be ~324 lines (the Phase 2H size), not 726

### 2.1 Missing Database Migrations — 10+ Tables Have No CREATE TABLE

The code queries **at least 16 database tables**, but migrations only create **6**:

| Table                    | Referenced In                                               | Migration?  |
| ------------------------ | ----------------------------------------------------------- | ----------- |
| `psypi_event_hooks`      | `event_hooks.gleam`                                         | YES - 003   |
| `system_directives`      | `directive.gleam`, `hook_on_agent_end.gleam`                | YES - 005   |
| `agent_identities`       | `agent_identity_db.gleam`, `agents.gleam`, `identity.gleam` | **MISSING** |
| `psypi_config`           | `psypi_config.gleam`                                        | YES - 007   |
| `agent_souls`            | `agent_identity.gleam`, `directive.gleam`                   | YES - 008   |
| `agent_jobs`             | (seed data only)                                            | YES - 009   |
| `tasks`                  | `task.gleam`, `hook_on_agent_end.gleam`                     | YES - 010   |
| `issues`                 | `issue_db.gleam`, `hook_on_agent_end.gleam`                 | **MISSING** |
| `skills`                 | `skill.gleam`, `stats.gleam`                                | **MISSING** |
| `meetings`               | `meeting.gleam`, `stats.gleam`                              | **MISSING** |
| `meeting_opinions`       | `meeting.gleam`                                             | **MISSING** |
| `inter_reviews`          | `inter_review.gleam`                                        | **MISSING** |
| `activity_log`           | `activity_log.gleam`, `monitor_ai.gleam`                    | **MISSING** |
| `memory`                 | `memory.gleam`, `monitor_ai.gleam`                          | **MISSING** |
| `code_versions`          | `code_version.gleam`, `monitor_ai.gleam`                    | **MISSING** |
| `provider_api_keys`      | `monitor.gleam`                                             | **MISSING** |
| `notifications`          | `monitor.gleam`                                             | **MISSING** |
| `project_communications` | `broadcast.gleam`                                           | **MISSING** |
| `agent_sessions`         | `hook_on_agent_end.gleam`                                   | **MISSING** |
| `agent_prefixes`         | `seed.gleam`                                                | **MISSING** |

**Impact**: A fresh database setup will fail immediately. The `seed.gleam` tries to INSERT into `agent_prefixes` which has no migration. The `hook_on_agent_end.gleam` queries `agent_sessions` which doesn't exist. This is the #1 problem — the project cannot be deployed from scratch.

### 2.2 Missing Migrations 001, 002, 004

The migration sequence jumps from nothing to 003, then 005. Files 001, 002, and 004 are missing. This suggests either:
- They were deleted (bad — migration history should be append-only)
- They were never created (meaning `agent_identities` and other base tables were created manually)

### 2.3 SQL Injection via `db.gleam` Connection Setup

In `db.gleam` lines 43-44:
```gleam
let set_sql = "SET app.current_project_id = '" <> project_id <> "'"
```
The `project_id` comes from an environment variable. While not directly user-controlled, this is still string concatenation into SQL. If `PSYPI_PROJECT_ID` contains a single quote, it breaks the SET statement.

### 2.4 `validation.gleam` Uses DB for Trivial Regex Check

`validation.gleam` opens a database connection just to run two regex checks on a commit message. This is absurd — a pure Gleam function with `string.contains` or regex would be 10x faster and simpler. The DB round-trip for a boolean check is a clear AI-generated anti-pattern.

---

## 3. MAJOR ISSUES (Should Fix)

### 3.1 Massive Dead Code — 30+ Unused Utility Modules

Verified imports across the entire codebase. Out of 70+ source files, **at least 30 are never imported by any other module**:

| Module                   | Lines | Actually Used? | Problem                                                    |
| ------------------------ | ----- | -------------- | ---------------------------------------------------------- |
| `bitwise_ops.gleam`      | 32    | NO             | Wraps `int.bitwise_and` etc. — pointless                   |
| `math_utils.gleam`       | 25    | NO             | `safe_divide`, `percentage`, `clamp` — unused              |
| `math_ops.gleam`         | 37    | NO             | `is_prime`, `to_degrees` — unused                          |
| `validation_utils.gleam` | 34    | NO             | Duplicate of `validation.gleam`                            |
| `hash_utils.gleam`       | 24    | NO             | Returns dummy values — placeholder                         |
| `encoding_utils.gleam`   | 31    | NO             | `url_encode` is naive, `base64_decode` not implemented     |
| `data_utils.gleam`       | 32    | NO             | `filter_map`, `group_by`, `sum_by` — unused                |
| `text_ops.gleam`         | 36    | NO             | `capitalize`, `pluralize` — unused                         |
| `string_ops.gleam`       | 33    | NO             | `title_case`, `truncate`, `count_occurrences` — duplicates |
| `string_utils.gleam`     | 23    | NO             | `truncate`, `split_lines` — duplicates                     |
| `cache_utils.gleam`      | 27    | NO             | In-memory Dict cache — never used                          |
| `error_utils.gleam`      | 30    | NO             | `AppError` type — never used                               |
| `json_utils.gleam`       | 26    | NO             | Naive JSON builder — `gleam_json` is already a dep         |
| `result_utils.gleam`     | 38    | NO             | `map_ok`, `combine_results` — unused                       |
| `path_utils.gleam`       | 28    | NO             | `filepath` package already imported                        |
| `time_ops.gleam`         | 40    | NO             | `format_seconds` with hardcoded patterns                   |
| `date_utils.gleam`       | 33    | NO             | `is_valid_date` — unused                                   |
| `utils.gleam`            | 7     | NO             | 7-line stub                                                |
| `cmd_utils.gleam`        | 13    | NO             | FFI stubs for `execute`/`exists`                           |
| `log_utils.gleam`        | 39    | NO             | `format_log` — unused                                      |
| `array_helpers.gleam`    | 39    | NO             | `chunk`, `flatten`, `find` — unused                        |
| `system_info.gleam`      | 15    | NO             | Returns "unknown" — placeholder                            |
| `package_json.gleam`     | 21    | NO             | Returns `Error(NotFound)` — placeholder                    |
| `context.gleam`          | 18    | NO             | Returns hardcoded strings                                  |
| `execute_cmd.gleam`      | 18    | NO             | Duplicate of `cmd_utils.gleam`                             |
| `identity.gleam`         | 91    | NO             | Redundant with `agent_identity.gleam`                      |
| `monitor.gleam`          | 294   | NO             | Redundant with `monitor_ai.gleam`                          |
| `config_reader.gleam`    | 46    | NO             | Duplicate of `config.gleam`                                |
| `db_query.gleam`         | 41    | NO             | Thin wrapper over `db.gleam`                               |
| `skill_loader.gleam`     | 346   | NO             | May be dead code                                           |
| `activity_log.gleam`     | 121   | NO             | Never imported by any active module                        |

**Only 1 utility module is actually used**: `file_utils.gleam` (imported by `extension_generator.gleam`).

This is classic AI bloat — each AI session added "utility" modules thinking they'd be useful, but none ever got consumed. These ~30 files represent ~800+ lines of dead code.

### 3.2 Duplicate `semantic_id` Implementation

There are **two** separate implementations of `semantic_id`:

1. `agent_identity_types.gleam` lines 23-44 — returns `Error(MissingSessionId)` when model is empty
2. `agent_identity.gleam` lines 56-76 — returns `Error(NotFound("missing model id"))` when model is empty

They produce the same ID format but use **different error types**. The test file imports from `agent_identity_types`, while the production code in `directive.gleam` uses `agent_identity_types.resolved_identity`. This is confusing and error-prone.

### 3.3 Duplicate `truncate` Function

`truncate` is implemented in at least 3 places:
- `string_utils.gleam` line 3
- `string_ops.gleam` line 17
- `hook_on_agent_end.gleam` line 523

### 3.4 `config.gleam` vs `config_reader.gleam` — Same Purpose, Different APIs

- `config.gleam`: reads `DATABASE_URL`, `AGENT_SESSION_ID` from env, returns `Config`
- `config_reader.gleam`: reads `DATABASE_URL`, `LOG_LEVEL`, `PORT` from env, returns `Config`

Both define a `Config` type with different fields. Both use `get_env` FFI but with different return types (`String` vs `Result(String, ConfigError)`). Neither is imported anywhere.

### 3.5 `hook_on_agent_end.gleam` — 546 Lines, Too Complex

This is the most critical file in the project (the A-agentbot coordination logic), and it's 546 lines of deeply nested `promise.await` calls. The function `coordinate_when_idle` has 6 levels of nesting. This is extremely hard to reason about and debug.

### 3.6 `parse_context_window` Does String Parsing of JSON

`hook_on_agent_end.gleam` lines 470-510 manually splits JSON strings to extract `contextWindow`:

```gleam
let key = "\"contextWindow\":"
case string.contains(usage_json, "contextWindow") {
  ...
  let parts = string.split(usage_json, key)
```

The project already depends on `gleam_json` — this should use a proper JSON decoder.

### 3.7 `call_monitor` in FFI Has Excessive Diagnostic Logging

`pi_extension_ffi.mjs` lines 51-165 has ~20 `ctx.ui.notify('[DIAG]...')` calls. These fire on every A-agentbot wake-up. In production, this creates noise and performance overhead. These should be behind a debug flag or removed.

### 3.8 `code_version.gleam` Calls Non-Existent DB Functions

`code_version.gleam` calls:
- `save_code_version(...)` — no migration creates this function
- `get_code_versions(...)` — no migration creates this function
- `restore_code_version(...)` — no migration creates this function

These are PostgreSQL functions that need `CREATE OR REPLACE FUNCTION` migrations. None exist.

---

## 4. MODERATE ISSUES (Should Address)

### 4.1 Test Coverage: 1 Test File, 3 Test Functions

The entire test suite is `test/psypi_test.gleam` — 123 lines testing only `semantic_id` from `agent_identity_types`. No tests for:
- Database operations
- Hook logic
- Extension generator output
- FFI functions
- Directive system
- Task/issue/skill management
- Monitor AI

### 4.2 `seed.gleam` References Non-Existent Table

`seed.gleam` line 56 tries to INSERT into `agent_prefixes` — a table with no migration.

### 4.3 `tasks` Table Schema Mismatch

Migration `010_create_tasks_table.sql` defines `priority INTEGER DEFAULT 0`, but `hook_on_agent_end.gleam` line 415 queries `is_stuck` column which doesn't exist in the migration. Similarly, `task_row_decoder` decodes `priority` as a string but the column is INTEGER.

### 4.4 `monitor.gleam` vs `monitor_ai.gleam` Overlap

- `monitor.gleam`: 294 lines, handles `provider_api_keys`, `notifications` — never imported
- `monitor_ai.gleam`: 607 lines, handles stats, health, suggestions — imported by extension_generator

These should be consolidated or the dead one removed.

### 4.5 `db.gleam` Hardcodes Connection Parameters

`db.gleam` lines 14-19 hardcodes `localhost:5432/psypi`. The `config.gleam` module reads `DATABASE_URL` from env but is never used by `db.gleam`. The connection should use the env var.

### 4.6 `simple_migrate.gleam` Silently Swallows Errors

`simple_migrate.gleam` lines 68-73:
```gleam
Error(e) -> {
  io.println("  ⚠️  " <> case e { ... })
  Ok(Nil)  // Returns Ok even on error!
}
```

Migration failures are logged as warnings but treated as success. This means a failed migration won't stop the process.

### 4.7 `memory.gleam` Tags Handling is Broken

`memory.gleam` line 81:
```gleam
dynamic.string(string.join(tags, ","))  // TODO: handle array properly
```

Tags are stored as comma-separated strings, but the decoder expects `decode.list(decode.string)`. This will fail at decode time if the DB column is `text[]` (PostgreSQL array), or will return a single string if the column is `text`.

---

## 5. DOCUMENTATION GAPS (Code vs. Docs)

### 5.1 ARCHITECTURE.md Describes Files That Don't Exist

`ARCHITECTURE.md` lists:
```
src/
  agent_identity_logic.gleam -- generate_semantic_id (pure)
  agent_end.gleam            -- agent_end hook (calls get_resolved_identity)
  autonomic_hooks.gleam      -- simple hooks (all take Context)
```

**Reality**: These files don't exist. The actual files are:
- `agent_identity_types.gleam` (not `agent_identity_logic.gleam`)
- `hook_on_agent_end.gleam` (not `agent_end.gleam`)
- No `autonomic_hooks.gleam` — hooks are in `extension_generator.gleam`

### 5.2 AS-COMMUNICATION.md Describes Wrong File Structure

`AS-COMMUNICATION.md` lists:
```
src/
  agent_identity_logic.gleam -- generate_semantic_id (ID format)
  agent_end.gleam           -- agent_end coordination (complex hook)
  autonomic_hooks.gleam     -- simple hooks (session_start, model_select, etc.)
```

Same issue — these files don't exist.

### 5.3 AS-COMMUNICATION.md Says "5 min debounce" but Code Has 15 min Default

The doc says:
> New: 5 minutes (300000ms) — enough time for S-agentbot to settle

But `hook_on_agent_end.gleam` line 63 has fallback `900000` (15 minutes):
```gleam
Error(_) -> 900000
```

And `psypi_config.gleam` reads from DB, where migration 007 seeds `300000` (5 min). So the DB default matches docs, but the code fallback doesn't.

### 5.4 MONITOR-BRIEF.md References `system_config` Table

`MONITOR-BRIEF.md` says:
> Read from `system_config` table

But the actual table is `psypi_config`. No `system_config` table exists.

### 5.5 ARCHITECTURE-A-S-CONTEXT.md Proposes `compaction_history` Table — Not Implemented

`ARCHITECTURE-A-S-CONTEXT.md` defines:
```sql
CREATE TABLE compaction_history (...)
```

No migration creates this table. The `session_compact` hook is listed as "needs implementation".

### 5.6 ARCHITECTURE-A-S-CONTEXT.md Proposes Context-Based Decision Logic — Not Implemented

The doc describes a 4-mode decision system (Preserve/Consolidate/Collaborate/Plan) based on context window usage. The actual `hook_on_agent_end.gleam` doesn't implement any of this — it just builds a prompt and calls the LLM.

### 5.7 SYSTEM-PROMPT-INJECTION.md Describes Old Architecture

`SYSTEM-PROMPT-INJECTION.md` references files that don't exist:
- `src/generator/agent_lifecycle.gleam`
- `src/generator/tool_result.gleam`

The actual code is in `hook_on_agent_end.gleam` and `hook_on_tool_result.gleam`.

### 5.8 AGENT-IDENTITY-FINAL.md Describes `Context` Type — Different from Actual

The doc shows:
```gleam
pub type Context {
  Context(is_idle: Bool, model_id: String, provider: String, ...)
}
```

But the actual type is `IdentityContext` in `agent_identity_types.gleam` with different field names (`source` not `provider`, `model` not `model_id`).

### 5.9 Docs Reference `deliverAs: 'nextTurn'` but Code Uses `deliverAs: 'steer'`

`SYSTEM-PROMPT-INJECTION.md` says:
> `deliverAs: "nextTurn"` — queue for next user prompt (non-interrupting)

But `pi_extension_ffi.mjs` line 43 uses:
```javascript
pi.sendMessage({...}, { triggerTurn: true, deliverAs: 'steer' });
```

`'steer'` interrupts the current turn, while `'nextTurn'` queues non-intrusively. This is a behavioral difference.

---

## 6. ARCHITECTURE OBSERVATIONS

### 6.1 What Works Well

1. **PiToolCall Generator Pattern** — Clean: Gleam defines tools as typed values, `extension_generator.gleam` composes JS text. Type-safe at the Gleam level.
2. **FFI Isolation** — Only 4 FFI files, properly using `new Ok(value)` / `new Error(error)` pattern.
3. **A-S Dual Workflow** — The core concept is sound: `ctx.isIdle()` as the gate, debounce for coordination, `pi.sendMessage()` for communication.
4. **SOUL from DB** — Agent identity enriched from `agent_souls` table is elegant.
5. **System Prompt Composition** — `system_prompt_types.gleam` with `PromptComposition`, `add_component`, `compose` is well-designed token budgeting.

### 6.2 What Needs Rethinking

1. **The `extension_generator.gleam` is a 726-line monolith** that inlines JS text for hooks, tools, commands, and helper functions. It's the single point of failure for the entire extension.
2. **Every DB operation opens a new connection** — `db.with_connection` creates and destroys a connection per call. No connection pooling.
3. **The `before_agent_start` hook is a hardcoded JS string** — It can't use the Gleam type system or be tested.
4. **`gleamValueToJson` in extension_generator** — A 50-line JS function that reverse-engineers Gleam's compiled JS object structure by checking `constructor.name`. This is extremely fragile — any Gleam compiler change breaks it.

---

## 7. SUMMARY SCORECARD

| Category           | Rating | Notes                                                                                                |
| ------------------ | ------ | ---------------------------------------------------------------------------------------------------- |
| **Architecture**   | B-     | Sound typed pipeline design, violated by PiRawHook/PiRawCommand escape hatches and inline JS helpers |
| **Database Layer** | F      | 10+ missing table migrations, broken code_version functions                                          |
| **Code Quality**   | D      | 30+ dead modules, duplicate implementations, excessive nesting                                       |
| **FFI Layer**      | B+     | Proper Ok/Error pattern, well-isolated, but excessive diagnostics                                    |
| **Test Coverage**  | F      | 3 test functions, 0% coverage of DB/hooks/tools                                                      |
| **Documentation**  | D      | Many docs describe aspirational or outdated architecture                                             |
| **Security**       | C      | SQL injection in db.gleam, shell escaping concerns in tool_commit                                    |

---

## 8. RECOMMENDED ACTION PLAN

### Priority 0 — Critical (system design violation)
0. **Restore the typed pipeline** — (a) move generator functions back to `pi_tool_call.gleam` (their Phase 2H home), (b) move `unwrapGleamResult` to FFI, (c) replace `gleamValueToJson` with `gleam_json` encoders, (d) convert `before_agent_start_body_js()` to proper `PiEventHook` with module/fn_name, (e) move `autonomic_wakeup_renderer_js()` to FFI, (f) eliminate `PiRawHook`/`PiRawCommand` escape hatches

### Priority 1 — Critical (blocks deployment)
1. Create missing migrations for all 14 tables without CREATE TABLE
2. Create PostgreSQL function migrations for `code_version.gleam` (save_code_version, get_code_versions, restore_code_version)
3. Fix SQL injection in `db.gleam` SET statement

### Priority 2 — Major (code health)
4. Delete 30 dead utility modules
5. Consolidate duplicate modules (identity, monitor, config)
6. Fix `parse_context_window` to use `gleam_json` decoder
7. Remove or flag diagnostic logging in `call_monitor`
8. Fix `memory.gleam` tags handling
9. Fix `tasks` table schema mismatch (`is_stuck` column, `priority` type)
10. Fix `simple_migrate.gleam` to propagate errors instead of swallowing them

### Priority 3 — Moderate (quality)
11. Update all documentation to match actual code
12. Add tests for DB operations, hook logic, extension generator
13. Add connection pooling to `db.gleam`
14. Use `DATABASE_URL` env var instead of hardcoded connection params
15. Split `hook_on_agent_end.gleam` into smaller functions
16. Split `extension_generator.gleam` into separate concerns

### Priority 4 — Nice to have
17. Implement `compaction_history` table and session_compact hook
18. Implement context-based decision logic (Preserve/Consolidate/Collaborate/Plan)
19. Replace `gleamValueToJson` with a more robust approach
20. Make `before_agent_start` hook testable
