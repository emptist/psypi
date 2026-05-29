-- 029i_insert_audit.sql
-- Audit of INSERT statements for missing NOT NULL columns and wrong column names

-- ============================================================
-- FINDING #420: monitor_ai.auto_file_issue() uses wrong column names + missing project_id
-- ============================================================
-- monitor_ai.gleam:561: INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment)
-- Bug 1: Column 'type' does not exist — should be 'issue_type'
-- Bug 2: Column 'discovered_by' does not exist in issues table
-- Bug 3: Column 'environment' does not exist in issues table
-- Bug 4: Missing 'project_id' — NOT NULL with no default
-- This INSERT can NEVER succeed — it will fail with column not found error
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837',
  420, 'critical', 'logic_error', 'monitor_ai',
  'auto_file_issue() uses 3 non-existent columns (type/discovered_by/environment) + missing project_id — INSERT always fails',
  'monitor_ai.gleam:561 INSERT INTO issues uses column "type" (should be "issue_type"), "discovered_by" (does not exist), and "environment" (does not exist). Also missing project_id which is NOT NULL with no default. This function can NEVER successfully insert an issue. PostgreSQL will reject with "column type does not exist".',
  'monitor_ai.gleam:561: INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment). psql \\d issues shows columns: issue_type (not type), no discovered_by, no environment, project_id NOT NULL.',
  'confirmed'
);

-- ============================================================
-- FINDING #421: areflect.save_issue() missing project_id — INSERT always fails
-- ============================================================
-- areflect.gleam:224: INSERT INTO issues (title, description, severity, created_by)
-- Missing: project_id (NOT NULL, no default) and issue_type (NOT NULL, has default 'bug')
-- project_id has no default, so this INSERT will always fail with NOT NULL violation
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837',
  421, 'critical', 'logic_error', 'areflect',
  'areflect.save_issue() missing project_id (NOT NULL, no default) — INSERT always fails',
  'areflect.gleam:224 inserts into issues without project_id. The issues table has project_id as NOT NULL with no default value. PostgreSQL will reject with NOT NULL constraint violation. This means areflect can never save issues. Compare with issue_db.gleam:88 which correctly includes project_id.',
  'areflect.gleam:224: INSERT INTO issues (title, description, severity, created_by). psql: issues.project_id is uuid NOT NULL with no default. issue_db.gleam:88 correctly includes project_id.',
  'confirmed'
);

-- ============================================================
-- FINDING #422: areflect.save_task() missing project_id — uses hardcoded default
-- ============================================================
-- areflect.gleam:262: INSERT INTO tasks (title, description, priority, created_by)
-- Missing: project_id (NOT NULL, has default '0d324e68-b399-4b85-bd8a-6b1ef7b46168')
-- This INSERT will succeed but always uses the hardcoded default UUID
-- All tasks created by areflect will be in the same default project
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837',
  422, 'medium', 'logic_error', 'areflect',
  'areflect.save_task() missing project_id — always uses hardcoded default UUID',
  'areflect.gleam:262 inserts into tasks without project_id. The tasks table has project_id as NOT NULL with default ''0d324e68-b399-4b85-bd8a-6b1ef7b46168''. The INSERT succeeds but all tasks are created in the same default project regardless of which project the agent is working in. Compare with task.gleam:126 which correctly includes project_id as a parameter.',
  'areflect.gleam:262: INSERT INTO tasks (title, description, priority, created_by). psql: tasks.project_id NOT NULL default ''0d324e68-b399-4b85-bd8a-6b1ef7b46168''. task.gleam:126 includes project_id.',
  'confirmed'
);

-- ============================================================
-- FINDING #423: areflect.save_learning() missing project_id — insights not project-associated
-- ============================================================
-- areflect.gleam:186: INSERT INTO learning_insights (insight_type, title, content, confidence)
-- Missing: project_id (nullable, so INSERT succeeds, but insights have no project association)
-- Learning insights won't be filtered by project in queries
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837',
  423, 'low', 'logic_error', 'areflect',
  'areflect.save_learning() missing project_id — insights not associated with any project',
  'areflect.gleam:186 inserts into learning_insights without project_id. The column is nullable so the INSERT succeeds, but insights will never be associated with a project. This means project-scoped queries for learning insights will miss all areflect-generated insights.',
  'areflect.gleam:186: INSERT INTO learning_insights (insight_type, title, content, confidence). psql: learning_insights.project_id is nullable.',
  'confirmed'
);

-- ============================================================
-- SUMMARY: INSERT audit results
-- ============================================================
-- Total INSERT statements audited: 21
-- Critical failures (INSERT always fails): 2 (#420, #421)
-- Silent data issues (wrong project association): 2 (#422, #423)
-- Already correct: 17 (task.gleam, project.gleam, meeting.gleam, skill.gleam, 
--   system_review_db.gleam, issue_db.gleam, broadcast.gleam, memory.gleam, 
--   learning.gleam, psypi_config.gleam, monitor.gleam)

SELECT 'INSERT AUDIT SUMMARY' AS section;
SELECT severity, COUNT(*) AS cnt
FROM review_findings
WHERE status = 'confirmed' AND finding_number >= 420 AND finding_number <= 423
GROUP BY severity
ORDER BY severity;

SELECT '=== TOTAL CONFIRMED FINDINGS ===' AS section;
SELECT severity, COUNT(*) AS cnt
FROM review_findings
WHERE status = 'confirmed'
GROUP BY severity
ORDER BY severity;
