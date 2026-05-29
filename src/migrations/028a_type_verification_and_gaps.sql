-- 028a_type_verification_and_gaps.sql
-- Comprehensive type verification: all Gleam types vs DB CHECK constraints
-- Plus new findings for broadcast.gleam SQL errors and missing types
-- Previous finding max: 354

-- ============================================================
-- PART 1: Update type_inventory to reflect verified uncommitted changes
-- ============================================================

-- meeting.gleam: Pending variant removed (was phantom), now matches DB CHECK
UPDATE type_inventory
SET gap_status = 'ok',
    gleam_variants = ARRAY['Active','Completed','Cancelled'],
    gap_detail = NULL
WHERE table_name = 'meetings' AND column_name = 'status';

-- issue_types.gleam: IssueStatus expanded to match DB CHECK
UPDATE type_inventory
SET gap_status = 'ok',
    gleam_variants = ARRAY['Open','Acknowledged','InProgress','Resolved','WontFix','Duplicate'],
    gap_detail = NULL
WHERE table_name = 'issues' AND column_name = 'status';

-- issue_types.gleam: IssueType added Proposal to match DB CHECK
UPDATE type_inventory
SET gap_status = 'ok',
    gleam_variants = ARRAY['Bug','Inconsistency','Feature','Improvement','Question','Debt','Proposal'],
    gap_detail = NULL
WHERE table_name = 'issues' AND column_name = 'type';

-- skill.gleam: SkillSource added AiBuilt to match DB CHECK
UPDATE type_inventory
SET gap_status = 'ok',
    gleam_variants = ARRAY['Clawhub','Local','Generated','Imported','AiBuilt'],
    gap_detail = NULL
WHERE table_name = 'skills' AND column_name = 'source';

-- task.gleam: TaskStatus added FakeComplete to match DB CHECK
UPDATE type_inventory
SET gap_status = 'ok',
    gleam_variants = ARRAY['Pending','Running','Completed','Failed','FakeComplete'],
    gap_detail = NULL
WHERE table_name = 'tasks' AND column_name = 'status';

-- ============================================================
-- PART 2: Add missing type_inventory rows for columns with CHECK constraints
-- that are used by psypi Gleam code but were not in type_inventory
-- ============================================================

-- inter_reviews.status: 5 values, used as raw String in inter_review.gleam:79
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES (
  'inter_reviews', 'status',
  ARRAY['pending','in_progress','completed','failed','superseded'],
  NULL, NULL,
  'no_gleam_type',
  'inter_reviews.status has CHECK with 5 values. inter_review.gleam:79 Review struct has status: String. No InterReviewStatus enum. list_reviews() takes status as Option(String) param with no validation. Any typo passes silently.',
  true
) ON CONFLICT (table_name, column_name) DO UPDATE SET
  db_values = EXCLUDED.db_values,
  gap_status = EXCLUDED.gap_status,
  gap_detail = EXCLUDED.gap_detail,
  used_by_psypi = EXCLUDED.used_by_psypi;

-- inter_reviews.response_status: 5 values, not read by psypi but table is used
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES (
  'inter_reviews', 'response_status',
  ARRAY['pending','accepted','rejected','partial','superseded'],
  NULL, NULL,
  'no_gleam_type',
  'inter_reviews.response_status has CHECK with 5 values. Not directly read by psypi Gleam code but column exists in table used by inter_review module. No ResponseStatus enum.',
  true
) ON CONFLICT (table_name, column_name) DO UPDATE SET
  db_values = EXCLUDED.db_values,
  gap_status = EXCLUDED.gap_status,
  gap_detail = EXCLUDED.gap_detail,
  used_by_psypi = EXCLUDED.used_by_psypi;

-- inter_reviews.reviewer_type: 2 values
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES (
  'inter_reviews', 'reviewer_type',
  ARRAY['ai','human'],
  NULL, NULL,
  'no_gleam_type',
  'inter_reviews.reviewer_type has CHECK with 2 values. Not read by psypi Gleam code. No ReviewerType enum.',
  true
) ON CONFLICT (table_name, column_name) DO UPDATE SET
  db_values = EXCLUDED.db_values,
  gap_status = EXCLUDED.gap_status,
  gap_detail = EXCLUDED.gap_detail,
  used_by_psypi = EXCLUDED.used_by_psypi;

-- dead_letter_queue.error_category: 8 values, CHECK constraint
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES (
  'dead_letter_queue', 'error_category',
  ARRAY['NETWORK','AUTH','TIMEOUT','SERVER','TRANSPORT','LOGIC','RESOURCE','UNKNOWN'],
  NULL, NULL,
  'no_gleam_type',
  'dead_letter_queue.error_category has CHECK with 8 values (UPPER_CASE). Same values as tasks.error_category. No ErrorCategory enum. Could share type with tasks.',
  true
) ON CONFLICT (table_name, column_name) DO UPDATE SET
  db_values = EXCLUDED.db_values,
  gap_status = EXCLUDED.gap_status,
  gap_detail = EXCLUDED.gap_detail,
  used_by_psypi = EXCLUDED.used_by_psypi;

-- dead_letter_queue.review_status: 4 values, CHECK constraint
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES (
  'dead_letter_queue', 'review_status',
  ARRAY['pending','reviewed','resolved','ignored'],
  NULL, NULL,
  'no_gleam_type',
  'dead_letter_queue.review_status has CHECK with 4 values. No DlqReviewStatus enum.',
  true
) ON CONFLICT (table_name, column_name) DO UPDATE SET
  db_values = EXCLUDED.db_values,
  gap_status = EXCLUDED.gap_status,
  gap_detail = EXCLUDED.gap_detail,
  used_by_psypi = EXCLUDED.used_by_psypi;

-- failure_alerts.alert_type: 5 values, CHECK constraint
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES (
  'failure_alerts', 'alert_type',
  ARRAY['repeated_failure','stuck_task','dlq_threshold','watchdog_kill','consecutive_failures'],
  NULL, NULL,
  'no_gleam_type',
  'failure_alerts.alert_type has CHECK with 5 values. No AlertType enum.',
  true
) ON CONFLICT (table_name, column_name) DO UPDATE SET
  db_values = EXCLUDED.db_values,
  gap_status = EXCLUDED.gap_status,
  gap_detail = EXCLUDED.gap_detail,
  used_by_psypi = EXCLUDED.used_by_psypi;

-- system_directives.priority: 4 values, CHECK constraint — PromptPriority exists
UPDATE type_inventory
SET gap_status = 'ok',
    gleam_type_name = 'PromptPriority',
    gleam_variants = ARRAY['Critical','High','Medium','Low'],
    gap_detail = NULL
WHERE table_name = 'system_directives' AND column_name = 'priority';

-- agent_sessions.status: 3 values, CHECK constraint
UPDATE type_inventory
SET db_values = ARRAY['alive','dead','sleeping'],
    gap_detail = 'agent_sessions.status has CHECK with 3 values (alive/dead/sleeping). No AgentSessionStatus enum. Not read by psypi Gleam code directly but table is referenced.'
WHERE table_name = 'agent_sessions' AND column_name = 'status';

-- ============================================================
-- PART 3: New review findings
-- ============================================================

-- Finding #355: broadcast.gleam stats() references non-existent status column
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  355, 'critical', 'sql_error', 'broadcast',
  'broadcast.gleam stats() references non-existent status column — guaranteed runtime failure',
  'The stats() function in broadcast.gleam contains SQL: COUNT(*) FILTER (WHERE status = ''sent'') as sent_count. The project_communications table has no status column. This query will fail with "column ''status'' does not exist" on every call. The BroadcastStatus type (Pending/Sent/Failed/Cancelled) maps to a phantom column that does not exist in the database.',
  'broadcast.gleam:258-262: SELECT COUNT(*) FILTER (WHERE status = ''sent'') as sent_count FROM project_communications WHERE from_ai = $1 AND message_type = ''broadcast''. Verified: psql returns ERROR: column "status" does not exist. The list()/get_recent() functions use ''sent'' as status (hardcoded alias), but stats() tries to filter on an actual status column.',
  'open'
);

-- Finding #356: broadcast.gleam stats() priority >= 2 is invalid integer comparison on text column
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  356, 'critical', 'sql_error', 'broadcast',
  'broadcast.gleam stats() uses priority >= 2 — invalid integer comparison on text column',
  'The stats() function contains SQL: COUNT(*) FILTER (WHERE priority >= 2) as high_priority_count. The priority column is text with CHECK constraint (low/normal/high/critical). Comparing text to integer fails with "operator does not exist: text >= integer". Correct approach: WHERE priority IN (''high'', ''critical'').',
  'broadcast.gleam:260: COUNT(*) FILTER (WHERE priority >= 2) as high_priority_count. Verified: psql returns ERROR: operator does not exist: text >= integer. The priority column is varchar with CHECK ((priority = ANY (ARRAY[''low'', ''normal'', ''high'', ''critical'']))).',
  'open'
);

-- Finding #357: BroadcastStatus type is phantom — maps to non-existent column
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  357, 'high', 'type_mismatch', 'broadcast',
  'BroadcastStatus type maps to phantom status column — type has no DB counterpart',
  'The BroadcastStatus enum (Pending/Sent/Failed/Cancelled) exists in Gleam but project_communications has no status column. The actual column is message_type with 8 values (task/review/feedback/status/question/answer/notification/broadcast). list()/get_recent() hardcode ''sent'' as status alias. send() never sets status. The type is entirely phantom — it cannot be read from or written to the database.',
  'broadcast.gleam:15-20 defines BroadcastStatus with 4 variants. project_communications has no status column. broadcast_row_decoder() decodes "status" field which only exists as SQL alias ''sent'' as status in list()/get_recent(). send() INSERT has no status column. stats() fails because it tries to use the non-existent column.',
  'open'
);

-- Finding #358: inter_reviews.status read as raw String — no InterReviewStatus enum
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  358, 'medium', 'missing_type', 'inter_review',
  'inter_reviews.status read as raw String — no InterReviewStatus enum for 5-value CHECK constraint',
  'inter_reviews.status has CHECK constraint with 5 values (pending/in_progress/completed/failed/superseded). inter_review.gleam reads it as plain String in Review struct. list_reviews() takes status as Option(String) with no validation. Any typo in status filter passes silently to SQL.',
  'inter_review.gleam:47 Review struct has status: String. inter_review.gleam:265 list_reviews(status: Option(String)). DB CHECK: CHECK ((status = ANY (ARRAY[''pending'', ''in_progress'', ''completed'', ''failed'', ''superseded'']))).',
  'open'
);

-- Finding #359: inter_reviews.response_status has CHECK but no Gleam type
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  359, 'low', 'missing_type', 'inter_review',
  'inter_reviews.response_status has CHECK with 5 values but no Gleam type',
  'inter_reviews.response_status has CHECK constraint (pending/accepted/rejected/partial/superseded). Not read by psypi Gleam code. If future code reads this column, it will lack type safety.',
  'DB CHECK: CHECK ((response_status = ANY (ARRAY[''pending'', ''accepted'', ''rejected'', ''partial'', ''superseded'']))). Not referenced in any Gleam SQL query.',
  'open'
);

-- Finding #360: agent_souls columns read as raw String — no enums for trigger_type, drive_mode, role, activation
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  360, 'medium', 'missing_type', 'agent_identity',
  'agent_souls columns (trigger_type, drive_mode, role, activation) read as raw String — no enum types',
  'agent_identity.gleam fetches 7 columns from agent_souls, 4 of which are implicit enums: trigger_type (event/prompt), drive_mode (autonomous/reactive), role (AutonomicBot/SomaticBot), activation (2 values). All decoded as String in soul_decoder(). EnrichedIdentity stores them as String. No compile-time safety for these enum-like values.',
  'agent_identity.gleam:97-103 soul_decoder() decodes all as decode.string. agent_identity.gleam:19-32 EnrichedIdentity has trigger_type: String, drive_mode: String, etc. DB data: trigger_type={event,prompt}, drive_mode={autonomous,reactive}, role={AutonomicBot,SomaticBot}, activation has 2 distinct values.',
  'open'
);

-- Finding #361: event_hooks.gleam reads hook_status and event_name as raw String
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  361, 'medium', 'missing_type', 'event_hooks',
  'event_hooks.gleam reads hook_status and event_name as raw String — no enum types for CHECK/implicit-enum columns',
  'psypi_event_hooks.hook_status has CHECK constraint with 4 values (active/inactive/error/experimental). event_name has 30 distinct values used as implicit enum. event_hooks.gleam reads both as String. set_hook_status() takes status as String param with no validation. format_hooks_summary() uses hardcoded strings.',
  'event_hooks.gleam:23 EventHook has hook_status: String, event_name: String. DB CHECK: CHECK ((hook_status = ANY (ARRAY[''active'', ''inactive'', ''error'', ''experimental'']))). event_name has 30 distinct values including tool_call, agent_start, session_start, etc.',
  'open'
);

-- Finding #362: memory.source is implicit enum (3 values) read as raw String
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  362, 'low', 'missing_type', 'memory',
  'memory.source is implicit enum (learn/areflect/traenupi) read as raw String — no MemorySource enum',
  'memory.source has 3 distinct values (learn/areflect/traenupi). learning.gleam:28 hardcodes ''learn'' in INSERT. areflect.gleam hardcodes ''areflect''. No MemorySource enum. If a typo occurs in source value, queries filtering by source would silently return no results.',
  'learning.gleam:28 INSERT INTO memory ... VALUES (... ''learn'' ...). memory.gleam:45 source: String in Memory struct. DB data: source IN (learn, areflect, traenupi).',
  'open'
);

-- Finding #363: meeting_opinions.position has CHECK but no Gleam type
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  363, 'medium', 'missing_type', 'meeting',
  'meeting_opinions.position has CHECK (support/oppose/neutral) but no MeetingPosition enum',
  'meeting_opinions.position has CHECK constraint with 3 values (support/oppose/neutral). meeting.gleam Opinion struct has perspective: String (not position). The position column is not decoded by meeting.gleam at all — it is missing from the SELECT. This means opinion position data is silently discarded.',
  'meeting.gleam:27 Opinion struct has no position field. DB CHECK: CHECK ((position = ANY (ARRAY[''support'', ''oppose'', ''neutral'']))). meeting_opinions table has position column but meeting.gleam SELECT does not include it.',
  'open'
);

-- Finding #364: provider_api_keys.status has implicit enum — no ApiKeyStatus type
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  364, 'low', 'missing_type', 'monitor',
  'provider_api_keys.status (in_use/not_used) has no ApiKeyStatus enum — monitor.gleam hardcodes values',
  'provider_api_keys.status has 2 values (in_use/not_used). monitor.gleam:104 sets ''not_used'', :113 sets ''in_use''. Unique index WHERE status = ''in_use'' enforces single active key. No ApiKeyStatus enum. Typo in status value would break the unique index constraint silently.',
  'monitor.gleam:104 UPDATE provider_api_keys SET status = ''not_used''. monitor.gleam:113 UPDATE provider_api_keys SET status = ''in_use''. DB: unique index WHERE status = ''in_use''.',
  'open'
);

-- Finding #365: dead_letter_queue columns have CHECK constraints but no Gleam types
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  365, 'low', 'missing_type', 'monitor_ai',
  'dead_letter_queue.error_category and review_status have CHECK constraints but no Gleam types',
  'dead_letter_queue has 2 enum columns with CHECK constraints: error_category (8 UPPER_CASE values: NETWORK/AUTH/TIMEOUT/SERVER/TRANSPORT/LOGIC/RESOURCE/UNKNOWN) and review_status (4 values: pending/reviewed/resolved/ignored). No Gleam types. error_category shares values with tasks.error_category — could be shared type.',
  'DB CHECK: CHECK ((error_category = ANY (ARRAY[''NETWORK'', ''AUTH'', ''TIMEOUT'', ''SERVER'', ''TRANSPORT'', ''LOGIC'', ''RESOURCE'', ''UNKNOWN'']))). CHECK ((review_status = ANY (ARRAY[''pending'', ''reviewed'', ''resolved'', ''ignored'']))).',
  'open'
);

-- Finding #366: tasks.type has CHECK with 10 values but no TaskType enum
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  366, 'medium', 'missing_type', 'task',
  'tasks.type has CHECK with 10 values but no TaskType enum — used as raw String',
  'tasks.type has CHECK constraint with 10 values (analysis/implementation/documentation/bugfix/research/testing/deployment/maintenance/discussion/announcement). task.gleam Task struct has type_: String. No TaskType enum. Any typo in type value passes silently.',
  'DB CHECK: CHECK ((type = ANY (ARRAY[''analysis'', ''implementation'', ''documentation'', ''bugfix'', ''research'', ''testing'', ''deployment'', ''maintenance'', ''discussion'', ''announcement'']))). task.gleam:17 Task struct has type_: String.',
  'open'
);

-- Finding #367: tasks.category has CHECK with 4 values + NULL but no TaskCategory enum
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  367, 'low', 'missing_type', 'task',
  'tasks.category has CHECK with 4 values + NULL but no TaskCategory enum',
  'tasks.category has CHECK constraint allowing (security/performance/feature/bugfix/NULL). task.gleam Task struct has category: Option(String). No TaskCategory enum. Nullable enum should be Option(TaskCategory) for type safety.',
  'DB CHECK: CHECK ((category = ANY (ARRAY[''security'', ''performance'', ''feature'', ''bugfix'', NULL::text]))). task.gleam:17 Task struct has category: Option(String).',
  'open'
);

-- Finding #368: tasks.error_category has CHECK with 8 UPPER_CASE values + NULL but no enum
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  368, 'low', 'missing_type', 'task',
  'tasks.error_category has CHECK with 8 UPPER_CASE values + NULL but no TaskErrorCategory enum',
  'tasks.error_category has CHECK constraint allowing (NETWORK/AUTH/TIMEOUT/SERVER/TRANSPORT/LOGIC/RESOURCE/UNKNOWN/NULL). These are UPPER_CASE, same as dead_letter_queue.error_category. No TaskErrorCategory enum. Could share type with dead_letter_queue.',
  'DB CHECK: CHECK ((error_category = ANY (ARRAY[''NETWORK'', ''AUTH'', ''TIMEOUT'', ''SERVER'', ''TRANSPORT'', ''LOGIC'', ''RESOURCE'', ''UNKNOWN'', NULL::text]))). task.gleam:17 Task struct has error_category: Option(String).',
  'open'
);

-- Finding #369: agent_jobs.category has 13 implicit enum values but no type
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  369, 'medium', 'missing_type', 'agent_identity',
  'agent_jobs.category has 13 implicit enum values but no JobCategory type',
  'agent_jobs.category has 13 distinct values (behavior/business/continue/definition/learning/maintenance/new_task/quality/research/review/safety/suggestion/unblock). agent_identity.gleam:154 reads it as String in job_row_decoder(). No CHECK constraint — any value is accepted by DB. No JobCategory enum.',
  'agent_identity.gleam:154 job_row_decoder() decodes category as decode.string. DB data: 13 distinct values. No CHECK constraint on this column.',
  'open'
);

-- Finding #370: psypi_config.key has 4 implicit enum values — no ConfigKey type
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  370, 'medium', 'missing_type', 'psypi_config',
  'psypi_config.key has 4 implicit enum values — no ConfigKey type, typo causes silent NotFound',
  'psypi_config.key has 4 distinct values (idle_since/last_wakeup/monitor_debounce_ms/monitor_enabled). psypi_config.gleam reads by key string. No ConfigKey type. A typo in key name causes silent NotFound error instead of compile-time error.',
  'DB data: key IN (idle_since, last_wakeup, monitor_debounce_ms, monitor_enabled). psypi_config.gleam reads by key string with no type validation.',
  'open'
);

-- Finding #371: notification.priority has no CHECK constraint — monitor.gleam uses CASE WHEN
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  371, 'low', 'missing_type', 'monitor',
  'notifications.priority has no CHECK constraint — monitor.gleam uses CASE WHEN for sorting',
  'notifications.priority defaults to ''medium'' but has no CHECK constraint. monitor.gleam:190-237 uses CASE WHEN for sorting (critical=1, high=2, medium=3, else=4). No NotificationPriority enum. Values should match project_communications.priority CHECK but no DB enforcement. Any invalid priority value gets sorted as 4.',
  'monitor.gleam:190-237 CASE priority WHEN ''critical'' THEN 1 WHEN ''high'' THEN 2 WHEN ''medium'' THEN 3 ELSE 4 END. notifications table has no CHECK on priority column.',
  'open'
);

-- Finding #372: agents.gleam reads agent_type as raw String — no AgentType enum
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  372, 'low', 'missing_type', 'agents',
  'agents.gleam reads agent_identities.agent_type as raw String — no AgentType enum',
  'agent_identities.agent_type currently has only 1 value (''self'') but is an implicit enum. agents.gleam:8 Agent struct has agent_type: String. No AgentType enum. If new agent types are added, no compile-time safety.',
  'agents.gleam:8 Agent struct has agent_type: String. DB data: agent_type = {self}. agent_identities.id_prefix = {S, empty string}.',
  'open'
);

-- Finding #373: activity_log.activity has 39 distinct values — no ActivityType enum
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  373, 'low', 'missing_type', 'monitor',
  'activity_log.activity has 39 distinct values — no ActivityType enum, monitor.gleam hardcodes ''model_used''',
  'activity_log.activity has 39 distinct values including tool names (psypi-commit, psypi-issues, etc.), actions (bash, edit, read, write), and system events (model_used). monitor.gleam:67 hardcodes ''model_used''. No CHECK constraint. No ActivityType enum. Large implicit enum makes type definition valuable for catching typos.',
  'monitor.gleam:67 INSERT INTO activity_log ... VALUES (... ''model_used'' ...). DB data: 39 distinct activity values. No CHECK constraint.',
  'open'
);

-- ============================================================
-- PART 4: Verified correct types — document for completeness
-- ============================================================

-- These types are verified correct against DB CHECK constraints:
-- IssueSeverity ↔ issues.severity (5 values) ✅
-- IssueStatus ↔ issues.status (6 values) ✅ (uncommitted change)
-- IssueType ↔ issues.issue_type (7 values) ✅ (uncommitted change)
-- MeetingStatus ↔ meetings.status (3 values) ✅ (uncommitted change, Pending removed)
-- SkillSource ↔ skills.source (5 values) ✅ (uncommitted change, AiBuilt added)
-- SkillStatus ↔ skills.status (6 values) ✅
-- TaskStatus ↔ tasks.status (5 values) ✅ (uncommitted change, FakeComplete added)
-- ProjectStatus ↔ projects.status (3 values) ✅
-- BroadcastPriority ↔ project_communications.priority (4 values) ✅
-- ReviewType ↔ system_reviews.review_type (8 values) ✅
-- ReviewStatus ↔ system_reviews.status (5 values) ✅
-- ReviewMethodology ↔ system_reviews.methodology (5 values) ✅
-- ReviewScope ↔ system_reviews.scope (3 values) ✅
-- FollowUpStatus ↔ system_reviews.follow_up_status (3 values) ✅
-- FindingSeverity ↔ review_findings.severity (5 values) ✅
-- FindingStatus ↔ review_findings.status (7 values) ✅
-- PromptPriority ↔ system_directives.priority (4 values) ✅

-- Insert verification record
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  374, 'cosmetic', 'verification', 'system_review',
  'Type verification complete: 17 Gleam types verified correct against DB CHECK constraints',
  'All 17 Gleam enum types that map to DB CHECK constraints have been verified as correct matches. This includes uncommitted changes in issue_types.gleam (IssueStatus +3 variants, IssueType +1 variant), meeting.gleam (Pending removed), skill.gleam (AiBuilt added), and task.gleam (FakeComplete added). The only mismatch is BroadcastStatus which maps to a phantom status column.',
  'Verified against: issues(4 CHECKs), meetings(1), skills(6), tasks(7), projects(2), project_communications(2), system_reviews(5), review_findings(2), system_directives(1). Total: 30 CHECK constraints checked against 17 Gleam types.',
  'confirmed'
);
