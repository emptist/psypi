# Review: SQL-Verified Re-Analysis of Append-Only Plan and S/A's Commits

**Date:** 2026-06-04
**Reviewer:** External AI (careful re-review after S's commits)
**Plan under review:** [PLAN-2026-06-03-append-only-souls-jobs.md](PLAN-2026-06-03-append-only-souls-jobs.md)
**Commits under review (table-redesign branch):** `014bad3`, `fd29273`, `070b100`, `111c1f5`, `71df3e7`, `4359fa2`
**Status:** SQL-verified. Two critical bugs found. Both have small, verified fixes.
**Constraint:** No code changes applied (per user instruction, to avoid conflict with S/A who are still working).

---

## 1. Executive summary

The plan's core design is sound. S's work on `simple_migrate.gleam` (dollar-quoted
string handling) and the `soul_version_writer.gleam` wrapper is solid. But the
committed migration `046_append_only_active_archived.sql` has **two critical bugs**
that would prevent the append-only design from working at all:

| Bug | What | Effect | Verified by |
|-----|------|--------|-------------|
| **B.1** | Partial unique indexes use `WHERE is_archived = false` | First `save_soul_version` call fails with unique violation | `/tmp/verify_b1_full.sql` |
| **B.2** | Backfill covers only 4 of A's 8 categories (and 0 of S's 13) | Fresh install fails at `SET NOT NULL` step | `/tmp/verify_b2_v2.sql` |

Both have small, verified fixes. **B.1** is fixed by changing the index condition
to `WHERE is_active = true` (verified by `/tmp/verify_fix.sql`). **B.2** is fixed
by reverting S's `111c1f5` commit and putting `job_key` back in 009's INSERTs
(verified by `/tmp/verify_b3_fix_v2.sql`).

---

## 2. Status of S/A's commits

| Commit | Author | What | Quality | Notes |
|--------|--------|------|---------|-------|
| `014bad3` | S | 009: added `job_key`+`is_archived` to CREATE TABLE; added `job_key` to all 28 INSERTs (13 A + 15 S) | OK | This was the right initial direction |
| `fd29273` | S | 046 created (259 lines): columns, partial indexes, backfill, deactivation, `save_*_version()` functions | **🔴 Has B.1** | First-call failure |
| `070b100` | S | `soul_version_writer.gleam` (90 lines) | ✅ OK | Type-safe, follows `inter_review` pattern |
| `111c1f5` | S | Removed `job_key` from 009 INSERTs | **🟡 Wrong call (B.3)** | Caused B.2 |
| `71df3e7` | S | Added `ON CONFLICT DO NOTHING` to 009 INSERTs | ✅ OK | Re-run hygiene |
| `4359fa2` | S | `simple_migrate.gleam` learned `$$...$$` dollar-quoted strings | ✅ OK | Necessary for 046 to even run |

The `4359fa2` fix was a non-obvious and necessary catch by S — without it, the
plpgsql function bodies in 046 would be split on their internal semicolons and
fail to parse.

---

## 3. Bug B.1: Partial unique indexes use the wrong condition

### 3.1 What the migration declares

```sql
CREATE UNIQUE INDEX uq_agent_souls_active_id_prefix
  ON agent_souls (id_prefix) WHERE is_archived = false;
```

### 3.2 What the function does

```sql
-- inside save_soul_version(p_id_prefix, p_content):
UPDATE agent_souls SET is_active = false
 WHERE id_prefix = p_id_prefix AND is_active = true;

INSERT INTO agent_souls (..., is_active, is_archived)
  SELECT ..., true, false   -- new row is NOT archived
  FROM agent_souls WHERE id_prefix = p_id_prefix
  ORDER BY created_at DESC LIMIT 1;
```

### 3.3 Walk-through of the FIRST call

| Step | id_prefix | is_active | is_archived | Note |
|------|-----------|-----------|-------------|------|
| Initial | A | true | false | one row |
| After UPDATE | A | **false** | **false** | deactivated but still non-archived |
| After INSERT (attempt) | A | true | false | new row, also non-archived |
| **Index state** | — | — | — | **2 non-archived rows with same id_prefix** |

The partial unique index `WHERE is_archived = false` sees two non-archived rows
and rejects the INSERT.

### 3.4 Verified evidence

`/tmp/verify_b1_full.sql` — full simulation of 046 with all 3 constraint drops:

```
─── Attempting save_soul_version( A, NEW_CONTENT ) ───
NOTICE:  ❌ B.1 CONFIRMED: duplicate key value violates unique constraint
        "uq_agent_souls_active_id_prefix"
```

### 3.5 Why both S's review AND A's inter-review missed it

S's review (Issue 4) stated:

> "the partial unique index `uq_agent_jobs_active_soul_job_key` only allows one
> non-archived row per `(soul_id, job_key)` (**should use `WHERE is_archived = false`,
> not `WHERE is_active = true`**)."

The parenthetical is backwards. `WHERE is_archived = false` is precisely what's
causing the bug. The reviewer treated it as the correct target, when it's
actually the wrong one. A's inter-review did not catch this either.

### 3.6 Fix (verified)

Change the three partial unique indexes to `WHERE is_active = true`:

```sql
CREATE UNIQUE INDEX uq_agent_souls_active_id_prefix
  ON agent_souls (id_prefix) WHERE is_active = true;

CREATE UNIQUE INDEX uq_agent_souls_active_role
  ON agent_souls (role) WHERE is_active = true;

CREATE UNIQUE INDEX uq_agent_jobs_active_soul_job_key
  ON agent_jobs (soul_id, job_key) WHERE is_active = true;
```

#### Why this works (verified by `/tmp/verify_fix.sql`)

After the fix:
- First `save_soul_version` call: ✓ succeeds
- Second `save_soul_version` call: ✓ succeeds
- Direct duplicate active insert: ✓ correctly rejected
- Historical insert (`is_active=false`): ✓ accepted (preserves append-only history)

Final state after two saves: 1 active row + 2 historical rows for `id_prefix = 'A'`.
Exactly what append-only needs.

#### Design implications

| Concern | Resolution |
|---------|-----------|
| Can we have multiple historical rows with same `id_prefix`? | Yes — that's the append-only goal |
| Can we have two active rows with same `id_prefix`? | No — index prevents it |
| What about `is_archived`? | Now purely a visibility flag, decoupled from the index |
| Does the plan's design intent still hold? | Yes — `is_active` is the current-version pointer, exactly as planned |

The alternative — making `save_soul_version` also set `is_archived=true` on the
old row — was rejected because it conflates "previous version" with "archived",
hiding history from the app immediately. That defeats the append-only goal.

---

## 4. Bug B.2: Fresh-install backfill is incomplete

### 4.1 What 046 does

The backfill has two parts:
1. **Hardcoded UUID updates** — 44 UPDATE statements keyed by the UUIDs from the
   live DB. These will be no-ops on a fresh install (different UUIDs).
2. **Category-based catch-up** — 4 UPDATE statements for A's `review`,
   `self_monitor`, `behavior`, `safety` categories.

### 4.2 What 046 doesn't catch

A's seed has 8 distinct categories. Only 4 are covered by the catch-up:
- ✅ `review`
- ✅ `self_monitor`
- ✅ `behavior`
- ✅ `safety`
- ❌ `unblock`, `suggestion`, `maintenance`, `definition`, `closed_loop` (5 categories)

S's seed has 12 distinct categories. **0 are covered by the catch-up.**

### 4.3 Verified evidence

`/tmp/verify_b2_v2.sql` — simulates fresh install with 13 A jobs + 15 S jobs
(28 fresh rows):

After hardcoded-UUID backfill (no-ops on fresh install) and 4 catch-up statements:

```
 id_prefix |   category   | rows | with_key | still_null
-----------+--------------+------+----------+------------
 A         | behavior     |    1 |        1 |          0
 A         | closed_loop  |    5 |        0 |          5    ← still NULL
 A         | definition   |    1 |        0 |          1    ← still NULL
 A         | maintenance  |    1 |        0 |          1    ← still NULL
 A         | review       |    1 |        1 |          0
 A         | safety       |    1 |        1 |          0
 A         | self_monitor |    1 |        1 |          0
 A         | suggestion   |    1 |        0 |          1    ← still NULL
 A         | unblock      |    1 |        0 |          1    ← still NULL
 S         | behavior     |    2 |        0 |          2    ← all S still NULL
 S         | business     |    1 |        0 |          1
 ... (12 more S categories, all NULL)
```

Total: **24 out of 28 rows have NULL `job_key` after the backfill.**

Then:

```
─── Now attempt the SET NOT NULL step (this is what fails) ───
NOTICE:  ❌ B.2 CONFIRMED: SET NOT NULL failed:
        column "job_key" of relation "agent_jobs" contains null values
```

The migration would abort at this step on a fresh install.

### 4.4 Root cause: S's 111c1f5 commit

S removed `job_key` from 009 INSERTs in commit `111c1f5` with this rationale:

> "009 INSERTs don't reference job_key (column doesn't exist yet on re-run)"

**This is incorrect reasoning.** 009's own CREATE TABLE already defines
`job_key text` (commit `014bad3` added it). The column exists from the moment
009 first runs, and on re-runs `CREATE TABLE IF NOT EXISTS` is a no-op but the
column definition is still in the file.

Removing `job_key` from the INSERTs leaves the column NULL for all 27 seed
rows. The 046 backfill is then the only place where `job_key` gets set, but
its hardcoded UUIDs don't match fresh-install UUIDs, and its catch-up is
incomplete.

### 4.5 Fix (verified)

Revert 111c1f5 — put `job_key` back in 009's INSERTs with the same slug
values from the live DB. 046's backfill then becomes a safety net only
(idempotent via `AND job_key IS NULL` filter).

#### Evidence

`/tmp/verify_b3_fix_v2.sql` — simulates fresh install with `job_key` in 009 INSERTs:

```
─── After fresh-install seed WITH job_key: how many NULL? ───
 null_keys | total
-----------+-------
         0 |    28        ← all rows have job_key from the seed

─── Now apply 046 SET NOT NULL (this should succeed) ───
NOTICE:  ✓ SET NOT NULL succeeded (B.3 fix works)

─── Verify: try to insert a row with NULL job_key (should now fail) ───
NOTICE:  ✓ NULL job_key correctly rejected: null value in column "job_key"
        of relation "agent_jobs" violates not-null constraint
```

---

## 5. Other findings

### 5.1 🟡 B.4: Plan documents the wrong index condition

The plan's §2 design table, §3 schema block, and §9 AGENTS.md addition all
state the indexes use `WHERE is_archived = false`. After the B.1 fix they
should use `WHERE is_active = true`. These three locations need updating.

### 5.2 🟡 B.5: `agent_souls.role` is unique but not a "stable business identifier"

The plan drops `agent_soul_role_key` (UNIQUE on `role`) and replaces it with
a partial unique index on `(role)`. The `save_soul_version` function copies
`role` from the most recent row, so this is safe. But the plan's "principles"
table is slightly misleading — it mentions `id_prefix` and `job_key` as
stable business identifiers but not `role`. Worth a note for clarity.

### 5.3 🟡 B.6: The catch-up in 046 could be removed once 009 has `job_key`

Once B.3 is fixed (job_key in 009 INSERTs), 046's catch-up becomes a no-op
in two of three scenarios:

| Scenario | Does catch-up do anything? |
|----------|---------------------------|
| Fresh install (009 has job_key) | No — rows already have keys |
| Re-run after 046 (rows have keys) | No — `AND job_key IS NULL` filters them out |

The only useful case is: a DB where 009 ran BEFORE `014bad3` added `job_key`
to the schema, and 046 hasn't run yet. For this case, the hardcoded-UUID
backfill is the right tool — it handles the live-DB transition. The
category-based catch-up is redundant.

**Recommendation:** remove the catch-up from 046 once B.3 is fixed. It
shrinks 046 and removes a fragile heuristic.

### 5.4 🟢 Things S got right

| Item | Why it's good |
|------|---------------|
| `4359fa2` dollar-quoted string handling in `simple_migrate.gleam` | Without it, 046's function definitions would be split on their internal semicolons and fail. Non-obvious catch. |
| `soul_version_writer.gleam` module | Type-safe, follows the `inter_review` pattern, error mapping is complete |
| `71df3e7` `ON CONFLICT DO NOTHING` on 009 INSERTs | Correct re-run hygiene; preserves idempotency |
| Plan's choice to keep 038-044 UPDATE-in-place migrations as-is | No risk of re-execution; honest history |
| `is_archived` as the new flag, `is_active` left alone | Matches the user's stated design intent |

---

## 6. Items still pending from earlier reviews

These are on the to-do list and not yet in the committed work:

| Item | From | Severity |
|------|------|----------|
| Add `AND is_archived = false` to `a_db_reader.gleam` reads | Review §3 Issue 1 | Medium |
| Add `AND is_archived = false` to `s_db_reader.gleam` reads | Review §3 Issue 1 | Medium |
| Add `AND is_archived = false` to `agent_identity.gleam`'s `fetch_jobs_by_prefix` | Review §7 Addition 11 | Medium |
| Update `table_documentation` with `is_archived` and `job_key` columns | Review §3 Issue 7 | Low-Medium |
| Update AGENTS.md: remove "Known doc/DB drift" note | Review §7 Addition 10 | Low |
| Add "Append-Only Pattern" section to AGENTS.md | Plan §9 | Low |
| Add deprecation comments to 038, 040, 041, 042, 043, 044 | Plan §8 | Low |
| **B.1 fix: change partial unique indexes to `WHERE is_active = true`** | **This review** | ✅ **DONE in a0d75fd** |
| **B.2 fix: revert 111c1f5, put `job_key` back in 009 INSERTs** | **This review** | ✅ **DONE in a0d75fd** |
| **B.4 fix: update plan to reflect the new index condition** | **This review** | 🟡 Pending |
| **B.6 fix: remove the catch-up from 046 once B.3 is fixed** | **This review** | ✅ **DONE in a0d75fd** |

---

## 7. Open questions for the user

1. **B.1 fix ordering**: Should the partial unique indexes be changed BEFORE
   046 is run, or only as a fix commit after first failure? The first save
   call would fail under the current 046 — but since the live DB has not
   run 046 yet, the safe order is: fix 046, then run 046.

2. **Should the Gleam readers' `AND is_archived = false` filter be added
   before or after 046 runs?** If added before 046, the existing `is_active=true`
   filter is sufficient (no rows have `is_archived=true` yet). If added after
   046, the new column is in scope. Either order is safe; the question is
   whether the changes ship as one atomic migration or as two.

3. **Should the catch-up in 046 be kept as a defensive safety net** even
   after B.3 is fixed, or removed (B.6)? Keeping it adds ~30 lines of
   fragile heuristic SQL. Removing it makes 046 smaller and the data flow
   cleaner.

4. **The plan mentions `change_reason` as optional in the plan §7 but
   dropped it. Is there a use case where the reason for a version bump
   matters for audit?** If yes, add a `change_reason text` column. If no,
   drop the question.

5. **Should there be a Gleam test for `soul_version_writer.gleam`?**
   A test that inserts two versions and asserts the row count would have
   caught B.1. Listed as optional in the plan. Recommend yes.

---

## 8. Recommended implementation order (when implementation resumes)

**Status as of S's commit `a0d75fd` (2026-06-04):** items 1, 2, 3 are DONE.
Remaining work begins at item 4.

1. ✅ **Fix 046**: change the three partial unique indexes from
   `WHERE is_archived = false` to `WHERE is_active = true`. (B.1) — **DONE in a0d75fd**
2. ✅ **Revert 111c1f5**: put `job_key` back in 009's INSERTs with the same
   slugs. (B.3 / B.2) — **DONE in a0d75fd**
3. ✅ **Remove the catch-up from 046** (optional cleanup, B.6). — **DONE in a0d75fd**
4. **Update the plan** to reflect the new index condition in three places. (B.4)
5. **User runs `gleam run migrate`** from terminal.
6. **Verify**: `psql -d psypi -c "SELECT COUNT(*) FROM agent_jobs WHERE job_key IS NULL;"` → 0
7. **Add `AND is_archived = false`** to the three Gleam readers
   (`a_db_reader.gleam`, `s_db_reader.gleam`, `agent_identity.gleam`).
8. **Update `table_documentation`** with `is_archived` and `job_key` columns.
9. **Update AGENTS.md**: remove "Known doc/DB drift" note; add "Append-Only Pattern" section.
10. **Add deprecation comments** to 038, 040, 041, 042, 043, 044.
11. **(Optional) Add Gleam test** for `soul_version_writer.gleam`.
12. **(Optional) Add `change_reason` column** if audit use case exists.

---

## 9. Test artifacts

All tests run in `BEGIN; ... ROLLBACK;` blocks against the live `psypi`
database, so they leave no residue.

| Test | File | What it proves |
|------|------|----------------|
| Test 1: minimal bug repro | `/tmp/verify_b1_bug.sql` | First save fails on the `agent_soul_role_key` constraint (because the test only simulates one of the three 046 constraint changes) |
| Test 1B: full bug repro | `/tmp/verify_b1_full.sql` | First save fails on the **correct** constraint `uq_agent_souls_active_id_prefix` after all 3 partial indexes are created |
| Test 2: fix verification | `/tmp/verify_fix.sql` | With `WHERE is_active = true`, all 4 sub-tests pass: first save, second save, duplicate-active rejection, historical-insert acceptance |
| Test 3: fresh-install backfill | `/tmp/verify_b2_v2.sql` | With 24 NULL rows remaining, `SET NOT NULL` fails |
| Test 4: B.3 fix verification | `/tmp/verify_b3_fix_v2.sql` | With `job_key` in 009 INSERTs, all 28 rows have keys and `SET NOT NULL` succeeds |

---

## 10. What I did NOT do (per user instruction)

- Did not modify any `.sql` migration files
- Did not modify any `.gleam` source files
- Did not run 046 against the live database
- Did not commit anything
- Did not delete or modify any other documentation files (only the existing
  `REVIEW-2026-06-03-append-only-souls-jobs.md` had a new revision section
  added, which the user requested)

This document is the complete record of findings. The verified SQL tests
back the bug claims. The fixes are small (one word in three places for B.1,
plus the revert of 111c1f5 for B.3) but they are not optional.

---

## 11. Overall assessment

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Plan core design | ⭐⭐⭐⭐⭐ | Sound. Append-only with two flags is the right call. |
| Plan details & risks | ⭐⭐⭐ | Identified the fresh-install risk but the catch-up mitigation is incomplete |
| 046 as committed (pre-a0d75fd) | ⭐⭐ | **Rejected every save on first try.** Fixed in a0d75fd. |
| 046 as committed (post-a0d75fd) | ⭐⭐⭐⭐⭐ | Uses `WHERE is_active = true` correctly. Re-verified with `/tmp/verify_actual_046.sql` (commit a0d75fd code): first save succeeds, second succeeds, final state 1 active + 2 historical. |
| 046 + 009 + simple_migrate combined (pre-a0d75fd) | ⭐⭐ | Failed on fresh install. Fixed in a0d75fd. |
| 046 + 009 + simple_migrate combined (post-a0d75fd) | ⭐⭐⭐⭐⭐ | All three pieces compose correctly. 009 has `job_key` in all 28 INSERTs. 046 backfill is safety net only. |
| S's work on the migration runner | ⭐⭐⭐⭐⭐ | `4359fa2` was a non-obvious and necessary catch |
| S's `soul_version_writer.gleam` | ⭐⭐⭐⭐⭐ | Type-safe, follows existing patterns |
| S's `a0d75fd` fix commit | ⭐⭐⭐⭐⭐ | All three findings (B.1, B.2, B.6) addressed in one coherent commit. Also fixed `decode_error_to_soul_error`. The commit message even cites this review by name. |
| S's review | ⭐⭐⭐ | Identified many correct issues but missed B.1 (the most critical) and the implication of 111c1f5 |
| A's inter-review | ⭐⭐⭐ | Caught `agent_identity.gleam` and AGENTS.md drift, but did not catch B.1 |

**Adjusted overall score (post-a0d75fd): 4.5/5.** The plan is good. The Gleam
wrapper is excellent. The migration runner fix is excellent. The append-only
migration is now correct. Remaining work is mechanical: update the plan doc
(B.4), wire the Gleam readers' `is_archived` filter, update
`table_documentation`, and add deprecation comments. None of these are
design-level risks.

---

## 12. Post-review update — 2026-06-04, after S's commit `a0d75fd`

**Author of this section:** External AI (re-verification after S's fix)
**New commit under review:** `a0d75fd` "fix: correct partial unique indexes
and restore job_key in 009" (HEAD on `table-redesign`)

### 12.1 What changed in a0d75fd

| File | Change | Resolves |
|------|--------|----------|
| `src/migrations/046_append_only_active_archived.sql` | 3 partial unique indexes: `WHERE is_archived = false` → `WHERE is_active = true` | **B.1** |
| `src/migrations/009_agent_jobs.sql` | Restored `job_key` column in all 28 INSERTs (reverts `111c1f5`) | **B.2 / B.3** |
| `src/migrations/046_append_only_active_archived.sql` | Removed the 4 catch-up UPDATE statements | **B.6** |
| `src/soul_version_writer.gleam` | `decode_error_to_soul_error` now uses `string.inspect(e)` instead of a hardcoded string | Bonus (separate issue) |
| `AGENTS.md`, `docs/REVIEW-2026-06-03-append-only-souls-jobs.md`, this file | Various doc updates | — |

### 12.2 Re-verification of the now-committed 046 code

I ran `/tmp/verify_actual_046.sql` using 046's code AS COMMITTED IN `a0d75fd`
(verbatim — `WHERE is_active = true`, no catch-up). Output:

```
─── Now attempt save_soul_version with 046 AS-IS index conditions ───
NOTICE:  ✓ First save_soul_version SUCCEEDED with 046 as-is

─── State after first save ───
                  id                  | id_prefix | is_active | is_archived
--------------------------------------+-----------+-----------+-------------
 bc956b52-bcc7-4308-aa7e-92477007a2b1 | A         | f         | f
 e4aa66e8-318e-4c81-81f8-91651ed92d81 | A         | t         | f

─── Now attempt a SECOND save (should also work) ───
NOTICE:  ✓ Second save_soul_version SUCCEEDED

─── Final state ───
 total | active | not_archived
-------+--------+--------------
     3 |      1 |            3
```

**Conclusion:** B.1 is RESOLVED. The append-only pattern works as designed on
the now-committed 046.

### 12.3 Items still pending (post-a0d75fd)

| Item | Source | Severity |
|------|--------|----------|
| Add `AND is_archived = false` to `a_db_reader.gleam` reads | Review §3 Issue 1 | Medium |
| Add `AND is_archived = false` to `s_db_reader.gleam` reads | Review §3 Issue 1 | Medium |
| Add `AND is_archived = false` to `agent_identity.gleam`'s `fetch_jobs_by_prefix` | Review §7 Addition 11 | Medium |
| Update `table_documentation` with `is_archived` and `job_key` columns | Review §3 Issue 7 | Low-Medium |
| Update AGENTS.md: remove "Known doc/DB drift" note | Review §7 Addition 10 | Low |
| Add deprecation comments to 038, 040, 041, 042, 043, 044 | Plan §8 | Low |
| Update plan doc to reflect the new index condition (B.4) | This review | Low (now cosmetic) |

The "Append-Only Pattern" section was already added to AGENTS.md by S in
`a0d75fd` (confirmed by reading the file: lines 627+ in `AGENTS.md`). So that
item is also effectively done.

### 12.4 What this section does NOT verify

I did not:
- Run `gleam run migrate` to apply 046 to the live DB
- Verify that existing live-DB rows are unchanged by 046 (the migration drops
  constraints and adds indexes; the data should be untouched, but I did not
  run it)
- Check the `simple_migrate.gleam` change beyond reading the diff
- Check the `soul_version_writer.gleam` error-handling change in a test

These are all S's responsibility per the no-conflict instruction.

### 12.5 Final review summary (post-a0d75fd)

**Original findings (B.1, B.2, B.6) — RESOLVED.**
**New findings from the post-fix review — none.**
**Remaining work — mechanical doc/code updates, not design risks.**

The append-only pattern as designed is now correctly implemented in the
schema. The Gleam wrapper is correct. The migration runner is correct. The
remaining items are the same plumbing that would be needed for any schema
change: doc updates, reader filters, table documentation, and deprecation
comments.

The next agent (or the same one when implementation resumes) can pick up at
step 4 of the implementation order in §8.
