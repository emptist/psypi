-- 027n_type_alignment_audit.sql
-- Comprehensive type alignment audit: PG column types vs Gleam decoder types
-- Based on systematic verification of all 22 psypi tables and their Gleam decoders
--
-- KEY FACTS (verified from node-postgres docs and pi_ffi.mjs source):
-- 1. uuid → JS string (no ::text needed for decode.string)
-- 2. timestamptz → JS Date object (MUST use ::text for decode.string)
-- 3. bigint/COUNT(*) → JS string (MUST use ::int cast in SQL or ::text + parse in Gleam)
-- 4. jsonb → JS parsed object (MUST use ::text for decode.string, or custom decoder)
-- 5. integer → JS number (decode.int works)
-- 6. boolean → JS boolean (decode.bool works)
-- 7. text/varchar → JS string (decode.string works)
-- 8. ARRAY → JS array (decode.list works for text arrays)

-- ============================================================================
-- RETRACT: Pure uuid-without-::text findings (already done, verify count)
-- ============================================================================
-- 11 findings retracted in previous step: #200-#205, #212, #216, #219, #220, #222

-- ============================================================================
-- CORRECT: Mixed uuid+timestamptz findings (already done, verify)
-- ============================================================================
-- #217, #218 corrected to medium (timestamptz only), #221 corrected to medium

-- ============================================================================
-- NEW FINDINGS: Type alignment bugs discovered during systematic audit
-- ============================================================================

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES

-- TA-1: task.gleam result column is jsonb but decoded as string
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 274, 'high', 'type_mismatch', 'task',
 'task.gleam: result column is jsonb but decoded as decode.optional(decode.string)',
 'The tasks.result column is jsonb in PostgreSQL. node-postgres returns jsonb as a parsed JavaScript object, but the Gleam decoder uses decode.optional(decode.string) which expects a string. This causes decode failure for any task with a non-null result. Both task.list() and task.get() SELECT the result column without ::text cast.',
 'task.gleam:58 decode.field("result", decode.optional(decode.string)); tasks table: result jsonb; node-postgres returns parsed object for jsonb',
 'task.list() and task.get() will fail with DecodeError whenever a task has a non-null result value. Since result is populated on task completion, this means completed tasks cannot be listed or retrieved.'),

-- TA-2: task.get() missing project_id in SELECT
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 275, 'medium', 'missing_column', 'task',
 'task.gleam: get() SELECT missing project_id column that decoder expects',
 'task.get() SELECTs 13 columns but the task_decoder expects 14 fields including project_id. The project_id field is Optional in the decoder, but decode.optional(decode.string) still requires the field to exist in the row object. Since project_id is not in the SELECT, the field is absent from the JS object, causing decode failure.',
 'task.gleam:229 SELECT includes created_at::text but not project_id; task.gleam:66 decode.field("project_id", decode.optional(decode.string))',
 'task.get() always fails with DecodeError because project_id field is missing from the query result. The list() function correctly includes project_id::text.'),

-- TA-3: memory.search() SELECT * includes created_at (timestamptz) without ::text
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 276, 'high', 'type_mismatch', 'memory',
 'memory.gleam: search() SELECT * returns created_at as timestamptz without ::text cast',
 'memory.search() uses "SELECT * FROM memory" which includes created_at (timestamptz). node-postgres returns timestamptz as JS Date object, but the Gleam decoder uses decode.string. This causes decode failure for every memory row with a non-null created_at.',
 'memory.gleam:97 SELECT * FROM memory; memory table: created_at timestamp with time zone; memory.gleam:47 decode.field("created_at", decode.string)',
 'memory.search() always fails with DecodeError because created_at is returned as JS Date object, not string. The memory search Pi tool (psypi-memory-search) is completely non-functional.'),

-- TA-4: memory.save() RETURNING id then decodes with full memory_decoder
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 277, 'high', 'logic_error', 'memory',
 'memory.gleam: save() RETURNING id then decodes with full memory_decoder (expects all 7 fields)',
 'memory.save() does "INSERT INTO memory ... RETURNING id" which only returns the id column. But the code then tries to decode the result row with memory_decoder() which expects id, content, tags, source, agent_id, importance, and created_at. Since only id is present, the decode fails for all other fields.',
 'memory.gleam:86 RETURNING id; memory.gleam:91 decode.run(row, memory_decoder()) which expects 7 fields',
 'memory.save() always fails with DecodeError after successful INSERT. The memory is saved to DB but the function returns an error, so the caller never gets the id. The psypi-memory-save tool appears to fail even though data is persisted.'),

-- TA-5: skill.gleam get() and search() missing ::text for content (jsonb) and reference_list (jsonb)
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 278, 'high', 'type_mismatch', 'skill',
 'skill.gleam: get() and search() missing ::text cast for content and reference_list (both jsonb)',
 'skill.list() correctly uses content::text and reference_list::text, but skill.get() and skill.search() SELECT these columns without ::text cast. Since both are jsonb in PostgreSQL, node-postgres returns parsed JS objects, but the Gleam decoder uses decode.optional(decode.string) which expects strings.',
 'skill.gleam:184 SELECT ... created_at::text, content, reference_list (no ::text); skills table: content jsonb, reference_list jsonb; skill.gleam:96 decode.field("content", decode.optional(decode.string))',
 'skill.get() and skill.search() fail with DecodeError for any skill with non-null content or reference_list. Since content stores the skill instructions, most skills will have content, making these functions mostly non-functional.'),

-- TA-6: monitor_ai.gleam auto_file_issue() uses column "type" but table has "issue_type"
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 279, 'high', 'schema_mismatch', 'monitor_ai',
 'monitor_ai.gleam: auto_file_issue() INSERT uses column "type" but issues table has "issue_type"',
 'auto_file_issue() does "INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment)" but the issues table column is named "issue_type" not "type". PostgreSQL will reject this with "column type does not exist".',
 'monitor_ai.gleam:559 INSERT INTO issues (..., type, ...); issues table: issue_type text NOT NULL',
 'auto_file_issue() always fails with SQL error. Tool errors are never auto-filed as issues, so the monitoring system has no self-healing capability for tool failures.'),

-- TA-7: monitor_ai.gleam auto_file_issue() missing project_id (NOT NULL, no default)
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 280, 'high', 'missing_column', 'monitor_ai',
 'monitor_ai.gleam: auto_file_issue() missing project_id (NOT NULL, no default) in INSERT',
 'auto_file_issue() INSERT INTO issues does not include project_id. The issues table has project_id uuid NOT NULL with no default value. Even if the "type" column name were fixed, the INSERT would fail with NOT NULL constraint violation.',
 'monitor_ai.gleam:559 INSERT INTO issues (title, description, severity, type, ...); issues table: project_id uuid NOT NULL (no default)',
 'auto_file_issue() always fails. Combined with #279 (wrong column name), this function has two independent bugs that each prevent it from working.'),

-- TA-8: areflect.gleam save_issue() missing project_id (NOT NULL, no default)
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 281, 'high', 'missing_column', 'areflect',
 'areflect.gleam: save_issue() missing project_id (NOT NULL, no default) in INSERT',
 'save_issue() does "INSERT INTO issues (title, description, severity, created_by)" but issues.project_id is uuid NOT NULL with no default. The INSERT will fail with NOT NULL constraint violation.',
 'areflect.gleam:228 INSERT INTO issues (title, description, severity, created_by); issues table: project_id uuid NOT NULL (no default)',
 'areflect.gleam save_issue() always fails. The psypi-areflect tool cannot save [ISSUE] markers to the database. All issue extraction from agent reflections is silently lost.'),

-- TA-9: a_db_reader.is_s_still_idle() COUNT(*) as cnt decoded as decode.int (bigint→string)
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 282, 'medium', 'type_mismatch', 'a_db_reader',
 'a_db_reader.gleam: is_s_still_idle() COUNT(*) decoded as decode.int but node-postgres returns bigint as string',
 'is_s_still_idle() does "SELECT COUNT(*) as cnt" and decodes with decode.field("cnt", decode.int). node-postgres returns bigint (int8) as JavaScript string, but decode.int expects a number. The decode always fails, and the error handler returns Ok(True) (assumes idle). This is the same issue as #244 but with the correct root cause: bigint type mismatch, not missing ::text.',
 'a_db_reader.gleam:49 SELECT COUNT(*) as cnt; a_db_reader.gleam:56 decode.field("cnt", decode.int); node-postgres docs: int8 returned as string',
 'is_s_still_idle() always returns Ok(True) because the decode fails and the error handler defaults to True. However, ctx_is_idle is the primary idle check per user confirmation, so this is a redundant secondary guard that defaults to the safe value. Impact is low in practice but the function is technically broken.'),

-- TA-10: broadcast.stats() 3 independent bugs (confirmed)
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 283, 'high', 'type_mismatch', 'broadcast',
 'broadcast.gleam: stats() has 3 independent bugs: bigint decode, text>=int comparison, missing status column',
 'broadcast.stats() has 3 bugs verified against database schema: (1) COUNT(*) returns bigint → node-postgres returns string → decode.int expects number → FAILS; (2) priority is text column, "priority >= 2" does lexicographic comparison → always false for text values like "low"/"normal"/"high"/"critical"; (3) project_communications has no "status" column → FILTER (WHERE status = sent) causes SQL error.',
 'broadcast.gleam:233 COUNT(*) as total with decode.int; broadcast.gleam:236 priority >= 2 (text vs int); project_communications table: no status column',
 'broadcast.stats() always fails. Bug 3 (missing column) causes SQL error, so bugs 1 and 2 are never reached. The stats function is completely non-functional.'),

-- TA-11: inter_review.gleam requested_at timestamptz without ::text (3 queries)
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 284, 'high', 'type_mismatch', 'inter_review',
 'inter_review.gleam: 3 queries SELECT requested_at (timestamptz) without ::text cast',
 'inter_review.gleam has 3 queries that SELECT requested_at without ::text cast: get_review_details() line 148, list_reviews() lines 283 and 285. node-postgres returns timestamptz as JS Date object, but the Gleam decoder uses decode.string. All 3 queries fail with DecodeError.',
 'inter_review.gleam:148,283,285 SELECT ... requested_at FROM inter_reviews (no ::text); inter_reviews table: requested_at timestamp with time zone; inter_review.gleam:117 decode.field("requested_at", decode.string)',
 'get_review_details() and list_reviews() always fail with DecodeError. This blocks tool_commit (which calls get_review_details) and any listing of inter-reviews. The inter-review system is completely non-functional for reading review results.'),

-- TA-12: areflect.gleam save_learning() inserts into learning_insights, not learnings table
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 285, 'medium', 'schema_mismatch', 'areflect',
 'areflect.gleam: save_learning() inserts into learning_insights table but psypi also has learnings table',
 'save_learning() does "INSERT INTO learning_insights (insight_type, title, content, confidence)" but the psypi project also has a learnings table. It is unclear which table is the correct target. The learning_insights table may belong to another project (nezha/nupi) in the shared database.',
 'areflect.gleam:253 INSERT INTO learning_insights; database has both learning_insights and learnings tables',
 'Learnings from areflect may be written to the wrong table, or may be mixed with data from other projects in the shared database. If learning_insights belongs to another project, psypi learnings are being stored in the wrong location.'),

-- TA-13: Comprehensive type alignment summary
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 286, 'medium', 'type_alignment', 'multiple',
 'Type alignment audit: 8 modules have timestamptz/jsonb/bigint decode mismatches',
 'Systematic audit of all 22 psypi tables and their Gleam decoders found type mismatches in 8 modules: (1) inter_review.gleam: requested_at timestamptz without ::text (3 queries); (2) memory.gleam: created_at timestamptz without ::text, RETURNING id decoded with full decoder; (3) task.gleam: result jsonb decoded as string, get() missing project_id; (4) skill.gleam: content/reference_list jsonb without ::text in get()/search(); (5) broadcast.gleam: COUNT(*) bigint decoded as int, text>=int comparison, missing status column; (6) a_db_reader.gleam: COUNT(*) bigint decoded as int; (7) monitor_ai.gleam: auto_file_issue() wrong column name + missing project_id; (8) areflect.gleam: save_issue() missing project_id. Modules with correct type handling: issue_db.gleam, meeting.gleam, event_hooks.gleam, agents.gleam, monitor.gleam, system_review_db.gleam, code_version.gleam (uses SQL functions).',
 'Full source code audit of all *.gleam files with DB queries, cross-referenced with information_schema.columns for all 22 tables',
 'This finding serves as a cross-reference for the individual type mismatch findings (#274-#285). The pattern is consistent: developers did not account for node-postgres type conversions when writing Gleam decoders. The correct patterns (used in issue_db.gleam, meeting.gleam, etc.) are: (1) always cast timestamptz to ::text, (2) always cast jsonb to ::text when using decode.string, (3) always cast COUNT(*) to ::int or use ::text + int.parse, (4) verify column names match between SQL and table schema.')

ON CONFLICT DO NOTHING;

-- ============================================================================
-- CORRECT: Update existing findings with verified type alignment facts
-- ============================================================================

-- #100: Already correct (timestamptz without ::text), but add cross-reference
UPDATE review_findings SET
  description = description || ' CROSS-REF: See #284 for the same issue across all 3 inter_review queries.',
  evidence = 'inter_review.gleam:148,283,285 SELECT requested_at without ::text; inter_reviews.requested_at is timestamptz; node-postgres returns Date object; decode.string expects string'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 100;

-- #116: Already correct (missing project_id in areflect save_issue), add cross-reference
UPDATE review_findings SET
  description = description || ' CROSS-REF: See #281 for same issue with verified root cause (project_id uuid NOT NULL no default).',
  severity = 'high'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 116;

-- #138: Already correct (memory.save RETURNING id decoded with full decoder), add cross-reference
UPDATE review_findings SET
  description = description || ' CROSS-REF: See #277 for verified analysis. RETURNING id only returns id column, but memory_decoder expects 7 fields.',
  severity = 'high'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 138;

-- #139: Already correct (broadcast.stats 3 bugs), add cross-reference
UPDATE review_findings SET
  description = description || ' CROSS-REF: See #283 for verified analysis with node-postgres type mapping evidence.',
  severity = 'high'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 139;

-- #244: Correct root cause — it is bigint type mismatch, not missing ::text
UPDATE review_findings SET
  title = 'is_s_still_idle() COUNT(*) bigint decoded as decode.int (should be ::int cast or ::text+parse)',
  description = 'a_db_reader.is_s_still_idle() does "SELECT COUNT(*) as cnt" and decodes with decode.int. node-postgres returns bigint (int8) as JavaScript string, but decode.int expects a number. The decode always fails, and the error handler returns Ok(True). This is a bigint type mismatch, not a missing ::text issue. However, ctx_is_idle is the primary idle check (confirmed by user), so this redundant secondary guard defaulting to True has low practical impact.',
  severity = 'medium',
  evidence = 'a_db_reader.gleam:49 SELECT COUNT(*) as cnt; a_db_reader.gleam:56 decode.field("cnt", decode.int); node-postgres docs: int8/bigint returned as JS string; ctx_is_idle is primary check (hook_on_agent_end.gleam:18)'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 244;

-- ============================================================================
-- Update table_documentation with type alignment reference
-- ============================================================================

INSERT INTO table_documentation (table_name, description, key_columns, related_tables, verification_notes)
VALUES (
  'type_alignment_reference',
  'Virtual reference: node-postgres type mapping rules for psypi Gleam decoders. uuid→string (no cast needed), timestamptz→Date (MUST cast ::text), bigint/int8→string (MUST cast ::int or ::text+parse), jsonb→object (MUST cast ::text for decode.string), integer→number (decode.int works), boolean→boolean (decode.bool works), text/varchar→string (decode.string works), ARRAY→array (decode.list works for text[])',
  'See finding #286 for complete audit results',
  'All 22 psypi tables',
  'To verify: (1) psql -d psypi -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name IN (...psypi tables...)" (2) Check each Gleam decoder for matching types (3) Verify ::text casts for timestamptz/jsonb columns (4) Verify ::int casts for COUNT(*)/bigint columns'
) ON CONFLICT (table_name) DO UPDATE SET
  description = EXCLUDED.description,
  key_columns = EXCLUDED.key_columns,
  related_tables = EXCLUDED.related_tables,
  verification_notes = EXCLUDED.verification_notes;
