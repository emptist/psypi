-- 027x_comprehensive_type_gap_findings.sql
-- Findings from comprehensive type inventory audit
-- Covers: 10 missing tables, broadcast.gleam bugs, MeetingStatus phantom variant,
--         inter_reviews String-only types, agent_jobs implicit enum, and more

-- Get the review_id
-- ca9e914c-cce6-4db4-b3b1-29779d8e1837

-- =====================================================================
-- #322: broadcast.gleam stats() references non-existent status column
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 322, 'critical', 'sql_error', 'broadcast.gleam',
  'broadcast.stats() SQL references non-existent status column — runtime SQL error',
  'broadcast.gleam:257-262 stats() function queries: COUNT(*) FILTER (WHERE status = ''sent''). The project_communications table has NO status column. This SQL always fails with: ERROR: column "status" does not exist. Verified by running the exact SQL against the database.',
  'broadcast.gleam:257 SQL: ''SELECT COUNT(*) as total, COUNT(*) FILTER (WHERE status = ''sent'') as sent_count...'' DB schema: project_communications has id, project_id, from_ai, to_ai, message_type, content, metadata, created_at, read_at, priority, git_hash, git_branch, environment. No status column.',
  'Every call to broadcast.stats() fails at the SQL level. The function returns QueryError. No broadcast statistics can ever be retrieved. This is a dead function.'
);

-- =====================================================================
-- #323: broadcast.gleam stats() compares text priority with integer
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 323, 'critical', 'sql_error', 'broadcast.gleam',
  'broadcast.stats() compares text priority >= 2 — type mismatch in SQL',
  'broadcast.gleam:261 stats() function queries: COUNT(*) FILTER (WHERE priority >= 2). The priority column is text type with CHECK constraint allowing low/normal/high/critical. Comparing text with integer >= 2 fails: ERROR: operator does not exist: text >= integer. Even if status column existed, this would still fail.',
  'broadcast.gleam:261 SQL: ''COUNT(*) FILTER (WHERE priority >= 2)''. DB: project_communications.priority is text with CHECK(low,normal,high,critical). psql returns: ERROR: operator does not exist: text >= integer.',
  'stats() has TWO independent SQL errors. Neither can be fixed without rewriting the entire query. The function is completely non-functional.'
);

-- =====================================================================
-- #324: BroadcastStatus type maps to phantom column
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 324, 'high', 'type_gap', 'broadcast.gleam',
  'BroadcastStatus type has no corresponding DB column — type maps to nothing',
  'broadcast.gleam defines BroadcastStatus with 4 variants (Pending/Sent/Failed/Cancelled) and string_to_status() function. But project_communications has no status column. The list() and get_recent() functions fake it with ''sent'' as status (SQL literal alias). BroadcastStatus is a phantom type with no DB backing.',
  'broadcast.gleam:7-12 BroadcastStatus type. broadcast.gleam:200 SQL: ''''sent'' as status'' (literal alias, not column). DB: project_communications has no status column.',
  'BroadcastStatus cannot represent real DB state. All broadcasts appear as "sent" regardless of actual state. Pending/Failed/Cancelled variants are unreachable from DB data. The type gives false impression of status tracking.'
);

-- =====================================================================
-- #325: MeetingStatus has phantom Pending variant
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 325, 'medium', 'type_gap', 'meeting.gleam',
  'MeetingStatus.Pending is a phantom variant — DB CHECK does not allow ''pending''',
  'meeting.gleam:9-13 defines MeetingStatus with 4 variants: Pending, Active, Completed, Cancelled. string_to_status() maps "pending" -> Pending. But meetings.status CHECK constraint only allows: active, completed, cancelled. The "pending" value is not in the constraint. Any row with status=pending would fail the CHECK. Pending can never be read from DB.',
  'meeting.gleam:9-13 MeetingStatus type. meeting.gleam:46-47 string_to_status maps "pending" -> Pending. DB: meetings_status_check allows only active/completed/cancelled.',
  'Pending variant is dead code. It can never be populated from DB reads. If code tries to insert with status=pending, it will fail the CHECK constraint. The variant exists in the type but not in the data model.'
);

-- =====================================================================
-- #326: agent_jobs.category — 13-value implicit enum with no Gleam type
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 326, 'medium', 'type_gap', 'agent_identity.gleam',
  'agent_jobs.category has 13 implicit enum values with no Gleam type — no validation',
  'agent_jobs.category has 13 distinct values in production: behavior, business, continue, definition, learning, maintenance, new_task, quality, research, review, safety, suggestion, unblock. No CHECK constraint. Gleam code reads it as plain String in agent_identity.gleam:154 and a_db_reader.gleam:199. Any string can be inserted as category.',
  'agent_identity.gleam:154 reads j.category as String. a_db_reader.gleam:199 reads j.category as String. DB: SELECT DISTINCT category FROM agent_jobs returns 13 values. No CHECK constraint on category column.',
  'No type safety for job categories. Typos in category values go undetected. Cannot pattern match on category in Gleam. New categories can be added without any validation or code update.'
);

-- =====================================================================
-- #327: agent_souls has 5 implicit enum columns with no Gleam types
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 327, 'medium', 'type_gap', 'agent_identity.gleam',
  'agent_souls has 5 implicit enum columns (trigger_type, drive_mode, activation, id_prefix, role) with no Gleam types',
  'agent_souls has 5 columns with de facto enum values but no CHECK constraints: trigger_type (event/prompt), drive_mode (autonomous/reactive), activation (3 complex values), id_prefix (A/S/G), role (AutonomicBot/SomaticBot). Gleam reads all as String in agent_identity.gleam:120. No type safety for any of these.',
  'agent_identity.gleam:120 SQL: ''SELECT id, name, domain, responsibility, trigger_type, drive_mode, activation FROM agent_souls''. All decoded as String. DB: SELECT DISTINCT trigger_type, drive_mode, activation FROM agent_souls shows 2 rows each.',
  'No compile-time guarantee that trigger_type is event or prompt. No validation on insert. Activation values contain spaces and special chars — problematic for simple enum mapping. id_prefix is used in WHERE clauses throughout with hardcoded strings.'
);

-- =====================================================================
-- #328: agent_sessions.status has CHECK but no Gleam type
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 328, 'medium', 'type_gap', 'a_db_reader.gleam',
  'agent_sessions.status has CHECK(alive/dead/sleeping) but no Gleam SessionStatus type',
  'agent_sessions has CHECK constraint: status IN (alive, dead, sleeping). a_db_reader.gleam:33 queries WHERE status = ''alive'' with hardcoded string. No SessionStatus enum in Gleam. The status values are used as magic strings throughout the codebase.',
  'a_db_reader.gleam:33 SQL: ''WHERE status = ''alive'' ''. DB: agent_sessions_status_check CHECK (status IN (''alive'',''dead'',''sleeping'')).',
  'No type safety for session status. Hardcoded string comparisons can have typos. Cannot pattern match on status in Gleam. If new status values are added to CHECK constraint, Gleam code won''t know about them.'
);

-- =====================================================================
-- #329: activity_log.activity has 39 implicit enum values with no Gleam type
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 329, 'low', 'type_gap', 'monitor.gleam',
  'activity_log.activity has 39 implicit enum values — largest untyped enum in the system',
  'activity_log.activity has 39 distinct values in production data. No CHECK constraint. monitor.gleam:77 inserts with hardcoded ''model_used''. No ActivityType enum. This is the largest implicit enum in the system. Values include tool names (psypi-commit, psypi-issues, etc.), file operations (bash, edit, read, write), and system activities.',
  'monitor.gleam:77 SQL: ''INSERT INTO activity_log (agent_id, activity, context) VALUES ($1, ''model_used'', $3)''. DB: SELECT DISTINCT activity FROM activity_log returns 39 values.',
  'Low severity because activity_log is write-heavy and rarely read with type safety needs. However, the 39 untyped values represent a maintenance burden. New activities can be inserted with any string.'
);

-- =====================================================================
-- #330: provider_api_keys.status implicit enum with unique partial index
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 330, 'medium', 'type_gap', 'monitor.gleam',
  'provider_api_keys.status has implicit enum (in_use/not_used) with unique partial index but no Gleam type',
  'provider_api_keys.status has 2 values: in_use, not_use. No CHECK constraint but a unique partial index enforces only one row can be in_use: idx_provider_api_keys_in_use UNIQUE WHERE status = ''in_use''. monitor.gleam:104 sets ''not_used'', :113 sets ''in_use''. No ApiKeyStatus enum.',
  'monitor.gleam:104 SQL: ''UPDATE provider_api_keys SET status = ''not_used'' ''. monitor.gleam:113 SQL: ''UPDATE provider_api_keys SET status = ''in_use'' ''. DB: idx_provider_api_keys_in_use UNIQUE, btree ((true)) WHERE status = ''in_use''.',
  'The unique partial index is a critical business rule (only one API key active at a time) but it''s invisible to Gleam code. No type safety for status transitions. A typo like ''in-use'' instead of ''in_use'' would bypass the unique index.'
);

-- =====================================================================
-- #331: notifications.priority implicit enum — no CHECK, no Gleam type
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 331, 'medium', 'type_gap', 'monitor.gleam',
  'notifications.priority has implicit enum (critical/high/medium/low) but no CHECK constraint and no Gleam type',
  'notifications.priority defaults to ''medium''. Has 4 implicit values matching project_communications.priority CHECK constraint. But notifications table has NO CHECK constraint on priority. monitor.gleam:190-237 sorts by CASE WHEN priority = ''critical'' THEN 1 etc. No NotificationPriority enum. Any string can be inserted.',
  'monitor.gleam:237 SQL: ''INSERT INTO notifications (agent_id, priority, title, body) VALUES (...)''. monitor.gleam:190 CASE WHEN priority = ''critical'' THEN 1. DB: notifications has no CHECK on priority. DB: project_communications has CHECK(low,normal,high,critical).',
  'Inconsistency: project_communications.priority has CHECK constraint but notifications.priority does not. Same logical enum (priority levels) enforced differently across tables. Inserting invalid priority into notifications succeeds silently.'
);

-- =====================================================================
-- #332: learning_insights.insight_type implicit enum
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 332, 'low', 'type_gap', 'areflect.gleam',
  'learning_insights.insight_type has implicit enum (pattern/architecture) — hardcoded in areflect.gleam',
  'learning_insights.insight_type varchar(50) NOT NULL. 2 values in data: pattern, architecture. areflect.gleam:186 hardcodes ''pattern'' in INSERT. No InsightType enum. No CHECK constraint.',
  'areflect.gleam:186 SQL: ''INSERT INTO learning_insights (insight_type, title, content, confidence) VALUES (''pattern'', $1, $2, 0.8)''. DB: SELECT DISTINCT insight_type FROM learning_insights returns pattern, architecture.',
  'Low severity because areflect only writes ''pattern''. But the architecture value exists in data from other sources. No type safety for insight type classification.'
);

-- =====================================================================
-- #333: memory.source implicit enum
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 333, 'low', 'type_gap', 'learning.gleam',
  'memory.source has implicit enum (learn/areflect/traenupi) — hardcoded in learning.gleam',
  'memory.source has 3 values in data: learn, areflect, traenupi. learning.gleam:28 hardcodes ''learn'' in INSERT. No MemorySource enum. No CHECK constraint.',
  'learning.gleam:28 SQL: ''INSERT INTO memory (content, tags, source, importance, agent_id) VALUES ($1, $2, ''learn'', $3, $4)''. DB: SELECT DISTINCT source FROM memory returns learn, areflect, traenupi.',
  'Low severity. The source column is used for filtering but not type-safe. New sources can be added without code changes.'
);

-- =====================================================================
-- #334: agent_identities.agent_type implicit enum — inconsistent with agent_sessions
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 334, 'medium', 'type_gap', 'agents.gleam',
  'agent_identities.agent_type has implicit enum (self/autonomic/somatic) — inconsistent with agent_sessions.agent_type',
  'agent_identities.agent_type varchar(50) defaults to ''self''. agents.gleam:57 reads it as String. agent_sessions.agent_type is a separate column with likely different values (autonomic/somatic). No shared AgentType enum. The same concept (agent type) is represented differently across tables.',
  'agents.gleam:57 SQL: ''SELECT id, agent_type, created_at::text FROM agent_identities''. DB: agent_identities.agent_type default is ''self''. DB: agent_sessions.agent_type NOT NULL.',
  'Inconsistent agent type representation. agent_identities uses ''self'' as default while agent_sessions likely uses ''autonomic''/''somatic''. No shared type definition. Code that joins these tables on agent_type would get wrong results.'
);

-- =====================================================================
-- #335: inter_reviews enum columns read as String — no type enforcement
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 335, 'medium', 'type_gap', 'inter_review.gleam',
  'inter_reviews has 3 CHECK-constrained enum columns (status, response_status, reviewer_type) all read as String in Gleam',
  'inter_reviews has 3 columns with CHECK constraints: status (pending/in_progress/completed/failed/superseded), response_status (pending/accepted/rejected/partial/superseded), reviewer_type (ai/human). inter_review.gleam reads ALL of these as plain String. is_review_complete() compares against hardcoded "completed" string. No InterReviewStatus, ResponseStatus, or ReviewerType enum.',
  'inter_review.gleam:148 SQL: ''SELECT id, task_id, status, summary, overall_score, requested_at FROM inter_reviews''. inter_review.gleam:250 SQL: ''SELECT status FROM inter_reviews''. DB: inter_reviews_status_check, inter_reviews_response_status_check, inter_reviews_reviewer_type_check.',
  'No type safety for review status transitions. Code could compare status against "COMPLETE" (typo) and get silent false instead of compile error. The 5-value status enum is business-critical for the commit workflow (tool_commit.gleam checks overall_score).'
);

-- =====================================================================
-- #336: psypi_config.key implicit enum — no type safety for config keys
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 336, 'low', 'type_gap', 'psypi_config.gleam',
  'psypi_config.key has implicit enum values — typo in key name causes silent NotFound',
  'psypi_config.key is the PRIMARY KEY. Known values: monitor_debounce_ms, last_wakeup. psypi_config.gleam:28 reads by key string. get_debounce_ms() calls get("monitor_debounce_ms"). A typo like "monitor_debounc_ms" returns NotFound error instead of compile-time error. No ConfigKey type.',
  'psypi_config.gleam:28 SQL: ''SELECT value FROM psypi_config WHERE key = $1''. psypi_config.gleam:67 get_debounce_ms() calls get_int("monitor_debounce_ms"). DB: SELECT key FROM psypi_config returns monitor_debounce_ms, last_wakeup.',
  'Low severity because psypi_config is a simple key-value store. But the lack of type safety means config key typos are runtime errors, not compile errors. Adding a ConfigKey enum would catch these at compile time.'
);

-- =====================================================================
-- #337: project.gleam ON CONFLICT (path) fails — no unique constraint
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 337, 'high', 'sql_error', 'project.gleam',
  'project.gleam insert_project() uses ON CONFLICT (path) but projects.path has no unique constraint — SQL error on conflict',
  'project.gleam:252-258 insert_project() uses: INSERT INTO projects (name, path, status) VALUES (...) ON CONFLICT (path) DO UPDATE SET last_seen = NOW(). But projects.path has NO unique constraint, only a btree index. ON CONFLICT requires a unique or exclusion constraint. Verified: test INSERT fails with ERROR: there is no unique or exclusion constraint matching the ON CONFLICT specification.',
  'project.gleam:252-258 SQL with ON CONFLICT (path). DB: \\d projects shows idx_projects_path is btree index, NOT unique. psql test: INSERT...ON CONFLICT(path) fails with constraint error.',
  'If two projects are created with the same path, the INSERT succeeds (duplicate path rows) instead of upserting. The ON CONFLICT clause is dead code that never triggers. If a unique constraint is later added to path, the ON CONFLICT would start working, potentially changing behavior unexpectedly.'
);

-- =====================================================================
-- #338: areflect.gleam INSERT into issues without project_id
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 338, 'medium', 'data_integrity', 'areflect.gleam',
  'areflect.gleam save_issue() inserts into issues without project_id — creates orphan issues',
  'areflect.gleam:224 SQL: INSERT INTO issues (title, description, severity, created_by) VALUES ($1, $2, ''medium'', $3). The issues table has a project_id column (uuid, nullable). This INSERT does not set project_id, creating issues with NULL project_id. These issues are invisible to project-scoped queries and violate the data model intent.',
  'areflect.gleam:224 SQL omits project_id. DB: issues.project_id is uuid nullable. issue_db.gleam:88 includes project_id in INSERT.',
  'Issues created by areflect have no project association. They appear in global queries but not in project-scoped views. This is inconsistent with issue_db.gleam which always sets project_id.'
);

-- =====================================================================
-- #339: areflect.gleam INSERT into tasks without project_id
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 339, 'medium', 'data_integrity', 'areflect.gleam',
  'areflect.gleam save_task() inserts into tasks without project_id — creates orphan tasks',
  'areflect.gleam:262 SQL: INSERT INTO tasks (title, description, priority, created_by) VALUES ($1, $2, 5, $3). The tasks table has a project_id column (uuid, nullable). This INSERT does not set project_id, creating tasks with NULL project_id. These tasks are invisible to project-scoped queries.',
  'areflect.gleam:262 SQL omits project_id. DB: tasks.project_id is uuid nullable. task.gleam:125 includes project_id in INSERT.',
  'Tasks created by areflect have no project association. They appear in global queries but not in project-scoped views. This is inconsistent with task.gleam which accepts project_id parameter.'
);

-- =====================================================================
-- #340: broadcast.gleam send() inserts with hardcoded metadata JSON
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 340, 'low', 'data_quality', 'broadcast.gleam',
  'broadcast.gleam send() inserts metadata as hardcoded JSON string — not type-safe',
  'broadcast.gleam:170 SQL: INSERT INTO project_communications (..., metadata) VALUES (..., $5) where $5 is dynamic.string(''{\"sent_at\": \"now\"}''). The metadata column is jsonb. The JSON is constructed via string concatenation, not using gleam/json. This is fragile and could produce invalid JSON.',
  'broadcast.gleam:170 dynamic.string(''{\"sent_at\": \"now\"}''). DB: project_communications.metadata is jsonb. inter_review.gleam:175 uses json.object() for jsonb.',
  'Low severity but inconsistent. inter_review.gleam correctly uses gleam/json for jsonb construction. broadcast.gleam uses string concatenation. If metadata values contain special characters (quotes, backslashes), the JSON will be malformed.'
);

-- =====================================================================
-- #341: agent_identity.gleam EnrichedIdentity uses String for all enum fields
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 341, 'medium', 'type_gap', 'agent_identity.gleam',
  'EnrichedIdentity struct uses String for trigger_type, drive_mode, activation — should be enum types',
  'agent_identity.gleam:16-30 defines EnrichedIdentity with trigger_type: String, drive_mode: String, activation: String. These are implicit enums from agent_souls. Using String means no pattern matching, no exhaustiveness checking, and no compile-time guarantee of valid values.',
  'agent_identity.gleam:16-30 EnrichedIdentity type. agent_identity.gleam:120 SQL reads trigger_type, drive_mode, activation as String.',
  'No type safety for agent identity fields. Code that branches on trigger_type or drive_mode uses string comparison instead of pattern matching. Adding new trigger types or drive modes won''t cause compile errors in consumers.'
);

-- =====================================================================
-- #342: inter_reviews has 33 DB columns but Gleam Review type has 6 fields
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 342, 'high', 'struct_gap', 'inter_review.gleam',
  'inter_reviews has 33 DB columns but Gleam Review type only maps 6 fields — 27 columns inaccessible',
  'inter_reviews has 33 columns including: commit_hash, branch, requester_id, reviewer_type, review_round, findings (jsonb), suggestions (jsonb), issues (jsonb), praise (jsonb), code_quality_score, test_coverage_score, documentation_score, response, response_at, accepted_suggestions, started_at, completed_at, review_context, issue_id, reviewer_id, response_status, raw_response, session_id, reviewed_by, leverage_ratio, rework_count, effort_minutes. Gleam Review type only has: id, task_id, status, summary, overall_score, requested_at. 27 columns are never read by Gleam code.',
  'inter_review.gleam:58-65 Review type with 6 fields. DB: \\d inter_reviews shows 33 columns. inter_review.gleam:148 SQL: ''SELECT id, task_id, status, summary, overall_score, requested_at FROM inter_reviews''.',
  'Critical business data is invisible to Gleam: findings, suggestions, code quality scores, reviewer info, response status, leverage ratio. The commit workflow (tool_commit.gleam) only checks overall_score but cannot access detailed review findings. Monitor AI cannot track review quality metrics.'
);

-- =====================================================================
-- #343: a_db_reader.gleam reads issues with wrong status filter
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 343, 'medium', 'logic_error', 'a_db_reader.gleam',
  'a_db_reader.gleam filters issues with NOT IN (''resolved'',''closed'') but DB has no ''closed'' status',
  'a_db_reader.gleam:142 SQL: FROM issues WHERE status NOT IN (''resolved'',''closed''). The issues.status CHECK constraint allows: open, acknowledged, in_progress, resolved, wont_fix, duplicate. There is no ''closed'' value in the CHECK constraint. The filter includes ''closed'' which is a no-op (never matches) but reveals confusion about the status values.',
  'a_db_reader.gleam:142 SQL: ''WHERE status NOT IN (''''resolved'''',''''closed'''')''. DB: issues_status_check allows open/acknowledged/in_progress/resolved/wont_fix/duplicate.',
  'The filter is partially correct (excludes resolved) but the ''closed'' exclusion is dead code. More importantly, this means wont_fix and duplicate issues ARE included in the "open issues" list, which may not be the intended behavior. If the intent was to show only actionable issues, wont_fix should also be excluded.'
);

-- =====================================================================
-- #344: monitor_ai.gleam get_model_stats() uses non-existent completed_at column
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 344, 'high', 'sql_error', 'monitor_ai.gleam',
  'monitor_ai.gleam get_model_stats() references completed_at column which may not be populated',
  'monitor_ai.gleam:275 SQL: AVG(EXTRACT(MILLISECONDS FROM (completed_at - requested_at))). The inter_reviews table does have a completed_at column, but it is only set when status transitions to ''completed''. For pending/in_progress reviews, completed_at is NULL. AVG of NULL values is skipped by PostgreSQL, so this may not cause an error but produces misleading averages (only completed reviews counted).',
  'monitor_ai.gleam:275 SQL with completed_at. DB: inter_reviews.completed_at is timestamptz nullable. Only set when review completes.',
  'The average response time metric only counts completed reviews, excluding failed/superseded ones. This may be intentional but is not documented. If all recent reviews are pending, AVG returns 0 (via COALESCE), giving false impression of fast response times.'
);

-- =====================================================================
-- Summary update
-- =====================================================================
UPDATE system_reviews 
SET status = 'in_progress',
    description = description || E'\n\nPhase 5 (2026-05-29): Comprehensive type inventory audit. Added 10 missing tables to type_inventory (agent_jobs, agent_souls, agent_sessions, psypi_config, activity_log, provider_api_keys, notifications, learning_insights, memory, agent_identities). Found 23 new findings (#322-#344) including 2 CRITICAL SQL errors in broadcast.stats(), phantom MeetingStatus.Pending variant, and 27 missing inter_reviews fields. Updated 3 previously-mismatched entries (TaskStatus, SkillSource, IssueStatus) to ok after working tree fixes.'
WHERE id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837';
