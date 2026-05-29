-- 027s_struct_field_audit.sql
-- Structural gap audit: Gleam struct fields vs DB columns for each psypi-used table

CREATE TABLE IF NOT EXISTS struct_field_inventory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name text NOT NULL,
  db_column_name text NOT NULL,
  db_data_type text NOT NULL,
  db_nullable text NOT NULL,
  in_gleam_struct boolean NOT NULL DEFAULT false,
  gleam_field_name text,
  gleam_field_type text,
  gap_type text,
  gap_detail text,
  created_at timestamptz DEFAULT NOW()
);

TRUNCATE struct_field_inventory;

-- ============================================================================
-- tasks: 60 DB columns, 15 Gleam fields
-- ============================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
('tasks', 'id', 'uuid', 'NO', true, 'id', 'String', 'type_mismatch', 'uuid decoded as String (ok with node-postgres)'),
('tasks', 'title', 'text', 'NO', true, 'title', 'String', 'ok', NULL),
('tasks', 'description', 'text', 'YES', true, 'description', 'Option(String)', 'ok', NULL),
('tasks', 'status', 'text', 'NO', true, 'status', 'TaskStatus', 'enum_gap', 'Missing FakeComplete variant'),
('tasks', 'priority', 'integer', 'YES', true, 'priority', 'Int', 'ok', NULL),
('tasks', 'result', 'jsonb', 'YES', true, 'result', 'Option(String)', 'type_mismatch', 'DB is jsonb, Gleam is Option(String). jsonb needs ::text cast or json decoder.'),
('tasks', 'error', 'text', 'YES', true, 'error', 'Option(String)', 'ok', NULL),
('tasks', 'retry_count', 'integer', 'YES', true, 'retry_count', 'Int', 'ok', NULL),
('tasks', 'created_at', 'timestamptz', 'YES', true, 'created_at', 'String', 'type_mismatch', 'timestamptz decoded as String. Needs ::text cast in query.'),
('tasks', 'updated_at', 'timestamptz', 'YES', true, 'updated_at', 'String', 'type_mismatch', 'timestamptz decoded as String. Needs ::text cast in query.'),
('tasks', 'completed_at', 'timestamptz', 'YES', true, 'completed_at', 'Option(String)', 'type_mismatch', 'timestamptz decoded as String. Needs ::text cast in query.'),
('tasks', 'project_id', 'uuid', 'NO', true, 'project_id', 'Option(String)', 'nullability_mismatch', 'DB is NOT NULL uuid, Gleam is Option(String). Should be String not Option(String).'),
('tasks', 'created_by', 'text', 'YES', true, 'created_by', 'String', 'ok', NULL),
('tasks', 'source', 'text', 'YES', true, 'source', 'Option(String)', 'ok', NULL),
-- tasks: columns NOT in Gleam struct
('tasks', 'depends_on', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Dependency tracking not available in Gleam'),
('tasks', 'blocking', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Blocking task tracking not available'),
('tasks', 'base_priority', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Priority calculation data'),
('tasks', 'weighted_priority', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Priority calculation data'),
('tasks', 'last_error', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Error history not tracked'),
('tasks', 'tags', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Task tagging not available'),
('tasks', 'auto_tagged', 'boolean', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Auto-tagging status'),
('tasks', 'encrypted_result', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Encrypted result storage'),
('tasks', 'result_iv', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Encryption IV'),
('tasks', 'next_retry_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Retry scheduling'),
('tasks', 'max_retries', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Retry limit'),
('tasks', 'timeout_seconds', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Timeout config'),
('tasks', 'started_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Start time tracking'),
('tasks', 'is_long_running', 'boolean', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Long-running task flag'),
('tasks', 'type', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Task type enum (10 values) - no Gleam type'),
('tasks', 'assigned_to', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Task assignment'),
('tasks', 'category', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Task category enum (4+NULL values)'),
('tasks', 'error_category', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Error categorization (8+NULL values)'),
('tasks', 'consecutive_failures', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Failure tracking'),
('tasks', 'last_failed_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Failure tracking'),
('tasks', 'is_stuck', 'boolean', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Stuck detection'),
('tasks', 'stuck_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Stuck detection'),
('tasks', 'watchdog_kills', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Watchdog tracking'),
('tasks', 'agent_id', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Agent execution tracking'),
('tasks', 'agent_name', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Agent execution tracking'),
('tasks', 'git_hash', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Git context'),
('tasks', 'git_branch', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Git context'),
('tasks', 'environment', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Environment context'),
('tasks', 'session_id', 'varchar', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Session tracking'),
('tasks', 'executor_type', 'varchar', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Executor metadata'),
('tasks', 'executor_model', 'varchar', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Executor metadata'),
('tasks', 'executor_provider', 'varchar', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Executor metadata'),
('tasks', 'delegate_to', 'varchar', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Task delegation'),
('tasks', 'complexity', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Complexity score'),
('tasks', 'delegated_from', 'varchar', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Delegation chain'),
('tasks', 'executor_source', 'varchar', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Executor source'),
('tasks', 'template_id', 'uuid', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Template reference'),
('tasks', 'metadata', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Extensible metadata'),
('tasks', 'created_by_identity', 'varchar', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Identity tracking'),
('tasks', 'result_tag', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Encryption tag'),
('tasks', 'result_salt', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Encryption salt'),
('tasks', 'encrypted_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Encryption timestamp'),
('tasks', 'pause_reason', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Pause tracking'),
('tasks', 'paused_until', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Pause scheduling'),
('tasks', 'progress_percent', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Progress tracking'),
('tasks', 'last_progress_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Progress tracking');

-- ============================================================================
-- issues: 30 DB columns, 15 Gleam fields
-- ============================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
('issues', 'id', 'uuid', 'NO', true, 'id', 'String', 'type_mismatch', 'uuid as String (ok with node-postgres)'),
('issues', 'title', 'text', 'NO', true, 'title', 'String', 'ok', NULL),
('issues', 'description', 'text', 'YES', true, 'description', 'Option(String)', 'ok', NULL),
('issues', 'issue_type', 'text', 'NO', true, 'issue_type', 'IssueType', 'enum_gap', 'Missing Proposal variant'),
('issues', 'severity', 'text', 'YES', true, 'severity', 'IssueSeverity', 'ok', NULL),
('issues', 'status', 'text', 'YES', true, 'status', 'IssueStatus', 'enum_gap', 'Missing acknowledged/wont_fix/duplicate; has Closed not in DB'),
('issues', 'created_at', 'timestamptz', 'YES', true, 'created_at', 'String', 'type_mismatch', 'timestamptz needs ::text cast'),
('issues', 'resolved_at', 'timestamptz', 'YES', true, 'resolved_at', 'Option(String)', 'type_mismatch', 'timestamptz needs ::text cast'),
('issues', 'created_by', 'text', 'NO', true, 'created_by', 'String', 'ok', NULL),
('issues', 'discovered_by', 'text', 'YES', true, 'discovered_by', 'Option(String)', 'ok', NULL),
('issues', 'environment', 'text', 'YES', true, 'environment', 'Option(String)', 'ok', NULL),
('issues', 'git_branch', 'text', 'YES', true, 'git_branch', 'Option(String)', 'ok', NULL),
('issues', 'git_hash', 'text', 'YES', true, 'git_hash', 'Option(String)', 'ok', NULL),
('issues', 'reported_by', 'text', 'YES', true, 'reported_by', 'Option(String)', 'ok', NULL),
('issues', 'source', 'text', 'YES', true, 'source', 'Option(String)', 'ok', NULL),
-- issues: columns NOT in Gleam struct
('issues', 'project_id', 'uuid', 'NO', false, NULL, NULL, 'missing_from_gleam', 'NOT NULL uuid. Issues belong to projects but Gleam has no project_id field.'),
('issues', 'task_id', 'uuid', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Issue-to-task linkage'),
('issues', 'resolution', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Resolution details'),
('issues', 'resolved_by', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Who resolved'),
('issues', 'tags', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Issue tagging'),
('issues', 'metadata', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Extensible metadata'),
('issues', 'updated_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Update tracking'),
('issues', 'assignee', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Issue assignment'),
('issues', 'assignee_type', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'agent/human/system'),
('issues', 'review_id', 'uuid', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Review linkage'),
('issues', 'dlq_id', 'uuid', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Dead letter queue'),
('issues', 'viewers', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Access control'),
('issues', 'milestone_id', 'uuid', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Milestone linkage'),
('issues', 'related_review_id', 'uuid', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Review cross-reference'),
('issues', 'related_issue_id', 'uuid', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Issue cross-reference'),
('issues', 'discovered_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Discovery timestamp');

-- ============================================================================
-- inter_reviews: 35 DB columns, 6 Gleam fields
-- ============================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
('inter_reviews', 'id', 'uuid', 'NO', true, 'id', 'String', 'type_mismatch', 'uuid as String'),
('inter_reviews', 'task_id', 'uuid', 'YES', true, 'task_id', 'Option(String)', 'type_mismatch', 'uuid as String'),
('inter_reviews', 'status', 'text', 'YES', true, 'status', 'String', 'enum_gap', '5 values, no Gleam type'),
('inter_reviews', 'summary', 'text', 'YES', true, 'summary', 'Option(String)', 'ok', NULL),
('inter_reviews', 'overall_score', 'integer', 'YES', true, 'overall_score', 'Option(Int)', 'ok', NULL),
('inter_reviews', 'requested_at', 'timestamptz', 'YES', true, 'requested_at', 'String', 'type_mismatch', 'timestamptz needs ::text cast'),
-- inter_reviews: columns NOT in Gleam struct
('inter_reviews', 'commit_hash', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Git context for review'),
('inter_reviews', 'branch', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Git context for review'),
('inter_reviews', 'requester_id', 'text', 'NO', false, NULL, NULL, 'missing_from_gleam', 'Who requested review'),
('inter_reviews', 'reviewer_type', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'ai/human enum'),
('inter_reviews', 'review_round', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Review iteration'),
('inter_reviews', 'findings', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Review findings data'),
('inter_reviews', 'suggestions', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Review suggestions'),
('inter_reviews', 'issues', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Review issues'),
('inter_reviews', 'praise', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Review praise'),
('inter_reviews', 'code_quality_score', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Quality metric'),
('inter_reviews', 'test_coverage_score', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Coverage metric'),
('inter_reviews', 'documentation_score', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Docs metric'),
('inter_reviews', 'response', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Review response text'),
('inter_reviews', 'response_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Response timestamp'),
('inter_reviews', 'accepted_suggestions', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Accepted suggestions'),
('inter_reviews', 'started_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Start time'),
('inter_reviews', 'completed_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Completion time - critical for commit workflow'),
('inter_reviews', 'review_context', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Review context data'),
('inter_reviews', 'issue_id', 'uuid', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Issue linkage'),
('inter_reviews', 'reviewer_id', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Who reviewed'),
('inter_reviews', 'response_status', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', '5-value enum, no Gleam type'),
('inter_reviews', 'raw_response', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Raw AI response'),
('inter_reviews', 'session_id', 'varchar', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Session tracking'),
('inter_reviews', 'reviewed_by', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Reviewer identity'),
('inter_reviews', 'leverage_ratio', 'numeric', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Leverage metric'),
('inter_reviews', 'rework_count', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Rework tracking'),
('inter_reviews', 'effort_minutes', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Effort tracking');

-- ============================================================================
-- Summary view
-- ============================================================================
CREATE OR REPLACE VIEW struct_gap_summary AS
SELECT
  table_name,
  COUNT(*) as total_db_columns,
  COUNT(*) FILTER (WHERE in_gleam_struct) as in_gleam,
  COUNT(*) FILTER (WHERE NOT in_gleam_struct) as missing_from_gleam,
  COUNT(*) FILTER (WHERE gap_type = 'type_mismatch') as type_mismatches,
  COUNT(*) FILTER (WHERE gap_type = 'enum_gap') as enum_gaps,
  COUNT(*) FILTER (WHERE gap_type = 'nullability_mismatch') as nullability_mismatches
FROM struct_field_inventory
GROUP BY table_name
ORDER BY table_name;

-- Update table_documentation
INSERT INTO table_documentation (table_name, purpose, usage_context, key_columns, related_tables, notes)
VALUES ('struct_field_inventory', 'Structural gap audit: Gleam struct fields vs DB columns', 'system_review',
  '["table_name","db_column_name","in_gleam_struct","gap_type"]'::jsonb,
  ARRAY['type_inventory','review_findings'],
  'Each row is one DB column. in_gleam_struct=true means the column has a corresponding Gleam struct field. gap_type: ok/type_mismatch/enum_gap/nullability_mismatch/missing_from_gleam.')
ON CONFLICT (table_name) DO UPDATE SET
  purpose = EXCLUDED.purpose,
  usage_context = EXCLUDED.usage_context,
  key_columns = EXCLUDED.key_columns,
  related_tables = EXCLUDED.related_tables,
  notes = EXCLUDED.notes;
