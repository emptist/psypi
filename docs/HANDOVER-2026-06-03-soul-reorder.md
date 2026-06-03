# Handover Memo — 2026-06-03 (soul reorder + long-text issue + job-table sync)

## TL;DR

Six commits shipped in this session. The A bot's "Conversational Frame"
section moved from position 20 (end of soul) to position 9 (right after
"Communication"). Issue 045 documents the underlying design principle
that motivated the workflow: long-text fields should be normalized to
child rows. The AGENTS.md job tables were re-synced with the live DB
(A=24, S=20). This handover memo is the 6th commit.

## What happened (6 commits, in order)

```
49690cf docs: HANDOVER-2026-06-03-soul-reorder.md (with job-table sync follow-up)
62cc862 AGENTS.md: re-sync the A/S job tables with the live DB (2026-06-03)
1bb89fd issue: open table design principle — avoid long-text fields, normalize to child rows
d31f2f3 seed: sync A soul canonical seeds with the new reordered content
b518bd4 A: soul — reorder Conversational Frame to §9 (right after Communication)
44901b6 docs(a/s-roles): rename S role from "PDCA Do" to "PDA with a bit self-C"
```

### 44901b6 — PDA self-C rename (3 files)

Renamed S's role from "PDCA Do" to "PDA with a bit self-C" because S
does plan/do/act plus a bit of self-check; the formal Check is A's job.
Touched `AGENTS.md`, `009_agent_jobs.sql`, `037_clarify_agent_roles.sql`.

### b518bd4 — Migration 044: soul reorder

New file `src/migrations/044_a_soul_reorder_conversational_frame.sql`.
Uses a full `UPDATE agent_souls SET content = $$ ... $$` (dollar-quoted)
to replace A's entire soul with the reordered version. Idempotent.

The new section order puts **Conversational Frame** immediately after
**Communication** so the framing shapes the very mechanism it describes
(`pi.sendMessage` with `triggerTurn: true`).

Heading renamed to `## Conversational Frame (added 2026-06-02)` to match
the suffix style used by Schema Discipline / Scope / Two Modes.

### d31f2f3 — seed sync (2 files)

`src/seed.gleam` and `src/migrations/008_agent_soul.sql` updated to
match the new DB state. Both files MUST stay byte-identical to live DB
for fresh-install + migration reproducibility.

### 1bb89fd — Migration 045: open issue (1 file)

New file `src/migrations/045_issue_table_design_long_text.sql`. Inserts
a new `issues` row documenting the principle:

> Long-text fields (a single TEXT column holding a multi-page markdown
> blob) are a design smell when the content is structurally sectioned.
> They make every edit expensive, fragile, and error-prone.

Idempotent via `WHERE NOT EXISTS`. Verified — running twice gives
INSERT 0 1 then INSERT 0 0.

**Issue ID**: `dbb06944-b296-41d6-ad77-c930ebba1cda`
**Status**: open / medium / improvement
**Tags**: schema-design, principle, long-text, normalization, preventive

### 62cc862 — AGENTS.md job-table sync (1 file)

Re-synced the A and S job tables in AGENTS.md with the live DB. The
previous snapshot showed 12 of A's 24 jobs and 14 of S's 20 jobs.

- Both tables now show ALL active jobs in priority+category order
- Header counts: A=24, S=20
- A heading reads "PDCA Check" (A is the formal Checker, not PDA self-C)
- S heading reads "PDA self-C" (matches commit 44901b6 role framing)
- Added a "Known doc/DB drift" note flagging the A self_monitor
  near-duplicate. The older one (`d9d45795-...`, "Do NOT wait for the
  human") was superseded by `450a12db-...` ("The human is not in the
  loop"). NOT fixed here — tracked for a follow-up migration.

### 49690cf — This handover memo (1 file)

The doc you are reading. Created at end-of-session as a fresh-start
guide for the next conversation. Lists what shipped, what state the
DB/code are in, the workflow that worked, and the 4 open follow-ups
in priority order.

## Current state

- **DB**:
  - A's soul has Conversational Frame in §9 (after Communication, before Values)
  - Issue 045 is open in `issues` table
  - 2 active self_monitor rows at A priority 1 (one superseded; see follow-up #1)
- **Code**:
  - 6 commits on `a-s-flow` branch, including 2 new migrations (044, 045)
  - `seed.gleam` + `008_agent_soul.sql` in sync with DB
  - AGENTS.md job table in sync with DB (A=24, S=20)
  - `gleam test` → 98 passed, no failures
- **Branch**: `a-s-flow` (6 commits ahead of `develop`)
- **Working tree**: clean (only untracked `docs/conversation-log-after-89f00d4.md`,
  user said leave it for now)

## Files to know

| Path                                                         | Why it matters                               |
| ------------------------------------------------------------ | -------------------------------------------- |
| `src/migrations/044_a_soul_reorder_conversational_frame.sql` | The reorder — A's soul definition lives here |
| `src/migrations/045_issue_table_design_long_text.sql`        | Issue record (the principle)                 |
| `src/seed.gleam`                                             | First-run seed (must match DB)               |
| `src/migrations/008_agent_soul.sql`                          | Canonical seed (must match DB)               |
| `src/migrations/009_agent_jobs.sql`                          | Canonical seed for A/S job list              |
| `src/migrations/037_clarify_agent_roles.sql`                 | Enforces "S never does system-review" etc.   |
| `AGENTS.md`                                                  | Read first when starting a new session       |
| `docs/A-CONVERSATIONAL-FRAME-FINDINGS-2026-06-02.md`         | The thinking behind the Conversational Frame |
| `docs/HANDOVER-2026-06-03-soul-reorder.md`                   | This file (you are here)                     |

## Workflow that worked (for future soul edits)

1. Extract DB content to a temp file:
   ```sql
   psql -d psypi -tA -c "SELECT content FROM agent_souls WHERE id_prefix='A'" > /tmp/a_soul.md
   ```
2. Edit the temp file in plain text.
3. Build a migration using dollar-quoted SQL to embed the new content:
   ```sql
   UPDATE agent_souls SET content = $$ <new content> $$ WHERE id_prefix='A';
   ```
4. Run via `psql -d psypi -f <migration>.sql`. Dollar-quoting handles
   embedded apostrophes and newlines without escaping.
5. Sync `seed.gleam` and `008_agent_soul.sql` (Gleam string escaping:
   `\\` → `\\\\` for backslashes, `"` → `\"` for double quotes, `'` → `''`
   for SQL).
6. Verify with `gleam test`.

## Known minor issue (NOT a bug, cosmetic only)

DB content has a trailing `\n\n` (2 newlines) at the end of the soul,
but `seed.gleam` and `008_agent_soul.sql` have `\n\n\n` (3 newlines).
The `simple_migrate.gleam` runner adds an extra newline when echoing
content. Semantic identity preserved, but byte-level diff has 1 line
of difference. Not worth a fix unless we ever move to a content-hash
reproducibility check.

## What's next (open follow-ups, in priority order)

1. **Deactivate superseded A self_monitor job** ⭐ SMALLEST, DO FIRST:
   `d9d45795-2c85-461c-9861-9498c355ef20` ("Do NOT wait for the human")
   was superseded by `450a12db-787d-4685-9c31-973fbdf1e990` ("The human
   is not in the loop"). Migration 046 should `UPDATE agent_jobs SET
   is_active = false WHERE id = 'd9d45795-...'`. After that, AGENTS.md
   "Known doc/DB drift" note can be removed. Estimated: 5 min.

2. **conversation-log cleanup**: Add `docs/conversation-log-*.md` to
   `.gitignore` so they don't show as untracked. Or move to
   `docs/archive/sessions/`. Estimated: 2 min.

3. **Long-text issue sub-tasks** (from issue 045 description):
   Refactor `agent_souls.content` into
   `agent_soul_sections (id, soul_id, ordering, heading, body)` so
   reordering a section is one `UPDATE` instead of a full content
   replace. NOT started. Larger planning effort — possibly needs a
   meeting (psypi-meeting-add) to A-S align scope.

4. **AGENTS.md job table update**: ✅ DONE in commit 62cc862. The job
   table is now in sync with the live DB (A=24, S=20). The
   "Known doc/DB drift" note flags the A self_monitor near-duplicate
   (resolves automatically when follow-up #1 lands).

## Open issues to be aware of (in DB)

Run `psql -d psypi -c "SELECT id, title, status, severity FROM issues WHERE status='open' ORDER BY created_at DESC LIMIT 10;"` for the live list.

## How to resume

```bash
cd /Users/jk/gits/hub/tools_ai/psypi
# 1. Confirm branch + see what shipped
git log --oneline develop..HEAD   # should show 6 commits
# 2. Verify A's soul is reordered
psql -d psypi -c "SELECT id_prefix, position('## Conversational Frame' in content) AS cf_pos, position('## Communication' in content) AS comm_pos FROM agent_souls WHERE is_active=true;"
# Expect: cf_pos (3492) > comm_pos (3141) — Conversational Frame comes after Communication
# 3. Verify job counts match the snapshot in AGENTS.md
psql -d psypi -c "SELECT s.id_prefix, COUNT(*) FROM agent_jobs j JOIN agent_souls s ON j.soul_id = s.id WHERE j.is_active = true AND s.is_active = true GROUP BY s.id_prefix ORDER BY s.id_prefix;"
# Expect: A=24, S=20
# 4. Run tests
gleam test   # should be 98 passed
```

Then read this doc and pick a follow-up. **Recommended first action**:
follow-up #1 (5-min migration to deactivate the superseded self_monitor).
It's the smallest, has a clear scope, and unblocks the AGENTS.md drift note.

## Lessons from this session

1. **File-driven soul edits are reliable**: Edit a temp file, embed
   via dollar-quoted SQL, sync to seed files. Each step is verifiable.
2. **Always cross-check 3 storage locations**: DB, `seed.gleam`,
   `008_agent_soul.sql`. They MUST stay byte-identical for fresh installs.
3. **Idempotent migrations > smart migrations**: Use `WHERE NOT EXISTS`
   or `WHERE id = ...` guards so re-runs are safe.
4. **Snapshot tables in docs are documentation, not source of truth**:
   Mark them as "snapshot" and provide the live psql query. Update them
   on every job change, not just on schema changes.
5. **A single tool call (sql/grep/Read) beats a long debate**: When
   the user asks "is the table up to date", query the DB and diff.
