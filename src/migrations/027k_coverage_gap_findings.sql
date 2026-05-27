-- Migration: 027k_coverage_gap_findings.sql
-- Add findings from old review not yet covered in DB review

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
-- #264: tool_commit permanently blocked by NULL overall_score
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 264, 'high', 'logic_error', 'tool_commit',
 'tool_commit permanently blocked: overall_score is always NULL because a_orchestrator never writes review response to DB',
 'tool_commit.commit_if_reviewed() checks review.overall_score. If None, returns "Review not yet complete". Since a_orchestrator never writes the review response to inter_reviews (finding #247), overall_score stays NULL forever. The entire commit workflow is dead at Phase 2.',
 'tool_commit.gleam:44 case review.overall_score { None -> Error("Review not yet complete...") }; inter_reviews table: overall_score column is NULL for all rows because no code writes it; a_orchestrator.gleam: no UPDATE inter_reviews SET overall_score=...',
 'Commits are permanently blocked. The psypi-commit tool can never succeed in Phase 2. Users must commit manually outside the tool.'),

-- #265: seed.gleam multi-statement SQL silently drops statements
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 265, 'high', 'logic_error', 'seed',
 'seed.gleam multi-statement SQL: node-postgres may only execute first statement, silently dropping rest',
 'seed.gleam passes multi-statement SQL strings (e.g. INSERT...; INSERT...; INSERT...) to db.query(). node-postgres may only execute the first statement and silently drop the rest. This means agent_souls and agent_prefixes may only get the first row seeded.',
 'seed.gleam:42 "INSERT INTO agent_souls ... SELECT ''A''...; INSERT INTO agent_souls ... SELECT ''S''..."; seed.gleam:56 "INSERT INTO agent_prefixes ... SELECT ''A''...; INSERT INTO agent_prefixes ... SELECT ''S''...; INSERT INTO agent_prefixes ... SELECT ''G''..."; node-postgres documentation: multi-statement queries may return only first result',
 'Only the first soul (A) and first prefix (A) may be seeded. S and G prefixes/souls may be missing, causing identity and session failures.'),

-- #266: 8 instances of Error(_) -> Ok(default) silently swallowing errors
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 266, 'medium', 'error_handling', 'multiple',
 '8 instances of Error(_) -> Ok(default) silently swallow errors across 3 modules',
 'Multiple modules catch decode errors and return Ok with a default value instead of propagating the error. This makes debugging impossible because failures are invisible. Found in: system_review_db.gleam (5: FuPending, Pending, None, Medium, FindingOpen), issue_db.gleam (1: Ok(0)), a_db_reader.gleam (1: Ok(True)).',
 'system_review_db.gleam:62 Error(_) -> FuPending; :66 Error(_) -> Pending; :96 Error(_) -> None; :119 Error(_) -> Medium; :123 Error(_) -> FindingOpen; issue_db.gleam:251 Error(_) -> Ok(0); a_db_reader.gleam:44 Error(_) -> Ok(True)',
 'Decode failures are invisible. Wrong data is returned as if correct. a_db_reader returning Ok(True) on error means is_s_still_idle always returns True even when the query fails.'),

-- #267: hook double-trigger: before_agent_start and agent_start both fire
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 267, 'medium', 'logic_error', 'event_hooks',
 'record_trigger called twice per agent start: before_agent_start and agent_start both trigger on same event',
 'hook_on_before_agent_start calls record_trigger("before_agent_start") and hook_on_agent_start calls record_trigger("agent_start"). Both hooks fire on the same agent start event, creating duplicate trigger records in event_hooks table. This inflates trigger counts and may confuse monitoring.',
 'hook_on_before_agent_start.gleam:8 record_trigger("before_agent_start"); hook_on_agent_start.gleam:7 record_trigger("agent_start"); extension_generator.gleam registers both as session_start hooks',
 'Duplicate trigger records inflate event counts. Monitoring based on trigger counts will be inaccurate.'),

-- #268: extension_generator uses raw JSON schema instead of TypeBox
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 268, 'low', 'design', 'extension_generator',
 'extension_generator uses raw JSON schema for tool parameters instead of Pi SDK recommended TypeBox',
 'Pi SDK documentation recommends using Type.Object() from typebox for tool parameter definitions. psypi generates inline JSON schema objects instead. While this works (registerTool accepts JSON schema), it misses TypeBox features like validation and Google-compatible enums (StringEnum).',
 'pi_tool_call.gleam:161 params_to_js() generates { "type": "object", "properties": {...} } instead of Type.Object({...}); Pi SDK docs: "import { Type } from typebox"; examples use Type.Object, Type.String',
 'No functional breakage, but misses TypeBox validation and enum features. Parameters with constrained values (enums) cannot be expressed.'),

-- #269: simple_migrate.gleam also affected by multi-statement SQL
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 269, 'medium', 'logic_error', 'simple_migrate',
 'simple_migrate.gleam may silently drop multi-statement migration scripts',
 'simple_migrate.gleam reads SQL files and passes them to db.query(). Migration scripts containing multiple statements (e.g. CREATE TABLE followed by CREATE INDEX) may only have the first statement executed, silently dropping the rest. Unlike seed.gleam, migrations are critical for schema correctness.',
 'simple_migrate.gleam reads .sql files and passes content directly to db.query(); migration files like 027_review_findings.sql contain multiple statements; node-postgres may only execute first statement',
 'Schema may be partially applied. Tables created but indexes/constraints/triggers silently dropped. This is worse than seed because it affects schema correctness.'),

-- #270: schema drift - migration scripts have no tracking table
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 270, 'medium', 'design', 'simple_migrate',
 'No migration tracking table: simple_migrate runs all scripts every time with no record of which were applied',
 'simple_migrate.gleam has no tracking table (like schema_migrations) to record which migration scripts have been applied. It uses IF NOT EXISTS / WHERE NOT EXISTS patterns instead. This means: (1) all scripts run every startup, (2) no way to know current schema version, (3) failed migrations are silently retried, (4) no rollback capability.',
 'simple_migrate.gleam: no CREATE TABLE schema_migrations; no INSERT INTO schema_migrations; all SQL uses IF NOT EXISTS / WHERE NOT EXISTS patterns; grep -rh "schema_migrations" src/ returns nothing',
 'No way to determine current schema version. Failed migrations are invisible. No rollback. All scripts run every startup (wasteful). Schema drift between environments is undetectable.');

-- Update finding #247 to cross-reference #264
UPDATE review_findings SET
  impact = impact || ' Additionally, tool_commit is permanently blocked because overall_score is never written (see #264).'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 247;
