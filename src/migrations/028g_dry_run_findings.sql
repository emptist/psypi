-- 028g_dry_run_findings.sql
-- Record dry-run migration findings

-- Finding #389: Migration order constraint
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  389, 'critical', 'migration_risk', 'schema',
  'Casing migration must DROP CHECK constraints BEFORE updating data',
  'Dry-run simulation revealed that UPDATE tasks SET status = LOWER(status) converts COMPLETED to completed, but the old tasks_status_check only allows UPPER_CASE values. If constraints are not dropped first, every row update fails with: new row for relation "tasks" violates check constraint "tasks_status_check". The correct migration order is: (1) DROP old constraints, (2) UPDATE data to lowercase, (3) ADD new lowercase constraints.',
  'Dry-run 028f: First attempt with UPDATE before DROP failed. Second attempt with DROP-first succeeded: all 20 tasks rows and 1 projects row updated without conflict.',
  'open'
);

-- Finding #390: CREATE OR REPLACE FUNCTION cannot change parameter names
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  390, 'high', 'migration_risk', 'schema',
  'CREATE OR REPLACE FUNCTION cannot change parameter names — must DROP and recreate',
  'Dry-run simulation showed that CREATE OR REPLACE FUNCTION fails when parameter names differ from the original. For example, check_dependencies_completed originally has parameter p_depends_on but the migration script used depends_on. PostgreSQL error: cannot change name of input parameter. All 13 functions must be DROP FUNCTION + CREATE FUNCTION instead of CREATE OR REPLACE.',
  'Dry-run 028f: ERROR: cannot change name of input parameter "p_depends_on". HINT: Use DROP FUNCTION first. Affected: check_dependencies_completed, convert_issue_to_task, create_qc_review, suggest_improvements_from_failures.',
  'open'
);

-- Finding #391: Function signature mismatches
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  391, 'high', 'migration_risk', 'schema',
  '3 functions have signature mismatches between current DB and migration script',
  'Dry-run revealed function signature discrepancies: (1) convert_issue_to_task: DB has (uuid, integer, text) with p_created_by, migration had (uuid, integer, uuid) with p_project_id. (2) create_qc_review: DB has (uuid, integer) with p_original_task_id, migration had (uuid, text, text, text). (3) suggest_improvements_from_failures: DB has (uuid, integer) with p_project_id/p_limit, migration had no parameters. These must use DROP with exact original signatures.',
  'pg_get_function_arguments() output: convert_issue_to_task(p_issue_id uuid, p_priority integer DEFAULT 5, p_created_by text), create_qc_review(p_original_task_id uuid, p_priority integer DEFAULT 5), suggest_improvements_from_failures(p_project_id uuid, p_limit integer DEFAULT 5).',
  'open'
);

-- Finding #392: Dry-run confirms casing migration is safe
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  392, 'low', 'migration_risk', 'schema',
  'Dry-run confirms casing migration is safe — no data conflicts with correct order',
  'After fixing the constraint order (DROP first) and function signatures (DROP+CREATE), the full dry-run completed successfully: 5 constraints dropped, 20 tasks + 1 projects rows updated to lowercase, 5 new lowercase constraints added, 2 views recreated, 13 functions recreated, all verification queries returned correct results. ROLLBACK confirmed data integrity preserved. No foreign key conflicts, no orphaned references, no data loss.',
  'Dry-run 028f output: tasks.status after migration: completed=18, pending=2. projects.status after migration: active=1. failure_statistics view: 1 row. task_health_metrics view: 2 rows. ROLLBACK successful, original UPPER_CASE data intact.',
  'open'
);
