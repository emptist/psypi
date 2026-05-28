-- 027q_type_inventory.sql
-- Complete type gap inventory: every DB CHECK constraint enum vs Gleam type
-- This is the foundation for all bug fixes. Types must be correct before fixing logic.

-- Create a type_inventory table for structured tracking
CREATE TABLE IF NOT EXISTS type_inventory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name text NOT NULL,
  column_name text NOT NULL,
  db_values text[] NOT NULL,
  gleam_type_name text,
  gleam_variants text[],
  gap_status text NOT NULL DEFAULT 'unknown',
  gap_detail text,
  used_by_psypi boolean DEFAULT false,
  created_at timestamptz DEFAULT NOW()
);

-- Clear existing data for idempotent re-insert
TRUNCATE type_inventory;

-- ============================================================================
-- PSYPI TABLES (used by Gleam code)
-- ============================================================================

-- tasks.status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('tasks', 'status',
  ARRAY['PENDING','RUNNING','COMPLETED','FAILED','FAKE_COMPLETE'],
  'TaskStatus', ARRAY['Pending','Running','Completed','Failed'],
  'missing_variant', 'Missing FakeComplete. DB has FAKE_COMPLETE but Gleam has no variant for it.', true);

-- tasks.category (nullable)
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('tasks', 'category',
  ARRAY['security','performance','feature','bugfix',NULL],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type for TaskCategory. Column is nullable. Used as raw string.', true);

-- tasks.type
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('tasks', 'type',
  ARRAY['analysis','implementation','documentation','bugfix','research','testing','deployment','maintenance','discussion','announcement'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type for TaskType. 10 DB values. Used as raw string.', true);

-- tasks.error_category (nullable)
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('tasks', 'error_category',
  ARRAY['NETWORK','AUTH','TIMEOUT','SERVER','TRANSPORT','LOGIC','RESOURCE','UNKNOWN',NULL],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type for TaskErrorCategory. 8 DB values + NULL. Used as raw string.', true);

-- issues.severity
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('issues', 'severity',
  ARRAY['critical','high','medium','low','cosmetic'],
  'IssueSeverity', ARRAY['Critical','High','Medium','Low','Cosmetic'],
  'ok', 'Exact match. 5 DB values = 5 Gleam variants.', true);

-- issues.status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('issues', 'status',
  ARRAY['open','acknowledged','in_progress','resolved','wont_fix','duplicate'],
  'IssueStatus', ARRAY['Open','InProgress','Resolved','Closed'],
  'mismatch', 'DB has acknowledged/wont_fix/duplicate (3 missing from Gleam). Gleam has Closed (not in DB). Decode fails for 3 DB values. INSERT with Closed fails constraint.', true);

-- issues.type
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('issues', 'type',
  ARRAY['bug','inconsistency','feature','improvement','question','debt'],
  'IssueType', ARRAY['Bug','Inconsistency','Feature','Improvement','Question','Debt'],
  'ok', 'Exact match. 6 DB values = 6 Gleam variants.', true);

-- skills.source
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('skills', 'source',
  ARRAY['clawhub','local','generated','imported','ai-built'],
  'SkillSource', ARRAY['Clawhub','Local','Generated','Imported'],
  'missing_variant', 'Missing AiBuilt. DB has ai-built but Gleam has no variant. Decode fails for ai-built skills.', true);

-- skills.status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('skills', 'status',
  ARRAY['pending','approved','rejected','blocked','installed','uninstalled'],
  'SkillStatus', ARRAY['Pending','Approved','Rejected','Blocked','Installed','Uninstalled'],
  'ok', 'Exact match. 6 DB values = 6 Gleam variants.', true);

-- skills.review_status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('skills', 'review_status',
  ARRAY['pending','auto_passed','auto_failed','needs_manual_review','manually_approved','manually_rejected'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 6 DB values. Column not in skill_decoder. Completely invisible to Gleam.', true);

-- skills.scan_status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('skills', 'scan_status',
  ARRAY['pending','clean','suspicious','malicious','reviewed'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 5 DB values. Column not in skill_decoder. Completely invisible to Gleam.', true);

-- meetings.status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('meetings', 'status',
  ARRAY['active','completed','cancelled'],
  'MeetingStatus', ARRAY['Pending','Active','Completed','Cancelled'],
  'mismatch', 'Gleam has Pending (not in DB). INSERT with pending fails. Also Gleam has Cancelled but DB has cancelled (case diff — Gleam string_to_status must lowercase).', true);

-- meeting_opinions.position
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('meeting_opinions', 'position',
  ARRAY['support','oppose','neutral'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type for MeetingPosition. 3 DB values. Used as raw string in opinion_decoder.', true);

-- project_communications.priority
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('project_communications', 'priority',
  ARRAY['low','normal','high','critical'],
  'BroadcastPriority', ARRAY['Low','Normal','High','Critical'],
  'ok', 'Exact match. 4 DB values = 4 Gleam variants. But broadcast.stats() compares priority >= 2 (text vs int bug).', true);

-- project_communications.message_type
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('project_communications', 'message_type',
  ARRAY['task','review','feedback','status','question','answer','notification','broadcast'],
  'BroadcastStatus', ARRAY['Pending','Sent','Failed','Cancelled'],
  'wrong_type', 'Gleam BroadcastStatus is for a non-existent status column, not message_type. message_type has 8 values with no Gleam type. BroadcastStatus should be MessageType or removed.', true);

-- projects.status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('projects', 'status',
  ARRAY['ACTIVE','INACTIVE','ARCHIVED'],
  'ProjectStatus', ARRAY['Active','Inactive','Archived'],
  'case_mismatch', 'DB uses UPPERCASE (ACTIVE/INACTIVE/ARCHIVED). Gleam string_to_status must handle uppercase. If Gleam writes lowercase, INSERT fails.', true);

-- system_reviews.review_type
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('system_reviews', 'review_type',
  ARRAY['code','design','qc','peer','task','security','system','other'],
  'ReviewType', ARRAY['Code','Design','Qc','Peer','Task','Security','System','Other'],
  'ok', 'Exact match. 8 DB values = 8 Gleam variants.', true);

-- system_reviews.status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('system_reviews', 'status',
  ARRAY['pending','in_progress','completed','follow_up','closed'],
  'ReviewStatus', ARRAY['Pending','InProgress','Completed','FollowUp','Closed'],
  'ok', 'Exact match. 5 DB values = 5 Gleam variants.', true);

-- system_reviews.methodology
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('system_reviews', 'methodology',
  ARRAY['document_analysis','code_comparison','git_log','concept_understanding','mixed'],
  'ReviewMethodology', ARRAY['DocumentAnalysis','CodeComparison','GitLog','ConceptUnderstanding','Mixed'],
  'ok', 'Exact match. 5 DB values = 5 Gleam variants.', true);

-- system_reviews.scope
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('system_reviews', 'scope',
  ARRAY['full','partial','focused'],
  'ReviewScope', ARRAY['Full','Partial','Focused'],
  'ok', 'Exact match. 3 DB values = 3 Gleam variants.', true);

-- system_reviews.follow_up_status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('system_reviews', 'follow_up_status',
  ARRAY['pending','completed','overdue'],
  'FollowUpStatus', ARRAY['FuPending','FuCompleted','FuOverdue'],
  'ok', 'Exact match. 3 DB values = 3 Gleam variants.', true);

-- review_findings.severity
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('review_findings', 'severity',
  ARRAY['critical','high','medium','low','cosmetic'],
  'FindingSeverity', ARRAY['Critical','High','Medium','Low','Cosmetic'],
  'ok', 'Exact match. 5 DB values = 5 Gleam variants.', true);

-- review_findings.status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('review_findings', 'status',
  ARRAY['open','confirmed','disputed','fixed','wont_fix','duplicate','retracted'],
  'FindingStatus', ARRAY['Open','Confirmed','Disputed','Fixed','WontFix','Duplicate','Retracted'],
  'ok', 'Exact match. 7 DB values = 7 Gleam variants.', true);

-- inter_reviews.status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('inter_reviews', 'status',
  ARRAY['pending','in_progress','completed','failed'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type for InterReviewStatus. 4 DB values. inter_review.gleam has no status enum type.', true);

-- inter_reviews.response_status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('inter_reviews', 'response_status',
  ARRAY['pending','accepted','rejected','expired'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type for InterReviewResponseStatus. 4 DB values.', true);

-- inter_reviews.reviewer_type
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('inter_reviews', 'reviewer_type',
  ARRAY['ai','human','automated'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type for ReviewerType. 3 DB values.', true);

-- psypi_event_hooks.hook_status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('psypi_event_hooks', 'hook_status',
  ARRAY['active','inactive','error','experimental'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type for HookStatus. 4 DB values. event_hooks.gleam has no status enum.', true);

-- system_directives.priority
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('system_directives', 'priority',
  ARRAY['critical','high','medium','low'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type for DirectivePriority. 4 DB values. Could reuse FindingSeverity but semantically different.', true);

-- skill_audit_log.action
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('skill_audit_log', 'action',
  ARRAY['installed','uninstalled','approved','rejected','enabled','disabled','updated','reviewed','used'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type for SkillAuditAction. 9 DB values. skill.gleam has no audit type.', true);

-- ============================================================================
-- NON-PSYPI TABLES (present in shared DB but not used by psypi Gleam code)
-- ============================================================================

-- agent_sessions.status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('agent_sessions', 'status',
  ARRAY['alive','dead','idle'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. a_db_reader.gleam queries this table but has no type for status.', true);

-- failure_alerts.alert_type
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('failure_alerts', 'alert_type',
  ARRAY['tool_failure','agent_crash','db_error','timeout','resource_exhausted','user_request','scheduled_maintenance','failure_threshold'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 8 DB values. Not used by psypi Gleam code.', false);

-- auto_category_rules.category
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('auto_category_rules', 'category',
  ARRAY['security','performance','feature','bugfix','documentation','testing','refactoring','devops'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 8 DB values. Not used by psypi Gleam code.', false);

-- dead_letter_queue.error_category
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('dead_letter_queue', 'error_category',
  ARRAY['validation','timeout','permission','not_found','conflict','rate_limit','internal'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 7 DB values. Not used by psypi Gleam code.', false);

-- dead_letter_queue.review_status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('dead_letter_queue', 'review_status',
  ARRAY['pending','reviewed','ignored','retried'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 4 DB values. Not used by psypi Gleam code.', false);

-- issue_events.event_type
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('issue_events', 'event_type',
  ARRAY['created','status_changed','commented','assigned','severity_changed','type_changed','closed','reopened'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 8 DB values. Not used by psypi Gleam code.', false);

-- issues.assignee_type
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('issues', 'assignee_type',
  ARRAY['ai','human','team'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 3 DB values. Not used by psypi Gleam code.', false);

-- long_tasks_pause.pause_reason
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('long_tasks_pause', 'pause_reason',
  ARRAY['user_request','dependency','resource_limit','error','maintenance'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 5 DB values. Not used by psypi Gleam code.', false);

-- mcp_configs.server_type
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('mcp_configs', 'server_type',
  ARRAY['local','remote'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 2 DB values. Not used by psypi Gleam code.', false);

-- process_pids.status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('process_pids', 'status',
  ARRAY['running','terminated','orphaned','zombie'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 4 DB values. Not used by psypi Gleam code.', false);

-- project_metrics.metric_type
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('project_metrics', 'metric_type',
  ARRAY['test_coverage','code_quality','documentation','type_safety','security','performance','custom'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 7 DB values. Not used by psypi Gleam code.', false);

-- prompt_suggestions.status
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('prompt_suggestions', 'status',
  ARRAY['pending','approved','rejected'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 3 DB values. Not used by psypi Gleam code.', false);

-- subscription_plans.interval
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('subscription_plans', 'interval',
  ARRAY['day','week','month','year'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 4 DB values. Not used by psypi Gleam code.', false);

-- users.role
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('users', 'role',
  ARRAY['user','admin','superadmin'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 3 DB values. Not used by psypi Gleam code.', false);

-- api_keys.role
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('api_keys', 'role',
  ARRAY['read','write','admin'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 3 DB values. Not used by psypi Gleam code.', false);

-- conversations.conversation_type
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('conversations', 'conversation_type',
  ARRAY['chat','command','review','planning'],
  NULL, NULL,
  'no_gleam_type', 'No Gleam type. 4 DB values. Not used by psypi Gleam code.', false);

-- ============================================================================
-- SUMMARY VIEW
-- ============================================================================
CREATE OR REPLACE VIEW type_inventory_summary AS
SELECT
  gap_status,
  COUNT(*) as column_count,
  COUNT(*) FILTER (WHERE used_by_psypi) as psypi_used,
  array_agg(table_name || '.' || column_name ORDER BY table_name, column_name) as columns
FROM type_inventory
GROUP BY gap_status
ORDER BY CASE gap_status
  WHEN 'mismatch' THEN 1
  WHEN 'missing_variant' THEN 2
  WHEN 'wrong_type' THEN 3
  WHEN 'case_mismatch' THEN 4
  WHEN 'no_gleam_type' THEN 5
  WHEN 'ok' THEN 6
  ELSE 7
END;

-- Update table_documentation
INSERT INTO table_documentation (table_name, purpose, usage_context, key_columns, related_tables, notes)
VALUES ('type_inventory', 'Complete inventory of DB enum columns vs Gleam types', 'system_review',
  'table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status',
  'review_findings, system_reviews',
  'Re-verified 2026-05-28. 46 DB enum columns total. gap_status: ok=exact match, mismatch=values differ, missing_variant=Gleam missing DB value, no_gleam_type=no Gleam type at all, wrong_type=Gleam type maps to wrong column, case_mismatch=DB uses different case.')
ON CONFLICT (table_name) DO UPDATE SET
  purpose = EXCLUDED.purpose,
  usage_context = EXCLUDED.usage_context,
  key_columns = EXCLUDED.key_columns,
  related_tables = EXCLUDED.related_tables,
  notes = EXCLUDED.notes;
