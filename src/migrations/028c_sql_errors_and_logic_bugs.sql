-- 028c_sql_errors_and_logic_bugs.sql
-- SQL errors and logic bugs found during module-by-module review
-- Previous finding max: 374

-- Finding #375: monitor_ai.gleam auto_file_issue() uses 'type' instead of 'issue_type'
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  375, 'critical', 'sql_error', 'monitor_ai',
  'monitor_ai.gleam auto_file_issue() uses column "type" instead of "issue_type" — guaranteed runtime failure',
  'The auto_file_issue() function in monitor_ai.gleam contains: INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment). The issues table has no "type" column — it is called "issue_type". This INSERT will fail with "column ''type'' of relation ''issues'' does not exist" on every call. This means tool errors can never be auto-filed as issues.',
  'monitor_ai.gleam:561: INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment). Verified: psql returns ERROR: column "type" of relation "issues" does not exist. The correct column name is "issue_type" (NOT NULL, default ''bug'').',
  'open'
);

-- Finding #376: a_db_reader.gleam filters issues by non-existent 'closed' status
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  376, 'medium', 'logic_bug', 'a_db_reader',
  'a_db_reader.gleam read_open_issues() filters by non-existent "closed" status — wont_fix/duplicate issues shown as open',
  'read_open_issues() uses WHERE status NOT IN (''resolved'',''closed''). The issues.status CHECK constraint allows: open/acknowledged/in_progress/resolved/wont_fix/duplicate. There is no "closed" value. This means wont_fix and duplicate issues are NOT filtered out and appear in the "open issues" list shown to the A-bot. This could mislead the A-bot into thinking there are more open issues than there actually are.',
  'a_db_reader.gleam:167: FROM issues WHERE status NOT IN (''resolved'',''closed''). DB CHECK: CHECK ((status = ANY (ARRAY[''open'', ''acknowledged'', ''in_progress'', ''resolved'', ''wont_fix'', ''duplicate'']))). No "closed" value exists. Should be: NOT IN (''resolved'', ''wont_fix'', ''duplicate'').',
  'open'
);

-- Finding #377: meeting_opinions.position not decoded in meeting.gleam Opinion struct
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  377, 'medium', 'missing_field', 'meeting',
  'meeting_opinions.position column not decoded — data silently discarded when reading opinions',
  'The meeting_opinions table has a position column with CHECK constraint (support/oppose/neutral). The meeting.gleam Opinion struct has no position field. The SELECT query in list_opinions() does not include position. When add_opinion() writes a position value, it is never read back. The position data is silently discarded on read.',
  'meeting.gleam:27 Opinion struct has: id, meeting_id, author, perspective, reasoning, created_at. No position field. meeting.gleam:271 SELECT id::text, meeting_id::text, author, perspective, reasoning, created_at::text FROM meeting_opinions — position not selected. meeting.gleam:238 INSERT INTO meeting_opinions (meeting_id, author, perspective, reasoning, position) — position IS written.',
  'open'
);

-- Finding #378: areflect.gleam creates tasks without project_id — uses hardcoded default
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  378, 'low', 'data_quality', 'areflect',
  'areflect.gleam creates tasks without project_id — uses hardcoded default UUID',
  'areflect.gleam:262 INSERT INTO tasks (title, description, priority, created_by) does not include project_id. The tasks.project_id column is NOT NULL with default ''0d324e68-b399-4b85-bd8a-6b1ef7b46168''. This means all areflect-created tasks are assigned to a hardcoded default project, not the current project. Tasks created via areflect will be invisible to project-scoped queries.',
  'areflect.gleam:262: INSERT INTO tasks (title, description, priority, created_by). tasks.project_id default: ''0d324e68-b399-4b85-bd8a-6b1ef7b46168''. task.gleam:141 correctly includes project_id parameter.',
  'open'
);

-- Finding #379: areflect.gleam creates issues without project_id — uses no default
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  379, 'low', 'data_quality', 'areflect',
  'areflect.gleam creates issues without project_id — project_id is nullable, issues have no project context',
  'areflect.gleam:224 INSERT INTO issues (title, description, severity, created_by) does not include project_id. The issues.project_id column is nullable with no default. This means all areflect-created issues have NULL project_id, making them invisible to project-scoped queries. Compare with issue_db.gleam:88 which correctly includes project_id.',
  'areflect.gleam:224: INSERT INTO issues (title, description, severity, created_by). issues.project_id is nullable. issue_db.gleam:88: INSERT INTO issues (title, description, severity, issue_type, created_by, project_id) — includes project_id.',
  'open'
);

-- Finding #380: broadcast.gleam send() never sets status — BroadcastStatus never written to DB
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  380, 'high', 'logic_bug', 'broadcast',
  'broadcast.gleam send() never sets status — BroadcastStatus type is never written to or read from DB',
  'The send() function INSERT INTO project_communications (project_id, from_ai, message_type, content, priority, metadata) has no status column. The list()/get_recent() functions hardcode ''sent'' as status alias. The BroadcastStatus type (Pending/Sent/Failed/Cancelled) is never written to or read from the database. All broadcasts are always "Sent" regardless of actual delivery status. The entire BroadcastStatus type is dead code.',
  'broadcast.gleam:135 INSERT INTO project_communications (project_id, from_ai, message_type, content, priority, metadata) — no status column. broadcast.gleam:204 ''sent'' as status — hardcoded alias. project_communications has no status column at all.',
  'open'
);
