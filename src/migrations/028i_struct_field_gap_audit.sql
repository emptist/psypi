-- 028i_struct_field_gap_audit.sql
-- Struct field gap audit: missing fields and type mismatches

-- Finding #407: 217 DB columns missing from Gleam structs across 19 tables
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  407, 'high', 'struct_gap', 'schema',
  '217 DB columns missing from Gleam structs across 19 tables — struct_field_inventory audit',
  'The struct_field_inventory table shows 217 columns present in the database but absent from corresponding Gleam structs. Worst affected: tasks (46 missing), skills (45 missing), inter_reviews (27 missing), issues (16 missing). Many missing fields are critical for functionality: tasks.depends_on (dependency tracking), tasks.error_category (error categorization), tasks.is_stuck (stuck detection), tasks.type (task type enum), inter_reviews.response_status, inter_reviews.reviewer_type. These gaps mean Gleam code cannot read or write these fields, limiting functionality and causing data loss on round-trip operations.',
  'struct_field_inventory query: SELECT table_name, COUNT(*) FROM struct_field_inventory WHERE gap_type=''missing_from_gleam'' GROUP BY table_name. Top: tasks=46, skills=45, inter_reviews=27, issues=16, agent_identities=12, agent_sessions=10, learning_insights=9, code_versions=9.',
  'open'
);

-- Finding #408: 51 type mismatches between DB columns and Gleam struct fields
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  408, 'medium', 'struct_gap', 'schema',
  '51 type mismatches between DB columns and Gleam struct fields — uuid/timestamptz read as String',
  'The struct_field_inventory shows 51 columns with type_mismatch gap_type across 12 tables. Most common pattern: uuid columns read as String (via ::text cast), timestamptz columns read as String (via ::text cast), jsonb columns read as String. While the ::text cast approach works, it loses type information and requires manual string parsing. Worst affected: system_reviews (7 mismatches), review_findings (6), tasks (5), projects (5).',
  'struct_field_inventory query: SELECT table_name, COUNT(*) FROM struct_field_inventory WHERE gap_type=''type_mismatch'' GROUP BY table_name. system_reviews=7, review_findings=6, tasks=5, projects=5, skills=4, meetings=3, meeting_opinions=3, inter_reviews=3, issues=3, memory=3.',
  'open'
);

-- Finding #409: tasks table has 46 missing Gleam fields — most structurally incomplete table
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  409, 'high', 'struct_gap', 'task',
  'tasks table has 46 missing Gleam fields — most structurally incomplete table in psypi',
  'The tasks table has 60 columns in the database but the Gleam Task struct only has 14 fields. 46 columns are missing from the Gleam type, including critical fields: depends_on (dependency tracking), error_category (8-value enum), is_stuck (stuck detection), type (10-value enum), category (4-value enum), consecutive_failures, watchdog_kills, last_error, progress_percent, timeout_seconds, session_id, metadata, tags. The Task struct cannot represent most task state, making it impossible to implement proper task lifecycle management in Gleam.',
  'struct_field_inventory: tasks has 46 missing_from_gleam + 5 type_mismatch + 9 ok = 60 total columns. Task struct in task.gleam:18-35 has 14 fields. Missing critical enum fields: tasks.type (10 values), tasks.category (4+NULL values), tasks.error_category (8+NULL values).',
  'open'
);

-- Finding #410: skills table has 45 missing Gleam fields — second most incomplete
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  410, 'medium', 'struct_gap', 'skill',
  'skills table has 45 missing Gleam fields — second most structurally incomplete',
  'The skills table has 57 columns in database but the Gleam Skill struct only has 12 fields. 45 columns are missing, including: review_status (6-value enum), scan_status (5-value enum), rating, use_count, verified, permissions, tags, repository, manifest, quick_start, documentation, examples. Most of these are metadata fields that may not be needed by psypi core, but review_status and scan_status are security-relevant enums that should have Gleam types.',
  'struct_field_inventory: skills has 45 missing_from_gleam + 4 type_mismatch + 8 ok = 57 total columns. Skill struct in skill.gleam:26-40 has 12 fields. Security-relevant missing: review_status (6 values), scan_status (5 values), verified (boolean), permissions (jsonb).',
  'open'
);

-- Finding #411: inter_reviews has 27 missing fields — critical for commit workflow
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  411, 'high', 'struct_gap', 'inter_review',
  'inter_reviews has 27 missing Gleam fields — critical for commit workflow in tool_commit.gleam',
  'The inter_reviews table has 33 columns but the Gleam Review struct only has 6 fields. 27 columns are missing, including: response_status (5-value enum), reviewer_type (2-value enum), commit_hash, branch, overall_score, findings_json, recommendations, requested_at, completed_at, reviewer_id. tool_commit.gleam depends on inter_reviews.overall_score for commit validation but the Review struct does not include this field, requiring separate queries. The missing response_status and reviewer_type enums mean review state cannot be properly tracked in Gleam.',
  'struct_field_inventory: inter_reviews has 27 missing_from_gleam + 3 type_mismatch + 3 ok = 33 total columns. Review struct in inter_review.gleam:47-55 has 6 fields (id, task_id, status, summary, overall_score, requested_at). Missing: response_status, reviewer_type, commit_hash, branch, findings_json, recommendations, completed_at, reviewer_id.',
  'open'
);
