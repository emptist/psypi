# Review: Append-Only `agent_souls` and `agent_jobs` Plan

**Date:** 2026-06-03
**Reviewer:** S (OWL)
**Plan under review:** `docs/PLAN-2026-06-03-append-only-souls-jobs.md`
**Status:** Review complete — findings below

---

## 1. Summary

The external AI's plan is **well-researched, thorough, and largely correct**. It correctly identifies the problem (UPDATE-in-place destroys history), proposes a sound solution (append-only with partial unique indexes), and validates it with real DB tests. The SQL functions are well-designed, the migration is idempotent, and the read-path compatibility is preserved.

However, there are **several issues** — some in the plan's details, some in what the plan omits, and some in the broader context that the external AI couldn't have known about from the files alone.

**Design simplification (confirmed by user):** The plan over-explains `is_active`. The actual design is simple:
- `is_archived = false` → row is alive, application cares about it
- `is_archived = true` → row is dead, historical only, who cares
- `is_active` → existing field, use it as-is, no need to redefine its meaning

Read path: `WHERE is_archived = false AND is_active = true`. That's it.

---

## 2. What the Plan Gets Right

| Aspect                                  | Assessment                                                                                                   |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Problem diagnosis                       | ✅ Correct — `agent_souls` and `agent_jobs` are the only two tables using UPDATE-in-place                     |
| `is_archived` as primary gate           | ✅ Sound — if archived, row is dead to the app. `is_active` is used as-is, no need to reinterpret its meaning |
| `job_key` as stable business identifier | ✅ Correct — needed because the old UNIQUE on `(soul_id, job, priority, category)` blocks versioned inserts   |
| Partial unique indexes                  | ✅ Correct approach — replaces full UNIQUE constraints                                                        |
| SQL function atomicity                  | ✅ Correct — single plpgsql body = implicit savepoint                                                         |
| Idempotency of migration                | ✅ All DDL uses IF NOT EXISTS, backfill keyed by stable UUID                                                  |
| Read-path compatibility                 | ✅ Confirmed — both `a_db_reader.gleam` and `s_db_reader.gleam` already filter on `is_active = true`          |
| Deprecation comments for old migrations | ✅ Right approach — don't rewrite history, annotate it                                                        |
| Validation evidence                     | ✅ The external AI ran real tests against the live DB                                                         |

---

## 3. Issues Found

### 🔴 Issue 1: `is_archived` column is NOT in the Gleam read path — but should be

**Severity:** Medium

The plan says "No changes required" for `a_db_reader.gleam` and `s_db_reader.gleam`. This is **technically true for the current code**, but semantically wrong for the new design.

The plan's own AGENTS.md addition (§9) says:
> Read path: `WHERE is_active = true AND is_archived = false`

But the actual Gleam code reads:
```gleam
-- a_db_reader.gleam
"SELECT content FROM agent_souls WHERE id_prefix = 'A' AND is_active = true"
-- s_db_reader.gleam  
"SELECT content FROM agent_souls WHERE id_prefix = 'S' AND is_active = true"
```

Neither filters on `is_archived = false`. This means if a row has `is_active=true, is_archived=true`, the Gleam code will still load it — violating the design intent.

**The plan is inconsistent with itself.** Either:
- (a) Update the Gleam readers to add `AND is_archived = false` — this is the correct approach per the plan's own design
- (b) Remove the `is_archived` filter from the AGENTS.md addition — but then `is_archived` is useless for the read path

**Recommendation:** Option (a). Update both `a_db_reader.gleam` and `s_db_reader.gleam` to add `AND is_archived = false`. This is a 2-line change per file.

---

### 🔴 Issue 2: `seed.gleam` does NOT seed `agent_jobs` — only `agent_souls`

**Severity:** Medium

The plan says the seed files "do not need to change" because they use `INSERT ... WHERE NOT EXISTS`. But this is only half true:

- `seed.gleam` seeds `agent_souls` ✅
- `seed.gleam` does **NOT** seed `agent_jobs` ❌ — there is no `seed_agent_jobs()` function

The `agent_jobs` data comes only from `009_agent_jobs.sql`. After the migration adds `job_key` (NOT NULL), a fresh install would:
1. Run `009_agent_jobs.sql` — inserts 27 jobs (13 A + 14 S) without `job_key`
2. Run migration 046 — adds `job_key` column, backfills 44 rows by UUID

But wait — the backfill in the plan's §3 only covers the **current 44 active jobs** (24 A + 20 S). The seed `009_agent_jobs.sql` only has 27 jobs. The plan's backfill UUIDs match the **live DB state**, not the seed state. This means:

- On a **fresh install**: `009` inserts 27 jobs → migration 046 backfills 44 jobs by UUID → only the 27 seed jobs exist → 17 of the 44 backfill UUIDs won't match anything → those `UPDATE` statements are no-ops → the remaining 27 jobs get `job_key` set → ✅ works
- But the 27 seed jobs in `009` don't have `job_key` values that match the plan's backfill — the plan's backfill UUIDs are from the **live DB**, not from the seed

**This is a hidden coupling.** The plan's backfill works on the live DB but would be mostly no-ops on a fresh install (since the seed creates different UUIDs). The fresh install relies on `009` not setting `job_key`, then the backfill sets it — but the backfill UUIDs won't match the seed's UUIDs.

**Actually, re-reading more carefully:** The backfill uses `WHERE id = '...'` — if the IDs don't match, the UPDATE is a no-op, and the row remains with `job_key = NULL`. Then step 5 `ALTER TABLE ... ALTER COLUMN job_key SET NOT NULL` would **FAIL** because rows with NULL `job_key` exist.

**This is a real bug in the plan.** On a fresh install, the backfill UUIDs won't match, and the NOT NULL constraint will fail.

**Recommendation:** The backfill should not rely on hardcoded UUIDs for fresh installs. Instead:
1. Make `job_key` nullable initially (already planned)
2. Backfill with a pattern-based approach: `UPDATE agent_jobs SET job_key = category || '.' || md5(job) WHERE job_key IS NULL` — but this could create duplicates
3. **Better:** Add `job_key` to `009_agent_jobs.sql` seed with proper values, then the backfill only needs to handle the live DB migration
4. **Best:** Add `job_key` to both `009_agent_jobs.sql` AND the plan's backfill. The seed provides the canonical keys for fresh installs; the backfill handles existing DBs that don't have keys yet.

---

### 🟡 Issue 3: `agent_jobs` UNIQUE constraint change may break `037_clarify_agent_roles.sql` on re-run

**Severity:** Low

Migration 037 uses `DELETE FROM agent_jobs WHERE soul_id = (SELECT id FROM agent_souls WHERE id_prefix = 'A') AND is_active = true AND (job ILIKE '%system review%')`. After migration 046 drops the UNIQUE on `(soul_id, job, priority, category)`, this DELETE would match the same rows — no problem.

But migration 041 uses `INSERT INTO agent_jobs ... ON CONFLICT DO NOTHING` — and the ON CONFLICT targets the old unique constraint. After 046 drops that constraint, the `ON CONFLICT DO NOTHING` becomes a no-op (no conflict target), so the INSERT would create duplicates on re-run.

**However**, the plan says the migration runner re-runs everything every time. So on re-run:
- 037 would delete the duplicate
- 041 would insert again (no conflict)
- Result: duplicate re-created then deleted by 037... but 037 runs before 041 in order

Actually, the runner runs files in sorted order. `037` < `041` < `046`. So on re-run:
1. 037 runs — deletes any A job mentioning "system review"
2. 041 runs — tries to insert self-monitor job, ON CONFLICT on old constraint (which doesn't exist after 046) — but 046 hasn't run yet in this re-run!

Wait — the runner runs ALL migrations every time, in order. So:
1. 009 creates initial jobs
2. 026 adds UNIQUE constraint
3. 037 deletes system-review jobs, deletes duplicate S jobs
...
4. 041 inserts self-monitor job with ON CONFLICT on `(soul_id, job, priority, category)` — this constraint exists (added by 026, not yet dropped)
5. 046 drops the UNIQUE constraint, adds partial index

So the re-run is actually fine for 041 because 026 runs before 041, and 046 runs after. The constraint exists when 041 needs it.

**This issue is actually NOT a problem** — the migration order is correct. Withdrawing this issue.

---

### 🟡 Issue 4: The plan doesn't address `agent_jobs` rows that have the same `job_key` but different `job` text

**Severity:** Low

The plan's `save_job_version` function deactivates by `(soul_id, job_key)` and inserts a new row. But the partial unique index `uq_agent_jobs_active_soul_job_key` only allows one non-archived row per `(soul_id, job_key)` (should use `WHERE is_archived = false`, not `WHERE is_active = true`). 

What if two different jobs (different text) get the same `job_key`? The partial unique index would block the second insert. The plan's backfill assigns unique keys, so this shouldn't happen in practice — but there's no constraint preventing it.

**Recommendation:** Add a comment in the migration noting that `job_key` must be unique per logical job. Consider adding a CHECK constraint or documentation.

---

### 🟡 Issue 5: `save_soul_version` copies metadata from the OLD row — but what about `id_prefix` uniqueness across the FK?

**Severity:** Low

The `save_soul_version` function does:
```sql
UPDATE agent_souls SET is_active = false WHERE id_prefix = p_id_prefix AND is_active = true;
INSERT INTO agent_souls (id_prefix, name, role, ...) 
  SELECT p_id_prefix, name, role, ... FROM agent_souls 
  WHERE id_prefix = p_id_prefix ORDER BY created_at DESC LIMIT 1;
```

After the partial unique index is in place, the INSERT will succeed (old row is deactivated). But the FK `fk_agent_souls_prefix` references `agent_prefixes(prefix)` — and `id_prefix` is the same value, so FK is fine.

**No actual issue here** — just confirming the logic is sound.

---

### 🟡 Issue 6: The plan's Gleam wrapper module name conflicts with existing naming

**Severity:** Low

The plan proposes `src/soul_version_writer.gleam`. Looking at existing modules:
- `src/a_db_reader.gleam` — A's DB reader
- `src/s_db_reader.gleam` — S's DB reader
- `src/code_version.gleam` — code versioning (similar pattern)

The naming is consistent. But note that `code_version.gleam` uses `save_version` as the function name, while the plan proposes `save_soul_version` and `save_job_version`. This is fine — different domain.

**No issue** — naming is good.

---

### 🟡 Issue 7: The plan doesn't update `table_documentation` for the new columns

**Severity:** Low-Medium

The `table_documentation` table documents the schema. After adding `is_archived` to both tables and `job_key` to `agent_jobs`, the documentation should be updated. The plan doesn't mention this.

**Recommendation:** Add a step to the implementation order: update `table_documentation` with the new columns.

---

### 🟡 Issue 8: The plan's `save_job_version` doesn't copy `job` text from the old row

**Severity:** Informational

The `save_job_version` function takes `p_job` as a parameter and inserts it directly. Unlike `save_soul_version` (which copies metadata from the old row), `save_job_version` requires the caller to provide the full job text. This is intentional — the job text IS the versioned content.

But this means the Gleam caller must always provide the full job text. If they only want to change the priority or category, they still need to pass the full job text. This is fine — it's the append-only pattern.

**No issue** — just noting the design difference between soul and job versioning.

---

### 🟢 Issue 9 (Minor): The plan's backfill has a typo in the comment

**Severity:** Cosmetic

In the plan's §3, step 3 comment says:
```sql
-- A's 24 active jobs
```
But the backfill actually lists 24 A jobs AND deactivates one (`d9d45795`). After deactivation, A has 23 active + 1 inactive self_monitor. The count "24 active jobs" is correct for the state before deactivation.

**No functional issue** — just noting for accuracy.

---

## 4. What the Plan Omits

### 4.1 No discussion of the `ON CONFLICT` in migration 041

Migration 041 uses:
```sql
INSERT INTO agent_jobs (id, soul_id, job, priority, category, is_active)
SELECT ... 
ON CONFLICT DO NOTHING;
```

After 046 drops the UNIQUE constraint and creates a partial unique index on `(soul_id, job_key) WHERE is_active = true`, the `ON CONFLICT DO NOTHING` in 041 (which targets the old constraint) would need to be updated. But since the migration runner re-runs in order, and 026 adds the constraint before 041 runs, this is fine for re-runs.

**However**, if someone runs 046 standalone (without re-running all migrations), the ON CONFLICT in 041 would fail if 041 is later re-run. This is an edge case — the plan's validation approach (run all in order) handles it.

### 4.2 No Gleam test file

The plan mentions creating a test file as optional (step 6). Given that the Gleam wrapper is a new module, a test file would be valuable. But the plan correctly notes there's no `test/` directory yet — creating one is a separate decision.

### 4.3 No discussion of `agent_jobs` seed synchronization

The plan says "The seed (`008_agent_soul.sql`, `009_agent_jobs.sql`) does NOT need to change." But after adding `job_key` (NOT NULL), the seed `009` MUST be updated to include `job_key` values, otherwise a fresh install followed by the backfill (which uses hardcoded UUIDs that won't match the seed's auto-generated UUIDs) will fail at the `SET NOT NULL` step.

**This is the most critical omission in the plan.** See Issue 2 above.

---

## 5. Recommended Changes to the Plan

### Must-fix before implementation:

1. **Update `009_agent_jobs.sql`** to include `job_key` column and values matching the plan's backfill. This ensures fresh installs work correctly.

2. **Update Gleam readers** (`a_db_reader.gleam`, `s_db_reader.gleam`) to add `AND is_archived = false` to the WHERE clause. The plan's own design says this should be done.

3. **Update `table_documentation`** with the new columns (`is_archived` on both tables, `job_key` on `agent_jobs`).

### Should-fix before implementation:

4. **Add `job_key` to `seed.gleam`** — or at minimum, ensure the seed's `009` migration includes `job_key` values that match the backfill UUIDs. The simplest approach: add `job_key` to `009_agent_jobs.sql` with proper values, and make the backfill in 046 use `WHERE job_key IS NULL` instead of hardcoded UUIDs (for forward compatibility).

5. **Add a note** in the migration about `job_key` uniqueness requirements.

### Nice-to-have:

6. Create a Gleam test file for `soul_version_writer.gleam`.
7. Add a `version` or `change_reason` column to track why a version was created (the handover mentions `save_soul_version(content, change_reason)` as an option but the plan drops it).

---

## 6. Overall Assessment

| Dimension               | Rating | Notes                                                      |
| ----------------------- | ------ | ---------------------------------------------------------- |
| Problem identification  | ⭐⭐⭐⭐⭐  | Correct and well-documented                                |
| Schema design           | ⭐⭐⭐⭐   | Sound, but seed sync issue (Issue 2)                       |
| SQL functions           | ⭐⭐⭐⭐⭐  | Well-designed, atomic, idempotent                          |
| Migration safety        | ⭐⭐⭐⭐   | Idempotent DDL, but backfill UUID coupling is fragile      |
| Read-path compatibility | ⭐⭐⭐⭐   | Claims no changes needed, but `is_archived` filter missing |
| Gleam wrapper design    | ⭐⭐⭐⭐   | Follows existing patterns                                  |
| Documentation updates   | ⭐⭐⭐    | Missing `table_documentation` update                       |
| Fresh install safety    | ⭐⭐     | Backfill UUIDs won't match seed — NOT NULL will fail       |
| Overall                 | ⭐⭐⭐⭐   | **Good plan, needs fixes before implementation**           |

---

## 7. Conclusion

The plan is **approved with modifications**. The core design is sound. The critical fixes needed are:

1. **Seed synchronization** — `009_agent_jobs.sql` must include `job_key` values
2. **Read path filter** — Gleam readers must add `AND is_archived = false`
3. **Table documentation** — update `table_documentation` for new columns

After these fixes, the plan is ready for implementation.

---

## Revision: Post-A inter-review additions (2026-06-03, second cycle)

After A's inter-review, two additions were identified:

### Addition 10: AGENTS.md "Known doc/DB drift" note must be updated

Migration 046 step 4 deactivates the older self-monitor job (`d9d45795`). After this, AGENTS.md's "Known doc/DB drift" note should be updated to reflect the resolved state (or removed since the drift is fixed). The plan's implementation order should include updating AGENTS.md after migration 046 lands.

### Addition 11: `agent_identity.gleam` also reads agent_jobs without `is_archived` filter

Issue #1 (01b5b072) correctly flags `a_db_reader.gleam` and `s_db_reader.gleam`, but A's inter-review and S's gap analysis confirmed a third file also needs the same fix: `src/agent_identity.gleam` (`fetch_jobs_by_prefix` function). This file joins `agent_jobs` with `agent_souls` and filters on `j.is_active = true` but not `j.is_archibed = false`. The fix is the same 1-line addition.

### A's behavioral note (accepted)

S prematurely created tasks before A's review in the first cycle. A scored 8/10 for this. S accepted the finding. **Going forward:** no implementation tasks until after A's inter-review AND user approval.

### Adjusted overall score: 8.5/10

Plan quality remains ⭐⭐⭐⭐. A's additional catch (AGENTS.md drift) and S's gap catch (`agent_identity.gleam`) both demonstrate the 1+1>2 value of inter-review.

### Closed-loop completeness (A's question)

A asked whether all 11 findings should become issues, or whether doc-only observations are acceptable. After re-examination:

- Findings 1-3 → Already filed as issues ✅
- Finding 4 (job_key uniqueness) → Now filed as issue a825877a (was under-filed)
- Finding 5 (FK/copy logic) → No actual issue, concluded sound — doc-only ✅
- Finding 6 (naming) → No issue — doc-only ✅
- Finding 7 (table_documentation) → Already filed as issue #3 ✅
- Finding 8 (save_job_version asymmetry) → Informational — doc-only ✅
- Finding 9 (cosmetic typo) — doc-only ✅
- Finding 10 (AGENTS.md drift note) → Actionable, but belongs in the plan's implementation order rather than a separate issue. Not filed as separate issue.
- Finding 11 (agent_identity.gleam) → Already covered by Issue #1 ✅

**4 issues filed total**, covering all actionable findings. Doc-only findings are intentionally not issues — they are observations, not bugs.

---

## Revision: User-confirmed additions (2026-06-03, final)

The user confirmed the following principle and approach:

### ☠️ IRON RULE: Neither A nor S should ever suggest killing Pi

Both agents live inside Pi. Killing Pi kills the agents. This is a human decision or an A decision (from `extension.js`), never an S decision. S must never suggest `pkill`, stopping Pi, or any action that terminates the host runtime.

### Finding 12: Migration must be online-safe — no stopping Pi

The plan's implementation order must specify:
1. **User runs migration from terminal** (not from inside Pi, not via any agent tool)
2. **Use `CREATE INDEX CONCURRENTLY`** to minimize lock contention during index creation
3. **Verify migration success** before continuing with any other changes

For small tables (2 rows in `agent_souls`, 44 rows in `agent_jobs`), the lock duration is milliseconds. Brief query delays are possible but unlikely to cause errors. No Pi restart needed.

### Updated implementation order

The plan's §12 implementation order should be updated to:
1. Update `009_agent_jobs.sql` to include `job_key` column and values
2. Create `src/migrations/046_append_only_active_archived.sql` (with `CREATE INDEX CONCURRENTLY`)
3. **User runs `gleam run migrate` from terminal** (Pi stays running)
4. Verify migration: `psql -d psypi -c "SELECT COUNT(*) FROM agent_jobs WHERE job_key IS NULL;"` → expect 0
5. Create `src/soul_version_writer.gleam`
6. Update Gleam readers: `a_db_reader.gleam`, `s_db_reader.gleam`, `agent_identity.gleam` — add `AND is_archived = false`
7. Update `table_documentation` with new columns
8. Update AGENTS.md: remove "Known doc/DB drift" note (self_monitor deactivation is fixed)
9. Add the "Two-Flag Pattern" section to AGENTS.md
10. (Optional) Add Gleam test file for `soul_version_writer.gleam`

### Adjusted overall score: 4/5 → remains ⭐⭐⭐⭐

The plan's core design is sound. The fixes identified through A-S cross-review and user input are all implementable. The plan is ready for implementation after the above updates.

---

## Revision: External AI deep re-review (2026-06-04, third cycle)

The external AI was asked to do a *careful* re-review of the plan and of S/A's
commits, identify uncertainties, and rethink. The user explicitly asked NOT to
apply any fixes to avoid conflicts with S/A who are still working.

This section is read-only analysis. No code changes proposed.

### A. Status of S/A's commits (as of `4359fa2`)

| Commit    | Author | What was done                                                                                                     | Quality                           |
| --------- | ------ | ----------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| `014bad3` | S      | Added `job_key` + `is_archived` to 009 CREATE TABLE; added `job_key` to all 27 INSERTs                            | OK initially                      |
| `fd29273` | S      | Created migration 046 (259 lines): columns, partial indexes, backfill, deactivation, `save_*_version()` functions | **Has a critical bug — see B.1**  |
| `070b100` | S      | Created `soul_version_writer.gleam` (90 lines)                                                                    | OK                                |
| `111c1f5` | S      | Removed `job_key` from 009 INSERTs                                                                                | **Wrong call — see B.3**          |
| `71df3e7` | S      | Added `ON CONFLICT (soul_id, job, priority, category) DO NOTHING` to 009 INSERTs                                  | OK                                |
| `4359fa2` | S      | `simple_migrate.gleam` learned to handle `$$...$$` dollar-quoted strings                                          | Necessary fix for 046 to even run |

The migration runner fix (`4359fa2`) is non-obvious and was a good catch by S
without it, 046 would crash because the `split_statements` function would
chop the plpgsql function bodies on internal semicolons.

### B. Critical issues found in this re-review

#### 🔴 B.1 Migration 046 partial unique indexes use the WRONG condition

This is the **most important finding of this re-review**. Both the plan and
the implementation in `046_append_only_active_archived.sql` declare the
partial unique indexes as:

```sql
CREATE UNIQUE INDEX uq_agent_souls_active_id_prefix
  ON agent_souls (id_prefix) WHERE is_archived = false;
```

But the same migration's `save_soul_version()` function only does this:

```sql
UPDATE agent_souls SET is_active = false
  WHERE id_prefix = p_id_prefix AND is_active = true;
-- then insert new row with is_active=true, is_archived=false
```

**Walk-through of the first `save_soul_version('A', new_content)` call:**

1. Initial state:
   - One row: `id_prefix='A', is_active=true, is_archived=false`
2. UPDATE: deactivates the old row → `is_active=false`. Row now:
   - One row: `id_prefix='A', is_active=false, is_archived=false`
3. INSERT: adds new row → `is_active=true, is_archived=false`. Rows now:
   - Old: `id_prefix='A', is_active=false, is_archived=false`  ← still non-archived
   - New: `id_prefix='A', is_active=true,  is_archived=false`
4. Partial unique index `WHERE is_archived = false` sees **two non-archived
   rows with the same `id_prefix`** → **unique violation on INSERT**.

**The migration as written will reject every save on the first try.**

This bug was not caught by S's review nor A's inter-review. The S review
actually stated (in Issue 4):

> "the partial unique index `uq_agent_jobs_active_soul_job_key` only allows
> one non-archived row per `(soul_id, job_key)` (**should use
> `WHERE is_archived = false`, not `WHERE is_active = true`**)."

That sentence is backwards. The parenthetical treats `WHERE is_archived = false`
as the *correct* target — but as just demonstrated, the function never sets
`is_archived = true` on the deactivated row, so `WHERE is_archived = false`
allows two alive rows after every version save. The index condition is wrong,
and the parenthetical is the bug, not the fix.

**Two ways to reconcile, in order of cleanliness:**

| #   | Fix                                                                 | Effect                                                                                                                                                                                                           |
| --- | ------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Change all three partial unique indexes to `WHERE is_active = true` | Function works as-is. Among active rows, `(id_prefix)` / `(role)` / `(soul_id, job_key)` is unique. `is_archived` is purely an app-managed visibility flag, decoupled from the index. **This is the right fix.** |
| 2   | Make `save_soul_version` also set `is_archived=true` on the old row | Conflates "previous version" with "archived" — every old version becomes invisible to the app immediately, defeating the "keep history visible" append-only goal. Rejected.                                      |

**Recommended fix (option 1):** the three indexes become

```sql
WHERE is_active = true
```

The plan and `AGENTS.md` addition §9 should be amended to say:

> "Partial unique indexes enforce uniqueness among active rows only:
> one active soul per `id_prefix`, one active soul per `role`,
> one active job per `(soul_id, job_key)`. `is_archived` is a
> separate, app-managed visibility flag."

#### 🔴 B.2 Fresh-install backfill is incomplete

The 046 backfill is keyed by hardcoded UUIDs from the live DB. The plan
called this out in Risks §11.0 as the "Fresh install failure" risk. The
implementation tries to mitigate this with a category-based catch-up at the
end:

```sql
UPDATE agent_jobs SET job_key = 'review.schema_discipline'
  WHERE id IN (
    SELECT j.id FROM agent_jobs j
    JOIN agent_souls s ON j.soul_id = s.id
    WHERE s.id_prefix = 'A' AND j.category = 'review' AND j.job_key IS NULL
    LIMIT 1
  );
```

…but the catch-up only covers **four** A categories (`review`,
`self_monitor`, `behavior`, `safety`). The other A categories that exist
in the seed (`unblock`, `suggestion`, `maintenance`, `definition`,
`closed_loop` — 5 more rows) would remain NULL. S has 13 more categories
that aren't covered at all. **`ALTER COLUMN job_key SET NOT NULL` would
fail on a fresh install** for those rows.

This is a real bug, not a theoretical one. The catch-up needs to be
exhaustive (all distinct `(id_prefix, category)` pairs in the seed), or
the catch-up needs to be removed in favour of an approach that doesn't
rely on it (see B.3).

#### 🟡 B.3 The 111c1f5 commit removed `job_key` from 009 INSERTs unnecessarily

S's commit message says: "009 INSERTs don't reference job_key (column
doesn't exist yet on re-run)".

This is **incorrect reasoning**: 009's own CREATE TABLE already defines
`job_key text`, so the column exists from the moment 009 first runs
(including on re-runs, because `CREATE TABLE IF NOT EXISTS` is a no-op
on re-run but the column definition is still in the file).

The net effect of 111c1f5 is: 009's INSERTs leave `job_key` NULL. This
forces 046 to be the only place where `job_key` gets set. Combined with
the hardcoded-UUID backfill (B.2), fresh installs break.

The cleanest path is: **revert 111c1f5 and put `job_key` back in 009
INSERTs** with the same slug values. The 046 backfill then becomes a
safety net only (idempotent: `AND job_key IS NULL` filter).

#### 🟡 B.4 The plan still says "partial unique indexes use `WHERE is_archived = false`" but this is wrong

The plan's own §3 design table and AGENTS.md addition §9 say the indexes
use `WHERE is_archived = false`. After the B.1 fix they would use
`WHERE is_active = true`. This needs to be updated in three places:

- `docs/PLAN-2026-06-03-append-only-souls-jobs.md` §2 design table
- `docs/PLAN-2026-06-03-append-only-souls-jobs.md` §3 schema block
- `docs/PLAN-2026-06-03-append-only-souls-jobs.md` §9 AGENTS.md addition

#### 🟡 B.5 `agent_souls.role` is part of a unique index but `role` may not be stable

The plan drops `agent_soul_role_key` (a full UNIQUE on `role`) and replaces
it with a partial unique index on `(role) WHERE is_archived = false`. This
preserves the "no two active souls with the same role" constraint, but it
implicitly assumes that `role` is stable across version updates. The
`save_soul_version` function copies `role` from the most recent row, so
that's true. **No fix needed, but the plan's "principles" table is
slightly misleading** — it doesn't mention `role` as a stable business
identifier the way it does for `id_prefix` and `job_key`.

#### 🟢 B.6 Things that are correctly handled

- The 4359fa2 dollar-quoted string handling in `simple_migrate.gleam` is
  the only reason 046's function definitions would even execute.
- `soul_version_writer.gleam` is type-safe and follows the `inter_review`
  pattern. The decoder is correct. Error mapping is complete.
- 71df3e7's `ON CONFLICT DO NOTHING` on 009 INSERTs is correct re-run
  hygiene.
- The plan's design choice to keep the 038-044 UPDATE-in-place migrations
  as-is and only annotate them is sound (no risk of re-execution).

### C. Open questions for the user

These are points where the plan made a design choice that the user might
want to revisit. They are not bugs — they are decisions where multiple
valid options exist.

1. **Should the partial unique indexes be on `WHERE is_active = true` (B.1
   fix) or should `save_soul_version` archive the old row instead?** The
   plan currently does neither cleanly. The first option is simpler and
   matches the "is_active is the current-version pointer" semantics.

2. **Should `job_key` be back in 009 INSERTs (revert 111c1f5)?** Without
   this, fresh installs need the 046 catch-up to be exhaustive (B.2).
   With this, 046's backfill is just an idempotent safety net.

3. **Should the catch-up in 046 be removed entirely** once `job_key` is
   in 009? It becomes a no-op on fresh installs (rows already have keys
   from the seed) and a no-op on re-runs (rows already have keys from
   the previous 046 run). Removing it shrinks 046 and removes a
   fragile heuristic.

4. **What happens to `agent_souls.role` if A and S ever swap roles in
   the future?** The partial unique index on `role` would block the
   swap, requiring an `is_archived = true` on the old role first. This
   is intentional friction, but worth knowing.

5. **Should there be a Gleam test for `soul_version_writer.gleam`?**
   Listed as optional in the plan. The function is small but the
   B.1-style logic is easy to get wrong, and a test that inserts two
   versions and asserts the row count would catch B.1.

### D. Items not yet addressed (still pending from earlier reviews)

These are still on the to-do list and not yet in the committed work:

| Item                                                                             | From                  | Severity                       |
| -------------------------------------------------------------------------------- | --------------------- | ------------------------------ |
| Add `AND is_archived = false` to `a_db_reader.gleam` reads                       | Review §3 Issue 1     | Medium                         |
| Add `AND is_archived = false` to `s_db_reader.gleam` reads                       | Review §3 Issue 1     | Medium                         |
| Add `AND is_archived = false` to `agent_identity.gleam`'s `fetch_jobs_by_prefix` | Review §7 Addition 11 | Medium                         |
| Update `table_documentation` with `is_archived` and `job_key` columns            | Review §3 Issue 7     | Low-Medium                     |
| Update AGENTS.md: remove "Known doc/DB drift" note                               | Review §7 Addition 10 | Low                            |
| Add "Append-Only Pattern" section to AGENTS.md                                   | Plan §9               | Low                            |
| Add deprecation comments to 038, 040, 041, 042, 043, 044                         | Plan §8               | Low                            |
| **B.1 fix: change partial unique indexes to `WHERE is_active = true`**           | **This re-review**    | **🔴 Critical**                 |
| **B.2 fix: complete the 046 backfill (or rely on 009)**                          | **This re-review**    | **🔴 Critical (fresh install)** |
| **B.3 fix: put `job_key` back in 009 INSERTs**                                   | **This re-review**    | **🟡 Medium**                   |
| **B.4 fix: update PLAN to reflect the new index condition**                      | **This re-review**    | **🟡 Medium**                   |

### E. Overall assessment of this re-review

| Dimension                                     | Rating | Notes                                                                                                 |
| --------------------------------------------- | ------ | ----------------------------------------------------------------------------------------------------- |
| Plan core design                              | ⭐⭐⭐⭐⭐  | Sound. Append-only with two flags is the right call.                                                  |
| Plan details & risks                          | ⭐⭐⭐    | The fresh-install risk was identified but not fully mitigated                                         |
| S's committed work (code)                     | ⭐⭐⭐    | 4/7 commits are good; 046 has a critical bug (B.1); 111c1f5 was a wrong call (B.3)                    |
| S's review                                    | ⭐⭐⭐    | Identified many correct issues but missed B.1 (the most important one) and the implication of 111c1f5 |
| A's inter-review                              | ⭐⭐⭐    | Caught `agent_identity.gleam` (good) and AGENTS.md drift (good), but did not catch B.1                |
| Migration 046 as committed                    | ⭐⭐     | **Will reject every save on first try.** Must be fixed before running.                                |
| Migration 046 + 009 + simple_migrate combined | ⭐⭐     | **Will fail on fresh install.** Backfill + ON CONFLICT pattern doesn't close the gap.                 |

**Adjusted overall score: 2/5.** The plan is good, but the committed
implementation has a critical bug that would prevent the system from
working at all. The fixes are small (one word in three places) but they
are not optional.

### F. What I did NOT do (per user instruction)

- Did not modify any `.sql` migration files
- Did not modify any `.gleam` source files
- Did not modify the plan or the existing review document
- Did not run the migration against the live database
- Did not commit anything

This is a read-only re-review. The user asked specifically to avoid
conflicts with S/A who are still working, so all findings are documented
here for human review and S/A's next pass.
