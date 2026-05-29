-- 027w_missing_type_inventory.sql
-- Add 10 tables used in Gleam code but missing from type_inventory
-- Plus add missing inter_reviews enum columns

-- =====================================================================
-- 1. agent_jobs (used in agent_identity.gleam, a_db_reader.gleam, s_db_reader.gleam)
-- =====================================================================
-- No CHECK constraints, but category has 13 de facto enum values
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES (
  'agent_jobs', 'category',
  ARRAY['behavior','business','continue','definition','learning','maintenance','new_task','quality','research','review','safety','suggestion','unblock'],
  NULL, NULL,
  'no_gleam_type',
  'agent_jobs.category has 13 distinct values used as implicit enum. Gleam code reads it as plain String in agent_identity.gleam:154 and a_db_reader.gleam:199. No type safety. Any typo in category value goes undetected.',
  true
);

-- agent_jobs.is_active is boolean, no enum needed
-- agent_jobs.priority is integer, no enum needed

-- =====================================================================
-- 2. agent_souls (used in agent_identity.gleam, a_db_reader.gleam, s_db_reader.gleam, seed.gleam)
-- =====================================================================
-- No CHECK constraints, but 5 columns have implicit enum values
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES
  ('agent_souls', 'trigger_type', ARRAY['event','prompt'], NULL, NULL, 'no_gleam_type',
   'agent_souls.trigger_type has 2 values: event, prompt. Gleam reads as String in agent_identity.gleam:120. No TriggerType enum defined.',
   true),
  ('agent_souls', 'drive_mode', ARRAY['autonomous','reactive'], NULL, NULL, 'no_gleam_type',
   'agent_souls.drive_mode has 2 values: autonomous, reactive. Gleam reads as String. No DriveMode enum defined.',
   true),
  ('agent_souls', 'activation', ARRAY['agent_end','user prompt, system directive, A message','ctx.isIdle() == true'], NULL, NULL, 'no_gleam_type',
   'agent_souls.activation has 3 complex values. Gleam reads as String. No ActivationType enum. Values contain spaces and special chars - problematic for simple enum mapping.',
   true),
  ('agent_souls', 'id_prefix', ARRAY['A','S','G'], NULL, NULL, 'no_gleam_type',
   'agent_souls.id_prefix has 3 values: A, S, G. Used in WHERE clauses throughout. No AgentPrefix enum defined.',
   true),
  ('agent_souls', 'role', ARRAY['AutonomicBot','SomaticBot'], NULL, NULL, 'no_gleam_type',
   'agent_souls.role has 2 values (UNIQUE constraint). Gleam reads as String. No AgentRole enum defined.',
   true);

-- =====================================================================
-- 3. agent_sessions (used in a_db_reader.gleam)
-- =====================================================================
-- Has CHECK constraint: status IN ('alive','dead','sleeping')
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES (
  'agent_sessions', 'status',
  ARRAY['alive','dead','sleeping'],
  NULL, NULL,
  'no_gleam_type',
  'agent_sessions.status CHECK allows alive/dead/sleeping. a_db_reader.gleam:33 queries WHERE status = ''alive''. No SessionStatus enum. Hardcoded string comparison.',
  true
);

-- agent_sessions.agent_type has implicit enum
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES (
  'agent_sessions', 'agent_type',
  ARRAY['autonomic','somatic'],
  NULL, NULL,
  'no_gleam_type',
  'agent_sessions.agent_type varchar(50) NOT NULL. Implicit enum with likely values autonomic/somatic. No AgentType enum in Gleam.',
  true
);

-- =====================================================================
-- 4. psypi_config (used in psypi_config.gleam, seed.gleam)
-- =====================================================================
-- No enum columns - key/value store. But the 'key' column has implicit enum values.
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES (
  'psypi_config', 'key',
  ARRAY['monitor_debounce_ms','last_wakeup'],
  NULL, NULL,
  'no_gleam_type',
  'psypi_config.key has implicit enum values. psypi_config.gleam:28 reads by key string. No ConfigKey type. Typo in key name causes silent NotFound error instead of compile-time error.',
  true
);

-- =====================================================================
-- 5. activity_log (used in monitor.gleam, monitor_ai.gleam)
-- =====================================================================
-- No CHECK constraints, but 'activity' has 39 distinct values
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES (
  'activity_log', 'activity',
  ARRAY['bash','edit','find','get_agent_id','get_partner_id','get_resolved_identity','grep','ls','model_used','psypi-agents','psypi-areflect','psypi-commit','psypi-doc-list','psypi-doc-save','psypi-issue-add','psypi-issues','psypi-learn-save','psypi-meeting-get','psypi-meetings','psypi-memory-search','psypi-monitor-alerts','psypi-monitor-consult','psypi-monitor-health','psypi-monitor-id','psypi-monitor-status','psypi-monitor-suggest','psypi-my-id','psypi-skill-get','psypi-skill-list','psypi-skill-search','psypi-stats-show','psypi-task-add','psypi-tasks','read','test_tool_call','tool_call','web_fetch','web_search','write'],
  NULL, NULL,
  'no_gleam_type',
  'activity_log.activity has 39 distinct values. monitor.gleam:77 inserts with hardcoded string ''model_used''. No ActivityType enum. New activities can be inserted with any string - no validation.',
  true
);

-- activity_log.environment has implicit enum
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES (
  'activity_log', 'environment',
  ARRAY['development'],
  NULL, NULL,
  'no_gleam_type',
  'activity_log.environment defaults to ''development''. Implicit single-value enum. No Environment enum.',
  true
);

-- =====================================================================
-- 6. provider_api_keys (used in monitor.gleam)
-- =====================================================================
-- No CHECK constraints, but 'status' has implicit enum values
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES (
  'provider_api_keys', 'status',
  ARRAY['in_use','not_used'],
  NULL, NULL,
  'no_gleam_type',
  'provider_api_keys.status has 2 values: in_use, not_used. monitor.gleam:104 sets ''not_used'', :113 sets ''in_use''. Unique index WHERE status = ''in_use'' enforces single active key. No ApiKeyStatus enum.',
  true
);

-- =====================================================================
-- 7. notifications (used in monitor.gleam)
-- =====================================================================
-- No CHECK constraints, but 'priority' has implicit enum values
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES (
  'notifications', 'priority',
  ARRAY['critical','high','medium','low'],
  NULL, NULL,
  'no_gleam_type',
  'notifications.priority defaults to ''medium''. monitor.gleam:190-237 uses CASE WHEN for sorting. No NotificationPriority enum. Values must match project_communications.priority CHECK constraint but no DB enforcement.',
  true
);

-- =====================================================================
-- 8. learning_insights (used in areflect.gleam)
-- =====================================================================
-- Has CHECK constraint on priority (range 1-10), and insight_type implicit enum
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES
  ('learning_insights', 'insight_type',
   ARRAY['pattern','architecture'],
   NULL, NULL,
   'no_gleam_type',
   'learning_insights.insight_type varchar(50) NOT NULL. 2 values in data: pattern, architecture. areflect.gleam:186 hardcodes ''pattern''. No InsightType enum.',
   true),
  ('learning_insights', 'priority',
   ARRAY['1-10'],
   NULL, NULL,
   'range_constraint',
   'learning_insights.priority CHECK (1-10). areflect.gleam does not read this column. Default is 5. Range constraint only.',
   true);

-- =====================================================================
-- 9. memory (used in learning.gleam, monitor_ai.gleam)
-- =====================================================================
-- Has CHECK constraint on importance (range 1-10), and source implicit enum
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES
  ('memory', 'source',
   ARRAY['learn','areflect','traenupi'],
   NULL, NULL,
   'no_gleam_type',
   'memory.source has 3 values in data: learn, areflect, traenupi. learning.gleam:28 hardcodes ''learn''. No MemorySource enum.',
   true),
  ('memory', 'importance',
   ARRAY['1-10'],
   NULL, NULL,
   'range_constraint',
   'memory.importance CHECK (1-10). learning.gleam:28 passes importance as Int param. Range constraint only, no enum.',
   true);

-- =====================================================================
-- 10. agent_identities (used in agents.gleam)
-- =====================================================================
-- No CHECK constraints, but agent_type has implicit enum
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES
  ('agent_identities', 'agent_type',
   ARRAY['self','autonomic','somatic'],
   NULL, NULL,
   'no_gleam_type',
   'agent_identities.agent_type varchar(50) defaults to ''self''. agents.gleam:57 reads it as String. No AgentType enum. Inconsistent with agent_sessions.agent_type.',
   true),
  ('agent_identities', 'id_prefix',
   ARRAY['A','S','G'],
   NULL, NULL,
   'no_gleam_type',
   'agent_identities.id_prefix text. Same values as agent_souls.id_prefix. No shared AgentPrefix enum. Duplicated implicit enum across tables.',
   true);

-- =====================================================================
-- 11. code_versions (used in monitor_ai.gleam)
-- =====================================================================
-- No enum columns - all structural data
-- monitor_ai.gleam:117 reads file_path and saved_at. No type gaps.

-- =====================================================================
-- 12. agent_prefixes (used in seed.gleam)
-- =====================================================================
-- No enum columns - just prefix/name/description
-- seed.gleam:56 inserts A/S/G prefixes. No type gaps.

-- =====================================================================
-- 13. psypi_event_hooks (already in type_inventory with hook_status)
-- =====================================================================
-- Already covered. No additional enum columns.

-- =====================================================================
-- 14. inter_reviews - add missing enum columns
-- =====================================================================
-- inter_reviews already has status, response_status, reviewer_type in type_inventory
-- But Gleam code reads ALL of these as plain String, no type enforcement

-- Mark inter_reviews.status as having no Gleam type enforcement
UPDATE type_inventory
SET gap_status = 'no_gleam_type',
    gap_detail = 'inter_reviews.status CHECK allows pending/in_progress/completed/failed/superseded. inter_review.gleam:148 reads as String. No InterReviewStatus enum. is_review_complete() compares against hardcoded "completed" string.'
WHERE table_name = 'inter_reviews' AND column_name = 'status';

UPDATE type_inventory
SET gap_status = 'no_gleam_type',
    gap_detail = 'inter_reviews.response_status CHECK allows pending/accepted/rejected/partial/superseded. No Gleam type. Not read by any Gleam code currently.'
WHERE table_name = 'inter_reviews' AND column_name = 'response_status';

UPDATE type_inventory
SET gap_status = 'no_gleam_type',
    gap_detail = 'inter_reviews.reviewer_type CHECK allows ai/human. No Gleam type. Not read by any Gleam code currently.'
WHERE table_name = 'inter_reviews' AND column_name = 'reviewer_type';

-- =====================================================================
-- 15. Update existing entries for recently-fixed type gaps
-- =====================================================================
-- TaskStatus: FakeComplete was added in working tree
UPDATE type_inventory
SET gap_status = 'ok',
    gleam_variants = ARRAY['Pending','Running','Completed','Failed','FakeComplete'],
    gap_detail = NULL
WHERE table_name = 'tasks' AND column_name = 'status';

-- SkillSource: AiBuilt was added in working tree
UPDATE type_inventory
SET gap_status = 'ok',
    gleam_variants = ARRAY['Clawhub','Local','Generated','Imported','AiBuilt'],
    gap_detail = NULL
WHERE table_name = 'skills' AND column_name = 'source';

-- IssueStatus: Acknowledged, WontFix, Duplicate added; Closed removed
UPDATE type_inventory
SET gap_status = 'ok',
    gleam_variants = ARRAY['Open','Acknowledged','InProgress','Resolved','WontFix','Duplicate'],
    gap_detail = NULL
WHERE table_name = 'issues' AND column_name = 'status';

-- IssueType: Proposal added
UPDATE type_inventory
SET gap_status = 'ok',
    gleam_variants = ARRAY['Bug','Inconsistency','Feature','Improvement','Question','Debt','Proposal'],
    gap_detail = NULL
WHERE table_name = 'issues' AND column_name = 'type';

-- =====================================================================
-- 16. project_communications.message_type - BroadcastStatus is wrong mapping
-- =====================================================================
-- BroadcastStatus maps to a phantom 'status' column. The real column is message_type.
-- BroadcastPriority correctly maps to priority column.
UPDATE type_inventory
SET gap_status = 'wrong_type',
    gap_detail = 'BroadcastStatus type maps to phantom status column that does not exist in project_communications. The actual column is message_type with 8 values: task,review,feedback,status,question,answer,notification,broadcast. BroadcastStatus only has 4 variants (Pending/Sent/Failed/Cancelled) which do not match any column. broadcast.gleam stats() queries non-existent status column causing SQL error.'
WHERE table_name = 'project_communications' AND column_name = 'message_type';

-- =====================================================================
-- 17. meetings.status - check against latest Gleam code
-- =====================================================================
-- Need to verify if MeetingStatus exists and matches
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES (
  'meetings', 'status',
  ARRAY['active','completed','cancelled'],
  'MeetingStatus', ARRAY['Active','Completed','Cancelled'],
  'needs_verification',
  'meetings.status CHECK allows active/completed/cancelled. Need to verify if MeetingStatus type exists in meeting.gleam and string_to_status handles all 3 values.',
  true
)
ON CONFLICT DO NOTHING;
