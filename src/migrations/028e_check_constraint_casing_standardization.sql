-- 028e_check_constraint_casing_standardization.sql
-- Finding: CHECK constraint casing inconsistency across psypi-used tables
-- 4 constraints use UPPER_CASE, 27 use lowercase — must standardize to lowercase
-- This is a meta-finding that documents the full scope of the problem

-- Finding #385: CHECK constraint casing inconsistency — 4 UPPER_CASE vs 27 lowercase
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  385, 'high', 'design_flaw', 'schema',
  'CHECK constraint casing inconsistency: 4 UPPER_CASE constraints vs 27 lowercase — must standardize',
  'The psypi database has inconsistent casing in CHECK constraint enum values. 27 constraints use lowercase (e.g. issues.status, skills.status, inter_reviews.status) but 4 use UPPER_CASE: tasks.status (PENDING/RUNNING/COMPLETED/FAILED/FAKE_COMPLETE), tasks.error_category (NETWORK/AUTH/TIMEOUT/SERVER/TRANSPORT/LOGIC/RESOURCE/UNKNOWN), dead_letter_queue.error_category (same as tasks), projects.status (ACTIVE/INACTIVE/ARCHIVED). This inconsistency causes: (1) monitor_ai.gleam bugs where UPPER_CASE is used for lowercase columns, (2) confusion about which case to use in new code, (3) Gleam string_to_status functions that handle both cases as a workaround. Standardization to lowercase is required because: lowercase is the majority (27 vs 4), Gleam convention is lowercase, and all other psypi tables use lowercase.',
  'UPPER_CASE constraints: tasks.tasks_status_check, tasks.tasks_error_category_check, dead_letter_queue.dead_letter_queue_error_category_check, projects.projects_status_check. All other 27 enum constraints use lowercase. 13 DB functions also reference UPPER_CASE values and must be updated: check_dependencies_completed, convert_issue_to_task, create_issue_from_dlq, create_qc_review, get_blocked_tasks, get_failure_recommendations, get_project_stats, get_subsystem_stats, get_watchdog_candidates, resume_task, start_task_execution, suggest_improvements_from_failures, update_weighted_priorities.',
  'open'
);

-- Finding #386: 13 database functions hardcode UPPER_CASE values that must change with constraint standardization
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  386, 'high', 'design_flaw', 'schema',
  '13 database functions hardcode UPPER_CASE values — must be updated when CHECK constraints are standardized to lowercase',
  'When tasks.status and tasks.error_category CHECK constraints are changed from UPPER_CASE to lowercase, 13 database functions that reference these values in their SQL bodies must also be updated. These include: check_dependencies_completed (references PENDING/COMPLETED), convert_issue_to_task (PENDING), create_issue_from_dlq (NETWORK/AUTH/etc), get_blocked_tasks (PENDING/RUNNING), get_project_stats (COMPLETED/FAILED/PENDING), get_subsystem_stats (FAILED), get_watchdog_candidates (RUNNING), resume_task (PENDING), start_task_execution (RUNNING), update_weighted_priorities (PENDING/RUNNING). Failure to update these functions will cause them to silently return empty results.',
  'SELECT proname FROM pg_proc WHERE prosrc LIKE ''%PENDING%'' OR prosrc LIKE ''%COMPLETED%'' OR prosrc LIKE ''%FAILED%'' OR prosrc LIKE ''%RUNNING%'' OR prosrc LIKE ''%NETWORK%'' — returns 13 functions.',
  'open'
);

-- Finding #387: Gleam code that must change with constraint standardization
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  387, 'medium', 'design_flaw', 'schema',
  'Gleam code using UPPER_CASE for tasks.status and projects.status must change when constraints are standardized',
  'When CHECK constraints are standardized to lowercase, the following Gleam code must be updated: (1) task.gleam:46-50 string_to_status — remove UPPER_CASE branches, keep only lowercase; (2) task.gleam:228 SET status = ''COMPLETED'' → ''completed''; (3) a_db_reader.gleam:117 NOT IN (''COMPLETED'',''FAILED'',''FAKE_COMPLETE'') → lowercase; (4) monitor_ai.gleam:63,213,274,352,497,507,512 — all ''FAILED'',''PENDING'' → lowercase; (5) project.gleam:53-55,62-64 — ''ACTIVE'',''INACTIVE'',''ARCHIVED'' → lowercase; (6) project.gleam:214,253 — ''ACTIVE'' → ''active''.',
  'Grep for ''PENDING''|''COMPLETED''|''FAILED''|''ACTIVE'' in *.gleam files returns 12 SQL references and 11 Gleam string matching references.',
  'open'
);

-- Finding #388: Existing data must be migrated from UPPER_CASE to lowercase
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  388, 'medium', 'data_migration', 'schema',
  'Existing data in tasks.status and projects.status uses UPPER_CASE — must be migrated to lowercase before constraint change',
  'Current data: tasks has 18 rows with status=COMPLETED and 2 rows with status=PENDING. projects has 1 row with status=ACTIVE. tasks.error_category has 0 rows. dead_letter_queue.error_category has 0 rows. The migration must: (1) UPDATE tasks SET status = LOWER(status), (2) UPDATE projects SET status = LOWER(status), (3) Drop old CHECK constraints, (4) Add new lowercase CHECK constraints, (5) Update 13 DB functions, (6) Update Gleam code.',
  'SELECT status, COUNT(*) FROM tasks GROUP BY status → COMPLETED:18, PENDING:2. SELECT status, COUNT(*) FROM projects GROUP BY status → ACTIVE:1.',
  'open'
);
