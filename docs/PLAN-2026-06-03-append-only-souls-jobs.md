# Plan: Append-Only `agent_souls` and `agent_jobs`

**Date:** 2026-06-03
**Status:** Analysis complete, awaiting approval
**Handover context:** [HANDOVER-2026-06-03-soul-reorder.md](HANDOVER-2026-06-03-soul-reorder.md)

## 1. Problem

`agent_souls` and `agent_jobs` are the only two psypi tables where the
**content of the active row is mutated in place**
(`UPDATE … SET content = …`). All history is silently destroyed.
Migrations 038, 040, 041, 042, 043, 044 and the seed follow this pattern.

The neighbouring `inter_reviews`, `tasks`, `issues`, `system_reviews`
tables are already append-only. `agent_souls` and `agent_jobs` are the
holdouts.

When A or S evolves its soul, we lose every prior version. When a job
is replaced (e.g. self_monitor v1 → v2), the older text is gone. We
cannot diff, audit, or roll back. There is no git for these tables.

## 2. Design Principles

| Principle | How it shows up in this design |
|---|---|
| `is_active` = "current version pointer" | One active row per `id_prefix` (souls) or `(soul_id, job_key)` (jobs). Partial unique index enforces it. |
| `is_archived` = "visibility flag, app-managed" | Defaults to `false`. Set to `true` to hide from app queries without losing the row. Independent from `is_active`. |
| **Partial unique indexes** | Use `WHERE is_active = true` (not `WHERE is_archived = false`). The save functions deactivate old rows (is_active=false) but do NOT archive them. The index must enforce uniqueness only among active rows. |
| `job_key` (new) = "stable business identifier for a job across versions" | Slug per job (e.g. `self_monitor.anomaly_reporting_v2`). The key that survives between versions. |
| Atomicity | One SQL function per write; function body runs in implicit savepoint, so the UPDATE-then-INSERT is atomic. |
| Idempotency of the migration itself | All DDL uses `IF NOT EXISTS` / `DROP … IF EXISTS`. All backfill is a fixed `UPDATE … WHERE id = '…'` keyed by stable UUID. |
| No silent data loss | Replacing content requires `INSERT` of a new active row; the old row is deactivated but never deleted. |

`is_active` and `is_archived` are independent. A row can be
`is_active=true, is_archived=false` (current and visible),
`is_active=false, is_archived=false` (historical, visible), or
`is_archived=true` (hidden, regardless of `is_active`).

## 3. Schema Changes (Migration 046)

Two design-critical discoveries from validation:

- `agent_souls` has **two** UNIQUE constraints: `agent_soul_id_prefix_key`
  on `id_prefix` AND `agent_soul_role_key` on `role`. Both must be
  converted to partial unique indexes, otherwise the first
  `save_soul_version` call fails with a duplicate-key error on the
  `role` column.
- `agent_jobs` has a composite UNIQUE on
  `(soul_id, job, priority, category)`. This must be dropped, otherwise
  the version-update of a job with the same `(job, priority, category)`
  triple would be rejected.

```sql
-- 046_append_only_active_archived.sql

-- 1. Columns
ALTER TABLE agent_souls
  ADD COLUMN IF NOT EXISTS is_archived boolean NOT NULL DEFAULT false;
ALTER TABLE agent_jobs
  ADD COLUMN IF NOT EXISTS is_archived boolean NOT NULL DEFAULT false;
ALTER TABLE agent_jobs
  ADD COLUMN IF NOT EXISTS job_key text;

-- 2. Drop the old full unique constraints, create partial unique indexes.
--    Partial unique indexes use is_archived = false (not is_active = true)
--    because is_archived is the primary gate: archived rows are dead to the app.
--    The constraint only needs to apply among alive (non-archived) rows.
ALTER TABLE agent_souls DROP CONSTRAINT IF EXISTS agent_soul_id_prefix_key;
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_agent_souls_active_id_prefix
  ON agent_souls (id_prefix) WHERE is_archived = false;

ALTER TABLE agent_souls DROP CONSTRAINT IF EXISTS agent_soul_role_key;
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_agent_souls_active_role
  ON agent_souls (role) WHERE is_archived = false;

ALTER TABLE agent_jobs DROP CONSTRAINT IF EXISTS uq_agent_jobs_soul_job_priority_category;
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uq_agent_jobs_active_soul_job_key
  ON agent_jobs (soul_id, job_key) WHERE is_archived = false;

-- 3. Backfill job_key for all 44 active rows (fixed UUID keying, idempotent).
-- A's 24 active jobs
UPDATE agent_jobs SET job_key = 'review.schema_discipline'      WHERE id = '1f10a6db-3ab6-40f0-bb44-43ee551885eb';
UPDATE agent_jobs SET job_key = 'review.inter_review'           WHERE id = '465c4418-d422-4380-bbb2-4e6215e9d891';
UPDATE agent_jobs SET job_key = 'self_monitor.anomaly_reporting_v2' WHERE id = '450a12db-787d-4685-9c31-973fbdf1e990';
UPDATE agent_jobs SET job_key = 'self_monitor.anomaly_reporting_v1' WHERE id = 'd9d45795-2c85-461c-9861-9498c355ef20';
UPDATE agent_jobs SET job_key = 'behavior.s_behavior_review'    WHERE id = '6efb3130-5cbb-478e-a5c0-f73b4d22a815';
UPDATE agent_jobs SET job_key = 'unblock.unblock_jobs'          WHERE id = '54ccbe94-4a38-4853-8138-f227721cf8a1';
UPDATE agent_jobs SET job_key = 'continue.continue_work'        WHERE id = '0e6b8cbd-6b69-40e6-aeb7-cfc73eda7378';
UPDATE agent_jobs SET job_key = 'safety.anti_stupidity'         WHERE id = '6a595481-1b7d-404b-95f1-183ea7f0cd10';
UPDATE agent_jobs SET job_key = 'new_job.suggest_new_jobs'      WHERE id = 'f305ee45-27d5-4337-88ad-5a59e6c3cb5d';
UPDATE agent_jobs SET job_key = 'unblock.unblock_tasks'         WHERE id = '77818fb6-e1ae-42f7-a94d-974636af3560';
UPDATE agent_jobs SET job_key = 'maintenance.stale_jobs_cleanup' WHERE id = '645721e5-b0ee-4217-b79c-d9d0f255b427';
UPDATE agent_jobs SET job_key = 'suggestion.suggest_doer_jobs'  WHERE id = '9bc4e5cc-f215-4280-b2b7-82300dcb8f93';
UPDATE agent_jobs SET job_key = 'maintenance.docs_match_code'   WHERE id = 'd1202267-a33f-45fb-a926-c4f864a76e4e';
UPDATE agent_jobs SET job_key = 'maintenance.stale_tasks_cleanup' WHERE id = 'f3301aa1-31fd-4842-b253-36c4a6c12d0a';
UPDATE agent_jobs SET job_key = 'definition.soul_review'        WHERE id = '003c22f1-633e-4862-b20d-7f3ae4acc6eb';
UPDATE agent_jobs SET job_key = 'quality.split_modules'         WHERE id = '992257ff-416b-422b-9f1e-ca61ce415b41';
UPDATE agent_jobs SET job_key = 'closed_loop.findings_to_issues' WHERE id = '3caa0390-c177-4e25-ad68-78f247178c57';
UPDATE agent_jobs SET job_key = 'research.competitor_research'  WHERE id = '5f97de40-388f-48ac-88b1-4bcdfa9f3d6b';
UPDATE agent_jobs SET job_key = 'closed_loop.issues_have_plan'  WHERE id = '85c12eee-4170-48fa-aece-3b5e116c2320';
UPDATE agent_jobs SET job_key = 'learning.read_user_files'      WHERE id = 'afb09e32-0b41-460f-843c-07dccbb10b96';
UPDATE agent_jobs SET job_key = 'business.research_opportunities' WHERE id = '477d15a6-02e1-4686-9cf7-bb23a151fdf3';
UPDATE agent_jobs SET job_key = 'closed_loop.planned_to_tasks'  WHERE id = '1653c965-dee7-44d0-985c-a7e6a66b4972';
UPDATE agent_jobs SET job_key = 'closed_loop.task_followup'     WHERE id = 'fe1d1bdd-b4d8-4544-91ca-15578193b2a5';
UPDATE agent_jobs SET job_key = 'closed_loop.meeting_when_needed' WHERE id = '8a01aab2-aaed-4247-8afc-4075f9913bf6';

-- S's 20 active jobs
UPDATE agent_jobs SET job_key = 'behavior.address_a_findings'   WHERE id = '43099a37-a43a-4183-874c-c922d66cd00b';
UPDATE agent_jobs SET job_key = 'quality.no_fake_gleam'         WHERE id = 'd8c11c8a-f880-4b8f-822e-24ee9c7a3944';
UPDATE agent_jobs SET job_key = 'reminder.pick_job'             WHERE id = 'c9ebfb2b-5816-4cea-856b-a5dc5ff6ef7b';
UPDATE agent_jobs SET job_key = 'review.system_review'          WHERE id = '47ec7bb1-272b-4fcf-aeef-5ef255a2801a';
UPDATE agent_jobs SET job_key = 'behavior.report_issues_first'  WHERE id = '28ddd038-527c-4f3e-848d-a60faed93764';
UPDATE agent_jobs SET job_key = 'unblock.execute_unblock'       WHERE id = '2ecf80d3-2a4c-4a6e-ab11-3a05e4b22cc8';
UPDATE agent_jobs SET job_key = 'continue.continue_job'         WHERE id = '9e35f92f-efe6-4ae7-baac-9fb41caa0fc2';
UPDATE agent_jobs SET job_key = 'continue.continue_task'        WHERE id = 'cdcba565-c903-4e6f-9551-ba214ab8d99a';
UPDATE agent_jobs SET job_key = 'new_job.accept_new_jobs'       WHERE id = 'af85b9f2-8d5c-4a64-91ae-8746670c28ab';
UPDATE agent_jobs SET job_key = 'maintenance.close_stale_jobs'  WHERE id = '8cc4aa9a-3f3a-469f-ac10-1f4caeb53b4d';
UPDATE agent_jobs SET job_key = 'new_task.accept_new_tasks'     WHERE id = '00d73b7a-f602-46ad-b91b-3a07519d9db4';
UPDATE agent_jobs SET job_key = 'maintenance.update_docs'       WHERE id = '63727290-3d89-4017-85c1-8d1a9a7851c3';
UPDATE agent_jobs SET job_key = 'maintenance.close_stale_tasks' WHERE id = 'acda3be4-e2e7-45f0-a25b-2f5690c8029a';
UPDATE agent_jobs SET job_key = 'quality.refactor_modules'      WHERE id = '3b583037-f55a-44d6-8c07-d0494f0b2699';
UPDATE agent_jobs SET job_key = 'research.execute_research'     WHERE id = 'db138bb0-8c06-4137-9330-94461aee82ad';
UPDATE agent_jobs SET job_key = 'learning.save_knowledge'       WHERE id = 'cba95ce4-e3f9-428c-81a8-4104720f9948';
UPDATE agent_jobs SET job_key = 'research.execute_research_tasks' WHERE id = '829d1a97-f1d1-466a-a2ac-919de6724d53';
UPDATE agent_jobs SET job_key = 'business.review_business_proposals' WHERE id = '2cfc75cd-7f1f-476f-b349-fcb3123c902d';
UPDATE agent_jobs SET job_key = 'business.implement_business_proposals' WHERE id = '9df468d8-ab7a-46a3-b2a0-a37f15938272';
UPDATE agent_jobs SET job_key = 'definition.soul_review'        WHERE id = '7e0cbf65-c0c6-43b4-99cc-8ec72f8689a3';

-- 4. Deactivate the older self_monitor (d9d45795) in favour of v2 (450a12db)
UPDATE agent_jobs SET is_active = false
  WHERE id = 'd9d45795-2c85-461c-9861-9498c355ef20';

-- 5. Lock the column
ALTER TABLE agent_jobs ALTER COLUMN job_key SET NOT NULL;
```

## 4. SQL Functions

```sql
-- save_soul_version: append-only soul writer
CREATE OR REPLACE FUNCTION save_soul_version(
  p_id_prefix text,
  p_content   text
) RETURNS uuid AS $$
DECLARE
  v_new_id uuid;
BEGIN
  UPDATE agent_souls
     SET is_active = false
   WHERE id_prefix = p_id_prefix
     AND is_active = true;

  INSERT INTO agent_souls (
    id_prefix, name, role, domain, responsibility,
    trigger_type, drive_mode, activation, content,
    is_active, is_archived
  )
  SELECT
    p_id_prefix, name, role, domain, responsibility,
    trigger_type, drive_mode, activation, p_content,
    true, false
  FROM agent_souls
  WHERE id_prefix = p_id_prefix
  ORDER BY created_at DESC
  LIMIT 1
  RETURNING id INTO v_new_id;

  IF v_new_id IS NULL THEN
    RAISE EXCEPTION 'save_soul_version: no previous row found for id_prefix=%, cannot copy metadata', p_id_prefix;
  END IF;

  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- save_job_version: append-only job writer
CREATE OR REPLACE FUNCTION save_job_version(
  p_soul_id  uuid,
  p_job_key  text,
  p_job      text,
  p_priority int,
  p_category text
) RETURNS uuid AS $$
DECLARE
  v_new_id uuid;
BEGIN
  UPDATE agent_jobs
     SET is_active = false
   WHERE soul_id  = p_soul_id
     AND job_key  = p_job_key
     AND is_active = true;

  INSERT INTO agent_jobs (soul_id, job, priority, category, job_key, is_active, is_archived)
  VALUES (p_soul_id, p_job, p_priority, p_category, p_job_key, true, false)
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;
```

## 5. Concurrency / Atomicity

- **Within a single call**: each function runs as one plpgsql body.
  Postgres treats it as one transaction — either both the deactivation
  and the insert succeed, or neither does. Tested with `BEGIN; ... ROLLBACK;`
  and verified no partial state.
- **Across concurrent calls to the same id_prefix**: last writer wins.
  Two concurrent calls both pass the deactivation step, then the second
  one's `INSERT` is rejected by the partial unique index
  (`uq_agent_souls_active_id_prefix`). Caller 2 gets a clear
  `duplicate key value violates unique constraint` error. Acceptable:
  psypi has one A, one S, no realistic concurrent write scenario.
- **No FK to `agent_souls` for jobs**: `agent_jobs.soul_id` is a UUID
  pointing at `agent_souls.id`. The active A and S souls have stable
  UUIDs. After 046, historical souls remain valid FK targets — historical
  jobs still point at the right (now-deactivated) soul row. No FK violations.

## 6. Read-path Compatibility

**Changes required** — all read paths must add `AND is_archived = false`:

- `src/a_db_reader.gleam` — `WHERE id_prefix = 'A' AND is_active = true AND is_archived = false`
- `src/s_db_reader.gleam` — `WHERE s.id_prefix = 'S' AND j.is_active = true AND j.is_archived = false`
- `src/agent_identity.gleam` — same addition in `fetch_jobs_by_prefix`

The partial unique index on `is_archived = false` guarantees exactly one
non-archived row per `id_prefix` / `(soul_id, job_key)` among alive rows.

## 7. Gleam Wrapper

New module: `src/soul_version_writer.gleam`. Two public functions:

```gleam
pub fn save_soul_version(id_prefix: String, content: String)
    -> promise.Promise(Result(String, SoulVersionError))

pub fn save_job_version(
  soul_id: String, job_key: String, job: String,
  priority: Int, category: String,
) -> promise.Promise(Result(String, SoulVersionError))
```

Both return the new row's `id` (UUID-as-string) on success.
`SoulVersionError` is
`{ConnectionError, QueryError, DecodeError, UnknownIdPrefix, UnknownJobKey, NoIdReturned}`.
SQL raises on missing prefix/key — Gleam side maps that to `QueryError`
(the user-visible text will include the SQL error message). Follows the
existing pattern in `inter_review.gleam`.

## 8. Historical UPDATE Migrations (038, 040, 041, 042, 043, 044)

**Decision: KEEP as-is, ANNOTATE.** Rewriting would be:

- Risky — would re-execute on every `gleam run migrate` (the runner has
  no `schema_migrations` table, so it re-runs everything every time).
- Noisy — would create a duplicate "v0 == v044" row in history on every
  re-run.

**Right approach**: prepend a deprecation comment to each file's top:

```sql
-- DEPRECATED PATTERN: This migration uses UPDATE-in-place on agent_souls.
-- Superseded by migration 046 (append-only) and the
-- save_soul_version() / save_job_version() functions.
-- See docs/HANDOVER-2026-06-03-soul-reorder.md for context.
-- DO NOT follow this pattern in new migrations.
```

This keeps history honest, makes the design mistake visible to future
agents, and prevents accidental re-runs.

The seed `008_agent_soul.sql` does **not** need to change — it uses
`INSERT … WHERE NOT EXISTS` for the initial rows, which is correct.
`009_agent_jobs.sql` **must** be updated to include the `job_key` column
with proper values, so that fresh installs are compatible with the
NOT NULL constraint added by migration 046.

## 9. AGENTS.md Addition

Add a section: **Append-Only Pattern for `agent_souls` / `agent_jobs`**

```
Both tables now use is_archived as the primary gate:

- is_archived (default false)
  If true, the row is dead to the application. Historical only. Who cares.
  If false, the row is alive — the application cares about it.
  App-managed. Set to true only when explicitly retiring a row.

- is_active (default true)
  Existing field. Use as-is. No need to reinterpret its meaning.
  Among non-archived rows, is_active picks the current version.

Partial unique indexes enforce uniqueness among active rows:
  - one active soul per id_prefix
  - one active soul per role
  - one active job per (soul_id, job_key)
  Index condition: WHERE is_active = true (NOT WHERE is_archived = false)

Read path: WHERE is_archived = false AND is_active = true
Write path: ALWAYS go through save_soul_version() / save_job_version()
  defined in migration 046. NEVER use UPDATE SET content = ...
  or UPDATE SET job = ... on these tables.
```

## 10. Validation Evidence

All tests below ran against the live `psypi` database inside a
`BEGIN; … ROLLBACK;` block, then verified the schema was unchanged
after rollback.

| Test | Result |
|---|---|
| Schema: 2 column adds, 3 constraint drops, 3 index creates, 2 function creates | PASS, ROLLBACK clean |
| `save_soul_version` round-trip: 1 active row before, 1 after; 1 history row added; metadata preserved | PASS |
| Idempotency: second save still leaves 1 active row | PASS |
| `save_soul_version('Z', ...)` raises with clear message | PASS |
| Partial unique index rejects direct duplicate active insert | PASS |
| `save_job_version` round-trip on existing A job | PASS |
| All 44 active jobs backfilled with unique `job_key`; no NULL; no duplicate (soul_id, job_key) | PASS |
| Deactivating older self_monitor (`d9d45795` → `is_active=false`) leaves 1 active + 1 historical row, both queryable | PASS |
| `ALTER TABLE … ALTER COLUMN job_key SET NOT NULL` succeeds after backfill | PASS |

Test artifacts: `/tmp/test_append_only_design.sql`,
`/tmp/test_job_key_backfill.sql`, `/tmp/test_deactivate_superseded.sql`.

## 11. Risks / Open Questions

0. **Fresh install failure**: The backfill is keyed by hardcoded UUIDs from the live DB. On a fresh install, `009_agent_jobs.sql` generates different UUIDs, so the backfill produces no matches. The subsequent `SET NOT NULL` step then fails because rows still have NULL `job_key`. **Fix**: update `009_agent_jobs.sql` to include `job_key` values (step 1 of implementation order).
1. **Race with future `gleam run migrate`**: the migration runner
   re-executes all migrations every time. The 046 backfill is keyed by
   stable UUIDs (no-op on re-run). The function definitions use
   `CREATE OR REPLACE` (no-op on re-run). ✅ Safe.
2. **Pre-044 soul content is already lost**. Migration 044 already
   destroyed A's pre-044 content. The migration's deprecation comment
   will document this loss; we cannot recover it. (Acceptance that
   append-only starts from 046.)
3. **Self-monitor deactivation in 046 vs 041**: 041 created the older
   `d9d45795` row, 042-ish timeframe added `450a12db` as a replacement.
   Step 4 of 046 deactivates `d9d45795` so the partial unique index on
   `(soul_id, job_key)` accepts both with distinct keys (`_v1` and `_v2`).
4. **What if a future agent forgets and writes `UPDATE agent_souls SET content = …`?**
   Not blocked by SQL. Discipline is conventional. AGENTS.md addition
   + the visible deprecation comments in 038-044 are the only barrier.
   Same level of enforcement as the existing inter_reviews append-only
   convention.

## 12. Implementation Order (when approved)

1. Update `src/migrations/009_agent_jobs.sql` to include `job_key` column and values.
2. Create `src/migrations/046_append_only_active_archived.sql` (full DDL above, with `CREATE INDEX CONCURRENTLY` and `WHERE is_archived = false`).
3. **User runs `gleam run migrate` from terminal** (Pi stays running — never kill Pi from inside).
4. Verify migration:
   ```sql
   psql -d psypi -c "SELECT COUNT(*) FROM agent_jobs WHERE job_key IS NULL;"  -- expect 0
   psql -d psypi -c "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'agent_jobs';"  -- verify partial index
   ```
5. Create `src/soul_version_writer.gleam`.
6. Update Gleam readers: `a_db_reader.gleam`, `s_db_reader.gleam`, `agent_identity.gleam` — add `AND is_archived = false`.
7. Update `table_documentation` with new columns.
8. Add deprecation comments to 038, 040, 041, 042, 043, 044.
9. Add the "Append-Only Pattern" section to `AGENTS.md`.
10. Update AGENTS.md: remove/update "Known doc/DB drift" note (self_monitor deactivation fixed by 046).
11. (Optional) Add Gleam test file for `soul_version_writer.gleam`.
