# System Review — psypi — 2026-05-28 (Database-Backed)

Generated from `system_reviews` + `review_findings` database tables.
Review ID: `ca9e914c-cce6-4db4-b3b1-29779d8e1837`
Type: `system` | Methodology: `mixed` | Scope: `full`
Reviewer: `trae-ai` | Git: `706494e` (`after-rewriting`)

## Severity Breakdown

| Severity | Count | Percentage |
|----------|-------|------------|
| **CRITICAL** | 7 | 5.1% |
| **HIGH** | 42 | 30.9% |
| **MEDIUM** | 68 | 50.0% |
| **LOW** | 19 | 14.0% |
| **TOTAL** | 136 | 100% |

## Category Breakdown

| Category | Count | Findings |
|----------|-------|----------|
| missing_cast | 29 | 1C/17H |
| logic_error | 15 | 3C/5H |
| design_flaw | 12 |  |
| unused_columns | 10 |  |
| wrong_status | 8 | 0C/2H |
| missing_project_id | 8 | 1C/2H |
| ffi_mismatch | 6 | 2C/2H |
| missing_params | 6 | 0C/2H |
| type_mismatch | 5 | 0C/3H |
| error_handling | 5 |  |
| style | 4 |  |
| disconnected_systems | 4 | 0C/2H |
| wrong_column | 3 | 0C/3H |
| design | 3 |  |
| config_desync | 3 | 0C/2H |
| hardcoded_config | 3 |  |
| dead_code | 3 |  |
| test_coverage | 2 |  |
| security | 2 |  |
| performance | 2 | 0C/1H |
| type_coverage | 1 |  |
| wrong_decoder | 1 | 0C/1H |
| unused_table | 1 |  |

## Findings by Severity

### CRITICAL

| # | Category | Module | Title | Impact |
|---|----------|--------|-------|--------|
| 121 | ffi_mismatch | pi_extension_ffi | get_config returns JS null/string not Gleam Option | A-bot debounce never fires; idle_since always reset; A-bot completely dead |
| 249 | ffi_mismatch | pi_extension_ffi | get_config FFI returns JS null/string which never matches Gleam None/Some constructors | idle_since is always re-recorded as now(). Debounce never fires. A-bot wakeup is completely broken. |
| 139 | logic_error | broadcast | broadcast.stats() 3 bugs: bigint decode, text>=int, missing status column | Stats query returns wrong results or fails |
| 244 | logic_error | a_db_reader | No code updates agent_sessions.last_heartbeat — is_s_still_idle always returns True | A-bot can wake up while S is actively working. No guard against concurrent A+S execution. |
| 261 | logic_error | multiple | A-bot wakeup chain has 4 sequential failures - entire A-bot system is non-functional | A-bot system is completely non-functional. No autonomous monitoring no inter-review no self-healing. The entire A/S dual-agent architecture is dead on the A side. |
| 100 | missing_cast | inter_review | inter_review requested_at decode fails without ::text cast | Inter-review requests always fail to decode |
| 116 | missing_project_id | areflect | areflect.save_issue omits project_id (NOT NULL, no default) | save_issue INSERT always fails; no issues can be saved via areflect |
### HIGH

| # | Category | Module | Title | Impact |
|---|----------|--------|-------|--------|
| 125 | config_desync | psypi_config | psypi_config.gleam (database) vs pi_extension_ffi.mjs (in-memory) never sync | hook_on_agent_end uses 5min debounce; monitor_ai uses 15min debounce |
| 262 | config_desync | pi_extension_ffi | Dual config stores: FFI _configStore (in-memory) and psypi_config table (DB) are never synchronized | idle_since and monitor_debounce_ms are stored in _configStore (in-memory) but never persisted to DB. On process restart all debounce state is lost. psypi_config table exists but is not used by the debounce logic. |
| 247 | disconnected_systems | a_orchestrator | a_orchestrator.run_a_workflow never writes inter-review response to DB | Inter-review responses are ephemeral. If Pi message queue is lost, review data is lost. No audit trail. Additionally, tool_commit is permanently blocked because overall_score is never written (see #264). |
| 258 | disconnected_systems | inter_review | Inter-review commit flow is permanently stuck — missing git add before git commit | Inter-review code changes are never actually committed. Review feedback is generated but code is not saved. |
| 122 | ffi_mismatch | pi_extension_ffi | set_config stores value but get_config cannot retrieve as Gleam Option | Config round-trip broken |
| 123 | ffi_mismatch | pi_extension_ffi | unwrapGleamResult may not handle all Gleam Result shapes | Error handling in extension.js may fail |
| 250 | logic_error | agent_identity | semantic_id uses is_idle (momentary state) for A/S prefix (permanent identity) | When S is momentarily idle, it gets A-prefixed identity. Wrong soul loaded, wrong jobs fetched, wrong behavior. |
| 251 | logic_error | a_orchestrator | compose() called instead of compose_within_budget() — token budget system unused | A-bot system prompt may exceed context window, causing LLM failures. Token budget system exists but is never used. |
| 259 | logic_error | a_db_reader | is_s_still_idle counts ALL alive sessions, not just S-bot sessions | A-bot may think S is busy when only A-bot itself has an active session. Incorrect idle detection. |
| 264 | logic_error | tool_commit | tool_commit permanently blocked: overall_score is always NULL because a_orchestrator never writes review response to DB | Commits are permanently blocked. The psypi-commit tool can never succeed in Phase 2. Users must commit manually outside the tool. |
| 265 | logic_error | seed | seed.gleam multi-statement SQL: node-postgres may only execute first statement, silently dropping rest | Only the first soul (A) and first prefix (A) may be seeded. S and G prefixes/souls may be missing, causing identity and session failures. |
| 101 | missing_cast | inter_review | inter_review id not cast to text | Decode may fail or return [object Object] |
| 102 | missing_cast | memory | memory.search SELECT * returns uuid/timestamptz without casts | memory.search always returns DecodeError |
| 103 | missing_cast | skill | skill.get missing ::text casts on content and reference_list | Skill details may fail to decode |
| 109 | missing_cast | areflect | areflect.fetch_recent_issues missing ::text casts for uuid and timestamps | Recent issues fetch always fails |
| 200 | missing_cast | agent_identity | agent_identity fetch_soul_by_prefix: id uuid without ::text | Soul fetch fails to decode; agent identity broken |
| 201 | missing_cast | meeting | meeting.gleam: id uuid without ::text in all SELECT queries | Meeting queries fail to decode id |
| 202 | missing_cast | agents | agents.gleam: id uuid without ::text | Agent list fails to decode id |
| 203 | missing_cast | monitor | monitor.gleam get_pending_notifications: id uuid without ::text | Notification queries fail to decode id |
| 204 | missing_cast | task | task.gleam: id uuid without ::text in list and get queries | Task queries fail to decode id |
| 205 | missing_cast | issue_db | issue_db.gleam: id uuid without ::text in list and get queries | Issue queries fail to decode id |
| 216 | missing_cast | code_version | code_version save_version: save_code_version() returns uuid but decoder uses decode.string without ::text | Save version always fails to decode the returned version_id |
| 217 | missing_cast | code_version | code_version query_versions: id uuid and saved_at timestamptz without ::text | Version history query returns undecodable uuid/timestamp values |
| 218 | missing_cast | code_version | code_version get_versions: get_code_versions() returns id uuid and saved_at timestamptz without ::text | Version list returns undecodable uuid/timestamp values |
| 219 | missing_cast | areflect | areflect read_recent_issues: id uuid without ::text | Reflective analysis fails to decode issue ids |
| 220 | missing_cast | broadcast | broadcast.gleam: id uuid without ::text in all list queries | Broadcast list queries fail to decode id |
| 221 | missing_cast | inter_review | inter_review.gleam: id uuid and requested_at timestamptz without ::text in list queries | Inter-review list and get queries fail to decode |
| 222 | missing_cast | inter_review | inter_review.gleam: request_inter_review() returns uuid without ::text | Creating inter-review fails to decode returned review_id |
| 129 | missing_params | code_version | psypi-doc-save only declares file_path but uses 5 parameters | Content always empty; saved versions have no content |
| 256 | missing_params | agent_identity | psypi-my-id missing project and global fields in generated JS object | Semantic IDs contain "undefined" instead of project name. G-prefix never used. Identity system broken. |
| 117 | missing_project_id | areflect | areflect.save_task missing project_id (has default but wrong) | Tasks may be assigned to wrong project |
| 118 | missing_project_id | monitor_ai | auto_file_issue uses non-existent column type, missing project_id | Auto-issue filing always fails |
| 137 | performance | db | db.with_connection() creates new TCP connection per query | 3-10x latency overhead; potential connection exhaustion |
| 226 | type_mismatch | skill | SkillSource missing ai-built variant that DB allows | Decode fails for ai-built skills; INSERT with ai-built source from Gleam impossible |
| 227 | type_mismatch | task | TaskStatus missing FAKE_COMPLETE variant that DB allows | Decode fails for FAKE_COMPLETE tasks; cannot represent this status in Gleam |
| 229 | type_mismatch | issue_types | IssueStatus missing acknowledged/wont_fix/duplicate; has Closed which DB doesnt have | Decode fails for acknowledged/wont_fix/duplicate issues; Closed maps to non-existent DB status; INSERT with Closed fails |
| 215 | wrong_column | monitor_ai | monitor_ai record_tool_error: INSERT uses type instead of issue_type, missing project_id | Tool error recording fails because type column does not exist; should be issue_type. discovered_by and environment are valid columns. |
| 236 | wrong_column | memory | memory.search SELECT references column "saved_at" which does not exist in memory table | Finding was incorrect — memory.gleam search uses created_at correctly |
| 237 | wrong_column | broadcast | broadcast.stats SELECT references status column which does not exist in project_communications | Broadcast stats always returns error or empty result |
| 138 | wrong_decoder | memory | memory.save() decodes RETURNING id with full memory_decoder() | Save always reports error (data IS saved but error returned) |
| 111 | wrong_status | monitor_ai | check_system_health uses FAILED for tasks but DB has PENDING/COMPLETED | Finding was incorrect; FAILED status exists in both DB and Gleam TaskStatus type |
| 112 | wrong_status | monitor_ai | analyze_and_act same status value bugs as check_system_health | Finding was incorrect |
### MEDIUM

| # | Category | Module | Title | Impact |
|---|----------|--------|-------|--------|
| 126 | config_desync | seed | seed.gleam seeds monitor_debounce_ms as 300000 but DB has 900000 | Fresh installs get different debounce than existing deployments |
| 145 | dead_code | monitor_ai | housekeeping() is a test stub left in production | Dead code in production module |
| 255 | dead_code | monitor_ai | tool_consult is a stub — returns hardcoded message, no actual A-bot consultation | Consultation tool is non-functional. Agents that try to consult A-bot get a placeholder response. |
| 260 | dead_code | agent_identity | _global computed but never used — global_prefix in semantic_id reads ctx.global which is never set | G-prefix never used. _global computation is wasted. semantic_id never produces G-prefixed IDs. |
| 270 | design | simple_migrate | No migration tracking table: simple_migrate runs all scripts every time with no record of which were applied | No way to determine current schema version. Failed migrations are invisible. No rollback. All scripts run every startup (wasteful). Schema drift between environments is undetectable. |
| 146 | design_flaw | monitor_ai | monitor_ai.prepare_context UNION ALL with mismatched columns | Context preparation may fail or return wrong data |
| 147 | design_flaw | hook_on_before_agent_start | Error fallback includes hardcoded soul content | Errors masked by fake soul data |
| 149 | design_flaw | extension_generator | Dynamic imports in every hook trigger | Performance overhead on every hook trigger |
| 151 | design_flaw | audit_trigger | Audit trigger source=learn not in allowed sources | areflect save_learning may fail audit trigger validation |
| 154 | design_flaw | pi_extension_ffi | Duplicate now_ms FFI in both pi_extension_ffi.mjs and time_ffi.mjs | Inconsistency; which one is authoritative? |
| 156 | design_flaw | monitor_ai | call_monitor retry without exponential backoff | Retry storms under load; no jitter |
| 158 | design_flaw | package | Package namespace mismatch between gleam.toml and import paths | Import resolution may fail for external consumers |
| 245 | design_flaw | a_db_reader | agent_sessions has TWO heartbeat columns: last_heartbeat and last_heartbeat_at | Confusion about which column is canonical. If wrong column is used for idle detection, results differ. |
| 246 | design_flaw | hook_on_tool_result | hook_on_tool_result uses string.contains for error detection instead of JSON parsing | False error reports from legitimate tool output, or missed errors from unrecognized patterns |
| 252 | design_flaw | hook_on_tool_call | hook_on_tool_call only handles "edit" tool — all other tools ignored | No monitoring of non-edit tool calls. No error recording for failed tool calls except edit. |
| 254 | design_flaw | simple_migrate | Migration system has no tracking table — cannot determine which migrations have run | Cannot determine current schema version. Re-running migrations may fail or cause duplicate data. No rollback capability. |
| 127 | disconnected_systems | areflect | areflect saves to learning_insights; learning.gleam saves to memory; neither reads the other | No unified learning retrieval; insights fragmented |
| 128 | disconnected_systems | areflect | areflect.save_learning ignores agent_id parameter | Cannot attribute learnings to specific agents |
| 142 | error_handling | pi_extension | pi_send_message fire-and-forget; no error feedback | A→S communication failures are silent |
| 159 | error_handling | multiple | Error handling anti-pattern: Ok(0) on decode failure in 4+ modules | Silent data loss; errors never surface |
| 266 | error_handling | multiple | 8 instances of Error(_) -> Ok(default) silently swallow errors across 3 modules | Decode failures are invisible. Wrong data is returned as if correct. a_db_reader returning Ok(True) on error means is_s_still_idle always returns True even when the query fails. |
| 124 | ffi_mismatch | pi_extension_ffi | ctx_is_idle/ctx_has_pending_messages return JS booleans not Gleam Bool | Works by accident; fragile to Gleam compiler changes |
| 153 | ffi_mismatch | pi_extension_ffi | gleamValueToJson uses constructor.name which breaks under minification | Type detection fails in production if code is minified |
| 134 | hardcoded_config | issue_db | issue_db.get() and resolve() hardcode project_id UUID | Only works for one project; breaks if project_id changes |
| 135 | hardcoded_config | issue_db | issue_db.list() comment says session variable but hardcodes UUID | False documentation; actual behavior differs from stated |
| 136 | hardcoded_config | db | db.connect() sets app.current_project_id but no module reads it | Dead code; creates false sense of project isolation |
| 140 | logic_error | agent_identity | semantic_id uses is_idle for A/S prefix; idle S-agent gets wrong identity | Idle S-agent gets A- prefix; wrong session tracking |
| 141 | logic_error | hook_on_agent_end | hook_on_tool_result synchronous return in async context | Hook may not properly chain with other hooks |
| 160 | logic_error | hook_on_agent_end | A/S agent debounce logic: idle_since reset on every tool call | A-bot never goes idle; debounce never triggers; S-bot never activated |
| 248 | logic_error | monitor | monitor.set_model blanket reset race condition | Temporary window where no API key is active. Concurrent set_model calls could corrupt state. |
| 267 | logic_error | event_hooks | record_trigger called twice per agent start: before_agent_start and agent_start both trigger on same event | Duplicate trigger records inflate event counts. Monitoring based on trigger counts will be inaccurate. |
| 269 | logic_error | simple_migrate | simple_migrate.gleam may silently drop multi-statement migration scripts | Schema may be partially applied. Tables created but indexes/constraints/triggers silently dropped. This is worse than seed because it affects schema correctness. |
| 104 | missing_cast | task | task.get missing project_id::text in SELECT | Task get may fail to decode project_id |
| 105 | missing_cast | task | task.list id not cast to text | Task list may fail to decode id |
| 106 | missing_cast | agents | agents.list missing ::text cast on created_at | Agent list may fail to decode |
| 107 | missing_cast | monitor | monitor.get_pending_notifications read_at cast mismatch | Notification queries may fail |
| 108 | missing_cast | code_version | code_version.query_versions missing ::text casts | Version queries may fail to decode |
| 110 | missing_cast | a_db_reader | a_db_reader multiple queries missing ::text casts | A-agent reads may fail silently |
| 207 | missing_cast | stats | stats.gleam COUNT(*) without ::text or ::INT; decode_bigint expects string | Stats query may fail to decode counts |
| 208 | missing_cast | broadcast | broadcast.gleam stats(): COUNT(*) without ::INT cast | Stats may fail to decode for large counts |
| 209 | missing_cast | a_db_reader | a_db_reader is_s_still_idle: COUNT(*) without ::INT | Session count may fail to decode for large values |
| 212 | missing_cast | meeting | meeting.gleam: meeting_id uuid without ::text in opinions query | Opinion queries fail to decode meeting_id |
| 214 | missing_cast | task | task.gleam get(): id uuid without ::text, missing project_id in SELECT | Task get fails to decode id; Task record has no project_id |
| 132 | missing_params | memory | memory.memory_search_tool result template uses literal {count} | Result message shows literal {count} not actual number |
| 133 | missing_params | agent_identity | psypi-my-id missing project and global fields | Semantic ID becomes S-undefined-... instead of S-psypi-... |
| 119 | missing_project_id | a_db_reader | a_db_reader.read_active_tasks no project_id filter | Returns tasks from all projects |
| 120 | missing_project_id | broadcast | broadcast.send empty string for UUID NOT NULL column | Broadcast send fails on NOT NULL constraint |
| 223 | missing_project_id | monitor_ai | monitor_ai record_tool_error: INSERT INTO issues omits project_id | Tool error issues not scoped to project |
| 224 | missing_project_id | areflect | areflect INSERT INTO issues and tasks omits project_id | Issues INSERT will fail with NOT NULL constraint violation. Tasks INSERT succeeds but creates tasks in wrong project (default UUID instead of actual project). |
| 253 | performance | db | No connection pooling — every query creates and destroys a connection | Connection overhead on every query. Under concurrent load, connection exhaustion or slowdown. |
| 155 | security | pi_extension_ffi | exec_sync allows command injection via unsanitized input | Arbitrary command execution if tool params contain shell metacharacters |
| 162 | security | db | SQL injection risk: string interpolation in WHERE clauses | Potential SQL injection if filter values contain SQL metacharacters |
| 164 | type_coverage | multiple | 80 public types across 28 modules; no type audit exists | Cannot verify which DB tables have matching Gleam types without a mapping |
| 228 | type_mismatch | meeting | MeetingStatus has Pending but DB only allows active/completed/cancelled | INSERT with pending status will fail DB constraint; Gleam type allows invalid state |
| 230 | type_mismatch | issue_types | IssueType missing proposal which DB allows | Decode fails for proposal-type issues; cannot create proposal issues from Gleam |
| 232 | unused_columns | task | tasks table has 60 DB columns but Gleam decoder only handles 14 (46 unused) | 46 columns of task data are invisible to psypi. Other projects may write them but psypi cannot read them. Massive schema-code gap. |
| 233 | unused_columns | skill | skills table has 60+ DB columns but Gleam decoder only handles ~10 (45+ unused) | 45+ columns of skill data are invisible to psypi. Skill management features like ratings, downloads, reviews, scanning are all inaccessible. |
| 234 | unused_columns | issue_db | issues table has 30+ DB columns but Gleam decoder only handles ~15 (15+ unused) | Issue management features like assignments, milestones, tags, resolution tracking are inaccessible to psypi. |
| 235 | unused_columns | inter_review | inter_reviews table has 30+ DB columns but Gleam decoder only handles 6 (27+ unused) | Inter-review features like code quality scoring, suggestions, rework tracking, test coverage are all inaccessible. |
| 238 | unused_columns | areflect | learning_insights: areflect only INSERTs 4 columns, never reads any. 9 DB columns never used. | Learning insights are written but never read. No feedback loop. All insight data is write-only. |
| 240 | unused_columns | event_hooks | psypi_event_hooks: 7 of 14 DB columns never used by Gleam code | Hook actions (agentbot_action, worker_action) are never read, so hooks may not trigger correct actions |
| 231 | unused_table | global | 4 agent_* tables exist in DB but are never used by psypi Gleam code | Orphan tables consume DB resources and create confusion about data ownership in shared database |
| 113 | wrong_status | monitor_ai | get_model_stats case-sensitive status comparison | Model stats may miss records |
| 114 | wrong_status | task | task.string_to_status accepts both cases but DB is uppercase | Inconsistency between insert and query |
| 115 | wrong_status | issue_types | IssueStatus Gleam type vs DB CHECK mismatch | Decode fails for acknowledged/wont_fix/duplicate statuses |
| 206 | wrong_status | a_db_reader | a_db_reader read_open_issues uses status=closed but DB has no closed status | Issues with wont_fix/duplicate status show as open when they shouldnt |
| 210 | wrong_status | issue_types | IssueStatus missing acknowledged/wont_fix/duplicate; has Closed which DB doesnt have | Decode fails for acknowledged/wont_fix/duplicate issues; Closed maps to non-existent DB status |
| 211 | wrong_status | issue_types | IssueType missing proposal which DB allows | Decode fails for proposal-type issues |
### LOW

| # | Category | Module | Title | Impact |
|---|----------|--------|-------|--------|
| 225 | design | simple_migrate | simple_migrate re-runs all migrations every time — no tracking of completed migrations | Re-running migrations can cause errors from duplicate objects; no idempotency guarantee |
| 268 | design | extension_generator | extension_generator uses raw JSON schema for tool parameters instead of Pi SDK recommended TypeBox | No functional breakage, but misses TypeBox validation and enum features. Parameters with constrained values (enums) cannot be expressed. |
| 150 | design_flaw | hook_on_tool_call | Only triggers on tool named "edit" | Other tool calls not tracked |
| 143 | error_handling | issue_db | issue_db.count() returns Ok(0) on decode failure | Reports 0 issues when decode fails; misleading |
| 144 | error_handling | a_db_reader | a_db_reader reports Ok(True) on decode failure | Errors hidden; always reports no sessions |
| 257 | logic_error | pi_extension_ffi | _configStore in-memory cache has race condition with concurrent access | Under concurrent access, stale config values may be used. Dual store (DB + in-memory) without synchronization. |
| 130 | missing_params | issue_tools | psypi-issue-add references created_by not in params | Always defaults to "psypi" |
| 131 | missing_params | issue_tools | psypi-issues does not declare limit/offset in params | No way to page through results |
| 213 | missing_project_id | learning | learning.save() INSERT INTO memory omits project_id | Memories not scoped to project; cross-project leakage possible |
| 148 | style | command_reload | command_reload only notifies; no error handling | Reload failures are silent |
| 157 | style | pi_extension_ffi | Orphan FFI file not imported by any Gleam module | Dead code in FFI layer |
| 163 | style | git | Git state shows AI repair pattern: many fix commits without verification | Unverified fixes may introduce new bugs |
| 263 | style | pi_extension_ffi | gleamValueToJson has hardcoded type name list — new Gleam types not serialized as records | New types may serialize incorrectly in tool results. Not a crash but data quality issue in JSON output. |
| 152 | test_coverage | test | Gleam test files import modules that dont exist | Tests cannot compile; false positive pass rate |
| 161 | test_coverage | test | No integration tests for database queries | DB query bugs never caught by tests |
| 239 | unused_columns | monitor | provider_api_keys: Gleam only reads provider and model, never reads encrypted_key, status, etc. | API key management is partial — encryption fields never accessed by Gleam |
| 241 | unused_columns | broadcast | project_communications: 4 DB columns never used by Gleam code | Broadcast targeting (to_ai) and traceability (git_hash, git_branch) are never used |
| 242 | unused_columns | meeting | meetings: 4 DB columns never used by Gleam code | Meeting summaries and project ownership are never accessible |
| 243 | unused_columns | system_review_db | system_reviews: 3 JSONB columns (findings, action_items, limitations) never read after migration to review_findings table | Legacy JSONB data may be stale. Should be dropped or documented as deprecated |

## Detailed Findings

### #121 — get_config returns JS null/string not Gleam Option

- **Severity**: CRITICAL
- **Category**: ffi_mismatch
- **Module**: `pi_extension_ffi`
- **Status**: duplicate

**Description**: Gleam expects Some(value)/None but JS returns null or string; pattern matching never works [DUPLICATE of #249 — more detailed]

**Evidence**: `pi_extension_ffi.mjs: return _configStore[key] || null`

**Impact**: A-bot debounce never fires; idle_since always reset; A-bot completely dead

### #249 — get_config FFI returns JS null/string which never matches Gleam None/Some constructors

- **Severity**: CRITICAL
- **Category**: ffi_mismatch
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: pi_extension_ffi.mjs get_config returns null when key not found, or the raw string value when found. Gleam expects Option(String): None or Some(string). JS null does not equal Gleam None, and JS string does not equal Gleam Some(string). The Some branch in hook_on_agent_end is NEVER reached.

**Evidence**: `pi_extension_ffi.mjs: return row ? row.value : null; hook_on_agent_end.gleam uses case get_config(...) { Some(val) -> ... None -> ... } but Some is never matched`

**Impact**: idle_since is always re-recorded as now(). Debounce never fires. A-bot wakeup is completely broken.

### #139 — broadcast.stats() 3 bugs: bigint decode, text>=int, missing status column

- **Severity**: CRITICAL
- **Category**: logic_error
- **Module**: `broadcast`
- **Status**: open

**Description**: broadcast.stats() has 3 bugs: (1) priority is text (low/normal/high/critical) but query does priority >= 2 which is text>=int comparison — always fails; (2) WHERE status = sent but project_communications has no status column; (3) COUNT(*) returns bigint without ::INT cast

**Evidence**: `broadcast.gleam stats(): priority text>=2, status column does not exist in project_communications, COUNT(*) without ::INT`

**Impact**: Stats query returns wrong results or fails

### #244 — No code updates agent_sessions.last_heartbeat — is_s_still_idle always returns True

- **Severity**: CRITICAL
- **Category**: logic_error
- **Module**: `a_db_reader`
- **Status**: open

**Description**: a_db_reader.gleam:34 queries WHERE status = 'alive' AND last_heartbeat > NOW() - INTERVAL '5 minutes' but no Gleam code ever UPDATEs last_heartbeat. All 19 sessions have last_heartbeat from 20+ days ago. The query always returns cnt=0, so is_s_still_idle() always returns Ok(True).

**Evidence**: `a_db_reader.gleam:34 SELECT COUNT(*) FROM agent_sessions WHERE status='alive' AND last_heartbeat > NOW() - INTERVAL '5 minutes'; grep -rh "UPDATE agent_sessions" src/*.gleam returns nothing; grep -rh "last_heartbeat" src/*.gleam only finds the SELECT`

**Impact**: A-bot can wake up while S is actively working. No guard against concurrent A+S execution.

### #261 — A-bot wakeup chain has 4 sequential failures - entire A-bot system is non-functional

- **Severity**: CRITICAL
- **Category**: logic_error
- **Module**: `multiple`
- **Status**: open

**Description**: The A-bot wakeup chain has 4 sequential failures each of which alone would break the system: (1) get_config FFI returns JS null/string not Gleam Option so debounce never fires (#249), (2) is_s_still_idle always returns True because no code updates heartbeats (#244), (3) compose() called instead of compose_within_budget() so prompt may exceed context (#251), (4) a_orchestrator never writes inter-review response to DB (#247). All 4 must be fixed for A-bot to work.

**Evidence**: `hook_on_agent_end.gleam:34 get_config never matches; a_db_reader.gleam:34 no heartbeat updates; a_orchestrator.gleam:66 compose() not compose_within_budget(); a_orchestrator.gleam: no INSERT INTO inter_reviews`

**Impact**: A-bot system is completely non-functional. No autonomous monitoring no inter-review no self-healing. The entire A/S dual-agent architecture is dead on the A side.

### #100 — inter_review requested_at decode fails without ::text cast

- **Severity**: CRITICAL
- **Category**: missing_cast
- **Module**: `inter_review`
- **Status**: open

**Description**: SELECT * returns timestamptz without cast; node-postgres returns Date object which Gleam decode.string cannot parse

**Evidence**: `inter_review.gleam: requested_at field decoded as string but SELECT * returns timestamptz`

**Impact**: Inter-review requests always fail to decode

### #116 — areflect.save_issue omits project_id (NOT NULL, no default)

- **Severity**: CRITICAL
- **Category**: missing_project_id
- **Module**: `areflect`
- **Status**: open

**Description**: INSERT INTO issues (title, description, severity, created_by) — missing project_id column

**Evidence**: `areflect.gleam save_issue(): 4-column INSERT into 6-column table`

**Impact**: save_issue INSERT always fails; no issues can be saved via areflect

### #125 — psypi_config.gleam (database) vs pi_extension_ffi.mjs (in-memory) never sync

- **Severity**: HIGH
- **Category**: config_desync
- **Module**: `psypi_config`
- **Status**: open

**Description**: Two independent config systems with different values for same keys

**Evidence**: `psypi_config reads from DB; pi_extension_ffi uses _configStore object`

**Impact**: hook_on_agent_end uses 5min debounce; monitor_ai uses 15min debounce

### #262 — Dual config stores: FFI _configStore (in-memory) and psypi_config table (DB) are never synchronized

- **Severity**: HIGH
- **Category**: config_desync
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: hook_on_agent_end.gleam uses pi_extension.get_config/set_config which goes to FFI _configStore (in-memory JS object). psypi_config.gleam has its own get/set that reads/writes the psypi_config DB table. These two stores are completely independent. Setting a value via one is invisible to the other. Process restart loses all _configStore data.

**Evidence**: `pi_extension_ffi.mjs: let _configStore = {}; get_config reads _configStore; psypi_config.gleam: SELECT value FROM psypi_config WHERE key = $1; hook_on_agent_end.gleam uses pi_extension.get_config not psypi_config.get`

**Impact**: idle_since and monitor_debounce_ms are stored in _configStore (in-memory) but never persisted to DB. On process restart all debounce state is lost. psypi_config table exists but is not used by the debounce logic.

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

### #122 — set_config stores value but get_config cannot retrieve as Gleam Option

- **Severity**: HIGH
- **Category**: ffi_mismatch
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: Even if set_config works, get_config breaks the Option contract

**Evidence**: `pi_extension_ffi.mjs: set_config stores, get_config returns raw`

**Impact**: Config round-trip broken

### #123 — unwrapGleamResult may not handle all Gleam Result shapes

- **Severity**: HIGH
- **Category**: ffi_mismatch
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: Gleam Result is {type: "Ok"/"Error", ...} but unwrap logic may miss edge cases

**Evidence**: `pi_extension_ffi.mjs: unwrapGleamResult()`

**Impact**: Error handling in extension.js may fail

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

### #259 — is_s_still_idle counts ALL alive sessions, not just S-bot sessions

- **Severity**: HIGH
- **Category**: logic_error
- **Module**: `a_db_reader`
- **Status**: open

**Description**: a_db_reader.gleam:34 SELECT COUNT(*) FROM agent_sessions WHERE status = 'alive' AND last_heartbeat > NOW() - INTERVAL '5 minutes'. This counts ALL alive sessions including A-bot sessions. If A-bot has an active session, is_s_still_idle returns False even when S is idle.

**Evidence**: `a_db_reader.gleam:34 no filter on agent prefix or role; counts all sessions with status=alive`

**Impact**: A-bot may think S is busy when only A-bot itself has an active session. Incorrect idle detection.

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

### #101 — inter_review id not cast to text

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `inter_review`
- **Status**: open

**Description**: UUID columns need ::text cast for Gleam string decoder

**Evidence**: `inter_review.gleam: id is uuid, decoded as string without cast`

**Impact**: Decode may fail or return [object Object]

### #102 — memory.search SELECT * returns uuid/timestamptz without casts

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `memory`
- **Status**: open

**Description**: SELECT * FROM memory returns created_at as timestamptz and id as uuid, both need ::text

**Evidence**: `memory.gleam search(): SELECT * FROM memory WHERE content ILIKE $1`

**Impact**: memory.search always returns DecodeError

### #103 — skill.get missing ::text casts on content and reference_list

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `skill`
- **Status**: open

**Description**: skill.get_by_name() and search() have reference_list (jsonb) without ::text cast; get() has the cast

**Evidence**: `skill.gleam: lines 184,214 missing ::text on reference_list; lines 137,144 have it`

**Impact**: Skill details may fail to decode

### #109 — areflect.fetch_recent_issues missing ::text casts for uuid and timestamps

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `areflect`
- **Status**: open

**Description**: id is uuid, created_at/resolved_at are timestamptz, all need ::text

**Evidence**: `areflect.gleam fetch_recent_issues(): SELECT without casts`

**Impact**: Recent issues fetch always fails

### #200 — agent_identity fetch_soul_by_prefix: id uuid without ::text

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `agent_identity`
- **Status**: open

**Description**: SELECT id, name, domain, responsibility, trigger_type, drive_mode, activation FROM agent_souls — id is uuid, decoder expects String

**Evidence**: `agent_identity.gleam:120 SELECT id without ::text cast`

**Impact**: Soul fetch fails to decode; agent identity broken

### #201 — meeting.gleam: id uuid without ::text in all SELECT queries

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `meeting`
- **Status**: open

**Description**: Lines 166,173,206,276 — id is uuid, decoder expects String

**Evidence**: `meeting.gleam: id column not cast to text`

**Impact**: Meeting queries fail to decode id

### #202 — agents.gleam: id uuid without ::text

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `agents`
- **Status**: open

**Description**: SELECT id, agent_type, created_at::text — id is uuid, decoder expects String

**Evidence**: `agents.gleam:52 SELECT id without ::text cast`

**Impact**: Agent list fails to decode id

### #203 — monitor.gleam get_pending_notifications: id uuid without ::text

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `monitor`
- **Status**: open

**Description**: SELECT id, agent_id, priority, title, body — id is uuid, decoder expects String

**Evidence**: `monitor.gleam:188 SELECT id without ::text cast`

**Impact**: Notification queries fail to decode id

### #204 — task.gleam: id uuid without ::text in list and get queries

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `task`
- **Status**: open

**Description**: Lines 182,240 — id is uuid, decoder expects String

**Evidence**: `task.gleam: id column not cast to text in list/get`

**Impact**: Task queries fail to decode id

### #205 — issue_db.gleam: id uuid without ::text in list and get queries

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `issue_db`
- **Status**: open

**Description**: Lines 166,267 — id is uuid, decoder expects String

**Evidence**: `issue_db.gleam: id column not cast to text`

**Impact**: Issue queries fail to decode id

### #216 — code_version save_version: save_code_version() returns uuid but decoder uses decode.string without ::text

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `code_version`
- **Status**: open

**Description**: SELECT save_code_version(...) as version_id — function returns uuid, version_id_decoder uses decode.string

**Evidence**: `code_version.gleam:19 SELECT save_code_version() as version_id without ::text; version_id_decoder at line 84 uses decode.string`

**Impact**: Save version always fails to decode the returned version_id

### #217 — code_version query_versions: id uuid and saved_at timestamptz without ::text

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `code_version`
- **Status**: open

**Description**: SELECT id, file_path, saved_by, saved_at — id is uuid, saved_at is timestamptz, no ::text casts

**Evidence**: `code_version.gleam:186-188 id and saved_at without ::text cast`

**Impact**: Version history query returns undecodable uuid/timestamp values

### #218 — code_version get_versions: get_code_versions() returns id uuid and saved_at timestamptz without ::text

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `code_version`
- **Status**: open

**Description**: SELECT * FROM get_code_versions() — returns TABLE(id uuid, ..., saved_at timestamptz, ...) without casts

**Evidence**: `code_version.gleam:66 SELECT * FROM get_code_versions(); \\df+ shows id uuid, saved_at timestamptz return types`

**Impact**: Version list returns undecodable uuid/timestamp values

### #219 — areflect read_recent_issues: id uuid without ::text

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `areflect`
- **Status**: open

**Description**: SELECT id, title, status, severity FROM issues — id is uuid, decoder expects String

**Evidence**: `areflect.gleam:133 SELECT id without ::text cast`

**Impact**: Reflective analysis fails to decode issue ids

### #220 — broadcast.gleam: id uuid without ::text in all list queries

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `broadcast`
- **Status**: open

**Description**: SELECT id, from_ai as agent_id, content as message, priority — id is uuid, decoder expects String

**Evidence**: `broadcast.gleam:196,204,233 SELECT id without ::text cast`

**Impact**: Broadcast list queries fail to decode id

### #221 — inter_review.gleam: id uuid and requested_at timestamptz without ::text in list queries

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `inter_review`
- **Status**: open

**Description**: SELECT id, task_id, status, summary, overall_score, requested_at — id is uuid, task_id is uuid, requested_at is timestamptz

**Evidence**: `inter_review.gleam:148,283,285 id/task_id/requested_at without ::text`

**Impact**: Inter-review list and get queries fail to decode

### #222 — inter_review.gleam: request_inter_review() returns uuid without ::text

- **Severity**: HIGH
- **Category**: missing_cast
- **Module**: `inter_review`
- **Status**: open

**Description**: SELECT request_inter_review(...) as review_id — function returns uuid, decoder uses decode.string

**Evidence**: `inter_review.gleam:184 as review_id without ::text; \\df+ shows return type uuid`

**Impact**: Creating inter-review fails to decode returned review_id

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

### #117 — areflect.save_task missing project_id (has default but wrong)

- **Severity**: HIGH
- **Category**: missing_project_id
- **Module**: `areflect`
- **Status**: open

**Description**: Uses DEFAULT for project_id which may assign to wrong project

**Evidence**: `areflect.gleam save_task(): relies on DB default`

**Impact**: Tasks may be assigned to wrong project

### #118 — auto_file_issue uses non-existent column type, missing project_id

- **Severity**: HIGH
- **Category**: missing_project_id
- **Module**: `monitor_ai`
- **Status**: open

**Description**: INSERT uses column "type" which does not exist; also missing project_id

**Evidence**: `monitor_ai.gleam auto_file_issue(): INSERT with wrong column name`

**Impact**: Auto-issue filing always fails

### #137 — db.with_connection() creates new TCP connection per query

- **Severity**: HIGH
- **Category**: performance
- **Module**: `db`
- **Status**: open

**Description**: Every query: connect → auth → SET variable → query → disconnect

**Evidence**: `db.gleam with_connection(): no pooling, uses pg.Client not pg.Pool`

**Impact**: 3-10x latency overhead; potential connection exhaustion

### #226 — SkillSource missing ai-built variant that DB allows

- **Severity**: HIGH
- **Category**: type_mismatch
- **Module**: `skill`
- **Status**: open

**Description**: DB skills_source_check: clawhub, local, generated, imported, ai-built. Gleam SkillSource: Clawhub, Local, Generated, Imported. Missing ai-built.

**Evidence**: `skill.gleam:16 SkillSource has 4 variants; DB CHECK has 5 values including ai-built`

**Impact**: Decode fails for ai-built skills; INSERT with ai-built source from Gleam impossible

### #227 — TaskStatus missing FAKE_COMPLETE variant that DB allows

- **Severity**: HIGH
- **Category**: type_mismatch
- **Module**: `task`
- **Status**: open

**Description**: DB tasks_status_check: PENDING, RUNNING, COMPLETED, FAILED, FAKE_COMPLETE. Gleam TaskStatus: Pending, Running, Completed, Failed. Missing FAKE_COMPLETE.

**Evidence**: `task.gleam:9 TaskStatus has 4 variants; DB CHECK has 5 values including FAKE_COMPLETE`

**Impact**: Decode fails for FAKE_COMPLETE tasks; cannot represent this status in Gleam

### #229 — IssueStatus missing acknowledged/wont_fix/duplicate; has Closed which DB doesnt have

- **Severity**: HIGH
- **Category**: type_mismatch
- **Module**: `issue_types`
- **Status**: open

**Description**: DB issues_status_check: open, acknowledged, in_progress, resolved, wont_fix, duplicate. Gleam IssueStatus: Open, InProgress, Resolved, Closed. Missing 3, extra 1.

**Evidence**: `issue_types.gleam:13 string_to_status() maps closed->Closed but DB has no closed; acknowledged/wont_fix/duplicate cause Error`

**Impact**: Decode fails for acknowledged/wont_fix/duplicate issues; Closed maps to non-existent DB status; INSERT with Closed fails

### #215 — monitor_ai record_tool_error: INSERT uses type instead of issue_type, missing project_id

- **Severity**: HIGH
- **Category**: wrong_column
- **Module**: `monitor_ai`
- **Status**: open

**Description**: monitor_ai record_tool_error: INSERT uses type instead of issue_type. discovered_by and environment columns DO exist.

**Evidence**: `monitor_ai.gleam:561 INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment) — column is issue_type not type. discovered_by and environment DO exist in issues table.`

**Impact**: Tool error recording fails because type column does not exist; should be issue_type. discovered_by and environment are valid columns.

### #236 — memory.search SELECT references column "saved_at" which does not exist in memory table

- **Severity**: HIGH
- **Category**: wrong_column
- **Module**: `memory`
- **Status**: retracted

**Description**: memory.gleam search function SELECTs saved_at column but memory table has created_at, not saved_at. Also references content type 'learning' but memory table has no such discriminator. [RETRACTED: memory.gleam uses SELECT * and created_at, not saved_at. The saved_at reference was from monitor_ai.gleam querying code_versions table, not memory table.]

**Evidence**: `memory.gleam search query; \\d memory shows no saved_at column, only created_at`

**Impact**: Finding was incorrect — memory.gleam search uses created_at correctly

### #237 — broadcast.stats SELECT references status column which does not exist in project_communications

- **Severity**: HIGH
- **Category**: wrong_column
- **Module**: `broadcast`
- **Status**: open

**Description**: broadcast.gleam stats() filters WHERE status = 'sent' but project_communications has no status column. Also compares priority (text) >= 2 (integer).

**Evidence**: `broadcast.gleam:261 WHERE status = 'sent'; \\d project_communications shows no status column`

**Impact**: Broadcast stats always returns error or empty result

### #138 — memory.save() decodes RETURNING id with full memory_decoder()

- **Severity**: HIGH
- **Category**: wrong_decoder
- **Module**: `memory`
- **Status**: open

**Description**: INSERT RETURNING id returns 1 column but decoder expects all Memory fields

**Evidence**: `memory.gleam save(): decode.run(row, memory_decoder()) on RETURNING id`

**Impact**: Save always reports error (data IS saved but error returned)

### #111 — check_system_health uses FAILED for tasks but DB has PENDING/COMPLETED

- **Severity**: HIGH
- **Category**: wrong_status
- **Module**: `monitor_ai`
- **Status**: retracted

**Description**: tasks.status CHECK allows PENDING/COMPLETED only; FAILED does not exist [RETRACTED: FAILED IS a valid task status per DB CHECK constraint: PENDING/RUNNING/COMPLETED/FAILED/FAKE_COMPLETE]

**Evidence**: `monitor_ai.gleam check_system_health(): WHERE status != 'FAILED'`

**Impact**: Finding was incorrect; FAILED status exists in both DB and Gleam TaskStatus type

### #112 — analyze_and_act same status value bugs as check_system_health

- **Severity**: HIGH
- **Category**: wrong_status
- **Module**: `monitor_ai`
- **Status**: retracted

**Description**: Same FAILED status issue propagated to analyze_and_act [RETRACTED: Same as #111, FAILED IS valid]

**Evidence**: `monitor_ai.gleam analyze_and_act(): same wrong status`

**Impact**: Finding was incorrect

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

### #146 — monitor_ai.prepare_context UNION ALL with mismatched columns

- **Severity**: MEDIUM
- **Category**: design_flaw
- **Module**: `monitor_ai`
- **Status**: open

**Description**: UNION ALL queries have different column counts/types

**Evidence**: `monitor_ai.gleam prepare_context(): UNION ALL mismatch`

**Impact**: Context preparation may fail or return wrong data

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

### #158 — Package namespace mismatch between gleam.toml and import paths

- **Severity**: MEDIUM
- **Category**: design_flaw
- **Module**: `package`
- **Status**: open

**Description**: Package name in gleam.toml may not match actual import structure

**Evidence**: `gleam.toml: name vs actual module paths`

**Impact**: Import resolution may fail for external consumers

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

### #254 — Migration system has no tracking table — cannot determine which migrations have run

- **Severity**: MEDIUM
- **Category**: design_flaw
- **Module**: `simple_migrate`
- **Status**: open

**Description**: simple_migrate.gleam reads all .sql files from src/migrations/ and runs them in order. But there is no migrations tracking table to record which migrations have already been applied. Running migrations twice could cause errors (duplicate tables, constraint violations).

**Evidence**: `simple_migrate.gleam: reads and executes all .sql files; no CREATE TABLE migrations_applied or similar tracking`

**Impact**: Cannot determine current schema version. Re-running migrations may fail or cause duplicate data. No rollback capability.

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

**Description**: Multiple modules return Ok(default) when decode fails, hiding errors

**Evidence**: `issue_db count(), a_db_reader read_*, memory search()`

**Impact**: Silent data loss; errors never surface

### #266 — 8 instances of Error(_) -> Ok(default) silently swallow errors across 3 modules

- **Severity**: MEDIUM
- **Category**: error_handling
- **Module**: `multiple`
- **Status**: open

**Description**: Multiple modules catch decode errors and return Ok with a default value instead of propagating the error. This makes debugging impossible because failures are invisible. Found in: system_review_db.gleam (5: FuPending, Pending, None, Medium, FindingOpen), issue_db.gleam (1: Ok(0)), a_db_reader.gleam (1: Ok(True)).

**Evidence**: `system_review_db.gleam:62 Error(_) -> FuPending; :66 Error(_) -> Pending; :96 Error(_) -> None; :119 Error(_) -> Medium; :123 Error(_) -> FindingOpen; issue_db.gleam:251 Error(_) -> Ok(0); a_db_reader.gleam:44 Error(_) -> Ok(True)`

**Impact**: Decode failures are invisible. Wrong data is returned as if correct. a_db_reader returning Ok(True) on error means is_s_still_idle always returns True even when the query fails.

### #124 — ctx_is_idle/ctx_has_pending_messages return JS booleans not Gleam Bool

- **Severity**: MEDIUM
- **Category**: ffi_mismatch
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: Gleam Bool is JS true/false so this actually works, but the type signature uses untyped `a`

**Evidence**: `pi_extension.gleam: ctx_is_idle(ctx: a) -> Bool`

**Impact**: Works by accident; fragile to Gleam compiler changes

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

### #207 — stats.gleam COUNT(*) without ::text or ::INT; decode_bigint expects string

- **Severity**: MEDIUM
- **Category**: missing_cast
- **Module**: `stats`
- **Status**: open

**Description**: COUNT(*) returns bigint; decode_bigint uses decode.string but no ::text cast in SQL

**Evidence**: `stats.gleam:30 COUNT(*) without cast; stats_decoder uses decode_bigint`

**Impact**: Stats query may fail to decode counts

### #208 — broadcast.gleam stats(): COUNT(*) without ::INT cast

- **Severity**: MEDIUM
- **Category**: missing_cast
- **Module**: `broadcast`
- **Status**: open

**Description**: COUNT(*) as total returns bigint; decoder uses decode.int

**Evidence**: `broadcast.gleam:257 COUNT(*) without ::INT`

**Impact**: Stats may fail to decode for large counts

### #209 — a_db_reader is_s_still_idle: COUNT(*) without ::INT

- **Severity**: MEDIUM
- **Category**: missing_cast
- **Module**: `a_db_reader`
- **Status**: open

**Description**: COUNT(*) as cnt returns bigint; decoder uses decode.int

**Evidence**: `a_db_reader.gleam:33 COUNT(*) without ::INT`

**Impact**: Session count may fail to decode for large values

### #212 — meeting.gleam: meeting_id uuid without ::text in opinions query

- **Severity**: MEDIUM
- **Category**: missing_cast
- **Module**: `meeting`
- **Status**: open

**Description**: SELECT id, meeting_id, author, perspective, reasoning — meeting_id is uuid without ::text

**Evidence**: `meeting.gleam:276 meeting_id not cast to text`

**Impact**: Opinion queries fail to decode meeting_id

### #214 — task.gleam get(): id uuid without ::text, missing project_id in SELECT

- **Severity**: MEDIUM
- **Category**: missing_cast
- **Module**: `task`
- **Status**: duplicate

**Description**: SELECT id,...FROM tasks WHERE id=$1 — id not cast, project_id not selected [DUPLICATE of #104]

**Evidence**: `task.gleam:240 id without ::text, missing project_id column`

**Impact**: Task get fails to decode id; Task record has no project_id

### #132 — memory.memory_search_tool result template uses literal {count}

- **Severity**: MEDIUM
- **Category**: missing_params
- **Module**: `memory`
- **Status**: open

**Description**: Template has ${count} but count is not a variable in scope

**Evidence**: `memory.gleam: template("Found {count} memories")`

**Impact**: Result message shows literal {count} not actual number

### #133 — psypi-my-id missing project and global fields

- **Severity**: MEDIUM
- **Category**: missing_params
- **Module**: `agent_identity`
- **Status**: duplicate

**Description**: lit() expression does not include project or global fields [DUPLICATE of #256 — more detailed]

**Evidence**: `agent_identity.gleam my_id_tool(): missing project/global`

**Impact**: Semantic ID becomes S-undefined-... instead of S-psypi-...

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

### #223 — monitor_ai record_tool_error: INSERT INTO issues omits project_id

- **Severity**: MEDIUM
- **Category**: missing_project_id
- **Module**: `monitor_ai`
- **Status**: duplicate

**Description**: INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment) — no project_id [DUPLICATE of #215 which also covers wrong column name]

**Evidence**: `monitor_ai.gleam:561 INSERT without project_id`

**Impact**: Tool error issues not scoped to project

### #224 — areflect INSERT INTO issues and tasks omits project_id

- **Severity**: MEDIUM
- **Category**: missing_project_id
- **Module**: `areflect`
- **Status**: duplicate

**Description**: areflect INSERT INTO issues omits project_id (NOT NULL, no default). INSERT INTO tasks omits project_id but tasks.project_id has a default value so it won't fail — however it creates tasks in the wrong project (always uses default UUID 0d324e68-b399-4b85-bd8a-6b1ef7b46168). [DUPLICATE: issues part covered by #116, tasks part covered by #117]

**Evidence**: `areflect.gleam:224,262 INSERT without project_id`

**Impact**: Issues INSERT will fail with NOT NULL constraint violation. Tasks INSERT succeeds but creates tasks in wrong project (default UUID instead of actual project).

### #253 — No connection pooling — every query creates and destroys a connection

- **Severity**: MEDIUM
- **Category**: performance
- **Module**: `db`
- **Status**: open

**Description**: db.gleam with_connection creates a new pg.Client.connect() for every query and closes it after. No connection pool. Under load (multiple concurrent tool calls), this creates many short-lived connections.

**Evidence**: `db.gleam: with_connection calls pg.Client.connect() then pg.Client.close() for every query`

**Impact**: Connection overhead on every query. Under concurrent load, connection exhaustion or slowdown.

### #155 — exec_sync allows command injection via unsanitized input

- **Severity**: MEDIUM
- **Category**: security
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: exec_sync runs shell commands; shell_escape() provides basic sanitization but may not cover all edge cases (newlines, semicolons, pipe characters)

**Evidence**: `pi_extension_ffi.mjs: exec_sync(cmd); tool_commit.gleam: shell_escape() covers backslash, quote, backtick, dollar sign`

**Impact**: Arbitrary command execution if tool params contain shell metacharacters

### #162 — SQL injection risk: string interpolation in WHERE clauses

- **Severity**: MEDIUM
- **Category**: security
- **Module**: `db`
- **Status**: open

**Description**: build_where functions concatenate user input into SQL strings

**Evidence**: `issue_db.gleam, task.gleam: string concatenation in SQL`

**Impact**: Potential SQL injection if filter values contain SQL metacharacters

### #164 — 80 public types across 28 modules; no type audit exists

- **Severity**: MEDIUM
- **Category**: type_coverage
- **Module**: `multiple`
- **Status**: open

**Description**: psypi has 80 pub types with ~230 constructors across 28 modules but no type coverage audit or DB-to-Gleam type mapping table

**Evidence**: `grep -c pub type src/*.gleam = 80 types; 28 modules have types`

**Impact**: Cannot verify which DB tables have matching Gleam types without a mapping

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

### #211 — IssueType missing proposal which DB allows

- **Severity**: MEDIUM
- **Category**: wrong_status
- **Module**: `issue_types`
- **Status**: duplicate

**Description**: DB CHECK includes proposal; Gleam IssueType does not have Proposal variant [DUPLICATE of #230]

**Evidence**: `issue_types.gleam: string_to_type() — no proposal case`

**Impact**: Decode fails for proposal-type issues

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

## Top 10 System-Stopping Issues

| # | Finding | Why It Stops The System |
|---|---------|------------------------|
| 249 | get_config FFI returns JS null/string which never matches Gleam None/Some constructors | idle_since is always re-recorded as now(). Debounce never fires. A-bot wakeup is completely broken. |
| 139 | broadcast.stats() 3 bugs: bigint decode, text>=int, missing status column | Stats query returns wrong results or fails |
| 244 | No code updates agent_sessions.last_heartbeat — is_s_still_idle always returns True | A-bot can wake up while S is actively working. No guard against concurrent A+S execution. |
| 261 | A-bot wakeup chain has 4 sequential failures - entire A-bot system is non-functional | A-bot system is completely non-functional. No autonomous monitoring no inter-review no self-healing. The entire A/S dual-agent architecture is dead on the A side. |
| 100 | inter_review requested_at decode fails without ::text cast | Inter-review requests always fail to decode |
| 116 | areflect.save_issue omits project_id (NOT NULL, no default) | save_issue INSERT always fails; no issues can be saved via areflect |
| 125 | psypi_config.gleam (database) vs pi_extension_ffi.mjs (in-memory) never sync | hook_on_agent_end uses 5min debounce; monitor_ai uses 15min debounce |
| 262 | Dual config stores: FFI _configStore (in-memory) and psypi_config table (DB) are never synchronized | idle_since and monitor_debounce_ms are stored in _configStore (in-memory) but never persisted to DB. On process restart all debounce state is lost. psypi_config table exists but is not used by the debounce logic. |
| 247 | a_orchestrator.run_a_workflow never writes inter-review response to DB | Inter-review responses are ephemeral. If Pi message queue is lost, review data is lost. No audit trail. Additionally, tool_commit is permanently blocked because overall_score is never written (see #264). |
| 258 | Inter-review commit flow is permanently stuck — missing git add before git commit | Inter-review code changes are never actually committed. Review feedback is generated but code is not saved. |

