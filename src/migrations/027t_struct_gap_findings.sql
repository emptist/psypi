-- 027t_struct_gap_findings.sql
-- Structural gap findings from struct_field_inventory audit

-- #310: tasks.result is jsonb but Gleam decodes as Option(String)
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 310, 'high', 'type_mismatch', 'task.gleam',
  'tasks.result is jsonb but Gleam decodes as Option(String) - decode fails for non-string jsonb',
  'DB column result is jsonb type. Gleam task_decoder uses decode.optional(decode.string). node-postgres returns jsonb as JavaScript object, not string. decode.string will fail for any jsonb value that is not a plain string.',
  'task.gleam:58 decode.field("result", decode.optional(decode.string)). DB: tasks.result jsonb.',
  'Any task with a jsonb result (object/array/number) causes decode failure. Only string jsonb values work.');

-- #311: tasks.project_id is uuid NOT NULL but Gleam has Option(String) - wrong nullability
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 311, 'medium', 'type_mismatch', 'task.gleam',
  'tasks.project_id is uuid NOT NULL but Gleam has Option(String) - wrong nullability and type',
  'DB column project_id is uuid NOT NULL. Gleam Task struct has project_id: Option(String). Should be String (not Optional) since DB requires it. Also uuid should be decoded as String (which node-postgres does automatically).',
  'task.gleam:66 decode.field("project_id", decode.optional(decode.string)). DB: project_id uuid NOT NULL.',
  'Gleam code treats project_id as optional when it is required. INSERT without project_id fails. Logic that checks is_some(project_id) is always True.');

-- #312: inter_reviews has 27/33 columns missing from Gleam Review struct
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 312, 'high', 'structural_gap', 'inter_review.gleam',
  'inter_reviews has 27 of 33 columns missing from Gleam Review struct - critical fields invisible',
  'Gleam Review has 6 fields. DB has 33 columns. Missing critical fields: commit_hash, branch, requester_id, reviewer_type, findings, suggestions, response_status, completed_at, reviewed_by. The commit workflow in tool_commit.gleam checks completed_at which is not in the struct.',
  'inter_review.gleam:47-53 defines Review with 6 fields. DB inter_reviews has 33 columns.',
  'Commit workflow cannot verify review completion. Findings/suggestions from reviews are invisible. Reviewer identity is lost. 82% of data is discarded.');

-- #313: issues.project_id is uuid NOT NULL but not in Gleam Issue struct
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 313, 'high', 'structural_gap', 'issue_db.gleam',
  'issues.project_id is uuid NOT NULL but not in Gleam Issue struct - INSERT always fails',
  'DB issues.project_id is uuid NOT NULL with no default. Gleam Issue struct has no project_id field. issue_db.gleam INSERT statements do not include project_id. Every INSERT will fail with NOT NULL constraint violation.',
  'issue_types.gleam:29-44 Issue struct has no project_id. DB: issues.project_id uuid NOT NULL.',
  'Creating issues from Gleam always fails. This is a hard blocker for the issue creation workflow.');

-- #314: tasks has 46 of 60 columns missing from Gleam Task struct
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 314, 'medium', 'structural_gap', 'task.gleam',
  'tasks has 46 of 60 columns missing from Gleam Task struct - 77% of data invisible',
  'Gleam Task has 14 fields. DB has 60 columns. Missing: type, category, error_category, tags, agent_id, session_id, executor metadata, delegation, progress tracking, encryption fields. Most are nullable so reads work but data is lost.',
  'task.gleam:16-30 Task struct. DB tasks has 60 columns per struct_field_inventory.',
  '77% of task data is invisible to Gleam. No progress tracking, no delegation, no error categorization, no executor metadata. Tasks are severely underrepresented.');

-- #315: issues has 16 of 31 columns missing from Gleam Issue struct
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 315, 'medium', 'structural_gap', 'issue_db.gleam',
  'issues has 16 of 31 columns missing from Gleam Issue struct - 52% of data invisible',
  'Gleam Issue has 15 fields. DB has 31 columns. Missing: project_id (NOT NULL!), task_id, resolution, resolved_by, tags, metadata, assignee, assignee_type, review_id, milestone_id. project_id NOT NULL causes INSERT failures.',
  'issue_types.gleam:29-44 Issue struct. DB issues has 31 columns per struct_field_inventory.',
  '52% of issue data invisible. Cannot link issues to tasks or reviews. No assignment tracking. No resolution details. project_id NOT NULL blocks creation.');
