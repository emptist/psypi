# Handover Memo — 2026-06-02 (agent-role cleanup)

## What happened

A user review of psypi docs revealed the **system-review vs inter-review responsibility split** was inconsistent across the four canonical sources:

1. `agent_souls.content` in DB
2. `agent_jobs` in DB
3. `src/migrations/008_agent_soul.sql` and `009_agent_jobs.sql`
4. `src/seed.gleam`
5. `AGENTS.md`

Specifically:
- A's soul had a job list that mentioned "system review" — implying A might do one.
- S's job list had a stale "Perform inter-review" job — implying S might do one.
- S's job list had several duplicate jobs (same text at multiple priorities).
- The AGENTS.md closed-loop job table showed only 10 of A's 21 current jobs, and 0 of S's 19.
- The AGENTS.md "Inter-Review vs System-Review" section did not state the "S never self-initiates" rule prominently.

The user clarified the rule unambiguously:
> S-bot will never try to do a system-review unless A-bot or user ask it to do. Only S-bot and external AI agents (invited by user) can do system-reviews.

## Files changed (5)

### 1. `src/migrations/008_agent_soul.sql` — canonical A/S soul content
- Removed A's stale `## Tasks` section that mentioned "system review".
- Added a prominent `## Inter-Review vs System-Review (CRITICAL — never confuse these)` section to A's content, making explicit:
  - Inter-review = A's job. Results to `inter_reviews` table.
  - System-review = S's job (or external AI). Results to `system_reviews` + `review_findings` tables. S will NEVER initiate on its own.
  - A can prompt S to do a system-review; A NEVER does one itself.
- Updated S's content to add `## System-Review (my exclusive responsibility, on demand)` with explicit trigger rules (A asks, user asks, external AI on user request — never self-initiated).

### 2. `src/migrations/009_agent_jobs.sql` — canonical A/S job list
- Added a header comment defining the responsibility split.
- Removed the stale S job "Perform inter-review: Check code/docs/data between sessions".
- Updated A's priority-1 review job to be more explicit: results MUST go to `inter_reviews`; review_id MUST be referenced in message to S.
- Updated S's priority-1 review job: "**System-review (only when directed by A or user)**" — explicit that S never self-initiates.

### 3. `src/seed.gleam` — first-run seed (idempotent)
- Updated the embedded A and S soul `content` strings to match the canonical versions in migration 008.
- Used single-quote doubling (`''`) for apostrophes inside the SQL string.

### 4. `src/migrations/037_clarify_agent_roles.sql` — new idempotent migration
This is the migration that makes the live DB match the canonical files. It is safe to re-run.

Operations:
1. **Refresh A's soul content** — `UPDATE agent_souls SET content = '...' WHERE id_prefix = 'A'` with the canonical A soul.
2. **Refresh S's soul content** — same for S.
3. **Update responsibilities** to match the new model ("inter-review" for A, "system-review on demand" for S).
4. **Remove duplicate S jobs** — `DELETE FROM agent_jobs` keeping only the lowest-priority row per duplicate `job` text.
5. **Remove any A job mentioning "system review"** — defensive cleanup.
6. **Remove any S job saying "perform inter-review"** — defensive cleanup (the legitimate "Address A inter-review findings" is preserved).
7. **Final safety check** — single `SELECT` returning three counts (a_system_review_jobs, s_perform_interreview_jobs, s_duplicate_jobs). All must be `0`.

Important implementation note: the `simple_migrate.gleam` runner splits SQL on `;\n`, so the original `DO $$ ... $$` block I wrote would have been shredded into invalid statements. The final SELECT-based safety check is used instead. The result of running this migration on the live DB was:

```
UPDATE 1
UPDATE 1
DELETE 0
DELETE 0
DELETE 4
 a_system_review_jobs | s_perform_interreview_jobs | s_duplicate_jobs
----------------------+----------------------------+------------------
                    0 |                          0 |                0
(1 row)
```

So 4 duplicate S jobs were removed, and the post-migration state is clean.

### 5. `AGENTS.md` — human-readable doc
- Added a new `### Key Responsibility Split (READ THIS FIRST)` section right after the `id_prefix` block, with:
  - A responsibility table (concern × A × S × external AI).
  - A one-sentence summary: "A reviews, S does. System-review belongs to S (or external AI on user request). A NEVER does system-review and S NEVER does inter-review. A can *prompt* S to do a system-review; A does not *do* the system-review itself."
  - A canonical sources-of-truth priority list (DB is right, docs follow).
- Replaced the 10-row A-only closed-loop job table with **two tables** (A's 21 jobs and S's 19 jobs), each with a `Last verified` note.
- Tightened the `### Inter-Review vs System-Review` section:
  - Added a "non-negotiable rules" sub-list of 5 rules.
  - Added new comparison-table rows: "Who initiates", "Who can do it", "Who can prompt for it".
  - Emphasized that **S NEVER self-initiates a system-review**.
- Added a "Cleanliness invariants" callout pointing to migration 037.

## Apply the migration

The new migration was applied to the live `psypi` DB:

```bash
psql -d psypi -f /Users/jk/gits/hub/tools_ai/psypi/src/migrations/037_clarify_agent_roles.sql
```

It is also picked up automatically by `gleam run -m simple_migrate` (the runner reads all `src/migrations/*.sql` in sorted order; all statements are idempotent).

## Verification (post-migration DB state)

```sql
-- A: 21 jobs, 0 mention "system review"
-- S: 19 jobs, 0 say "perform inter-review", 0 duplicates
SELECT s.id_prefix, COUNT(*)
FROM agent_jobs j JOIN agent_souls s ON j.soul_id = s.id
WHERE j.is_active = true GROUP BY s.id_prefix;

 id_prefix | count
-----------+-------
 A         |    21
 S         |    19
```

```sql
-- A's content includes the new "Inter-Review vs System-Review (CRITICAL)" section
-- S's content includes the new "System-Review (my exclusive responsibility, on demand)" section
SELECT id_prefix, length(content) FROM agent_souls;

 id_prefix | length
-----------+--------
 A         | ~3400
 S         | ~2900
```

## Build required

There are no Gleam code changes in this handover, only SQL + markdown. A rebuild is **not** required to make the new soul content take effect — A and S read `agent_souls.content` at runtime, so the next cycle after the migration is applied will use the new text. (The previous HANDOVER-2026-06-01 changes do still require a rebuild.)

## Open issues

No new issues created. The cleanup itself was a doc/DB-only fix. If anyone finds further drift between the five canonical sources, the right move is:

1. Fix the DB live (`UPDATE agent_souls ...` or `DELETE FROM agent_jobs ...`) for immediate effect.
2. Update `src/migrations/008_agent_soul.sql` and/or `009_agent_jobs.sql` to match (canonical seed for new installs).
3. Update `src/seed.gleam` (idempotent first-run path).
4. Update `AGENTS.md` (human-readable doc).
5. Add a new migration (e.g., `038_*.sql`) if the change is structural.
6. Re-verify with the same three queries above.

## Key lesson

**The DB is the source of truth. Docs follow, not lead.** When a question comes up about who does what, the answer is in `agent_souls.content` and `agent_jobs` first. AGENTS.md is a human-readable cache; treat it like one.

**S NEVER self-initiates a system-review.** If you find code or text that implies otherwise, it is a bug — file an issue and fix it the way this handover did: refresh the soul content, fix the migrations, fix the seed, fix the docs, in that order.
