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

| Aspect | Assessment |
|--------|-----------|
| Problem diagnosis | ✅ Correct — `agent_souls` and `agent_jobs` are the only two tables using UPDATE-in-place |
| `is_archived` as primary gate | ✅ Sound — if archived, row is dead to the app. `is_active` is used as-is, no need to reinterpret its meaning |
| `job_key` as stable business identifier | ✅ Correct — needed because the old UNIQUE on `(soul_id, job, priority, category)` blocks versioned inserts |
| Partial unique indexes | ✅ Correct approach — replaces full UNIQUE constraints |
| SQL function atomicity | ✅ Correct — single plpgsql body = implicit savepoint |
| Idempotency of migration | ✅ All DDL uses IF NOT EXISTS, backfill keyed by stable UUID |
| Read-path compatibility | ✅ Confirmed — both `a_db_reader.gleam` and `s_db_reader.gleam` already filter on `is_active = true` |
| Deprecation comments for old migrations | ✅ Right approach — don't rewrite history, annotate it |
| Validation evidence | ✅ The external AI ran real tests against the live DB |

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

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Problem identification | ⭐⭐⭐⭐⭐ | Correct and well-documented |
| Schema design | ⭐⭐⭐⭐ | Sound, but seed sync issue (Issue 2) |
| SQL functions | ⭐⭐⭐⭐⭐ | Well-designed, atomic, idempotent |
| Migration safety | ⭐⭐⭐⭐ | Idempotent DDL, but backfill UUID coupling is fragile |
| Read-path compatibility | ⭐⭐⭐⭐ | Claims no changes needed, but `is_archived` filter missing |
| Gleam wrapper design | ⭐⭐⭐⭐ | Follows existing patterns |
| Documentation updates | ⭐⭐⭐ | Missing `table_documentation` update |
| Fresh install safety | ⭐⭐ | Backfill UUIDs won't match seed — NOT NULL will fail |
| Overall | ⭐⭐⭐⭐ | **Good plan, needs fixes before implementation** |

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
