-- Migration 058: Add tool_documentation and key_concept_definitions tables
--
-- Two new tables to solve the "AI keeps asking the same questions" problem:
--
-- 1. tool_documentation: proper documentation for psypi tools, with
--    append-only pattern, usage examples, and anti-patterns.
--    (Existing tool_definitions table is empty and lacks append-only
--     fields and usage notes — we add columns to it instead of creating
--     a new table, to avoid schema duplication.)
--
-- 2. key_concept_definitions: a dictionary of concepts that AI agents
--    repeatedly get wrong because there's no shared vocabulary.
--    Examples: is_archived vs is_active, append-only, turn-based dialogue,
--    A/S roles, debounce timer, etc.
--
-- Online-safe: yes (< 1 second)

-- ═══════════════════════════════════════════════════════════════════
-- 1. Extend tool_definitions with append-only + documentation fields
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE tool_definitions ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;
ALTER TABLE tool_definitions ADD COLUMN IF NOT EXISTS is_archived boolean NOT NULL DEFAULT false;
ALTER TABLE tool_definitions ADD COLUMN IF NOT EXISTS usage_notes text;
ALTER TABLE tool_definitions ADD COLUMN IF NOT EXISTS anti_patterns text;
ALTER TABLE tool_definitions ADD COLUMN IF NOT EXISTS returns_description text;
ALTER TABLE tool_definitions ADD COLUMN IF NOT EXISTS examples jsonb DEFAULT '[]'::jsonb;

-- Partial unique index: at most one active non-archived row per tool_name
CREATE UNIQUE INDEX IF NOT EXISTS uq_tool_definitions_active_name
  ON tool_definitions (tool_name) WHERE is_active = true AND is_archived = false;

-- save_tool_version function (append-only, same pattern as save_job_version)
CREATE OR REPLACE FUNCTION save_tool_version(
  p_tool_name text,
  p_description text,
  p_parameters jsonb,
  p_category text,
  p_usage_notes text,
  p_anti_patterns text,
  p_returns_description text,
  p_examples jsonb
) RETURNS uuid AS $$
DECLARE
  v_new_id uuid;
  v_existing_id uuid;
BEGIN
  -- Find existing active non-archived row
  SELECT id INTO v_existing_id FROM tool_definitions
  WHERE tool_name = p_tool_name AND is_active = true AND is_archived = false LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    -- Archive the old row (ONLY set is_archived, do NOT touch is_active)
    UPDATE tool_definitions SET is_archived = true WHERE id = v_existing_id;
  END IF;

  INSERT INTO tool_definitions (tool_name, description, parameters, category,
    usage_notes, anti_patterns, returns_description, examples, is_active, is_archived)
  VALUES (p_tool_name, p_description, p_parameters, p_category,
    p_usage_notes, p_anti_patterns, p_returns_description, p_examples, true, false)
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════
-- 2. Create key_concept_definitions table
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS key_concept_definitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  concept_key text NOT NULL,            -- stable slug: "append-only", "is_archived"
  term text NOT NULL,                   -- short name: "Append-Only Pattern"
  definition text NOT NULL,             -- precise definition
  context text,                         -- when/where this applies
  examples text,                        -- correct usage examples
  anti_patterns text,                   -- common mistakes to avoid
  related_concepts text[] DEFAULT '{}', -- links to other concept_keys
  category text NOT NULL DEFAULT 'general', -- grouping: "database", "agent", "architecture"
  is_active boolean NOT NULL DEFAULT true,
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Partial unique index: at most one active non-archived row per concept_key
CREATE UNIQUE INDEX uq_key_concepts_active_key
  ON key_concept_definitions (concept_key) WHERE is_active = true AND is_archived = false;

-- save_concept_version function (append-only)
CREATE OR REPLACE FUNCTION save_concept_version(
  p_concept_key text,
  p_term text,
  p_definition text,
  p_context text,
  p_examples text,
  p_anti_patterns text,
  p_related_concepts text[],
  p_category text
) RETURNS uuid AS $$
DECLARE
  v_new_id uuid;
  v_existing_id uuid;
BEGIN
  SELECT id INTO v_existing_id FROM key_concept_definitions
  WHERE concept_key = p_concept_key AND is_active = true AND is_archived = false LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    UPDATE key_concept_definitions SET is_archived = true WHERE id = v_existing_id;
  END IF;

  INSERT INTO key_concept_definitions (concept_key, term, definition, context,
    examples, anti_patterns, related_concepts, category, is_active, is_archived)
  VALUES (p_concept_key, p_term, p_definition, p_context,
    p_examples, p_anti_patterns, p_related_concepts, p_category, true, false)
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════
-- 3. Seed initial key concepts
-- ═══════════════════════════════════════════════════════════════════

-- 3a. is_archived (primary gate)
INSERT INTO key_concept_definitions (concept_key, term, definition, context, examples, anti_patterns, related_concepts, category) VALUES
('is_archived', 'is_archived (Primary Gate)',
 'The primary visibility gate for append-only tables. When is_archived = true, the row is historical — the application never reads it regardless of other flags. When is_archived = false, the row is alive and may be read (subject to is_active). Versioning functions (save_soul_version, save_job_version, etc.) ONLY set is_archived = true on old rows — they never change is_active.',
 'Applies to: agent_souls, agent_jobs, skills, tool_definitions, key_concept_definitions — any append-only table.',
 'Read path: WHERE is_active = true AND is_archived = false. Archiving: UPDATE SET is_archived = true (never set false again in normal flow). Un-archiving: possible but rare — is_active retains its original business value.',
 'Setting is_active = false when archiving (destroys business semantics). Using is_archived as the only filter (must also check is_active). Creating partial unique indexes with only WHERE is_active = true (must be WHERE is_active = true AND is_archived = false).',
 ARRAY['is_active', 'append-only'],
 'database');

-- 3b. is_active (business flag)
INSERT INTO key_concept_definitions (concept_key, term, definition, context, examples, anti_patterns, related_concepts, category) VALUES
('is_active', 'is_active (Business Flag)',
 'A business-level flag indicating whether a row is enabled or disabled. This is NOT a versioning field — versioning functions must NEVER change it. If a row is archived (is_archived = true) and later un-archived, is_active should still reflect its original business value.',
 'Applies to: agent_souls, agent_jobs, skills, tool_definitions, key_concept_definitions.',
 'A soul with is_active = true is enabled. A soul with is_active = false is disabled (e.g., temporarily turned off). Archiving does NOT change is_active.',
 'Letting versioning functions set is_active = false on old rows (this destroys the original business value and makes un-archiving unsafe). Confusing is_active with "current version" — that role belongs to is_archived.',
 ARRAY['is_archived', 'append-only'],
 'database');

-- 3c. append-only pattern
INSERT INTO key_concept_definitions (concept_key, term, definition, context, examples, anti_patterns, related_concepts, category) VALUES
('append-only', 'Append-Only Pattern',
 'A data versioning pattern where rows are never UPDATEd in place. Instead, a new row is INSERTed and the old row is archived (is_archived = true). This preserves full change history. The current version is identified by is_active = true AND is_archived = false.',
 'Use for: configuration tables, identity tables, any table where change history matters and reads are frequent. Do NOT use for: write-once logs (already append-only), transactional status transitions (UPDATE is correct).',
 'save_soul_version(soul_id, new_content) — archives old row, inserts new. save_job_version(soul_id, job_key, new_job, priority, category) — same pattern.',
 'UPDATE agent_souls SET content = ... (destroys history). Setting is_active = false in versioning functions (destroys business semantics). Forgetting partial unique indexes (causes duplicate active rows).',
 ARRAY['is_archived', 'is_active'],
 'architecture');

-- 3d. turn-based dialogue
INSERT INTO key_concept_definitions (concept_key, term, definition, context, examples, anti_patterns, related_concepts, category) VALUES
('turn-based-dialogue', 'Turn-Based Dialogue (A/S Communication)',
 'A and S take turns speaking — one sends a message, the other reads and responds. A can ask S for any data (file contents, query results, system state). S provides the raw evidence. A evaluates the evidence and forms its own judgment. A never delegates judgment — A delegates data collection only.',
 'A has no tools (no file access, no DB queries, no shell). S has all tools. When A needs information, A asks S via pi.sendMessage(). S investigates and reports back in its next turn. A then evaluates.',
 'A: "S, check prelude.mjs for the List class and report back what methods it has. I''ll evaluate." → S reads file, reports evidence → A: "The List class has toArray(), so the bug report is wrong."',
 'A saying "S, verify this and let me know if it''s true" (delegates judgment). A accepting bug reports without evidence. A saying "I cannot check this" (A CAN check — through S). Treating A-S communication as one-way delegation instead of dialogue.',
 ARRAY['a-bot', 's-bot', 'debounce-timer'],
 'agent');

-- 3e. A-bot
INSERT INTO key_concept_definitions (concept_key, term, definition, context, examples, anti_patterns, related_concepts, category) VALUES
('a-bot', 'A-bot (Autonomic Agent)',
 'The Check phase of PDCA. Activates when S has been continuously idle for the debounce period. Has NO tools — cannot read files, run queries, or call Pi tools. Can only: (1) read its user_prompt (soul + jobs + recent context), (2) write to ctx.ui.notify() (internal thinking), (3) send messages to S via pi.sendMessage() with triggerTurn: true. Primary job: review S''s work, verify claims, enforce standards, identify issues.',
 'A is activated by the debounce timer in extension.js. On agent_end: set timer. On agent_start or input: clear timer. Timer fires → A runs. A never interrupts S.',
 'A reviews S''s code change → finds potential issue → asks S to check a specific file → S reports back → A evaluates evidence and concludes.',
 'Giving A tools (breaks the A/S separation). A making code changes (A reviews, S executes). A accepting claims without evidence. A using alarming language without confirmed evidence.',
 ARRAY['s-bot', 'turn-based-dialogue', 'debounce-timer'],
 'agent');

-- 3f. S-bot
INSERT INTO key_concept_definitions (concept_key, term, definition, context, examples, anti_patterns, related_concepts, category) VALUES
('s-bot', 'S-bot (Somatic Agent)',
 'The Plan/Do/Act phases of PDCA. Has all psypi-* Pi tools. Executes tasks, writes code, runs queries. When A asks for data, S provides raw evidence — S does not evaluate for A. S responds to A''s inter-review findings by addressing them.',
 'S is activated by user input or by A''s sendMessage(). S works continuously while the user is active. When S stops, the debounce timer starts for A.',
 'S receives A''s inter-review → addresses findings → if A asked for data, provides the raw evidence (file contents, query results).',
 'S evaluating evidence on A''s behalf (A evaluates, S collects). S ignoring A''s data requests. S making changes without addressing A''s findings.',
 ARRAY['a-bot', 'turn-based-dialogue'],
 'agent');

-- 3g. debounce timer
INSERT INTO key_concept_definitions (concept_key, term, definition, context, examples, anti_patterns, related_concepts, category) VALUES
('debounce-timer', 'Debounce Timer',
 'A setTimeout in extension.js that determines when A-bot activates. On agent_end: clear any existing timer, set new timer (monitor_debounce_ms). On agent_start and input: clear timer immediately. The timer ONLY fires if S has been continuously idle for the full debounce period — like graduating from 6 years of school, you must attend continuously.',
 'The debounce duration is a design choice, not a bug. If A doesn''t fire, S hasn''t been idle long enough. Never reduce debounce time as a "fix".',
 'S finishes work → agent_end fires → timer starts → 30s of continuous idle → timer fires → A runs. User types → input fires → timer cleared → A does NOT run.',
 'Reducing debounce time because "A doesn''t fire enough". Firing A immediately on agent_end without debounce. Confusing "S is idle now" with "S has been continuously idle for the debounce period".',
 ARRAY['a-bot'],
 'architecture');

-- 3h. zero-handwritten-js
INSERT INTO key_concept_definitions (concept_key, term, definition, context, examples, anti_patterns, related_concepts, category) VALUES
('zero-handwritten-js', 'Zero Hand-Written JS',
 'All JavaScript in the project is produced by exactly three mechanisms: (1) Gleam compilation (build/ directory .mjs files), (2) FFI bridge files (*_ffi.mjs), (3) Extension generator (structured Gleam types → JS text). No JS is ever written as string literals in Gleam code. All JS generation is type-driven and mechanical.',
 'Applies to: pi_tool_call.gleam (PiToolCall/PiEventHook types generate extension.js), *_ffi.mjs files (hand-written but isolated), build/ output (auto-generated).',
 'FnArgument type → generates function call arguments. ParamSrc type → generates parameter extraction code. HookGuard type → generates conditional execution. ResultFormat type → generates result processing.',
 'Writing JS string literals in Gleam code (use structured types instead). Using JsLiteral/CustomJs types (deleted — never reintroduce). Creating FFI for logic that can be written in Gleam. Directly editing build/ directory files.',
 ARRAY['append-only'],
 'architecture');

-- ═══════════════════════════════════════════════════════════════════
-- 4. Add table_documentation entries for new tables
-- ═══════════════════════════════════════════════════════════════════

-- Update existing tool_definitions entry
UPDATE table_documentation SET
  purpose = 'Documentation for psypi Pi tools with append-only versioning',
  usage_context = 'AI agents query this to understand available tools and their usage',
  key_columns = '{"id": "uuid PK", "tool_name": "text - unique tool name (e.g. psypi-issues)", "description": "text - what the tool does", "parameters": "jsonb - parameter schema", "category": "text - tool category", "usage_notes": "text - important usage notes", "anti_patterns": "text - common mistakes", "returns_description": "text - what the tool returns", "examples": "jsonb - usage examples", "is_active": "boolean - business flag (NOT touched by versioning)", "is_archived": "boolean - primary gate (true = historical)"}'::jsonb,
  notes = 'Append-only table. Use save_tool_version() for updates. Versioning ONLY sets is_archived=true, never changes is_active. Read path: WHERE is_active=true AND is_archived=false.',
  tags = ARRAY['tools', 'documentation']
WHERE table_name = 'tool_definitions';

-- Insert new entry for key_concept_definitions
INSERT INTO table_documentation (table_name, purpose, usage_context, key_columns, notes, ai_can_modify, tags)
VALUES

('key_concept_definitions', 'Dictionary of key concepts that AI agents need to understand — prevents repeated explanations and misunderstandings', 'AI agents query this as a shared vocabulary/dictionary',
 '{"id": "uuid PK", "concept_key": "text - stable slug (e.g. append-only)", "term": "text - short name", "definition": "text - precise definition", "context": "text - when/where this applies", "examples": "text - correct usage examples", "anti_patterns": "text - common mistakes to avoid", "related_concepts": "text[] - links to other concept_keys", "category": "text - grouping", "is_active": "boolean - business flag (NOT touched by versioning)", "is_archived": "boolean - primary gate (true = historical)"}',
 'Append-only table. Use save_concept_version() for updates. Versioning ONLY sets is_archived=true, never changes is_active. Read path: WHERE is_active=true AND is_archived=false. This table IS the single source of truth for concept definitions — if a concept is not here, it needs to be added.',
 true, ARRAY['concepts', 'dictionary', 'documentation']);

-- ═══════════════════════════════════════════════════════════════════
-- Verification
-- ═══════════════════════════════════════════════════════════════════

SELECT 'tool_definitions columns' as check_name,
  COUNT(*) as has_append_only_fields
FROM information_schema.columns
WHERE table_name = 'tool_definitions' AND column_name IN ('is_active', 'is_archived', 'usage_notes', 'anti_patterns');

SELECT 'key_concept_definitions' as check_name, COUNT(*) as seeded_concepts
FROM key_concept_definitions WHERE is_active = true AND is_archived = false;

SELECT 'table_documentation' as check_name, COUNT(*) as documented
FROM table_documentation WHERE table_name IN ('tool_definitions', 'key_concept_definitions');
