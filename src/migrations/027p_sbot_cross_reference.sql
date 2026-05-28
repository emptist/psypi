-- 027p_sbot_cross_reference.sql
-- Add verified S-bot findings that my review missed or under-weighted

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 288, 'high', 'design_flaw', 'areflect',
  'areflect.save_issue omits project_id - INSERT always fails with NOT NULL violation',
  'areflect.gleam save_issue() does INSERT INTO issues (title, description, severity, created_by) - 4 columns, no project_id. issues.project_id is NOT NULL with no default value. This INSERT always fails with constraint violation. S-bot review ab6e34f0 also identified this. My earlier finding #116 was retracted incorrectly for tasks (which HAS a default), but issues.project_id has NO default.',
  'areflect.gleam: INSERT INTO issues (title, description, severity, created_by); issues.project_id: NOT NULL, no default',
  'Every call to save_issue() fails. A-bot cannot file issues from reflections.'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 289, 'medium', 'logic_error', 'a_db_reader',
  'No code updates agent_sessions.last_heartbeat - is_s_still_idle always returns True',
  'a_db_reader.is_s_still_idle() queries WHERE status=''alive'' AND last_heartbeat > NOW() - INTERVAL ''5 minutes''. No Gleam code or FFI code ever writes to agent_sessions.last_heartbeat. No UPDATE or INSERT sets this column. The heartbeat is never refreshed, so is_s_still_idle() always returns True (count=0). However, ctx_is_idle is the primary idle check (per user confirmation), so this is a redundant secondary guard that always passes rather than a system-breaking bug.',
  'a_db_reader.gleam:34 WHERE last_heartbeat > NOW() - INTERVAL ''5 minutes''; grep for heartbeat/agent_sessions UPDATE: zero results',
  'is_s_still_idle() is a no-op guard. If ctx_is_idle were ever wrong, this DB check would not catch it.'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 290, 'high', 'logic_error', 'broadcast',
  'broadcast.stats() fails: references non-existent status column, text>=int comparison, bigint without cast',
  'broadcast.gleam stats() has 3 bugs: (1) WHERE status = ''sent'' - project_communications has no status column; (2) WHERE priority >= 2 - priority is text column, comparing text>=integer is invalid; (3) COUNT(*) returns bigint without ::INT cast, decoder uses decode.int. The stats query always errors.',
  'broadcast.gleam:258; project_communications columns: id, project_id, from_ai, to_ai, message_type, content, metadata, created_at, read_at, priority, git_hash, git_branch, environment - no status column',
  'Broadcast stats always returns error.'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 291, 'high', 'design_flaw', 'multiple',
  'No Project type in Gleam - project_id is raw String everywhere, hardcoded to single UUID',
  'psypi has no Project type, no project lookup function, and no way to resolve the current project from context. Every module that needs project_id either hardcodes the UUID or omits it entirely. The fix: create Project.resolve(ctx) that queries projects table WHERE path = ctx.cwd, auto-creates if missing, returns project UUID. S-bot review a4300fec identified this as root cause.',
  'db.gleam: hardcoded project_id in SET app.current_project_id; areflect.gleam: omits project_id; issue_db.gleam: hardcodes UUID; broadcast.gleam: passes empty string; memory.gleam: omits project_id',
  'In shared database with multiple projects, all data is either tagged wrong or fails to insert. Root cause for #280, #288, and multiple other project_id findings.'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 292, 'high', 'type_mismatch', 'meeting',
  'meeting decoder reads timestamptz without ::text - all queries fail',
  'meeting.gleam meeting_decoder() decodes created_at, consensus_at as decode.string. These are timestamptz columns. node-postgres returns timestamptz as Date object, not string. decode.string will fail. SELECT queries lack ::text cast for these columns. S-bot review a4300fec finding #9.',
  'meeting.gleam: decode.string for created_at, consensus_at (timestamptz); no ::text cast in SELECT',
  'Meeting list/get/decode fails for any row with non-null timestamptz values.'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 293, 'medium', 'design_flaw', 'memory',
  'memory.save() omits project_id - memories not scoped to project',
  'memory.gleam save() does INSERT INTO memory (content, tags, source, importance, agent_id) - no project_id. memory table has project_id column (nullable). All memories are written without project scope. In shared DB, memories from different projects are indistinguishable.',
  'memory.gleam: INSERT INTO memory without project_id; memory table: project_id column exists (nullable)',
  'Memories are not scoped to projects. Cross-project contamination possible.'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 294, 'medium', 'design_flaw', 'learning',
  'areflect.save_learning and learning.save() omit project_id - learnings not scoped',
  'areflect.gleam save_learning() does INSERT INTO learning_insights (insight_type, title, content, confidence) - no project_id. learning.gleam save() does INSERT INTO memory (content, tags, source, importance, agent_id) - no project_id. Both tables have project_id columns.',
  'areflect.gleam: INSERT INTO learning_insights without project_id; learning.gleam: INSERT INTO memory without project_id',
  'Learnings are not scoped to projects. Cross-project contamination.'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 295, 'medium', 'logic_error', 'a_db_reader',
  'a_db_reader.read_open_issues uses status=closed but DB has no closed - wont_fix/duplicate treated as open',
  'a_db_reader.gleam read_open_issues(): WHERE status NOT IN (''resolved'',''closed''). DB issues_status_check has no closed status - it has wont_fix and duplicate instead. Issues with wont_fix or duplicate status are incorrectly shown as open.',
  'a_db_reader.gleam: WHERE status NOT IN (''resolved'',''closed''); DB: issues_status_check = open, acknowledged, in_progress, resolved, wont_fix, duplicate - no closed',
  'wont_fix and duplicate issues appear as open in A-bot reports.'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 296, 'medium', 'type_coverage', 'skill',
  'skills.review_status (6 values) and skills.scan_status (5 values) completely absent from Gleam',
  'DB skills table has review_status with 6 allowed values and scan_status with 5 values. Neither field has a Gleam type definition or appears in the skill_decoder. These columns exist in DB but are completely invisible to psypi.',
  'skills table: review_status CHECK (6 values), scan_status CHECK (5 values); skill.gleam: skill_decoder reads only id, name, description, source, status, safety_score, version, author, created_at, content, reference_list',
  'Skill review workflow and scan workflow cannot be managed from Gleam.'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 297, 'medium', 'type_coverage', 'multiple',
  'DB has 43 enum columns across 26 tables; Gleam has types for only 14 - 29 enum columns have no Gleam type',
  'Complete cross-reference of every DB CHECK constraint enum column against Gleam pub type definitions. DB has 43 distinct enum columns. Gleam defines types for only 14. The remaining 29 enum columns are managed as raw strings with no type safety.',
  'Cross-reference of information_schema CHECK constraints vs Gleam pub type definitions; 43 total enum columns, 14 with Gleam types, 29 without',
  '29 enum columns have no type safety in Gleam. Invalid values pass through as strings without validation.');
