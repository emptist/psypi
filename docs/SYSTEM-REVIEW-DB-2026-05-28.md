# System Review — psypi — 2026-05-28 (Database-Backed)

Generated from `system_reviews` + `review_findings` database tables.
Review ID: `ca9e914c-cce6-4db4-b3b1-29779d8e1837`
Type: `system` | Methodology: `mixed` | Scope: `full`
Reviewer: `trae-ai` | Git: `706494e` (`after-rewriting`)

## Severity Breakdown

| Severity | Count | Percentage |
|----------|-------|------------|
| **CRITICAL** | 4 | 4.2% |
| **HIGH** | 31 | 32.3% |
| **MEDIUM** | 49 | 51.0% |
| **LOW** | 12 | 12.5% |
| **TOTAL** | 96 | 100% |

## Category Breakdown

| Category | Count | Findings |
|----------|-------|----------|
| missing_cast | 29 | 1C/17H |
| design_flaw | 8 |  |
| missing_project_id | 8 | 1C/2H |
| wrong_status | 8 | 0C/2H |
| ffi_mismatch | 5 | 1C/2H |
| type_mismatch | 5 | 0C/3H |
| missing_params | 5 | 0C/1H |
| logic_error | 4 | 1C/0H |
| error_handling | 4 |  |
| style | 3 |  |
| hardcoded_config | 3 |  |
| disconnected_systems | 2 |  |
| test_coverage | 2 |  |
| config_desync | 2 | 0C/1H |
| security | 2 |  |
| performance | 1 | 0C/1H |
| wrong_decoder | 1 | 0C/1H |
| dead_code | 1 |  |
| wrong_column | 1 | 0C/1H |
| type_coverage | 1 |  |
| design | 1 |  |

## Findings by Severity

### CRITICAL

| # | Category | Module | Title | Impact |
|---|----------|--------|-------|--------|
| 121 | ffi_mismatch | pi_extension_ffi | get_config returns JS null/string not Gleam Option | A-bot debounce never fires; idle_since always reset; A-bot completely dead |
| 139 | logic_error | broadcast | broadcast.stats() 3 bugs: bigint decode, text>=int, missing status column | Stats query returns wrong results or fails |
| 100 | missing_cast | inter_review | inter_review requested_at decode fails without ::text cast | Inter-review requests always fail to decode |
| 116 | missing_project_id | areflect | areflect.save_issue omits project_id (NOT NULL, no default) | save_issue INSERT always fails; no issues can be saved via areflect |
### HIGH

| # | Category | Module | Title | Impact |
|---|----------|--------|-------|--------|
| 125 | config_desync | psypi_config | psypi_config.gleam (database) vs pi_extension_ffi.mjs (in-memory) never sync | hook_on_agent_end uses 5min debounce; monitor_ai uses 15min debounce |
| 122 | ffi_mismatch | pi_extension_ffi | set_config stores value but get_config cannot retrieve as Gleam Option | Config round-trip broken |
| 123 | ffi_mismatch | pi_extension_ffi | unwrapGleamResult may not handle all Gleam Result shapes | Error handling in extension.js may fail |
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
| 117 | missing_project_id | areflect | areflect.save_task missing project_id (has default but wrong) | Tasks may be assigned to wrong project |
| 118 | missing_project_id | monitor_ai | auto_file_issue uses non-existent column type, missing project_id | Auto-issue filing always fails |
| 137 | performance | db | db.with_connection() creates new TCP connection per query | 3-10x latency overhead; potential connection exhaustion |
| 226 | type_mismatch | skill | SkillSource missing ai-built variant that DB allows | Decode fails for ai-built skills; INSERT with ai-built source from Gleam impossible |
| 227 | type_mismatch | task | TaskStatus missing FAKE_COMPLETE variant that DB allows | Decode fails for FAKE_COMPLETE tasks; cannot represent this status in Gleam |
| 229 | type_mismatch | issue_types | IssueStatus missing acknowledged/wont_fix/duplicate; has Closed which DB doesnt have | Decode fails for acknowledged/wont_fix/duplicate issues; Closed maps to non-existent DB status; INSERT with Closed fails |
| 215 | wrong_column | monitor_ai | monitor_ai record_tool_error: INSERT uses type instead of issue_type, missing project_id | Tool error recording fails because type column does not exist; should be issue_type. discovered_by and environment are valid columns. |
| 138 | wrong_decoder | memory | memory.save() decodes RETURNING id with full memory_decoder() | Save always reports error (data IS saved but error returned) |
| 111 | wrong_status | monitor_ai | check_system_health uses FAILED for tasks but DB has PENDING/COMPLETED | Finding was incorrect; FAILED status exists in both DB and Gleam TaskStatus type |
| 112 | wrong_status | monitor_ai | analyze_and_act same status value bugs as check_system_health | Finding was incorrect |
### MEDIUM

| # | Category | Module | Title | Impact |
|---|----------|--------|-------|--------|
| 126 | config_desync | seed | seed.gleam seeds monitor_debounce_ms as 300000 but DB has 900000 | Fresh installs get different debounce than existing deployments |
| 145 | dead_code | monitor_ai | housekeeping() is a test stub left in production | Dead code in production module |
| 146 | design_flaw | monitor_ai | monitor_ai.prepare_context UNION ALL with mismatched columns | Context preparation may fail or return wrong data |
| 147 | design_flaw | hook_on_before_agent_start | Error fallback includes hardcoded soul content | Errors masked by fake soul data |
| 149 | design_flaw | extension_generator | Dynamic imports in every hook trigger | Performance overhead on every hook trigger |
| 151 | design_flaw | audit_trigger | Audit trigger source=learn not in allowed sources | areflect save_learning may fail audit trigger validation |
| 154 | design_flaw | pi_extension_ffi | Duplicate now_ms FFI in both pi_extension_ffi.mjs and time_ffi.mjs | Inconsistency; which one is authoritative? |
| 156 | design_flaw | monitor_ai | call_monitor retry without exponential backoff | Retry storms under load; no jitter |
| 158 | design_flaw | package | Package namespace mismatch between gleam.toml and import paths | Import resolution may fail for external consumers |
| 127 | disconnected_systems | areflect | areflect saves to learning_insights; learning.gleam saves to memory; neither reads the other | No unified learning retrieval; insights fragmented |
| 128 | disconnected_systems | areflect | areflect.save_learning ignores agent_id parameter | Cannot attribute learnings to specific agents |
| 142 | error_handling | pi_extension | pi_send_message fire-and-forget; no error feedback | A→S communication failures are silent |
| 159 | error_handling | multiple | Error handling anti-pattern: Ok(0) on decode failure in 4+ modules | Silent data loss; errors never surface |
| 124 | ffi_mismatch | pi_extension_ffi | ctx_is_idle/ctx_has_pending_messages return JS booleans not Gleam Bool | Works by accident; fragile to Gleam compiler changes |
| 153 | ffi_mismatch | pi_extension_ffi | gleamValueToJson uses constructor.name which breaks under minification | Type detection fails in production if code is minified |
| 134 | hardcoded_config | issue_db | issue_db.get() and resolve() hardcode project_id UUID | Only works for one project; breaks if project_id changes |
| 135 | hardcoded_config | issue_db | issue_db.list() comment says session variable but hardcodes UUID | False documentation; actual behavior differs from stated |
| 136 | hardcoded_config | db | db.connect() sets app.current_project_id but no module reads it | Dead code; creates false sense of project isolation |
| 140 | logic_error | agent_identity | semantic_id uses is_idle for A/S prefix; idle S-agent gets wrong identity | Idle S-agent gets A- prefix; wrong session tracking |
| 141 | logic_error | hook_on_agent_end | hook_on_tool_result synchronous return in async context | Hook may not properly chain with other hooks |
| 160 | logic_error | hook_on_agent_end | A/S agent debounce logic: idle_since reset on every tool call | A-bot never goes idle; debounce never triggers; S-bot never activated |
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
| 224 | missing_project_id | areflect | areflect INSERT INTO issues and tasks omits project_id | Reflective issues/tasks not scoped to project |
| 155 | security | pi_extension_ffi | exec_sync allows command injection via unsanitized input | Arbitrary command execution if tool params contain shell metacharacters |
| 162 | security | db | SQL injection risk: string interpolation in WHERE clauses | Potential SQL injection if filter values contain SQL metacharacters |
| 164 | type_coverage | multiple | 80 public types across 28 modules; no type audit exists | Cannot verify which DB tables have matching Gleam types without a mapping |
| 228 | type_mismatch | meeting | MeetingStatus has Pending but DB only allows active/completed/cancelled | INSERT with pending status will fail DB constraint; Gleam type allows invalid state |
| 230 | type_mismatch | issue_types | IssueType missing proposal which DB allows | Decode fails for proposal-type issues; cannot create proposal issues from Gleam |
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
| 150 | design_flaw | hook_on_tool_call | Only triggers on tool named "edit" | Other tool calls not tracked |
| 143 | error_handling | issue_db | issue_db.count() returns Ok(0) on decode failure | Reports 0 issues when decode fails; misleading |
| 144 | error_handling | a_db_reader | a_db_reader reports Ok(True) on decode failure | Errors hidden; always reports no sessions |
| 130 | missing_params | issue_tools | psypi-issue-add references created_by not in params | Always defaults to "psypi" |
| 131 | missing_params | issue_tools | psypi-issues does not declare limit/offset in params | No way to page through results |
| 213 | missing_project_id | learning | learning.save() INSERT INTO memory omits project_id | Memories not scoped to project; cross-project leakage possible |
| 148 | style | command_reload | command_reload only notifies; no error handling | Reload failures are silent |
| 157 | style | pi_extension_ffi | Orphan FFI file not imported by any Gleam module | Dead code in FFI layer |
| 163 | style | git | Git state shows AI repair pattern: many fix commits without verification | Unverified fixes may introduce new bugs |
| 152 | test_coverage | test | Gleam test files import modules that dont exist | Tests cannot compile; false positive pass rate |
| 161 | test_coverage | test | No integration tests for database queries | DB query bugs never caught by tests |

## Detailed Findings

### #121 — get_config returns JS null/string not Gleam Option

- **Severity**: CRITICAL
- **Category**: ffi_mismatch
- **Module**: `pi_extension_ffi`
- **Status**: open

**Description**: Gleam expects Some(value)/None but JS returns null or string; pattern matching never works

**Evidence**: `pi_extension_ffi.mjs: return _configStore[key] || null`

**Impact**: A-bot debounce never fires; idle_since always reset; A-bot completely dead

### #139 — broadcast.stats() 3 bugs: bigint decode, text>=int, missing status column

- **Severity**: CRITICAL
- **Category**: logic_error
- **Module**: `broadcast`
- **Status**: open

**Description**: broadcast.stats() has 3 bugs: (1) priority is text (low/normal/high/critical) but query does priority >= 2 which is text>=int comparison — always fails; (2) WHERE status = sent but project_communications has no status column; (3) COUNT(*) returns bigint without ::INT cast

**Evidence**: `broadcast.gleam stats(): priority text>=2, status column does not exist in project_communications, COUNT(*) without ::INT`

**Impact**: Stats query returns wrong results or fails

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
- **Status**: open

**Description**: SELECT id,...FROM tasks WHERE id=$1 — id not cast, project_id not selected

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
- **Status**: open

**Description**: lit() expression does not include project or global fields

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
- **Status**: open

**Description**: INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment) — no project_id

**Evidence**: `monitor_ai.gleam:561 INSERT without project_id`

**Impact**: Tool error issues not scoped to project

### #224 — areflect INSERT INTO issues and tasks omits project_id

- **Severity**: MEDIUM
- **Category**: missing_project_id
- **Module**: `areflect`
- **Status**: open

**Description**: INSERT INTO issues (title, description, severity, created_by) and INSERT INTO tasks (title, description, priority, created_by) — no project_id

**Evidence**: `areflect.gleam:224,262 INSERT without project_id`

**Impact**: Reflective issues/tasks not scoped to project

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
- **Status**: open

**Description**: DB CHECK includes proposal; Gleam IssueType does not have Proposal variant

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

## Top 10 System-Stopping Issues

| # | Finding | Why It Stops The System |
|---|---------|------------------------|
| 121 | get_config FFI returns JS null/string not Gleam Option | A-bot debounce never fires; idle_since always reset; A-bot completely dead |
| 116 | areflect.save_issue omits project_id (NOT NULL) | INSERT always fails; no issues can be saved via areflect |
| 118 | auto_file_issue uses non-existent column type | Auto-issue filing always fails |
| 138 | memory.save() decodes RETURNING id with full memory_decoder() | Save always reports error; confusing for users |
| 102 | memory.search SELECT * without ::text on created_at | Decode always fails; search returns no results |
| 111 | check_system_health uses FAILED for tasks (no rows) | Health metrics for tasks always return 0 |
| 137 | No connection pooling; new TCP connection per query | 3-10x latency overhead; potential connection exhaustion |
| 139 | broadcast.stats() 3 bugs: bigint decode, text>=int, missing status | Stats query returns wrong results or fails |
| 129 | psypi-doc-save only declares file_path but uses 5 params | Content always empty; saved versions have no content |
| 140 | semantic_id uses is_idle for A/S prefix | Idle S-agent gets A- prefix; wrong session tracking |

