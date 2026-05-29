-- 028d_case_mismatches_and_missing_tables.sql
-- Case mismatch bugs in monitor_ai.gleam and missing type_inventory entries
-- Previous finding max: 380

-- Finding #381: monitor_ai.gleam uses 'PENDING' for skills.status — should be lowercase 'pending'
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  381, 'high', 'sql_error', 'monitor_ai',
  'monitor_ai.gleam uses ''PENDING'' for skills.status — should be lowercase ''pending'' per CHECK constraint',
  'monitor_ai.gleam:357 uses WHERE status = ''PENDING'' for skills table. The skills_status_check constraint only allows lowercase values: pending/approved/rejected/blocked/installed/uninstalled. The uppercase ''PENDING'' will never match any rows. Verified: SELECT COUNT(*) FROM skills WHERE status = ''PENDING'' returns 0, but WHERE status = ''pending'' returns 3. This means the monitor will never suggest reviewing pending skills.',
  'monitor_ai.gleam:357: FROM skills WHERE status = ''PENDING''. DB CHECK: CHECK ((status = ANY (ARRAY[''pending'', ''approved'', ''rejected'', ''blocked'', ''installed'', ''uninstalled'']))). Same bug on line 507 (duplicate query in different function).',
  'open'
);

-- Finding #382: monitor_ai.gleam uses 'FAILED' for inter_reviews.status — should be lowercase 'failed'
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  382, 'medium', 'sql_error', 'monitor_ai',
  'monitor_ai.gleam uses ''FAILED'' for inter_reviews.status — should be lowercase ''failed'' per CHECK constraint',
  'monitor_ai.gleam:274 uses WHERE status = ''FAILED'' for inter_reviews table. The inter_reviews_status_check constraint only allows lowercase values: pending/in_progress/completed/failed/superseded. The uppercase ''FAILED'' will never match any rows. Currently no failed reviews exist so no data impact yet, but when failures occur they will be invisible to the monitor.',
  'monitor_ai.gleam:274: COUNT(*) FILTER (WHERE status = ''FAILED'')::INT as failure_count FROM inter_reviews. DB CHECK: CHECK ((status = ANY (ARRAY[''pending'', ''in_progress'', ''completed'', ''failed'', ''superseded'']))).',
  'open'
);

-- Finding #383: task.gleam string_to_status accepts both cases — lowercase branch is dead code
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  383, 'low', 'dead_code', 'task',
  'task.gleam string_to_status accepts both cases — lowercase branch is unreachable dead code',
  'task.gleam:46-49 matches both "pending"|"PENDING", "running"|"RUNNING" etc. But the tasks_status_check constraint only allows UPPER_CASE values (PENDING/RUNNING/COMPLETED/FAILED/FAKE_COMPLETE). The lowercase branches will never match real database data. This is misleading — it suggests the DB might store lowercase values when it cannot.',
  'task.gleam:46: "pending" | "PENDING" -> Ok(Pending). DB CHECK: CHECK ((status = ANY (ARRAY[''PENDING'', ''RUNNING'', ''COMPLETED'', ''FAILED'', ''FAKE_COMPLETE'']))).',
  'open'
);

-- Finding #384: stats.gleam counts ALL rows across ALL projects — no project_id filter
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  384, 'medium', 'logic_bug', 'stats',
  'stats.gleam counts ALL rows across ALL projects — no project_id filter in shared database',
  'The stats() function uses subqueries like (SELECT COUNT(*) FROM tasks) without any WHERE project_id = $1 filter. In a shared database where multiple projects store data, this returns counts from ALL projects combined, not just psypi. The same issue applies to issues, skills, and meetings counts. The Stats type and tool output will show inflated numbers.',
  'stats.gleam:16-19: SELECT (SELECT COUNT(*) FROM tasks) as tasks, (SELECT COUNT(*) FROM issues) as issues, (SELECT COUNT(*) FROM skills) as skills, (SELECT COUNT(*) FROM meetings) as meetings. No project_id filter. tasks.project_id is NOT NULL, issues.project_id is nullable, skills has no project_id column.',
  'open'
);

-- Add missing tables to type_inventory: agent_prefixes
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES
  ('agent_prefixes', 'prefix', ARRAY['A','S','G'], NULL, NULL, 'no_gleam_type', 'agent_prefixes.prefix is PK (text). Used by seed.gleam. No Gleam type for prefix values (A/S/G).', true),
  ('agent_prefixes', 'name', ARRAY['AutonomicBot','SomaticBot','GlobalBot'], NULL, NULL, 'no_gleam_type', 'agent_prefixes.name is text. Values: AutonomicBot/SomaticBot/GlobalBot. No Gleam type.', true),
  ('agent_prefixes', 'description', ARRAY[]::text[], NULL, NULL, 'no_gap', 'Simple text description field. No type gap.', true);

-- Add missing tables to type_inventory: code_versions
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES
  ('code_versions', 'id', ARRAY[]::text[], NULL, NULL, 'no_gleam_type', 'code_versions.id is uuid PK. Used as text in Gleam via ::text cast. No Gleam type.', true),
  ('code_versions', 'file_path', ARRAY[]::text[], NULL, NULL, 'no_gap', 'Simple text field. No type gap.', true),
  ('code_versions', 'content', ARRAY[]::text[], NULL, NULL, 'no_gap', 'Simple text field. No type gap.', true),
  ('code_versions', 'version_hash', ARRAY[]::text[], NULL, NULL, 'no_gap', 'Simple varchar field. No type gap.', true),
  ('code_versions', 'saved_by', ARRAY[]::text[], NULL, NULL, 'no_gap', 'Simple varchar field. No type gap.', true),
  ('code_versions', 'saved_at', ARRAY[]::text[], NULL, NULL, 'no_gleam_type', 'code_versions.saved_at is timestamptz. Gleam reads as string via ::text. No Timestamp type.', true),
  ('code_versions', 'commit_hash', ARRAY[]::text[], NULL, NULL, 'no_gap', 'Simple nullable varchar. No type gap.', true),
  ('code_versions', 'reason', ARRAY[]::text[], NULL, NULL, 'no_gap', 'Simple nullable text. No type gap.', true),
  ('code_versions', 'project_name', ARRAY['psypi'], NULL, NULL, 'no_gap', 'Default ''psypi''. Simple varchar. No type gap.', true),
  ('code_versions', 'file_size', ARRAY[]::text[], NULL, NULL, 'no_gap', 'Simple nullable integer. No type gap.', true),
  ('code_versions', 'line_count', ARRAY[]::text[], NULL, NULL, 'no_gap', 'Simple nullable integer. No type gap.', true);
