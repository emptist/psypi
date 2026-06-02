-- Migration 045: Open an issue documenting the table design principle that
-- long-text fields (single TEXT column holding a multi-page markdown blob)
-- are a design smell. When the content is structurally sectioned (e.g. a
-- soul with 20+ ## sections), prefer normalizing to child rows.
--
-- 2026-06-02: This principle surfaced while reordering the A soul.
-- agent_souls.content is a single TEXT column holding ~12.5KB of markdown
-- with 21 ## sections. Editing it required:
--   - Extracting to a temp file
--   - Programmatic section reordering
--   - Re-embedding in a dollar-quoted SQL migration
--   - Synchronizing 3 places (DB, seed.gleam, 008_agent_soul.sql)
-- A normalized design (agent_soul_sections with section_id, ordering, body
-- columns) would let the same reorder be expressed as:
--   UPDATE agent_soul_sections SET section_order = 9
--     WHERE soul_id = 'A' AND heading = 'Conversational Frame';
-- 3 lines instead of 200+ lines of section extraction/embed.
--
-- This is an OPEN issue, not a fix. The principle is recorded so future
-- schema design avoids creating new long-text fields. Existing long-text
-- fields (agent_souls.content, system_directives, etc.) are not in scope
-- for immediate refactor — that would be a separate, larger effort.
--
-- Idempotent: WHERE NOT EXISTS guards against duplicate insert on re-run.

INSERT INTO issues (
    project_url, title, description, issue_type, severity, status,
    created_by, discovered_by, environment, tags, metadata
)
SELECT
    'git@github.com:emptist/psypi',
    'Table design principle: avoid long-text fields, normalize to child rows',
    $$Long-text fields (a single TEXT column holding a multi-page markdown
blob) are a design smell when the content is structurally sectioned. They
make every edit expensive, fragile, and error-prone.

OBSERVATION (2026-06-02, while reordering A's soul)
=====================================================
agent_souls.content is a single TEXT column holding ~12.5KB of markdown
with 21 `## ` sections. To move the "Conversational Frame" section from
position 20 to position 9, the workflow required:

  1. Extract DB content -> /tmp/a_soul_reordered.md (edit medium)
  2. Programmatically reorder sections with a Python script
  3. Generate migration 044 with dollar-quoted SQL embedding the new content
  4. Synchronize 3 storage locations: DB row, src/seed.gleam, 008_agent_soul.sql
  5. Verify with byte-level diff between DB and temp file

200+ lines of orchestration for a 1-section move. If the soul were
normalized into child rows, the same move would be:

  UPDATE agent_soul_sections
     SET section_order = 9
   WHERE soul_id = 'A' AND heading = 'Conversational Frame';

3 lines.

WHY THIS IS A DESIGN SMELL
==========================
1. Every edit touches the entire blob, even for a 1-section change.
2. The blob becomes a target for SQL escaping issues (single quotes, dollar
   signs, multi-byte UTF-8 Chinese characters).
3. Multiple storage locations (DB, seed scripts, migration files) must stay
   byte-identical, requiring complex synchronization scripts.
4. Diff tools show "huge change" for a tiny semantic edit, drowning out
   actual concerns in code review.
5. Authors accumulate complexity (programmatic reorder, escape rules)
   to manage what should be a trivial operation.
6. The 12.5KB soul also does not fit cleanly in many editor buffers,
   tooling windows, or diff displays.

WHEN LONG-TEXT FIELDS ARE ACCEPTABLE
====================================
- Truly free-form text with no internal structure (a chat message body,
  a user bio, a description field)
- Append-only or rarely edited content
- Where the text is the natural unit of access (the whole field is read
  or written together, never partially)

WHEN LONG-TEXT FIELDS ARE A SMELL
==================================
- Content has clear sub-structure (sections, items, list items)
- The structure needs to be queried, ordered, or partially edited
- Multiple storage locations must stay synchronized
- The field grows over time and the original size assumption is broken

PRINCIPLE
=========
When designing a table, if a text field is expected to grow beyond a
few hundred bytes AND has natural sub-structure, normalize to a child
table from the start. The cost of normalization is small; the cost of
un-normalizing a long-lived table is enormous.

EXISTING FIELDS IN SCOPE (NOT FOR IMMEDIATE FIX)
================================================
- agent_souls.content (~12.5KB, 21 sections) — refactor would need
  careful migration with no downtime for running A
- system_directives.content (size unknown) — similar shape
- Any other TEXT field > 1KB with sectioned structure

These should be tracked in follow-up issues, one per table, with
specific refactor plans. The principle here is preventive: do not
create new long-text fields without strong justification.

REFERENCE
=========
- agent_souls table: src/migrations/008_agent_soul.sql
- Recent edit: src/migrations/044_a_soul_reorder_conversational_frame.sql
- Edit medium: /tmp/a_soul_reordered.md (now deleted)
- Related skill: TBD (a skill for "designing tables" should reference
  this principle)$$,
    'improvement',
    'medium',
    'open',
    'psypi',
    'nezha',
    'development',
    ARRAY['schema-design','principle','long-text','normalization','preventive'],
    jsonb_build_object(
        'observation_date', '2026-06-02',
        'trigger', 'Reorder of A soul Conversational Frame section',
        'related_migrations', ARRAY['043','044'],
        'related_files', ARRAY[
            'src/migrations/008_agent_soul.sql',
            'src/migrations/044_a_soul_reorder_conversational_frame.sql',
            'src/seed.gleam'
        ],
        'in_scope_tables', ARRAY['agent_souls','system_directives'],
        'out_of_scope', 'Refactor of existing long-text fields is NOT in scope of this issue'
    )
WHERE NOT EXISTS (
    SELECT 1 FROM issues
    WHERE project_url = 'git@github.com:emptist/psypi'
      AND title = 'Table design principle: avoid long-text fields, normalize to child rows'
);
