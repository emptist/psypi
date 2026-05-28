# System Review — psypi — 2026-05-28 (Database-Backed, Re-verified)

Generated from `system_reviews` + `review_findings` database tables.
Review ID: `ca9e914c-cce6-4db4-b3b1-29779d8e1837`
Type: `system` | Methodology: `mixed` | Scope: `full`
Reviewer: `trae-ai` | Git: `706494e` (`after-rewriting`)

### Re-verification Notes

This review was re-verified against actual code flow and database schema. Key corrections:
- Retracted 11 false-positive uuid-without-::text findings (node-postgres returns uuid as string automatically)
- Retracted findings based on incorrect assumptions (e.g., #124 Gleam Bool=JS boolean, #158 Gleam package imports, #162 SQL injection)
- Corrected severity: only 1 CRITICAL finding remains (#249 FFI type mismatch)
- Added type alignment audit findings (#274-#287) based on systematic PG-column-type vs Gleam-decoder-type comparison
- All findings verified against: (1) actual source code, (2) database CHECK constraints, (3) node-postgres type mapping rules

## Severity Breakdown (Open Findings Only)

| Severity | Count | Percentage |
|----------|-------|------------|
| **CRITICAL** | 1 | 0.9% |
| **HIGH** | 27 | 25.5% |
| **MEDIUM** | 57 | 53.8% |
| **LOW** | 21 | 19.8% |
| **TOTAL (open)** | 106 | 100% |
| Retracted | 23 | - |
| Duplicate | 21 | - |
| **ALL findings** | 152 | - |

## Category Breakdown (Open Findings)

| Category | Count | C/H |
|----------|-------|-----|
| logic_error | 15 | 0C/7H |
| design_flaw | 10 | 0C/1H |
| unused_columns | 10 | - |
| type_mismatch | 9 | 0C/6H |
| missing_cast | 7 | 0C/1H |
| wrong_status | 5 | - |
| missing_params | 5 | 0C/2H |
| error_handling | 5 | - |
| missing_project_id | 4 | 0C/1H |
| disconnected_systems | 4 | 0C/2H |
| style | 4 | - |
| dead_code | 3 | - |
| hardcoded_config | 3 | - |
| missing_column | 3 | 0C/2H |
| ffi_mismatch | 3 | 1C/1H |
| design | 3 | - |
| schema_mismatch | 2 | 0C/1H |
| security | 2 | - |
| performance | 2 | 0C/1H |
| test_coverage | 2 | - |
| config_desync | 2 | 0C/1H |
| type_alignment | 1 | - |
| wrong_decoder | 1 | 0C/1H |
| unused_table | 1 | - |

## Type Alignment Reference

node-postgres type mapping rules (verified):
| PG Type | JS Type | Gleam Decoder | Cast Needed |
|---------|---------|---------------|-------------|
| uuid | string | decode.string | No |
| timestamptz | Date object | decode.string | **YES: ::text** |
| bigint/int8 | string | decode.int | **YES: ::int or custom** |
| jsonb | parsed object | decode.string | **YES: ::text** |
| integer | number | decode.int | No |
| boolean | boolean | decode.bool | No |
| text/varchar | string | decode.string | No |
| ARRAY | array | decode.list | No (for text[]) |

## Findings by Severity (Open Only)

### CRITICAL

| # | Category | Module | Title |
|---|----------|--------|-------|
| 249 | ffi_mismatch | pi_extension_ffi | get_config FFI returns JS null/string which never matches Gleam None/Some constructors |
### HIGH

| # | Category | Module | Title |
|---|----------|--------|-------|
| 262 | config_desync | pi_extension_ffi | Dual config stores: FFI _configStore (in-memory) and psypi_config table (DB) are never synchronized |
| 146 | design_flaw | monitor_ai | monitor_ai prepare_context: memory table has no saved_at column (SQL error) |
| 247 | disconnected_systems | a_orchestrator | a_orchestrator.run_a_workflow never writes inter-review response to DB |
| 258 | disconnected_systems | inter_review | Inter-review commit flow is permanently stuck — missing git add before git commit |
| 123 | ffi_mismatch | pi_extension_ffi | unwrapGleamResult may not handle all Gleam Result shapes |
| 139 | logic_error | broadcast | broadcast.stats() 3 bugs: bigint decode, text>=int, missing status column |
| 250 | logic_error | agent_identity | semantic_id uses is_idle (momentary state) for A/S prefix (permanent identity) |
| 251 | logic_error | a_orchestrator | compose() called instead of compose_within_budget() — token budget system unused |
| 261 | logic_error | multiple | A-bot wakeup chain: get_config FFI type mismatch prevents debounce from working |
| 264 | logic_error | tool_commit | tool_commit permanently blocked: overall_score is always NULL because a_orchestrator never writes review response to DB |
| 265 | logic_error | seed | seed.gleam multi-statement SQL: node-postgres may only execute first statement, silently dropping rest |
| 277 | logic_error | memory | memory.gleam: save() RETURNING id then decodes with full memory_decoder (expects all 7 fields) |
| 100 | missing_cast | inter_review | inter_review requested_at decode fails without ::text cast |
| 280 | missing_column | monitor_ai | monitor_ai.gleam: auto_file_issue() missing project_id (NOT NULL, no default) in INSERT |
| 281 | missing_column | areflect | areflect.gleam: save_issue() missing project_id (NOT NULL, no default) in INSERT |
| 129 | missing_params | code_version | psypi-doc-save only declares file_path but uses 5 parameters |
| 256 | missing_params | agent_identity | psypi-my-id missing project and global fields in generated JS object |
| 116 | missing_project_id | areflect | areflect.save_issue omits project_id (NOT NULL, no default) |
| 137 | performance | db | db.with_connection() creates new TCP connection per query |
| 279 | schema_mismatch | monitor_ai | monitor_ai.gleam: auto_file_issue() INSERT uses column "type" but issues table has "issue_type" |
| 226 | type_mismatch | skill | SkillSource missing ai-built variant that DB allows |
| 274 | type_mismatch | task | task.gleam: result column is jsonb but decoded as decode.optional(decode.string) |
| 276 | type_mismatch | memory | memory.gleam: search() SELECT * returns created_at as timestamptz without ::text cast |
| 278 | type_mismatch | skill | skill.gleam: get() and search() missing ::text cast for content and reference_list (both jsonb) |
| 283 | type_mismatch | broadcast | broadcast.gleam: stats() has 3 independent bugs: bigint decode, text>=int comparison, missing status column |
| 284 | type_mismatch | inter_review | inter_review.gleam: 3 queries SELECT requested_at (timestamptz) without ::text cast |
| 138 | wrong_decoder | memory | memory.save() decodes RETURNING id with full memory_decoder() |
### MEDIUM

| # | Category | Module | Title |
|---|----------|--------|-------|
| 126 | config_desync | seed | seed.gleam seeds monitor_debounce_ms as 300000 but DB has 900000 |
| 145 | dead_code | monitor_ai | housekeeping() is a test stub left in production |
| 255 | dead_code | monitor_ai | tool_consult is a stub — returns hardcoded message, no actual A-bot consultation |
| 260 | dead_code | agent_identity | _global computed but never used — global_prefix in semantic_id reads ctx.global which is never set |
| 270 | design | simple_migrate | No migration tracking table: simple_migrate runs all scripts every time with no record of which were applied |
| 147 | design_flaw | hook_on_before_agent_start | Error fallback includes hardcoded soul content |
| 149 | design_flaw | extension_generator | Dynamic imports in every hook trigger |
| 151 | design_flaw | audit_trigger | Audit trigger source=learn not in allowed sources |
| 154 | design_flaw | pi_extension_ffi | Duplicate now_ms FFI in both pi_extension_ffi.mjs and time_ffi.mjs |
| 156 | design_flaw | monitor_ai | call_monitor retry without exponential backoff |
| 245 | design_flaw | a_db_reader | agent_sessions has TWO heartbeat columns: last_heartbeat and last_heartbeat_at |
| 246 | design_flaw | hook_on_tool_result | hook_on_tool_result uses string.contains for error detection instead of JSON parsing |
| 252 | design_flaw | hook_on_tool_call | hook_on_tool_call only handles "edit" tool — all other tools ignored |
| 127 | disconnected_systems | areflect | areflect saves to learning_insights; learning.gleam saves to memory; neither reads the other |
| 128 | disconnected_systems | areflect | areflect.save_learning ignores agent_id parameter |
| 142 | error_handling | pi_extension | pi_send_message fire-and-forget; no error feedback |
| 159 | error_handling | multiple | Error handling anti-pattern: Ok(0) on decode failure in 4+ modules |
| 153 | ffi_mismatch | pi_extension_ffi | gleamValueToJson uses constructor.name which breaks under minification |
| 134 | hardcoded_config | issue_db | issue_db.get() and resolve() hardcode project_id UUID |
| 135 | hardcoded_config | issue_db | issue_db.list() comment says session variable but hardcodes UUID |
| 136 | hardcoded_config | db | db.connect() sets app.current_project_id but no module reads it |
| 140 | logic_error | agent_identity | semantic_id uses is_idle for A/S prefix; idle S-agent gets wrong identity |
| 141 | logic_error | hook_on_agent_end | hook_on_tool_result synchronous return in async context |
| 160 | logic_error | hook_on_agent_end | A/S agent debounce logic: idle_since reset on every tool call |
| 248 | logic_error | monitor | monitor.set_model blanket reset race condition |
| 267 | logic_error | event_hooks | record_trigger called twice per agent start: before_agent_start and agent_start both trigger on same event |
| 269 | logic_error | simple_migrate | simple_migrate.gleam may silently drop multi-statement migration scripts |
| 271 | logic_error | command_listen | command_listen bypasses A-bot debounce chain — directly calls LLM and sends to S with no DB record |
| 104 | missing_cast | task | task.get missing project_id::text in SELECT |
| 105 | missing_cast | task | task.list id not cast to text |
| 106 | missing_cast | agents | agents.list missing ::text cast on created_at |
| 107 | missing_cast | monitor | monitor.get_pending_notifications read_at cast mismatch |
| 108 | missing_cast | code_version | code_version.query_versions missing ::text casts |
| 110 | missing_cast | a_db_reader | a_db_reader multiple queries missing ::text casts |
| 275 | missing_column | task | task.gleam: get() SELECT missing project_id column that decoder expects |
| 132 | missing_params | memory | memory.memory_search_tool result template uses literal {count} |
| 119 | missing_project_id | a_db_reader | a_db_reader.read_active_tasks no project_id filter |
| 120 | missing_project_id | broadcast | broadcast.send empty string for UUID NOT NULL column |
| 253 | performance | db | No connection pooling — every query creates and destroys a connection |
| 285 | schema_mismatch | areflect | areflect.gleam: save_learning() inserts into learning_insights table but psypi also has learnings table |
| 155 | security | pi_extension_ffi | exec_sync allows command injection via unsanitized input |
| 286 | type_alignment | multiple | Type alignment audit: 8 modules have timestamptz/jsonb/bigint decode mismatches |
| 228 | type_mismatch | meeting | MeetingStatus has Pending but DB only allows active/completed/cancelled |
| 230 | type_mismatch | issue_types | IssueType missing proposal which DB allows |
| 282 | type_mismatch | a_db_reader | a_db_reader.gleam: is_s_still_idle() COUNT(*) decoded as decode.int but node-postgres returns bigint as string |
| 232 | unused_columns | task | tasks table has 60 DB columns but Gleam decoder only handles 14 (46 unused) |
| 233 | unused_columns | skill | skills table has 60+ DB columns but Gleam decoder only handles ~10 (45+ unused) |
| 234 | unused_columns | issue_db | issues table has 30+ DB columns but Gleam decoder only handles ~15 (15+ unused) |
| 235 | unused_columns | inter_review | inter_reviews table has 30+ DB columns but Gleam decoder only handles 6 (27+ unused) |
| 238 | unused_columns | areflect | learning_insights: areflect only INSERTs 4 columns, never reads any. 9 DB columns never used. |
| 240 | unused_columns | event_hooks | psypi_event_hooks: 7 of 14 DB columns never used by Gleam code |
| 231 | unused_table | global | 4 agent_* tables exist in DB but are never used by psypi Gleam code |
| 113 | wrong_status | monitor_ai | get_model_stats case-sensitive status comparison |
| 114 | wrong_status | task | task.string_to_status accepts both cases but DB is uppercase |
| 115 | wrong_status | issue_types | IssueStatus Gleam type vs DB CHECK mismatch |
| 206 | wrong_status | a_db_reader | a_db_reader read_open_issues uses status=closed but DB has no closed status |
| 210 | wrong_status | issue_types | IssueStatus missing acknowledged/wont_fix/duplicate; has Closed which DB doesnt have |
### LOW

| # | Category | Module | Title |
|---|----------|--------|-------|
| 225 | design | simple_migrate | simple_migrate re-runs all migrations every time — no tracking of completed migrations |
| 268 | design | extension_generator | extension_generator uses raw JSON schema for tool parameters instead of Pi SDK recommended TypeBox |
| 150 | design_flaw | hook_on_tool_call | Only triggers on tool named "edit" |
| 143 | error_handling | issue_db | issue_db.count() returns Ok(0) on decode failure |
| 144 | error_handling | a_db_reader | a_db_reader reports Ok(True) on decode failure |
| 273 | error_handling | db | db.gleam with_connection() ignores disconnect errors — potential connection leak |
| 257 | logic_error | pi_extension_ffi | _configStore in-memory cache has race condition with concurrent access |
| 130 | missing_params | issue_tools | psypi-issue-add references created_by not in params |
| 131 | missing_params | issue_tools | psypi-issues does not declare limit/offset in params |
| 213 | missing_project_id | learning | learning.save() INSERT INTO memory omits project_id |
| 272 | security | node_ffi | node_ffi execute() uses execSync with unsanitized shell commands — command injection risk |
| 148 | style | command_reload | command_reload only notifies; no error handling |
| 157 | style | pi_extension_ffi | Orphan FFI file not imported by any Gleam module |
| 163 | style | git | Git state shows AI repair pattern: many fix commits without verification |
| 263 | style | pi_extension_ffi | gleamValueToJson has hardcoded type name list — new Gleam types not serialized as records |
| 152 | test_coverage | test | Gleam test files import modules that dont exist |
| 161 | test_coverage | test | No integration tests for database queries |
| 239 | unused_columns | monitor | provider_api_keys: Gleam only reads provider and model, never reads encrypted_key, status, etc. |
| 241 | unused_columns | broadcast | project_communications: 4 DB columns never used by Gleam code |
| 242 | unused_columns | meeting | meetings: 4 DB columns never used by Gleam code |
| 243 | unused_columns | system_review_db | system_reviews: 3 JSONB columns (findings, action_items, limitations) never read after migration to review_findings table |

## Detailed Findings (Open Only)

### #249 — get_config FFI returns JS null/string which never matches Gleam None/Some constructors

- **Severity**: CRITICAL
- **Category**: ffi_mismatch
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: pi_extension_ffi.mjs get_config returns null when key not found, or the raw string value when found. Gleam expects Option(String): None or Some(string). JS null does not equal Gleam None, and JS string does not equal Gleam Some(string). The Some branch in hook_on_agent_end is NEVER reached.

**Evidence**: `pi_extension_ffi.mjs: return row ? row.value : null; hook_on_agent_end.gleam uses case get_config(...) { Some(val) -> ... None -> ... } but Some is never matched`

**Impact**: idle_since is always re-recorded as now(). Debounce never fires. A-bot wakeup is completely broken.

### #262 — Dual config stores: FFI _configStore (in-memory) and psypi_config table (DB) are never synchronized

- **Severity**: HIGH
- **Category**: config_desync
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: hook_on_agent_end.gleam uses pi_extension.get_config/set_config which goes to FFI _configStore (in-memory JS object). psypi_config.gleam has its own get/set that reads/writes the psypi_config DB table. These two stores are completely independent. Setting a value via one is invisible to the other. Process restart loses all _configStore data.

**Evidence**: `pi_extension_ffi.mjs: let _configStore = {}; get_config reads _configStore; psypi_config.gleam: SELECT value FROM psypi_config WHERE key = $1; hook_on_agent_end.gleam uses pi_extension.get_config not psypi_config.get`

**Impact**: idle_since and monitor_debounce_ms are stored in _configStore (in-memory) but never persisted to DB. On process restart all debounce state is lost. psypi_config table exists but is not used by the debounce logic.

### #146 — monitor_ai prepare_context: memory table has no saved_at column (SQL error)

- **Severity**: HIGH
- **Category**: design_flaw
- **Module**: `monitor_ai`
- **Status**: open

**Description**: monitor_ai.prepare_context() UNION ALL query references saved_at::text from the memory table, but memory has no saved_at column. The memory table has created_at and updated_at, not saved_at. This causes a SQL error: "column saved_at does not exist". The code_versions table does have saved_at, so the second SELECT is fine. The first SELECT fails.

**Evidence**: `monitor_ai.gleam:112 SELECT saved_at::text FROM memory; memory table columns: id, project_id, content, source, tags, metadata, created_at, updated_at, embedding, importance, agent_id, session_id, viewers, has_sensitive (no saved_at)`

**Impact**: Context preparation may fail or return wrong data

### #247 — a_orchestrator.run_a_workflow never writes inter-review response to DB

- **Severity**: HIGH
- **Category**: disconnected_systems
- **Module**: `a_orchestrator`
- **Status**: open

**Description**: When A-bot generates a review response via call_monitor, the response is only sent via pi_send_message("autonomic-wakeup"). It is never written to inter_reviews table. The review response exists only in the Pi message queue, not in the database.

**Evidence**: `a_orchestrator.gleam: full file — no INSERT INTO inter_reviews; only pi_send_message(pi, "autonomic-wakeup", response, "persistent")`

**Impact**: Inter-review responses are ephemeral. If Pi message queue is lost, review data is lost. No audit trail. Additionally, tool_commit is permanently blocked because overall_score is never written (see #264).

### #258 — Inter-review commit flow is permanently stuck — missing git add before git commit

- **Severity**: HIGH
- **Category**: disconnected_systems
- **Module**: `inter_review`
- **Status**: open

**Description**: The inter-review flow calls tool_commit.gleam which runs git commit but does not run git add first. Without git add, untracked files are not committed. The commit may succeed but with empty diff, or fail if no staged changes exist.

**Evidence**: `tool_commit.gleam: exec_sync("git commit ...") without prior git add; inter_review flow never calls git add`

**Impact**: Inter-review code changes are never actually committed. Review feedback is generated but code is not saved.

### #123 — unwrapGleamResult may not handle all Gleam Result shapes

- **Severity**: HIGH
- **Category**: ffi_mismatch
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: Gleam Result is {type: "Ok"/"Error", ...} but unwrap logic may miss edge cases

**Evidence**: `pi_extension_ffi.mjs: unwrapGleamResult()`

**Impact**: Error handling in extension.js may fail

### #139 — broadcast.stats() 3 bugs: bigint decode, text>=int, missing status column

- **Severity**: HIGH
- **Category**: logic_error
- **Module**: `broadcast`
- **Status**: open

**Description**: broadcast.stats() has 3 bugs: (1) priority is text (low/normal/high/critical) but query does priority >= 2 which is text>=int comparison — always fails; (2) WHERE status = sent but project_communications has no status column; (3) COUNT(*) returns bigint without ::INT cast CROSS-REF: See #283 for verified analysis with node-postgres type mapping evidence.

**Evidence**: `broadcast.gleam stats(): priority text>=2, status column does not exist in project_communications, COUNT(*) without ::INT`

**Impact**: Stats query returns wrong results or fails

### #250 — semantic_id uses is_idle (momentary state) for A/S prefix (permanent identity)

- **Severity**: HIGH
- **Category**: logic_error
- **Module**: `agent_identity`
- **Status**: open

**Description**: psypi-my-id tool determines A or S prefix by calling ctx_is_idle(ctx). When S is idle between turns, calling psypi-my-id returns an A-prefixed identity. Wrong soul loaded, wrong jobs fetched.

**Evidence**: `agent_identity.gleam: semantic_id() calls ctx_is_idle(ctx) to determine prefix; if idle, returns "A-" prefix`

**Impact**: When S is momentarily idle, it gets A-prefixed identity. Wrong soul loaded, wrong jobs fetched, wrong behavior.

### #251 — compose() called instead of compose_within_budget() — token budget system unused

- **Severity**: HIGH
- **Category**: logic_error
- **Module**: `a_orchestrator`
- **Status**: open

**Description**: a_orchestrator.gleam:66 calls compose(a_prompt_builder.build_system_prompt(...)) which concatenates all prompt parts without limit. compose_within_budget() exists in system_prompt_types.gleam and respects token limits but is never called.

**Evidence**: `a_orchestrator.gleam:66 compose(...); system_prompt_types.gleam has compose_within_budget() that truncates to fit context window`

**Impact**: A-bot system prompt may exceed context window, causing LLM failures. Token budget system exists but is never used.

### #261 — A-bot wakeup chain: get_config FFI type mismatch prevents debounce from working

- **Severity**: HIGH
- **Category**: logic_error
- **Module**: `multiple`
- **Status**: open

**Description**: The A-bot wakeup chain has 4 sequential failures each of which alone would break the system: (1) get_config FFI returns JS null/string not Gleam Option so debounce never fires (#249), (2) is_s_still_idle always returns True because no code updates heartbeats (#244), (3) compose() called instead of compose_within_budget() so prompt may exceed context (#251), (4) a_orchestrator never writes inter-review response to DB (#247). All 4 must be fixed for A-bot to work.

**Evidence**: `hook_on_agent_end.gleam:34 get_config never matches; a_db_reader.gleam:34 no heartbeat updates; a_orchestrator.gleam:66 compose() not compose_within_budget(); a_orchestrator.gleam: no INSERT INTO inter_reviews`

**Impact**: A-bot system is completely non-functional. No autonomous monitoring no inter-review no self-healing. The entire A/S dual-agent architecture is dead on the A side.

### #264 — tool_commit permanently blocked: overall_score is always NULL because a_orchestrator never writes review response to DB

- **Severity**: HIGH
- **Category**: logic_error
- **Module**: `tool_commit`
- **Status**: open

**Description**: tool_commit.commit_if_reviewed() checks review.overall_score. If None, returns "Review not yet complete". Since a_orchestrator never writes the review response to inter_reviews (finding #247), overall_score stays NULL forever. The entire commit workflow is dead at Phase 2.

**Evidence**: `tool_commit.gleam:44 case review.overall_score { None -> Error("Review not yet complete...") }; inter_reviews table: overall_score column is NULL for all rows because no code writes it; a_orchestrator.gleam: no UPDATE inter_reviews SET overall_score=...`

**Impact**: Commits are permanently blocked. The psypi-commit tool can never succeed in Phase 2. Users must commit manually outside the tool.

### #265 — seed.gleam multi-statement SQL: node-postgres may only execute first statement, silently dropping rest

- **Severity**: HIGH
- **Category**: logic_error
- **Module**: `seed`
- **Status**: open

**Description**: seed.gleam passes multi-statement SQL strings (e.g. INSERT...; INSERT...; INSERT...) to db.query(). node-postgres may only execute the first statement and silently drop the rest. This means agent_souls and agent_prefixes may only get the first row seeded.

**Evidence**: `seed.gleam:42 "INSERT INTO agent_souls ... SELECT 'A'...; INSERT INTO agent_souls ... SELECT 'S'..."; seed.gleam:56 "INSERT INTO agent_prefixes ... SELECT 'A'...; INSERT INTO agent_prefixes ... SELECT 'S'...; INSERT INTO agent_prefixes ... SELECT 'G'..."; node-postgres documentation: multi-statement queries may return only first result`

**Impact**: Only the first soul (A) and first prefix (A) may be seeded. S and G prefixes/souls may be missing, causing identity and session failures.

### #277 — memory.gleam: save() RETURNING id then decodes with full memory_decoder (expects all 7 fields)

- **Severity**: HIGH
- **Category**: logic_error
- **Module**: `memory`
- **Status**: open

**Description**: memory.save() does "INSERT INTO memory ... RETURNING id" which only returns the id column. But the code then tries to decode the result row with memory_decoder() which expects id, content, tags, source, agent_id, importance, and created_at. Since only id is present, the decode fails for all other fields.

**Evidence**: `memory.gleam:86 RETURNING id; memory.gleam:91 decode.run(row, memory_decoder()) which expects 7 fields`

**Impact**: memory.save() always fails with DecodeError after successful INSERT. The memory is saved to DB but the function returns an error, so the caller never gets the id. The psypi-memory-save tool appears to fail even though data is persisted.

### #100 — inter_review requested_at decode fails without ::text cast

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `inter_review`
- **Status**: open

**Description**: SELECT * returns timestamptz without cast; node-postgres returns Date object which Gleam decode.string cannot parse CROSS-REF: See #284 for the same issue across all 3 inter_review queries.

**Evidence**: `inter_review.gleam:148,283,285 SELECT requested_at without ::text; inter_reviews.requested_at is timestamptz; node-postgres returns Date object; decode.string expects string`

**Impact**: Inter-review requests always fail to decode

### #280 — monitor_ai.gleam: auto_file_issue() missing project_id (NOT NULL, no default) in INSERT

- **Severity**: HIGH
- **Category**: missing_column
- **Module**: `monitor_ai`
- **Status**: open

**Description**: auto_file_issue() INSERT INTO issues does not include project_id. The issues table has project_id uuid NOT NULL with no default value. Even if the "type" column name were fixed, the INSERT would fail with NOT NULL constraint violation.

**Evidence**: `monitor_ai.gleam:559 INSERT INTO issues (title, description, severity, type, ...); issues table: project_id uuid NOT NULL (no default)`

**Impact**: auto_file_issue() always fails. Combined with #279 (wrong column name), this function has two independent bugs that each prevent it from working.

### #281 — areflect.gleam: save_issue() missing project_id (NOT NULL, no default) in INSERT

- **Severity**: HIGH
- **Category**: missing_column
- **Module**: `areflect`
- **Status**: open

**Description**: save_issue() does "INSERT INTO issues (title, description, severity, created_by)" but issues.project_id is uuid NOT NULL with no default. The INSERT will fail with NOT NULL constraint violation.

**Evidence**: `areflect.gleam:228 INSERT INTO issues (title, description, severity, created_by); issues table: project_id uuid NOT NULL (no default)`

**Impact**: areflect.gleam save_issue() always fails. The psypi-areflect tool cannot save [ISSUE] markers to the database. All issue extraction from agent reflections is silently lost.

### #129 — psypi-doc-save only declares file_path but uses 5 parameters

- **Severity**: HIGH
- **Category**: missing_params
- **Module**: `code_version`
- **Status**: open

**Description**: params: [file_path] but args references content, saved_by, commit_hash, reason

**Evidence**: `code_version.gleam doc_save_tool(): 1 param declared, 5 used`

**Impact**: Content always empty; saved versions have no content

### #256 — psypi-my-id missing project and global fields in generated JS object

- **Severity**: HIGH
- **Category**: missing_params
- **Module**: `agent_identity`
- **Status**: open

**Description**: agent_identity.gleam builds IdentityContext with lit() but omits project and global fields. semantic_id() reads ctx.project which becomes undefined in JS, stringifying to "undefined". Semantic ID becomes "S-undefined-anthropic-claude-3.5-sonnet" instead of "S-psypi-anthropic-...".

**Evidence**: `agent_identity.gleam: lit() expression does not include project or global fields; compiled JS shows ctx.project is undefined`

**Impact**: Semantic IDs contain "undefined" instead of project name. G-prefix never used. Identity system broken.

### #116 — areflect.save_issue omits project_id (NOT NULL, no default)

- **Severity**: HIGH
- **Category**: missing_project_id
- **Module**: `areflect`
- **Status**: open

**Description**: INSERT INTO issues (title, description, severity, created_by) — missing project_id column CROSS-REF: See #281 for same issue with verified root cause (project_id uuid NOT NULL no default).

**Evidence**: `areflect.gleam save_issue(): 4-column INSERT into 6-column table`

**Impact**: save_issue INSERT always fails; no issues can be saved via areflect

### #137 — db.with_connection() creates new TCP connection per query

- **Severity**: HIGH
- **Category**: performance
- **Module**: `db`
- **Status**: open

**Description**: Every query: connect → auth → SET variable → query → disconnect

**Evidence**: `db.gleam with_connection(): no pooling, uses pg.Client not pg.Pool`

**Impact**: 3-10x latency overhead; potential connection exhaustion

### #279 — monitor_ai.gleam: auto_file_issue() INSERT uses column "type" but issues table has "issue_type"

- **Severity**: HIGH
- **Category**: schema_mismatch
- **Module**: `monitor_ai`
- **Status**: open

**Description**: auto_file_issue() does "INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment)" but the issues table column is named "issue_type" not "type". PostgreSQL will reject this with "column type does not exist".

**Evidence**: `monitor_ai.gleam:559 INSERT INTO issues (..., type, ...); issues table: issue_type text NOT NULL`

**Impact**: auto_file_issue() always fails with SQL error. Tool errors are never auto-filed as issues, so the monitoring system has no self-healing capability for tool failures.

### #226 — SkillSource missing ai-built variant that DB allows

- **Severity**: HIGH
- **Category**: type_mismatch
- **Module**: `skill`
- **Status**: open

**Description**: DB skills_source_check: clawhub, local, generated, imported, ai-built. Gleam SkillSource: Clawhub, Local, Generated, Imported. Missing ai-built.

**Evidence**: `skill.gleam:16 SkillSource has 4 variants; DB CHECK has 5 values including ai-built`

**Impact**: Decode fails for ai-built skills; INSERT with ai-built source from Gleam impossible

### #274 — task.gleam: result column is jsonb but decoded as decode.optional(decode.string)

- **Severity**: HIGH
- **Category**: type_mismatch
- **Module**: `task`
- **Status**: open

**Description**: The tasks.result column is jsonb in PostgreSQL. node-postgres returns jsonb as a parsed JavaScript object, but the Gleam decoder uses decode.optional(decode.string) which expects a string. This causes decode failure for any task with a non-null result. Both task.list() and task.get() SELECT the result column without ::text cast.

**Evidence**: `task.gleam:58 decode.field("result", decode.optional(decode.string)); tasks table: result jsonb; node-postgres returns parsed object for jsonb`

**Impact**: task.list() and task.get() will fail with DecodeError whenever a task has a non-null result value. Since result is populated on task completion, this means completed tasks cannot be listed or retrieved.

### #276 — memory.gleam: search() SELECT * returns created_at as timestamptz without ::text cast

- **Severity**: HIGH
- **Category**: type_mismatch
- **Module**: `memory`
- **Status**: open

**Description**: memory.search() uses "SELECT * FROM memory" which includes created_at (timestamptz). node-postgres returns timestamptz as JS Date object, but the Gleam decoder uses decode.string. This causes decode failure for every memory row with a non-null created_at.

**Evidence**: `memory.gleam:97 SELECT * FROM memory; memory table: created_at timestamp with time zone; memory.gleam:47 decode.field("created_at", decode.string)`

**Impact**: memory.search() always fails with DecodeError because created_at is returned as JS Date object, not string. The memory search Pi tool (psypi-memory-search) is completely non-functional.

### #278 — skill.gleam: get() and search() missing ::text cast for content and reference_list (both jsonb)

- **Severity**: HIGH
- **Category**: type_mismatch
- **Module**: `skill`
- **Status**: open

**Description**: skill.list() correctly uses content::text and reference_list::text, but skill.get() and skill.search() SELECT these columns without ::text cast. Since both are jsonb in PostgreSQL, node-postgres returns parsed JS objects, but the Gleam decoder uses decode.optional(decode.string) which expects strings.

**Evidence**: `skill.gleam:184 SELECT ... created_at::text, content, reference_list (no ::text); skills table: content jsonb, reference_list jsonb; skill.gleam:96 decode.field("content", decode.optional(decode.string))`

**Impact**: skill.get() and skill.search() fail with DecodeError for any skill with non-null content or reference_list. Since content stores the skill instructions, most skills will have content, making these functions mostly non-functional.

### #283 — broadcast.gleam: stats() has 3 independent bugs: bigint decode, text>=int comparison, missing status column

- **Severity**: HIGH
- **Category**: type_mismatch
- **Module**: `broadcast`
- **Status**: open

**Description**: broadcast.stats() has 3 bugs verified against database schema: (1) COUNT(*) returns bigint → node-postgres returns string → decode.int expects number → FAILS; (2) priority is text column, "priority >= 2" does lexicographic comparison → always false for text values like "low"/"normal"/"high"/"critical"; (3) project_communications has no "status" column → FILTER (WHERE status = sent) causes SQL error.

**Evidence**: `broadcast.gleam:233 COUNT(*) as total with decode.int; broadcast.gleam:236 priority >= 2 (text vs int); project_communications table: no status column`

**Impact**: broadcast.stats() always fails. Bug 3 (missing column) causes SQL error, so bugs 1 and 2 are never reached. The stats function is completely non-functional.

### #284 — inter_review.gleam: 3 queries SELECT requested_at (timestamptz) without ::text cast

- **Severity**: HIGH
- **Category**: type_mismatch
- **Module**: `inter_review`
- **Status**: open

**Description**: inter_review.gleam has 3 queries that SELECT requested_at without ::text cast: get_review_details() line 148, list_reviews() lines 283 and 285. node-postgres returns timestamptz as JS Date object, but the Gleam decoder uses decode.string. All 3 queries fail with DecodeError.

**Evidence**: `inter_review.gleam:148,283,285 SELECT ... requested_at FROM inter_reviews (no ::text); inter_reviews table: requested_at timestamp with time zone; inter_review.gleam:117 decode.field("requested_at", decode.string)`

**Impact**: get_review_details() and list_reviews() always fail with DecodeError. This blocks tool_commit (which calls get_review_details) and any listing of inter-reviews. The inter-review system is completely non-functional for reading review results.

### #138 — memory.save() decodes RETURNING id with full memory_decoder()

- **Severity**: HIGH
- **Category**: wrong_decoder
- **Module**: `memory`
- **Status**: open

**Description**: INSERT RETURNING id returns 1 column but decoder expects all Memory fields CROSS-REF: See #277 for verified analysis. RETURNING id only returns id column, but memory_decoder expects 7 fields.

**Evidence**: `memory.gleam save(): decode.run(row, memory_decoder()) on RETURNING id`

**Impact**: Save always reports error (data IS saved but error returned)

### #126 — seed.gleam seeds monitor_debounce_ms as 300000 but DB has 900000

- **Severity**: MEDIUM
- **Category**: config_desync
- **Module**: `seed`
- **Status**: open

**Description**: Seed script and existing data disagree on debounce value

**Evidence**: `seed.gleam: 300000 vs psypi_config table: 900000`

**Impact**: Fresh installs get different debounce than existing deployments

### #145 — housekeeping() is a test stub left in production

- **Severity**: MEDIUM
- **Category**: dead_code
- **Module**: `monitor_ai`
- **Status**: open

**Description**: Function body is placeholder/test code

**Evidence**: `monitor_ai.gleam housekeeping(): stub implementation`

**Impact**: Dead code in production module

### #255 — tool_consult is a stub — returns hardcoded message, no actual A-bot consultation

- **Severity**: MEDIUM
- **Category**: dead_code
- **Module**: `monitor_ai`
- **Status**: open

**Description**: monitor_ai.gleam tool_consult() returns "Consultation feature not yet implemented. Please use the psypi-consult tool for A-bot queries." It does not call any A-bot function or query any data.

**Evidence**: `monitor_ai.gleam: tool_conslect returns hardcoded string; no call_monitor, no DB query, no A-bot interaction`

**Impact**: Consultation tool is non-functional. Agents that try to consult A-bot get a placeholder response.

### #260 — _global computed but never used — global_prefix in semantic_id reads ctx.global which is never set

- **Severity**: MEDIUM
- **Category**: dead_code
- **Module**: `agent_identity`
- **Status**: open

**Description**: agent_identity.gleam:172-174 computes _global = case check_git_exists(ctx.cwd) { True -> False, False -> True } but never uses it. semantic_id() reads ctx.global for global_prefix, but the lit() expression in my_id_tool() never sets ctx.global. So ctx.global is always undefined/undefined in JS.

**Evidence**: `agent_identity.gleam:172 let _global = case check_git_exists(ctx.cwd) {...}; line 87 global_prefix = case ctx.global { True -> "G-" ... }; my_id_tool lit() does not include global field`

**Impact**: G-prefix never used. _global computation is wasted. semantic_id never produces G-prefixed IDs.

### #270 — No migration tracking table: simple_migrate runs all scripts every time with no record of which were applied

- **Severity**: MEDIUM
- **Category**: design
- **Module**: `simple_migrate`
- **Status**: open

**Description**: simple_migrate.gleam has no tracking table (like schema_migrations) to record which migration scripts have been applied. It uses IF NOT EXISTS / WHERE NOT EXISTS patterns instead. This means: (1) all scripts run every startup, (2) no way to know current schema version, (3) failed migrations are silently retried, (4) no rollback capability.

**Evidence**: `simple_migrate.gleam: no CREATE TABLE schema_migrations; no INSERT INTO schema_migrations; all SQL uses IF NOT EXISTS / WHERE NOT EXISTS patterns; grep -rh "schema_migrations" src/ returns nothing`

**Impact**: No way to determine current schema version. Failed migrations are invisible. No rollback. All scripts run every startup (wasteful). Schema drift between environments is undetectable.

### #147 — Error fallback includes hardcoded soul content

- **Severity**: MEDIUM
- **Category**: design_flaw
- **Module**: `hook_on_before_agent_start`
- **Status**: open

**Description**: On error, returns hardcoded soul instead of graceful failure

**Evidence**: `hook_on_before_agent_start.gleam: hardcoded fallback soul`

**Impact**: Errors masked by fake soul data

### #149 — Dynamic imports in every hook trigger

- **Severity**: MEDIUM
- **Category**: design_flaw
- **Module**: `extension_generator`
- **Status**: open

**Description**: Each hook invocation dynamically imports the module

**Evidence**: `extension_generator.gleam: dynamic import per hook call`

**Impact**: Performance overhead on every hook trigger

### #151 — Audit trigger source=learn not in allowed sources

- **Severity**: MEDIUM
- **Category**: design_flaw
- **Module**: `audit_trigger`
- **Status**: open

**Description**: learning_insights audit trigger allows source IN (agent,system,hook,tool) but not learn; areflect saves with source=learn

**Evidence**: `SQL migration: CHECK source IN (...) missing learn`

**Impact**: areflect save_learning may fail audit trigger validation

### #154 — Duplicate now_ms FFI in both pi_extension_ffi.mjs and time_ffi.mjs

- **Severity**: MEDIUM
- **Category**: design_flaw
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: Two separate FFI implementations for getting current time in ms

**Evidence**: `pi_extension_ffi.mjs: now_ms(); time_ffi.mjs: now_ms()`

**Impact**: Inconsistency; which one is authoritative?

### #156 — call_monitor retry without exponential backoff

- **Severity**: MEDIUM
- **Category**: design_flaw
- **Module**: `monitor_ai`
- **Status**: open

**Description**: Retries on failure but uses fixed delay, not exponential backoff

**Evidence**: `pi_extension_ffi.mjs: call_monitor() retry logic`

**Impact**: Retry storms under load; no jitter

### #245 — agent_sessions has TWO heartbeat columns: last_heartbeat and last_heartbeat_at

- **Severity**: MEDIUM
- **Category**: design_flaw
- **Module**: `a_db_reader`
- **Status**: open

**Description**: agent_sessions table has both last_heartbeat and last_heartbeat_at (both timestamptz). Code only uses last_heartbeat. last_heartbeat_at is never referenced by any Gleam code. Likely added by an AI that did not check existing columns.

**Evidence**: `\\d agent_sessions shows both columns; grep -rh "last_heartbeat_at" src/*.gleam returns nothing`

**Impact**: Confusion about which column is canonical. If wrong column is used for idle detection, results differ.

### #246 — hook_on_tool_result uses string.contains for error detection instead of JSON parsing

- **Severity**: MEDIUM
- **Category**: design_flaw
- **Module**: `hook_on_tool_result`
- **Status**: open

**Description**: on_tool_result detects errors by checking string.contains(result_json, "\"error\"") and similar patterns. This is fragile: legitimate tool output containing the word "error" triggers false positives. Missing actual error patterns causes false negatives.

**Evidence**: `hook_on_tool_result.gleam:9-14 uses string.contains for 5 patterns; no json.decode or structured parsing`

**Impact**: False error reports from legitimate tool output, or missed errors from unrecognized patterns

### #252 — hook_on_tool_call only handles "edit" tool — all other tools ignored

- **Severity**: MEDIUM
- **Category**: design_flaw
- **Module**: `hook_on_tool_call`
- **Status**: open

**Description**: hook_on_tool_call.gleam only processes tool calls where tool_name == "edit". All other tool calls pass through without any monitoring or recording.

**Evidence**: `hook_on_tool_call.gleam: checks if tool_name == "edit" then records; all other tools silently pass through`

**Impact**: No monitoring of non-edit tool calls. No error recording for failed tool calls except edit.

### #127 — areflect saves to learning_insights; learning.gleam saves to memory; neither reads the other

- **Severity**: MEDIUM
- **Category**: disconnected_systems
- **Module**: `areflect`
- **Status**: open

**Description**: Two separate tables for the same concept (learned insights)

**Evidence**: `areflect.gleam → learning_insights; learning.gleam → memory`

**Impact**: No unified learning retrieval; insights fragmented

### #128 — areflect.save_learning ignores agent_id parameter

- **Severity**: MEDIUM
- **Category**: disconnected_systems
- **Module**: `areflect`
- **Status**: open

**Description**: Parameter _agent_id is accepted but not used in INSERT

**Evidence**: `areflect.gleam save_learning(): _agent_id unused`

**Impact**: Cannot attribute learnings to specific agents

### #142 — pi_send_message fire-and-forget; no error feedback

- **Severity**: MEDIUM
- **Category**: error_handling
- **Module**: `pi_extension`
- **Status**: open

**Description**: Returns Nil synchronously; no way to know if message was sent

**Evidence**: `pi_extension.gleam: pi_send_message returns Nil`

**Impact**: A→S communication failures are silent

### #159 — Error handling anti-pattern: Ok(0) on decode failure in 4+ modules

- **Severity**: MEDIUM
- **Category**: error_handling
- **Module**: `multiple`
- **Status**: open

**Description**: Error handling anti-pattern: Error(_) -> Ok(default) silently swallows errors in 3 modules: system_review_db.gleam:438 (Ok(0)), issue_db.gleam:251 (Ok(0)), a_db_reader.gleam:44 (Ok(True)). This pattern hides decode failures and makes debugging extremely difficult. The a_db_reader case is particularly dangerous because Ok(True) means "S is idle" which is the safe default but masks the real error.

**Evidence**: `issue_db count(), a_db_reader read_*, memory search()`

**Impact**: Silent data loss; errors never surface

### #153 — gleamValueToJson uses constructor.name which breaks under minification

- **Severity**: MEDIUM
- **Category**: ffi_mismatch
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: Pattern matching on constructor.name is fragile; breaks if JS is minified

**Evidence**: `pi_extension_ffi.mjs: constructor.name checks`

**Impact**: Type detection fails in production if code is minified

### #134 — issue_db.get() and resolve() hardcode project_id UUID

- **Severity**: MEDIUM
- **Category**: hardcoded_config
- **Module**: `issue_db`
- **Status**: open

**Description**: UUID hardcoded instead of using session variable

**Evidence**: `issue_db.gleam: "0d324e68-b399-4b85-bd8a-6b1ef7b46168"`

**Impact**: Only works for one project; breaks if project_id changes

### #135 — issue_db.list() comment says session variable but hardcodes UUID

- **Severity**: MEDIUM
- **Category**: hardcoded_config
- **Module**: `issue_db`
- **Status**: open

**Description**: Comment claims "from session variable" but code hardcodes

**Evidence**: `issue_db.gleam build_where(): misleading comment`

**Impact**: False documentation; actual behavior differs from stated

### #136 — db.connect() sets app.current_project_id but no module reads it

- **Severity**: MEDIUM
- **Category**: hardcoded_config
- **Module**: `db`
- **Status**: open

**Description**: Session variable set on every connection but never used in queries

**Evidence**: `db.gleam connect(): SET app.current_project_id = $1`

**Impact**: Dead code; creates false sense of project isolation

### #140 — semantic_id uses is_idle for A/S prefix; idle S-agent gets wrong identity

- **Severity**: MEDIUM
- **Category**: logic_error
- **Module**: `agent_identity`
- **Status**: open

**Description**: is_idle=True → "A" prefix, but idle S-agent should still be "S"

**Evidence**: `agent_identity_types.gleam semantic_id(): is_idle determines prefix`

**Impact**: Idle S-agent gets A- prefix; wrong session tracking

### #141 — hook_on_tool_result synchronous return in async context

- **Severity**: MEDIUM
- **Category**: logic_error
- **Module**: `hook_on_agent_end`
- **Status**: open

**Description**: Returns Result synchronously but caller expects Promise

**Evidence**: `hook_on_agent_end.gleam: sync return in async hook`

**Impact**: Hook may not properly chain with other hooks

### #160 — A/S agent debounce logic: idle_since reset on every tool call

- **Severity**: MEDIUM
- **Category**: logic_error
- **Module**: `hook_on_agent_end`
- **Status**: open

**Description**: get_config returns JS null (not Gleam None) so pattern match always hits Some branch

**Evidence**: `hook_on_agent_end.gleam: idle_since reset logic`

**Impact**: A-bot never goes idle; debounce never triggers; S-bot never activated

### #248 — monitor.set_model blanket reset race condition

- **Severity**: MEDIUM
- **Category**: logic_error
- **Module**: `monitor`
- **Status**: open

**Description**: set_model() does UPDATE provider_api_keys SET status = 'not_used' (resets ALL keys), then sets one key to 'in_use'. Between the two UPDATEs, all keys are temporarily 'not_used'. Concurrent calls could leave zero keys active.

**Evidence**: `monitor.gleam:104 UPDATE provider_api_keys SET status = 'not_used'; then line 113-115 UPDATE ... SET status = 'in_use' WHERE provider = $1`

**Impact**: Temporary window where no API key is active. Concurrent set_model calls could corrupt state.

### #267 — record_trigger called twice per agent start: before_agent_start and agent_start both trigger on same event

- **Severity**: MEDIUM
- **Category**: logic_error
- **Module**: `event_hooks`
- **Status**: open

**Description**: hook_on_before_agent_start calls record_trigger("before_agent_start") and hook_on_agent_start calls record_trigger("agent_start"). Both hooks fire on the same agent start event, creating duplicate trigger records in event_hooks table. This inflates trigger counts and may confuse monitoring.

**Evidence**: `hook_on_before_agent_start.gleam:8 record_trigger("before_agent_start"); hook_on_agent_start.gleam:7 record_trigger("agent_start"); extension_generator.gleam registers both as session_start hooks`

**Impact**: Duplicate trigger records inflate event counts. Monitoring based on trigger counts will be inaccurate.

### #269 — simple_migrate.gleam may silently drop multi-statement migration scripts

- **Severity**: MEDIUM
- **Category**: logic_error
- **Module**: `simple_migrate`
- **Status**: open

**Description**: simple_migrate.gleam reads SQL files and passes them to db.query(). Migration scripts containing multiple statements (e.g. CREATE TABLE followed by CREATE INDEX) may only have the first statement executed, silently dropping the rest. Unlike seed.gleam, migrations are critical for schema correctness.

**Evidence**: `simple_migrate.gleam reads .sql files and passes content directly to db.query(); migration files like 027_review_findings.sql contain multiple statements; node-postgres may only execute first statement`

**Impact**: Schema may be partially applied. Tables created but indexes/constraints/triggers silently dropped. This is worse than seed because it affects schema correctness.

### #271 — command_listen bypasses A-bot debounce chain — directly calls LLM and sends to S with no DB record

- **Severity**: MEDIUM
- **Category**: logic_error
- **Module**: `command_listen`
- **Status**: open

**Description**: command_listen.on_autonomic_listen() calls call_monitor() (direct LLM call) and then pi_send_message() with "autonomic-wakeup" type. This completely bypasses the A-bot debounce/wakeup chain (hook_on_agent_end). No inter_review record is created, no debounce protection, no heartbeat check. The message goes directly from LLM to S with no tracking.

**Evidence**: `command_listen.gleam:30 call_monitor(ctx, user_prompt, system_prompt); :38 pi_send_message(pi, "autonomic-wakeup", message, "persistent"); no call to a_orchestrator; no INSERT INTO inter_reviews; no debounce check`

**Impact**: Human-triggered A messages bypass all safety mechanisms. No audit trail. No debounce. Could flood S with messages if human types rapidly.

### #104 — task.get missing project_id::text in SELECT

- **Severity**: MEDIUM
- **Category**: missing_cast
- **Module**: `task`
- **Status**: open

**Description**: project_id is uuid, needs ::text cast for Gleam string decoder

**Evidence**: `task.gleam get(): project_id not cast to text`

**Impact**: Task get may fail to decode project_id

### #105 — task.list id not cast to text

- **Severity**: MEDIUM
- **Category**: missing_cast
- **Module**: `task`
- **Status**: open

**Description**: id is uuid in tasks table but not cast in list query

**Evidence**: `task.gleam list(): id column not cast`

**Impact**: Task list may fail to decode id

### #106 — agents.list missing ::text cast on created_at

- **Severity**: MEDIUM
- **Category**: missing_cast
- **Module**: `agents`
- **Status**: open

**Description**: created_at is timestamptz, needs ::text for Gleam decoder

**Evidence**: `agents.gleam list(): created_at not cast`

**Impact**: Agent list may fail to decode

### #107 — monitor.get_pending_notifications read_at cast mismatch

- **Severity**: MEDIUM
- **Category**: missing_cast
- **Module**: `monitor`
- **Status**: open

**Description**: read_at is timestamptz but may be decoded inconsistently

**Evidence**: `monitor.gleam: read_at handling inconsistent`

**Impact**: Notification queries may fail

### #108 — code_version.query_versions missing ::text casts

- **Severity**: MEDIUM
- **Category**: missing_cast
- **Module**: `code_version`
- **Status**: open

**Description**: Multiple timestamptz/uuid columns not cast

**Evidence**: `code_version.gleam query_versions(): missing casts`

**Impact**: Version queries may fail to decode

### #110 — a_db_reader multiple queries missing ::text casts

- **Severity**: MEDIUM
- **Category**: missing_cast
- **Module**: `a_db_reader`
- **Status**: open

**Description**: read_a_soul, read_active_tasks, read_open_issues all have uncast columns

**Evidence**: `a_db_reader.gleam: multiple SELECT queries without casts`

**Impact**: A-agent reads may fail silently

### #275 — task.gleam: get() SELECT missing project_id column that decoder expects

- **Severity**: MEDIUM
- **Category**: missing_column
- **Module**: `task`
- **Status**: open

**Description**: task.get() SELECTs 13 columns but the task_decoder expects 14 fields including project_id. The project_id field is Optional in the decoder, but decode.optional(decode.string) still requires the field to exist in the row object. Since project_id is not in the SELECT, the field is absent from the JS object, causing decode failure.

**Evidence**: `task.gleam:229 SELECT includes created_at::text but not project_id; task.gleam:66 decode.field("project_id", decode.optional(decode.string))`

**Impact**: task.get() always fails with DecodeError because project_id field is missing from the query result. The list() function correctly includes project_id::text.

### #132 — memory.memory_search_tool result template uses literal {count}

- **Severity**: MEDIUM
- **Category**: missing_params
- **Module**: `memory`
- **Status**: open

**Description**: Template has ${count} but count is not a variable in scope

**Evidence**: `memory.gleam: template("Found {count} memories")`

**Impact**: Result message shows literal {count} not actual number

### #119 — a_db_reader.read_active_tasks no project_id filter

- **Severity**: MEDIUM
- **Category**: missing_project_id
- **Module**: `a_db_reader`
- **Status**: open

**Description**: SELECT from tasks without WHERE project_id = ...

**Evidence**: `a_db_reader.gleam read_active_tasks(): no project filter`

**Impact**: Returns tasks from all projects

### #120 — broadcast.send empty string for UUID NOT NULL column

- **Severity**: MEDIUM
- **Category**: missing_project_id
- **Module**: `broadcast`
- **Status**: open

**Description**: Uses empty string for project_id which is uuid NOT NULL

**Evidence**: `broadcast.gleam send(): project_id = empty string`

**Impact**: Broadcast send fails on NOT NULL constraint

### #253 — No connection pooling — every query creates and destroys a connection

- **Severity**: MEDIUM
- **Category**: performance
- **Module**: `db`
- **Status**: open

**Description**: db.gleam with_connection creates a new pg.Client.connect() for every query and closes it after. No connection pool. Under load (multiple concurrent tool calls), this creates many short-lived connections.

**Evidence**: `db.gleam: with_connection calls pg.Client.connect() then pg.Client.close() for every query`

**Impact**: Connection overhead on every query. Under concurrent load, connection exhaustion or slowdown.

### #285 — areflect.gleam: save_learning() inserts into learning_insights table but psypi also has learnings table

- **Severity**: MEDIUM
- **Category**: schema_mismatch
- **Module**: `areflect`
- **Status**: open

**Description**: save_learning() does "INSERT INTO learning_insights (insight_type, title, content, confidence)" but the psypi project also has a learnings table. It is unclear which table is the correct target. The learning_insights table may belong to another project (nezha/nupi) in the shared database.

**Evidence**: `areflect.gleam:253 INSERT INTO learning_insights; database has both learning_insights and learnings tables`

**Impact**: Learnings from areflect may be written to the wrong table, or may be mixed with data from other projects in the shared database. If learning_insights belongs to another project, psypi learnings are being stored in the wrong location.

### #155 — exec_sync allows command injection via unsanitized input

- **Severity**: MEDIUM
- **Category**: security
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: exec_sync runs shell commands; shell_escape() provides basic sanitization but may not cover all edge cases (newlines, semicolons, pipe characters)

**Evidence**: `pi_extension_ffi.mjs: exec_sync(cmd); tool_commit.gleam: shell_escape() covers backslash, quote, backtick, dollar sign`

**Impact**: Arbitrary command execution if tool params contain shell metacharacters

### #286 — Type alignment audit: 8 modules have timestamptz/jsonb/bigint decode mismatches

- **Severity**: MEDIUM
- **Category**: type_alignment
- **Module**: `multiple`
- **Status**: open

**Description**: Systematic audit of all 22 psypi tables and their Gleam decoders found type mismatches in 8 modules: (1) inter_review.gleam: requested_at timestamptz without ::text (3 queries); (2) memory.gleam: created_at timestamptz without ::text, RETURNING id decoded with full decoder; (3) task.gleam: result jsonb decoded as string, get() missing project_id; (4) skill.gleam: content/reference_list jsonb without ::text in get()/search(); (5) broadcast.gleam: COUNT(*) bigint decoded as int, text>=int comparison, missing status column; (6) a_db_reader.gleam: COUNT(*) bigint decoded as int; (7) monitor_ai.gleam: auto_file_issue() wrong column name + missing project_id; (8) areflect.gleam: save_issue() missing project_id. Modules with correct type handling: issue_db.gleam, meeting.gleam, event_hooks.gleam, agents.gleam, monitor.gleam, system_review_db.gleam, code_version.gleam (uses SQL functions).

**Evidence**: `Full source code audit of all *.gleam files with DB queries, cross-referenced with information_schema.columns for all 22 tables`

**Impact**: This finding serves as a cross-reference for the individual type mismatch findings (#274-#285). The pattern is consistent: developers did not account for node-postgres type conversions when writing Gleam decoders. The correct patterns (used in issue_db.gleam, meeting.gleam, etc.) are: (1) always cast timestamptz to ::text, (2) always cast jsonb to ::text when using decode.string, (3) always cast COUNT(*) to ::int or use ::text + int.parse, (4) verify column names match between SQL and table schema.

### #228 — MeetingStatus has Pending but DB only allows active/completed/cancelled

- **Severity**: MEDIUM
- **Category**: type_mismatch
- **Module**: `meeting`
- **Status**: open

**Description**: DB meetings_status_check: active, completed, cancelled. Gleam MeetingStatus: Pending, Active, Completed, Cancelled. Pending not in DB.

**Evidence**: `meeting.gleam:10 MeetingStatus has Pending; DB CHECK has no pending value`

**Impact**: INSERT with pending status will fail DB constraint; Gleam type allows invalid state

### #230 — IssueType missing proposal which DB allows

- **Severity**: MEDIUM
- **Category**: type_mismatch
- **Module**: `issue_types`
- **Status**: open

**Description**: DB issues_issue_type_check: bug, inconsistency, feature, improvement, question, debt, proposal. Gleam IssueType: Bug, Inconsistency, Feature, Improvement, Question, Debt. Missing proposal.

**Evidence**: `issue_types.gleam:20 string_to_type() has no proposal case`

**Impact**: Decode fails for proposal-type issues; cannot create proposal issues from Gleam

### #282 — a_db_reader.gleam: is_s_still_idle() COUNT(*) decoded as decode.int but node-postgres returns bigint as string

- **Severity**: MEDIUM
- **Category**: type_mismatch
- **Module**: `a_db_reader`
- **Status**: open

**Description**: is_s_still_idle() does "SELECT COUNT(*) as cnt" and decodes with decode.field("cnt", decode.int). node-postgres returns bigint (int8) as JavaScript string, but decode.int expects a number. The decode always fails, and the error handler returns Ok(True) (assumes idle). This is the same issue as #244 but with the correct root cause: bigint type mismatch, not missing ::text.

**Evidence**: `a_db_reader.gleam:49 SELECT COUNT(*) as cnt; a_db_reader.gleam:56 decode.field("cnt", decode.int); node-postgres docs: int8 returned as string`

**Impact**: is_s_still_idle() always returns Ok(True) because the decode fails and the error handler defaults to True. However, ctx_is_idle is the primary idle check per user confirmation, so this is a redundant secondary guard that defaults to the safe value. Impact is low in practice but the function is technically broken.

### #232 — tasks table has 60 DB columns but Gleam decoder only handles 14 (46 unused)

- **Severity**: MEDIUM
- **Category**: unused_columns
- **Module**: `task`
- **Status**: open

**Description**: Gleam task_decoder handles: id, title, description, status, priority, result, error, retry_count, created_at, updated_at, completed_at, created_by, source, project_id. DB has 60 columns including: agent_id, agent_name, executor_type, executor_model, executor_provider, delegate_to, complexity, encrypted_result, metadata, tags, session_id, etc.

**Evidence**: `task.gleam task_decoder() has 14 fields; \\d tasks shows 60 columns. 46 columns never read or written by Gleam code.`

**Impact**: 46 columns of task data are invisible to psypi. Other projects may write them but psypi cannot read them. Massive schema-code gap.

### #233 — skills table has 60+ DB columns but Gleam decoder only handles ~10 (45+ unused)

- **Severity**: MEDIUM
- **Category**: unused_columns
- **Module**: `skill`
- **Status**: open

**Description**: Gleam skill decoder handles: id, name, description, source, status, safety_score, version, author, content, reference_list. DB has 60+ columns including: allowed_projects, allowed_users, anti_patterns, build_metadata, category, code_analysis, content_hash, downloads, embedding, emoji, examples, generation_prompt, instructions, is_enabled, is_public, maintainer, manifest, permissions, quick_start, rating, repository, review_notes, scan_status, tags, trigger_phrases, use_count, verified, warnings, etc.

**Evidence**: `skill.gleam skill_decoder() has ~10 fields; \\d skills shows 60+ columns. 45+ columns never read or written.`

**Impact**: 45+ columns of skill data are invisible to psypi. Skill management features like ratings, downloads, reviews, scanning are all inaccessible.

### #234 — issues table has 30+ DB columns but Gleam decoder only handles ~15 (15+ unused)

- **Severity**: MEDIUM
- **Category**: unused_columns
- **Module**: `issue_db`
- **Status**: open

**Description**: Gleam issue decoder handles: id, title, description, severity, status, issue_type, created_at, resolved_at, created_by, discovered_by, environment, git_branch, git_hash, reported_by, source. DB has 30+ columns including: assignee, assignee_type, discovered_at, dlq_id, metadata, milestone_id, related_issue_id, related_review_id, resolution, resolved_by, review_id, tags, task_id, updated_at, viewers.

**Evidence**: `issue_db.gleam issue_decoder() has ~15 fields; \\d issues shows 30+ columns. 15+ columns never used.`

**Impact**: Issue management features like assignments, milestones, tags, resolution tracking are inaccessible to psypi.

### #235 — inter_reviews table has 30+ DB columns but Gleam decoder only handles 6 (27+ unused)

- **Severity**: MEDIUM
- **Category**: unused_columns
- **Module**: `inter_review`
- **Status**: open

**Description**: Gleam inter_review decoder handles: id, task_id, status, summary, overall_score, requested_at. DB has 30+ columns including: accepted_suggestions, branch, code_quality_score, commit_hash, completed_at, documentation_score, effort_minutes, findings, issue_id, leverage_ratio, praise, raw_response, requester_id, response, response_at, response_status, review_context, review_round, reviewed_by, reviewer_id, reviewer_type, rework_count, session_id, started_at, suggestions, test_coverage_score.

**Evidence**: `inter_review.gleam review_decoder() has 6 fields; \\d inter_reviews shows 30+ columns. 27+ columns never used.`

**Impact**: Inter-review features like code quality scoring, suggestions, rework tracking, test coverage are all inaccessible.

### #238 — learning_insights: areflect only INSERTs 4 columns, never reads any. 9 DB columns never used.

- **Severity**: MEDIUM
- **Category**: unused_columns
- **Module**: `areflect`
- **Status**: open

**Description**: areflect.save_learning INSERT INTO learning_insights (insight_type, title, content, confidence) — only 4 columns. No SELECT from learning_insights exists in any Gleam file. DB has: id, project_id, priority, evidence, is_applied, applied_at, expires_at, metadata, created_at — all never used.

**Evidence**: `areflect.gleam:183 INSERT INTO learning_insights with 4 columns; no SELECT from learning_insights in any .gleam file`

**Impact**: Learning insights are written but never read. No feedback loop. All insight data is write-only.

### #240 — psypi_event_hooks: 7 of 14 DB columns never used by Gleam code

- **Severity**: MEDIUM
- **Category**: unused_columns
- **Module**: `event_hooks`
- **Status**: open

**Description**: Gleam reads: id, event_type, is_active, tool_name, debounce_ms, filter_condition, priority. Never reads: agentbot_action, worker_action, description, last_error, last_triggered, created_at, updated_at.

**Evidence**: `event_hooks.gleam SELECT id, event_type, is_active, tool_name, debounce_ms, filter_condition, priority; \\d psypi_event_hooks shows 14 columns`

**Impact**: Hook actions (agentbot_action, worker_action) are never read, so hooks may not trigger correct actions

### #231 — 4 agent_* tables exist in DB but are never used by psypi Gleam code

- **Severity**: MEDIUM
- **Category**: unused_table
- **Module**: `global`
- **Status**: open

**Description**: agent_configs (12 cols), agent_identity (8 cols), agent_moods (5 cols), agent_scores (13 cols) exist in the psypi database but no Gleam source file references them. These may belong to other projects or represent dead schema.

**Evidence**: `SELECT table_name FROM information_schema.tables WHERE table_name IN ('agent_configs','agent_identity','agent_moods','agent_scores'); grep -rh these names in src/*.gleam returns nothing`

**Impact**: Orphan tables consume DB resources and create confusion about data ownership in shared database

### #113 — get_model_stats case-sensitive status comparison

- **Severity**: MEDIUM
- **Category**: wrong_status
- **Module**: `monitor_ai`
- **Status**: open

**Description**: Compares status as text but DB stores uppercase

**Evidence**: `monitor_ai.gleam get_model_stats(): status comparison`

**Impact**: Model stats may miss records

### #114 — task.string_to_status accepts both cases but DB is uppercase

- **Severity**: MEDIUM
- **Category**: wrong_status
- **Module**: `task`
- **Status**: open

**Description**: DB CHECK allows PENDING/COMPLETED (uppercase); code accepts both

**Evidence**: `task.gleam string_to_status(): case-insensitive matching`

**Impact**: Inconsistency between insert and query

### #115 — IssueStatus Gleam type vs DB CHECK mismatch

- **Severity**: MEDIUM
- **Category**: wrong_status
- **Module**: `issue_types`
- **Status**: open

**Description**: DB has open/acknowledged/in_progress/resolved/wont_fix/duplicate; Gleam has Open/InProgress/Resolved/Closed

**Evidence**: `issue_types.gleam: missing acknowledged/wont_fix/duplicate, extra Closed`

**Impact**: Decode fails for acknowledged/wont_fix/duplicate statuses

### #206 — a_db_reader read_open_issues uses status=closed but DB has no closed status

- **Severity**: MEDIUM
- **Category**: wrong_status
- **Module**: `a_db_reader`
- **Status**: open

**Description**: WHERE status NOT IN (resolved,closed) — closed does not exist; DB has wont_fix and duplicate instead

**Evidence**: `a_db_reader.gleam:130 status NOT IN (resolved,closed)`

**Impact**: Issues with wont_fix/duplicate status show as open when they shouldnt

### #210 — IssueStatus missing acknowledged/wont_fix/duplicate; has Closed which DB doesnt have

- **Severity**: MEDIUM
- **Category**: wrong_status
- **Module**: `issue_types`
- **Status**: open

**Description**: DB CHECK: open/acknowledged/in_progress/resolved/wont_fix/duplicate. Gleam: Open/InProgress/Resolved/Closed. Missing 3, extra 1.

**Evidence**: `issue_types.gleam: string_to_status() maps closed->Closed but DB has no closed; acknowledged/wont_fix/duplicate cause Error`

**Impact**: Decode fails for acknowledged/wont_fix/duplicate issues; Closed maps to non-existent DB status

### #225 — simple_migrate re-runs all migrations every time — no tracking of completed migrations

- **Severity**: LOW
- **Category**: design
- **Module**: `simple_migrate`
- **Status**: open

**Description**: run_all_migrations() reads all .sql files and runs them; no migration_history table or checkpoint

**Evidence**: `simple_migrate.gleam: run_all_migrations() has no deduplication`

**Impact**: Re-running migrations can cause errors from duplicate objects; no idempotency guarantee

### #268 — extension_generator uses raw JSON schema for tool parameters instead of Pi SDK recommended TypeBox

- **Severity**: LOW
- **Category**: design
- **Module**: `extension_generator`
- **Status**: open

**Description**: Pi SDK documentation recommends using Type.Object() from typebox for tool parameter definitions. psypi generates inline JSON schema objects instead. While this works (registerTool accepts JSON schema), it misses TypeBox features like validation and Google-compatible enums (StringEnum).

**Evidence**: `pi_tool_call.gleam:161 params_to_js() generates { "type": "object", "properties": {...} } instead of Type.Object({...}); Pi SDK docs: "import { Type } from typebox"; examples use Type.Object, Type.String`

**Impact**: No functional breakage, but misses TypeBox validation and enum features. Parameters with constrained values (enums) cannot be expressed.

### #150 — Only triggers on tool named "edit"

- **Severity**: LOW
- **Category**: design_flaw
- **Module**: `hook_on_tool_call`
- **Status**: open

**Description**: Hook checks event.toolName === "edit" only

**Evidence**: `hook_on_tool_call.gleam: edit-only trigger`

**Impact**: Other tool calls not tracked

### #143 — issue_db.count() returns Ok(0) on decode failure

- **Severity**: LOW
- **Category**: error_handling
- **Module**: `issue_db`
- **Status**: open

**Description**: Error(_) -> Ok(0) silently swallows decode errors

**Evidence**: `issue_db.gleam count(): Error(_) -> Ok(0)`

**Impact**: Reports 0 issues when decode fails; misleading

### #144 — a_db_reader reports Ok(True) on decode failure

- **Severity**: LOW
- **Category**: error_handling
- **Module**: `a_db_reader`
- **Status**: open

**Description**: Error(_) -> Ok(True) returns "no sessions" on any error

**Evidence**: `a_db_reader.gleam: Error(_) -> Ok(True)`

**Impact**: Errors hidden; always reports no sessions

### #273 — db.gleam with_connection() ignores disconnect errors — potential connection leak

- **Severity**: LOW
- **Category**: error_handling
- **Module**: `db`
- **Status**: open

**Description**: with_connection() calls disconnect(conn) after the callback, but uses `let _ = disconnect(conn)` which discards the result. If disconnect fails, the connection is leaked. Over time this could exhaust the connection pool.

**Evidence**: `db.gleam:82 let _ = disconnect(conn); disconnect returns Result(Nil, DbError) but the result is discarded`

**Impact**: Connection leak if disconnect fails. Over time could exhaust pool. Low severity because PostgreSQL connections auto-close on process exit.

### #257 — _configStore in-memory cache has race condition with concurrent access

- **Severity**: LOW
- **Category**: logic_error
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: pi_extension_ffi.mjs uses a module-level _configStore object as in-memory cache. Multiple async operations can read/write _configStore concurrently. get_config reads from _configStore first, then DB. set_config writes to DB then updates _configStore. Between DB write and cache update, stale values may be read.

**Evidence**: `pi_extension_ffi.mjs: let _configStore = {}; get_config checks _configStore first; set_config updates DB then _configStore`

**Impact**: Under concurrent access, stale config values may be used. Dual store (DB + in-memory) without synchronization.

### #130 — psypi-issue-add references created_by not in params

- **Severity**: LOW
- **Category**: missing_params
- **Module**: `issue_tools`
- **Status**: open

**Description**: created_by used in args but not declared in params schema

**Evidence**: `issue_tools.gleam: params.created_by always undefined`

**Impact**: Always defaults to "psypi"

### #131 — psypi-issues does not declare limit/offset in params

- **Severity**: LOW
- **Category**: missing_params
- **Module**: `issue_tools`
- **Status**: open

**Description**: AI cannot control pagination beyond first 50 results

**Evidence**: `issue_tools.gleam: limit/offset not in params`

**Impact**: No way to page through results

### #213 — learning.save() INSERT INTO memory omits project_id

- **Severity**: LOW
- **Category**: missing_project_id
- **Module**: `learning`
- **Status**: open

**Description**: INSERT INTO memory (content, tags, source, importance, agent_id) — no project_id

**Evidence**: `learning.gleam:28 INSERT without project_id`

**Impact**: Memories not scoped to project; cross-project leakage possible

### #272 — node_ffi execute() uses execSync with unsanitized shell commands — command injection risk

- **Severity**: LOW
- **Category**: security
- **Module**: `node_ffi`
- **Status**: open

**Description**: node_ffi.mjs execute() passes cmd directly to execSync(cmd, ...). While callers like tool_commit.gleam use shell_escape(), other callers may not. execSync runs commands through a shell, making it vulnerable to injection if any part of the command comes from untrusted input. UPDATE: node_ffi.execute() is dead code — no Gleam module imports it. The function exists in node_ffi.mjs but is never called via @external. The security risk is latent (could be imported in future) but not currently exploitable.

**Evidence**: `node_ffi.mjs:17 execSync(cmd, { encoding: "utf-8", timeout: timeout, stdio: ["pipe", "pipe", "pipe"] }); tool_commit.gleam:87 shell_escape(message); but pi_extension.gleam exec_sync has no escaping requirement in its type signature`

**Impact**: If any caller forgets to escape, arbitrary commands can be executed. The type system does not enforce sanitization.

### #148 — command_reload only notifies; no error handling

- **Severity**: LOW
- **Category**: style
- **Module**: `command_reload`
- **Status**: open

**Description**: notify_info called but no error path

**Evidence**: `command_reload.gleam: no error handling`

**Impact**: Reload failures are silent

### #157 — Orphan FFI file not imported by any Gleam module

- **Severity**: LOW
- **Category**: style
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: FFI file exists but no corresponding Gleam external function

**Evidence**: `pi_extension_ffi.mjs: orphan exports`

**Impact**: Dead code in FFI layer

### #163 — Git state shows AI repair pattern: many fix commits without verification

- **Severity**: LOW
- **Category**: style
- **Module**: `git`
- **Status**: open

**Description**: Commit history shows pattern of fix-attempt-fix without testing between

**Evidence**: `git log: fix/repair/revert pattern`

**Impact**: Unverified fixes may introduce new bugs

### #263 — gleamValueToJson has hardcoded type name list — new Gleam types not serialized as records

- **Severity**: LOW
- **Category**: style
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: gleamValueToJson checks for 15 hardcoded type name prefixes (Task$Task, Issue$Issue, etc.) to serialize as flat records. New types like EnrichedIdentity, HealthMetrics, ReviewFinding, SystemReview are not in the list and fall through to generic handling. The generic $ check may work for some but not all.

**Evidence**: `pi_extension_ffi.mjs:178 name.startsWith() checks 15 types; EnrichedIdentity, HealthMetrics, ReviewFinding, SystemReview not included`

**Impact**: New types may serialize incorrectly in tool results. Not a crash but data quality issue in JSON output.

### #152 — Gleam test files import modules that dont exist

- **Severity**: LOW
- **Category**: test_coverage
- **Module**: `test`
- **Status**: open

**Description**: Test imports reference modules not in src/ directory

**Evidence**: `test/*.gleam: import paths broken`

**Impact**: Tests cannot compile; false positive pass rate

### #161 — No integration tests for database queries

- **Severity**: LOW
- **Category**: test_coverage
- **Module**: `test`
- **Status**: open

**Description**: All Gleam test files are unit tests; no test actually connects to PostgreSQL

**Evidence**: `test/ directory: no DB integration tests`

**Impact**: DB query bugs never caught by tests

### #239 — provider_api_keys: Gleam only reads provider and model, never reads encrypted_key, status, etc.

- **Severity**: LOW
- **Category**: unused_columns
- **Module**: `monitor`
- **Status**: open

**Description**: monitor.gleam reads provider, model, status from provider_api_keys but never reads encrypted_key, encrypted_iv, encrypted_salt, encrypted_tag, id, created_at, updated_at.

**Evidence**: `monitor.gleam SELECT provider, model, status FROM provider_api_keys; \\d provider_api_keys shows 10 columns`

**Impact**: API key management is partial — encryption fields never accessed by Gleam

### #241 — project_communications: 4 DB columns never used by Gleam code

- **Severity**: LOW
- **Category**: unused_columns
- **Module**: `broadcast`
- **Status**: open

**Description**: Gleam never reads: to_ai, environment, git_branch, git_hash from project_communications.

**Evidence**: `broadcast.gleam SELECT id, from_ai, message_type, content, priority, metadata, created_at, read_at; \\d project_communications shows to_ai, environment, git_branch, git_hash unused`

**Impact**: Broadcast targeting (to_ai) and traceability (git_hash, git_branch) are never used

### #242 — meetings: 4 DB columns never used by Gleam code

- **Severity**: LOW
- **Category**: unused_columns
- **Module**: `meeting`
- **Status**: open

**Description**: Gleam never reads: project_id, summary, metadata, updated_at from meetings.

**Evidence**: `meeting.gleam SELECT id, topic, created_by, status, created_at, consensus_at, consensus; \\d meetings shows project_id, summary, metadata, updated_at unused`

**Impact**: Meeting summaries and project ownership are never accessible

### #243 — system_reviews: 3 JSONB columns (findings, action_items, limitations) never read after migration to review_findings table

- **Severity**: LOW
- **Category**: unused_columns
- **Module**: `system_review_db`
- **Status**: open

**Description**: After creating review_findings table, the JSONB columns findings, action_items, limitations in system_reviews are legacy. system_review_db.gleam never SELECTs them.

**Evidence**: `system_review_db.gleam SELECT does not include findings, action_items, limitations columns; these are now in review_findings table`

**Impact**: Legacy JSONB data may be stale. Should be dropped or documented as deprecated

## Retracted/Duplicate Findings

| # | Title | Status |
|---|-------|--------|
| 101 | inter_review id not cast to text | retracted |
| 102 | memory.search SELECT * returns uuid/timestamptz without casts | duplicate |
| 103 | skill.get missing ::text casts on content and reference_list | duplicate |
| 109 | areflect.fetch_recent_issues missing ::text casts for uuid and timestamps | retracted |
| 111 | check_system_health uses FAILED for tasks but DB has PENDING/COMPLETED | retracted |
| 112 | analyze_and_act same status value bugs as check_system_health | retracted |
| 117 | areflect.save_task missing project_id (has default but wrong) | retracted |
| 118 | auto_file_issue uses non-existent column type, missing project_id | duplicate |
| 121 | get_config returns JS null/string not Gleam Option | duplicate |
| 122 | set_config stores value but get_config cannot retrieve as Gleam Option | duplicate |
| 124 | ctx_is_idle/ctx_has_pending_messages return JS booleans not Gleam Bool | retracted |
| 125 | psypi_config.gleam (database) vs pi_extension_ffi.mjs (in-memory) never sync | duplicate |
| 133 | psypi-my-id missing project and global fields | duplicate |
| 158 | Package namespace mismatch between gleam.toml and import paths | retracted |
| 162 | SQL injection risk: string interpolation in WHERE clauses | retracted |
| 164 | 80 public types across 28 modules; no type audit exists | duplicate |
| 200 | agent_identity fetch_soul_by_prefix: id uuid without ::text | retracted |
| 201 | meeting.gleam: id uuid without ::text in all SELECT queries | retracted |
| 202 | agents.gleam: id uuid without ::text | retracted |
| 203 | monitor.gleam get_pending_notifications: id uuid without ::text | retracted |
| 204 | task.gleam: id uuid without ::text in list and get queries | retracted |
| 205 | issue_db.gleam: id uuid without ::text in list and get queries | retracted |
| 207 | stats.gleam COUNT(*) without ::text or ::INT; decode_bigint expects string | retracted |
| 208 | broadcast.gleam stats(): COUNT(*) without ::INT cast | duplicate |
| 209 | a_db_reader is_s_still_idle: COUNT(*) without ::INT | duplicate |
| 211 | IssueType missing proposal which DB allows | duplicate |
| 212 | meeting.gleam: meeting_id uuid without ::text in opinions query | retracted |
| 214 | task.gleam get(): id uuid without ::text, missing project_id in SELECT | duplicate |
| 215 | monitor_ai record_tool_error: INSERT uses type instead of issue_type, missing project_id | duplicate |
| 216 | code_version save_version: save_code_version() returns uuid but decoder uses decode.string without ::text | retracted |
| 217 | code_version query_versions: id uuid and saved_at timestamptz without ::text | retracted |
| 218 | code_version get_versions: get_code_versions() returns id uuid and saved_at timestamptz without ::text | retracted |
| 219 | areflect read_recent_issues: id uuid without ::text | retracted |
| 220 | broadcast.gleam: id uuid without ::text in all list queries | retracted |
| 221 | inter_review.gleam: id uuid and requested_at timestamptz without ::text in list queries | duplicate |
| 222 | inter_review.gleam: request_inter_review() returns uuid without ::text | retracted |
| 223 | monitor_ai record_tool_error: INSERT INTO issues omits project_id | duplicate |
| 224 | areflect INSERT INTO issues and tasks omits project_id | duplicate |
| 227 | TaskStatus missing FAKE_COMPLETE variant that DB allows | duplicate |
| 229 | IssueStatus missing acknowledged/wont_fix/duplicate; has Closed which DB doesnt have | duplicate |
| 236 | memory.search SELECT references column "saved_at" which does not exist in memory table | retracted |
| 237 | broadcast.stats SELECT references status column which does not exist in project_communications | duplicate |
| 254 | Migration system has no tracking table — cannot determine which migrations have run | duplicate |
| 266 | 8 instances of Error(_) -> Ok(default) silently swallow errors across 3 modules | duplicate |

## Top 10 System-Stopping Issues

| # | Finding | Why It Stops The System |
|---|---------|------------------------|
| 249 | get_config FFI returns JS null/string which never matches Gleam None/Some constructors | idle_since is always re-recorded as now(). Debounce never fires. A-bot wakeup is completely broken. |
| 262 | Dual config stores: FFI _configStore (in-memory) and psypi_config table (DB) are never synchronized | idle_since and monitor_debounce_ms are stored in _configStore (in-memory) but never persisted to DB. On process restart all debounce state is lost. psypi_config table exists but is not used by the debounce logic. |
| 146 | monitor_ai prepare_context: memory table has no saved_at column (SQL error) | Context preparation may fail or return wrong data |
| 247 | a_orchestrator.run_a_workflow never writes inter-review response to DB | Inter-review responses are ephemeral. If Pi message queue is lost, review data is lost. No audit trail. Additionally, tool_commit is permanently blocked because overall_score is never written (see #264). |
| 258 | Inter-review commit flow is permanently stuck — missing git add before git commit | Inter-review code changes are never actually committed. Review feedback is generated but code is not saved. |
| 123 | unwrapGleamResult may not handle all Gleam Result shapes | Error handling in extension.js may fail |
| 139 | broadcast.stats() 3 bugs: bigint decode, text>=int, missing status column | Stats query returns wrong results or fails |
| 250 | semantic_id uses is_idle (momentary state) for A/S prefix (permanent identity) | When S is momentarily idle, it gets A-prefixed identity. Wrong soul loaded, wrong jobs fetched, wrong behavior. |
| 251 | compose() called instead of compose_within_budget() — token budget system unused | A-bot system prompt may exceed context window, causing LLM failures. Token budget system exists but is never used. |
| 261 | A-bot wakeup chain: get_config FFI type mismatch prevents debounce from working | A-bot system is completely non-functional. No autonomous monitoring no inter-review no self-healing. The entire A/S dual-agent architecture is dead on the A side. |

## Verification Instructions

Any AI can verify this review by:
1. `psql -d psypi -c "SELECT severity, COUNT(*) FROM review_findings WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND status = 'open' GROUP BY severity"`
2. `psql -d psypi -c "SELECT * FROM table_documentation WHERE table_name = 'type_alignment_reference'"`
3. Cross-reference each finding with source code and database schema
4. Verify node-postgres type mapping: https://node-postgres.com/features/types

