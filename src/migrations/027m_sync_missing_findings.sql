-- Migration: 027m_sync_missing_findings.sql
-- Findings #261 and #262 were inserted directly via psql; this file ensures they are tracked in git
-- Also includes table_documentation updates that were done directly

-- These INSERTs are idempotent: they will fail silently if the rows already exist
-- (using ON CONFLICT DO NOTHING since finding_number+review_id is unique)

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 261, 'high', 'logic_error', 'multiple',
 'A-bot wakeup chain: get_config FFI type mismatch prevents debounce from working',
 'The A-bot wakeup chain has a critical FFI type mismatch: get_config in pi_extension_ffi.mjs returns JS null/string, but hook_on_agent_end.gleam pattern-matches on option.None/option.Some. Since JS null is not Gleam None, the debounce logic cannot function. Additionally: (1) compose() is called instead of compose_within_budget() so prompt may exceed context (#251), (2) a_orchestrator never writes inter-review response to DB (#247). The is_s_still_idle() DB guard always returns True but this is harmless since ctx_is_idle is the primary source of truth (not #244).',
 'hook_on_agent_end.gleam:34 get_config never matches; a_orchestrator.gleam:66 compose() not compose_within_budget(); a_orchestrator.gleam: no INSERT INTO inter_reviews; ctx_is_idle is the primary idle check (line 18)',
 'get_config FFI mismatch means debounce state cannot be read/written correctly. A-bot may wake up every turn (no debounce) or never wake up (crash on pattern match). The inter-review and compose_within_budget issues compound the problem but are separate fixable items.'),
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 262, 'high', 'config_desync', 'pi_extension_ffi',
 'Dual config stores: FFI _configStore (in-memory) and psypi_config table (DB) are never synchronized',
 'hook_on_agent_end.gleam uses pi_extension.get_config/set_config which goes to FFI _configStore (in-memory JS object). psypi_config.gleam has its own get/set that reads/writes the psypi_config DB table. These two stores are completely independent. Setting a value via one is invisible to the other. Process restart loses all _configStore data.',
 'pi_extension_ffi.mjs: let _configStore = {}; get_config reads _configStore; psypi_config.gleam: SELECT value FROM psypi_config WHERE key = $1; hook_on_agent_end.gleam uses pi_extension.get_config not psypi_config.get',
 'idle_since and monitor_debounce_ms are stored in _configStore (in-memory) but never persisted to DB. On process restart all debounce state is lost. psypi_config table exists but is not used by the debounce logic.')
ON CONFLICT (review_id, finding_number) DO NOTHING;

-- Update table_documentation for system_reviews and review_findings
UPDATE table_documentation SET
  key_columns = '["id (UUID PK)", "project_id (UUID FK)", "review_type (TEXT)", "status (TEXT CHECK: draft/in_progress/completed/archived)", "created_at (TIMESTAMPTZ)", "completed_at (TIMESTAMPTZ)"]'::jsonb,
  related_tables = ARRAY['review_findings (child, FK review_id -> system_reviews.id)', 'projects (parent, FK project_id)'],
  notes = 'To verify: SELECT * FROM system_reviews WHERE project_id = (SELECT id FROM projects WHERE name = ''psypi''); Check status is one of: draft, in_progress, completed, archived. Use review_id to join review_findings.'
WHERE table_name = 'system_reviews';

UPDATE table_documentation SET
  key_columns = '["id (UUID PK)", "review_id (UUID FK -> system_reviews.id)", "finding_number (INT)", "severity (TEXT CHECK: critical/high/medium/low/cosmetic)", "category (TEXT)", "module (TEXT)", "title (TEXT)", "status (TEXT CHECK: open/fixed/retracted/duplicate/wont_fix)", "description (TEXT)", "evidence (TEXT)", "impact (TEXT)"]'::jsonb,
  related_tables = ARRAY['system_reviews (parent, FK review_id)'],
  notes = 'To verify review completeness: (1) SELECT severity, COUNT(*) FROM review_findings WHERE review_id = ''<uuid>'' GROUP BY severity; (2) Check each finding has non-empty evidence field; (3) Verify status values match CHECK constraint; (4) Cross-reference finding.module against actual Gleam source files in src/; (5) Generate markdown report: python3 scripts/generate_review_md.py > docs/SYSTEM-REVIEW-DB-<date>.md; (6) Any AI can query: SELECT title, severity, evidence FROM review_findings WHERE review_id = ''<uuid>'' AND severity IN (''critical'', ''high'') AND status = ''open'' ORDER BY finding_number;'
WHERE table_name = 'review_findings';
