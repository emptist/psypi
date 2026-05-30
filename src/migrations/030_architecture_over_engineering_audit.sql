-- 030_architecture_over_engineering_audit.sql
-- Review ID: ca9e914c-cce6-4db4-b3b1-29779d8e1837
-- Findings #424-#447: Architecture over-engineering, dead code, ghost tables,
-- duplicate code, redundant checks, and logic errors discovered via 5-question audit:
--   1. Who uses them?
--   2. Why should they use them instead of a simpler way?
--   3. Are they solving a real problem?
--   4. Are they the real solve in real Gleam code?
--   5. Are they inevitable?
-- TARGET DATABASE: psypi (not jk)

-- ============================================================
-- OVER-ENGINEERING: Files that exist for false architecture
-- ============================================================

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 424, 'high', 'over_engineering', 'a_orchestrator',
 'a_orchestrator.gleam: single-consumer orchestrator with zero branching - straight-line pipeline',
 'a_orchestrator.gleam (161 lines) has exactly one caller: hook_on_agent_end.gleam:134. The orchestration is a straight-line pipeline: read 4 things from DB then build 2 prompts then call AI then send response. There is no branching, no conditional workflow, no decision-making. The name orchestrator implies complex routing but the entire file is just sequential data gathering. Compare command_listen.gleam which does the same thing (build prompt, call_monitor, pi_send_message) in 48 lines inline. The run_a_workflow() function is a pointless wrapper that calls run_full_workflow() with zero transformation. The 4 independent DB reads are chained sequentially in a 5-level nested promise.await pyramid instead of being parallelized.',
 'a_orchestrator.gleam:14 run_a_workflow() calls run_full_workflow() with identical args. a_orchestrator.gleam:20-97 5-level nested promise.await for 4 independent DB reads. Only caller: hook_on_agent_end.gleam:134. command_listen.gleam does same job in 48 lines.',
 '747 lines across 5 files for what command_listen.gleam does in 48 lines. Adds latency (4 sequential DB round-trips instead of parallel). Increases maintenance burden with no architectural benefit.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 425, 'high', 'over_engineering', 'a_db_reader',
 'a_db_reader.gleam: 255-line A-only DB reader - false per-agent abstraction with duplicated helpers',
 'a_db_reader.gleam (255 lines) contains 5 DB query functions that all follow the identical pattern: db.with_connection, db.query, case result, decode_rows. The db_error_to_string and decode_rows helpers are copy-pasted into s_db_reader.gleam, project.gleam, and broadcast.gleam (4 copies total). The A reader / S reader split is a false separation - they both query the same database through the same db.with_connection pattern. The split exists because someone thought A-bot needs its own reader was architecture. It is not - it is just SQL queries. The helpers should be in db.gleam and the queries should be wherever they are needed.',
 'a_db_reader.gleam:10 pub fn db_error_to_string - same as s_db_reader.gleam:10, project.gleam:247, broadcast.gleam:169. a_db_reader.gleam:17 pub fn decode_rows - same as s_db_reader.gleam:77, project.gleam:247, broadcast.gleam:169. 20 files each define their own db_error_to_* mapper.',
 '255 lines of boilerplate for 5 queries. 4 copies of db_error_to_string + decode_rows across codebase. False per-agent reader abstraction adds files without adding structure.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 426, 'high', 'over_engineering', 's_db_reader',
 's_db_reader.gleam: 94-line S-only DB reader - 1 function used, 1 dead, helpers duplicated',
 's_db_reader.gleam (94 lines) has one caller: hook_on_before_agent_start.gleam:5, which uses only read_s_soul_from_db(). The read_s_jobs_from_db() function is never called - dead code. The db_error_to_string and decode_rows helpers are identical to those in a_db_reader.gleam. 94 lines for 1 used query is unjustifiable as a separate file.',
 's_db_reader.gleam:14 read_s_soul_from_db() - only used function. s_db_reader.gleam:44 read_s_jobs_from_db() - never called. Only caller: hook_on_before_agent_start.gleam:5.',
 '94 lines for 1 used query. Dead function read_s_jobs_from_db. Duplicated helpers.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 427, 'medium', 'over_engineering', 'a_context_utils',
 'a_context_utils.gleam: 52-line file for 1 used function + 1 dead function with duplicate FFI',
 'a_context_utils.gleam (52 lines) has one caller: hook_on_agent_end.gleam:1, which uses only parse_context_window(). The current_time_ms() function is never called and wraps a duplicate now_ms FFI from node_ffi.mjs that returns Result(Int, String) - different from the correct pi_extension.now_ms() which returns Int. The parse_context_window function is a JSON decode of one field that could be inline.',
 'a_context_utils.gleam:44 current_time_ms() - never called. a_context_utils.gleam:51 @external now_ms from node_ffi.mjs - duplicate of pi_extension.now_ms. Only caller: hook_on_agent_end.gleam:1 uses parse_context_window only.',
 '52 lines for 1 used function. Dead current_time_ms. Duplicate FFI.');

-- ============================================================
-- REDUNDANT CHECK: Asking the database what the runtime already knows
-- ============================================================

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 428, 'critical', 'redundant_check', 'a_db_reader',
 'is_s_still_idle() queries ghost table agent_sessions - nothing writes to it, always returns True',
 'a_db_reader.is_s_still_idle() opens a database connection, runs SET app.current_project_id, then executes SELECT COUNT(*) FROM agent_sessions WHERE status = ''alive'' AND last_heartbeat > NOW() - INTERVAL ''5 minutes''. But the agent_sessions table is never INSERTed into or UPDATEd by any Gleam code - the only reference to this table in the entire codebase is this SELECT query. The query always returns COUNT(*)=0, so is_s_still_idle() always returns Ok(True). This means the DB check provides zero additional information beyond ctx_is_idle(ctx) which is instant and free. The DB check costs ~50-100ms (TCP connect + auth + SET + SELECT + disconnect) for a known-always-True result.',
 'a_db_reader.gleam:30-55 is_s_still_idle() definition. grep agent_sessions across all .gleam files: only reference is a_db_reader.gleam:33. No INSERT/UPDATE to agent_sessions exists. hook_on_agent_end.gleam:122 calls a_db_reader.is_s_still_idle() after already checking ctx_is_idle(ctx) on line 118.',
 'Wastes 50-100ms per A-bot wakeup on a DB round-trip that always returns the same answer. Creates false sense of defense in depth when there is no depth. The only reason a_db_reader is imported by hook_on_agent_end is this one useless function.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 429, 'high', 'redundant_check', 'hook_on_agent_end',
 'hook_on_agent_end: redundant DB idle check after ctx_is_idle - DB check result silently swallowed on error',
 'hook_on_agent_end.gleam coordinate_with_s() performs two idle checks: (1) ctx_is_idle(ctx) on line 118 - instant, from Pi runtime, the source of truth; (2) a_db_reader.is_s_still_idle() on line 122 - DB round-trip to a ghost table. The DB check result is silently swallowed on error: case idle_result { Ok(False) -> abort, _ -> proceed } - meaning both Ok(True) and Error(_) proceed. If the DB is down, the check is skipped. If the DB returns stale data, it is ignored when it disagrees. The check guards nothing. It is the only reason a_db_reader is imported by hook_on_agent_end.',
 'hook_on_agent_end.gleam:118 ctx_is_idle(ctx) - first check. hook_on_agent_end.gleam:122 a_db_reader.is_s_still_idle() - redundant second check. hook_on_agent_end.gleam:124 case idle_result { Ok(False) -> abort, _ -> proceed } - error silently swallowed. Import a_db_reader exists solely for this check.',
 'Adds latency and a DB dependency to the A-bot wakeup path for zero benefit. The error-swallowing means the guard cannot guard. Creates false confidence in a non-functional safety net.');

-- ============================================================
-- GHOST TABLE: Tables that nothing writes to
-- ============================================================

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 430, 'critical', 'ghost_table', 'a_db_reader',
 'agent_sessions table is never written to - is_s_still_idle() always returns True, table is dead infrastructure',
 'The agent_sessions table (created in migration 013_agent_sessions.sql) is never INSERTed into or UPDATEd by any Gleam code. The only reference to this table in the entire codebase is the SELECT query in a_db_reader.is_s_still_idle(). This means: (1) The table is always empty or stale. (2) COUNT(*) always returns 0. (3) is_s_still_idle() always returns Ok(True). (4) The table serves no purpose. The migration created infrastructure (table + query) that was never connected to the code that would populate it.',
 '013_agent_sessions.sql creates the table. grep agent_sessions across all .gleam files: only a_db_reader.gleam:33 SELECTs from it. No INSERT/UPDATE/DELETE exists. a_db_reader.is_s_still_idle() always returns Ok(True) because table is empty.',
 'Dead table consumes DB space. Dead query wastes 50-100ms per A-bot wakeup. Creates false impression that session tracking exists when it does not. The migration and table should be removed or the session tracking should be implemented.');

-- ============================================================
-- DUPLICATE CODE: Same logic copy-pasted across files
-- ============================================================

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 431, 'high', 'duplicate_code', 'db',
 'db_error_to_string / decode_rows copied 20 times across codebase instead of being in db.gleam',
 'Every file that uses db.with_connection defines its own error mapper function (db_error_to_string, db_error_to_monitor_error, db_error_to_task_error, etc.) - 20 copies total. The pattern is always the same 3 lines: case e { db.ConnectionError(msg) -> XError(msg), db.QueryError(msg) -> XError(msg) }. Additionally, decode_rows (map decode.run over list, collect errors) is duplicated in a_db_reader.gleam, s_db_reader.gleam, project.gleam, and broadcast.gleam. The root cause is db.with_connection requiring an error_mapper: fn(DbError) -> e parameter, which forces every consumer to define its own error type and mapper. These helpers should be in db.gleam as shared utilities.',
 '20 files define db_error_to_* functions: agent_identity, seed, a_db_reader, task, inter_review, project, meeting, skill, system_review_db, issue_db, broadcast, areflect, memory, learning, s_db_reader, monitor_ai, simple_migrate, psypi_config, monitor, agents. decode_rows duplicated in a_db_reader.gleam:17, s_db_reader.gleam:77, project.gleam:247, broadcast.gleam:169.',
 '60+ lines of duplicated code. Every new DB module must copy the same boilerplate. Inconsistent error handling across modules (some map to String, some to custom types). Changes to the pattern must be applied 20 times.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 432, 'high', 'duplicate_code', 'monitor_ai',
 'monitor_ai.gleam and monitor.gleam both define MonitorError type + db_error_to_monitor_error - name collision',
 'monitor_ai.gleam (583 lines) defines: pub type MonitorError { ConnectionError(String), QueryError(String), DecodeError(String) } and fn db_error_to_monitor_error. monitor.gleam (294 lines) defines: pub type MonitorError { ConnectionError(String), QueryError(String), NotFound(String), DecodeError(String) } and fn db_error_to_monitor_error. These are two different types with the same name in two different modules. monitor_ai has 3 variants (no NotFound); monitor has 4 variants (with NotFound). If any code ever imports both, Gleam would require disambiguation. The split between these two files is arbitrary - monitor.gleam handles model selection + notifications, monitor_ai.gleam handles health + alerts + stats + suggestions + actions. Both are monitor functionality.',
 'monitor_ai.gleam:14 pub type MonitorError { ConnectionError, QueryError, DecodeError }. monitor.gleam:11 pub type MonitorError { ConnectionError, QueryError, NotFound, DecodeError }. Both define fn db_error_to_monitor_error. extension_generator.gleam:129,138 references monitor module for hooks.',
 'Name collision risk. Two files with 877 combined lines doing monitor things with different error types. Any refactoring that needs both modules requires disambiguation. Inconsistent error handling for the same domain.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 433, 'medium', 'duplicate_code', 'a_context_utils',
 'a_context_utils.gleam has duplicate now_ms FFI - pi_extension.now_ms() already exists with correct signature',
 'pi_extension.gleam:71 declares @external now_ms() -> Int, used by hook_on_agent_end.gleam and a_orchestrator.gleam. a_context_utils.gleam:51-52 declares @external now_ms() -> Result(Int, String) from node_ffi.mjs - a different signature returning Result. The a_context_utils version is wrapped by current_time_ms() which discards the error and returns 0. This is Bug #9 from the handoff. The duplicate exists because a_context_utils was written independently without checking pi_extension.',
 'pi_extension.gleam:71 @external now_ms() -> Int. a_context_utils.gleam:51 @external now_ms() -> Result(Int, String). node_ffi.mjs exports now_ms returning new Ok(Date.now()). pi_extension_ffi.mjs exports now_ms returning Date.now() directly.',
 'Two FFI functions doing the same thing with different return types. a_context_utils version silently returns 0 on error instead of propagating. node_ffi.mjs has an unnecessary Ok wrapper.');

-- ============================================================
-- DEAD CODE: Functions that nobody calls
-- ============================================================

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 434, 'medium', 'dead_code', 's_db_reader',
 's_db_reader.read_s_jobs_from_db() is never called by any module',
 's_db_reader.gleam:44 defines read_s_jobs_from_db() which queries agent_jobs for S-prefix souls. No .gleam file imports or calls this function. The only caller of s_db_reader is hook_on_before_agent_start.gleam which uses only read_s_soul_from_db(). S-bot jobs are never loaded from the database.',
 's_db_reader.gleam:44 pub fn read_s_jobs_from_db(). grep read_s_jobs_from_db across all .gleam files: only definition, no calls. hook_on_before_agent_start.gleam:5 imports s_db_reader but only calls read_s_soul_from_db().',
 'Dead code adds maintenance burden. S-bot jobs exist in the database but are never loaded - the jobs system is incomplete for S-bot.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 435, 'medium', 'dead_code', 'a_context_utils',
 'a_context_utils.current_time_ms() is never called - wraps duplicate FFI, silently returns 0 on error',
 'a_context_utils.gleam:44 defines current_time_ms() which calls the duplicate now_ms FFI from node_ffi.mjs and returns 0 on error. No .gleam file calls this function. The correct now_ms is in pi_extension.gleam which returns Int directly without Result wrapping.',
 'a_context_utils.gleam:44 pub fn current_time_ms(). grep current_time_ms across all .gleam files: only definition, no calls. pi_extension.gleam:71 has the correct now_ms() -> Int.',
 'Dead code. If someone did call it, they would get 0 on error instead of the actual time - a silent data corruption bug.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 436, 'low', 'dead_code', 'monitor_ai',
 'monitor_ai.housekeeping() is a no-op stub in production - returns Ok(Nil) unconditionally',
 'monitor_ai.gleam:87 housekeeping() has comment Currently a no-op; previously inserted test stub data into code_versions. TODO: Implement proper housekeeping. The function body is just promise.resolve(Ok(Nil)). It is never called from any hook or tool registration.',
 'monitor_ai.gleam:87 pub fn housekeeping(_agent_id: String) -> promise.resolve(Ok(Nil)). Not registered in extension_generator.gleam all_tools() or all_event_hooks().',
 'Dead stub code. If ever called, does nothing. The TODO comment indicates awareness that it should be implemented but never was.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 437, 'medium', 'dead_code', 'monitor_ai',
 'monitor_ai.prepare_context() is never called from any hook or tool - 30 lines of dead DB query code',
 'monitor_ai.gleam:99 prepare_context() queries memory and code_versions tables to build a context string for the agentbot AI. It is never registered as a Pi tool (not in extension_generator.gleam all_tools()) and never called from any hook. The function includes a comment HELPS ME WORK FASTER! suggesting it was intended for use but never connected.',
 'monitor_ai.gleam:99 pub fn prepare_context(). Not in extension_generator.gleam all_tools() or all_event_hooks(). Not called by a_orchestrator or hook_on_agent_end.',
 '30 lines of dead DB query code. Memory and code_versions data is never used for A-bot context despite being queried.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 438, 'medium', 'dead_code', 'monitor_ai',
 'monitor_ai.check_safety() is never called - safety blocking system exists but is not wired up',
 'monitor_ai.gleam:390 check_safety() wraps check_system_health() and adds a should_block boolean based on whether open_issues > 3. It is never registered as a Pi tool or called from any hook. The SafetyResult type and the entire safety check system is dead code.',
 'monitor_ai.gleam:384 pub type SafetyResult. monitor_ai.gleam:390 pub fn check_safety(). Not in extension_generator.gleam all_tools() or all_event_hooks().',
 'Safety blocking system exists but is not wired up. If open issues exceed threshold, nothing happens. The code gives a false impression that safety checks are in place.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 439, 'medium', 'dead_code', 'monitor_ai',
 'monitor_ai.analyze_and_act() is never called - autonomous action system exists but is not wired up',
 'monitor_ai.gleam:489 analyze_and_act() queries tasks and issues to determine what autonomous action the monitor should take. It is never registered as a Pi tool or called from any hook. The MonitorAction type and the entire autonomous action system is dead code. The comment says Called on session_start and agent_end events but it is not registered for either event.',
 'monitor_ai.gleam:483 pub type MonitorAction. monitor_ai.gleam:489 pub fn analyze_and_act(). Not in extension_generator.gleam all_tools() or all_event_hooks(). Comment says Called on session_start and agent_end events but it is not.',
 'Autonomous action system exists but is not wired up. Monitor cannot take autonomous actions despite having the code for it. The comment claiming it is called is misleading.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 440, 'high', 'dead_code', 'monitor_ai',
 'monitor_ai.record_review_score() is never called - a_orchestrator never writes review response to DB',
 'monitor_ai.gleam:304 record_review_score() updates inter_reviews SET overall_score = $1 WHERE id = $2. It is never called because a_orchestrator.gleam never writes the review response to the inter_reviews table - it only sends the response via pi_send_message. This means overall_score stays NULL forever in inter_reviews, which breaks tool_commit.commit_if_reviewed() which checks review.overall_score. The entire commit workflow is dead at Phase 2 because no code writes the review result.',
 'monitor_ai.gleam:304 pub fn record_review_score(). Not called by a_orchestrator.gleam or any other module. a_orchestrator.gleam:93 only calls pi_send_message(pi, autonomic-wakeup, response, persistent) - no DB write. tool_commit.gleam checks overall_score which is always NULL.',
 'Inter-review scores are never recorded. Commit workflow is broken because overall_score is always NULL.');

-- ============================================================
-- FALSE ABSTRACTION: Split that doesn't serve a purpose
-- ============================================================

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 441, 'high', 'false_abstraction', 'monitor_ai',
 'monitor_ai.gleam (583 lines) + monitor.gleam (294 lines) = 877 lines split across 2 files with same MonitorError type - no clear separation principle',
 'monitor_ai.gleam and monitor.gleam both define MonitorError types and db_error_to_monitor_error functions. The split is: monitor.gleam handles model selection (get_model, set_model, record_current_model) + notifications (get_pending_notifications, create_notification, mark_notifications_read). monitor_ai.gleam handles health (check_system_health, get_alerts), stats (get_model_stats, record_review_score), suggestions (get_work_suggestions), safety (check_safety), actions (analyze_and_act, auto_file_issue), and Pi tool definitions. There is no clear separation principle - both are monitor functionality. The split appears to be things that were added later vs things that were added first.',
 'monitor_ai.gleam:14 pub type MonitorError { ConnectionError, QueryError, DecodeError }. monitor.gleam:11 pub type MonitorError { ConnectionError, QueryError, NotFound, DecodeError }. Both define fn db_error_to_monitor_error. extension_generator.gleam:129,138 references monitor module for hooks. monitor_ai is imported for tools.',
 '877 lines of monitor code split across 2 files with no clear boundary. Duplicate error types. Name collision risk. Anyone working on monitor functionality must navigate both files.');

-- ============================================================
-- BOILERPLATE: db.with_connection pattern repeated 90 times
-- ============================================================

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 442, 'high', 'boilerplate', 'db',
 'db.with_connection API forces every consumer to define its own error type + mapper - 20 copies of the same 3-line function',
 'db.gleam:73 with_connection(callback, error_mapper) requires an error_mapper: fn(DbError) -> e parameter. This forces every module that uses DB to: (1) define its own error type with ConnectionError and QueryError variants, (2) define its own db_error_to_X function mapping DbError to that type. There are 20 such copies in the codebase. The pattern is always identical: case e { db.ConnectionError(msg) -> XError(msg), db.QueryError(msg) -> XError(msg) }. A better API would provide a default error type in db.gleam that modules can use directly, or use a generic error type that does not require per-module mapping.',
 'db.gleam:73 pub fn with_connection(callback, error_mapper). 20 files define db_error_to_* functions. 90 calls to db.with_connection across the codebase. Every DB module has 3-5 lines of boilerplate for the error mapper alone.',
 '60+ lines of duplicated error mapping code. Every new DB module must copy the same boilerplate. Inconsistent error handling (some map to String, some to custom types). The error_mapper parameter adds cognitive overhead without providing value in most cases where the default mapping would suffice.');

-- ============================================================
-- LOGIC ERROR: Code that can't work as written
-- ============================================================

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 443, 'critical', 'logic_error', 'monitor_ai',
 'check_system_health() queries status=FAILED but tasks table has no FAILED status - always returns 0',
 'monitor_ai.gleam:65 check_system_health() executes: SELECT (SELECT COUNT(*)::INT FROM tasks WHERE status = ''FAILED'') as failed_tasks. But the tasks table CHECK constraint only allows PENDING and COMPLETED (uppercase). There is no FAILED status. The query always returns 0 for failed_tasks. This means the health monitoring system can never detect failed tasks.',
 'monitor_ai.gleam:65 WHERE status = ''FAILED''. tasks table CHECK (status IN (''PENDING'', ''COMPLETED'')). No FAILED status exists. Query always returns 0.',
 'Health monitoring for failed tasks is completely non-functional. The failed_tasks field in HealthMetrics is always 0. Any code that relies on health metrics to detect problems will miss task failures.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 444, 'critical', 'logic_error', 'monitor_ai',
 'get_alerts() same FAILED status bug - failed_tasks in AlertMetrics always 0',
 'monitor_ai.gleam:208 get_alerts() executes: SELECT (SELECT COUNT(*)::INT FROM tasks WHERE status = ''FAILED'') as failed_tasks. Same bug as #443 - tasks table has no FAILED status. The AlertMetrics.failed_tasks field is always 0.',
 'monitor_ai.gleam:208 WHERE status = ''FAILED''. Same root cause as #443.',
 'Alert system cannot detect failed tasks. The psypi-autonomic-alerts tool always shows 0 failed tasks.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 445, 'high', 'logic_error', 'monitor_ai',
 'analyze_and_act() same FAILED status bug - never detects failed tasks in autonomous action analysis',
 'monitor_ai.gleam:505 analyze_and_act() executes: SELECT ''failed_tasks'' as action, COUNT(*)::TEXT || '' failed tasks need review'' as details FROM tasks WHERE status = ''FAILED''. Same bug as #443 - tasks table has no FAILED status. The analyze_and_act function can never return the failed_tasks action.',
 'monitor_ai.gleam:505 WHERE status = ''FAILED''. Same root cause as #443.',
 'Autonomous action analysis can never detect failed tasks. Even if analyze_and_act were wired up (it is not - see #439), it could not detect task failures.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 446, 'medium', 'logic_error', 'hook_on_tool_result',
 'hook_on_tool_result detects errors by string.contains on JSON - fragile, false positives on legitimate content',
 'hook_on_tool_result.gleam:7 detects errors by checking: string.contains(result_json, "\"error\"") || string.contains(result_json, "Error:") || string.contains(result_json, "execution error") || string.contains(result_json, "tool_execution_blocked") || string.contains(result_json, "\"is_error\":true"). This is fragile because: (1) A legitimate tool result discussing errors (e.g. a code review finding) would trigger a false positive. (2) The check is case-sensitive - error matches but ERROR does not. (3) JSON structure is not parsed - the string error anywhere in the JSON triggers it. (4) The extract_error_msg function does crude string splitting on error and Error: which breaks on nested JSON.',
 'hook_on_tool_result.gleam:7-12 is_error check via string.contains. hook_on_tool_result.gleam:39-60 extract_error_msg via string.split on error and Error:.',
 'False positive error notifications when tools return legitimate content containing the word error. False negatives when errors use different casing or format. Error messages extracted by string splitting are often garbled or incomplete.');

-- ============================================================
-- META: system_review_db.gleam was dead code (tables now exist in psypi DB)
-- ============================================================

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 447, 'high', 'ghost_table', 'system_review_db',
 'system_review_db.gleam references system_reviews table - previously no migration created it, table only existed in psypi DB not jk DB',
 'system_review_db.gleam (559 lines) queries system_reviews and review_findings tables. These tables exist in the psypi database but were missing from the jk database (which some environments default to). No migration in the migrations/ directory creates the system_reviews table. Migration 027 creates review_findings but depends on system_reviews. The system-review-tools Pi commands would fail if connected to the wrong database. This was discovered when an AI session accidentally operated on the jk database instead of psypi.',
 'system_review_db.gleam:193 INSERT INTO system_reviews. system_review_db.gleam:237 INSERT INTO review_findings. No migration creates system_reviews. Migration 027 depends on it. .env.example specifies DATABASE_URL=postgresql://postgres:postgres@localhost:5432/psypi but default psql connects to jk database.',
 'System review Pi tools fail silently when connected to wrong database. No migration creates system_reviews table. The infrastructure depends on manual table creation or a missing migration.');

-- ============================================================
-- SUMMARY
-- ============================================================

SELECT 'ARCHITECTURE OVER-ENGINEERING AUDIT (psypi DB)' AS section;
SELECT severity, category, COUNT(*) AS cnt
FROM review_findings
WHERE finding_number >= 424 AND finding_number <= 447
GROUP BY severity, category
ORDER BY severity, category;

SELECT '=== TOTAL NEW FINDINGS BY SEVERITY ===' AS section;
SELECT severity, COUNT(*) AS cnt
FROM review_findings
WHERE finding_number >= 424 AND finding_number <= 447
GROUP BY severity
ORDER BY
  CASE severity
    WHEN 'critical' THEN 1
    WHEN 'high' THEN 2
    WHEN 'medium' THEN 3
    WHEN 'low' THEN 4
    WHEN 'cosmetic' THEN 5
  END;
