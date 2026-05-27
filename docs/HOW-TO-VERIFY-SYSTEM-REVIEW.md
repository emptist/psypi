# How to Verify the System Review

This document explains how any AI (or human) can verify the findings in the psypi system review.

## Current Review

- **Review ID**: `ca9e914c-cce6-4db4-b3b1-29779d8e1837`
- **Database**: `psypi` (PostgreSQL, **shared by multiple projects**)
- **Tables**: `system_reviews`, `review_findings`
- **Total findings**: 109 (106 open, 3 retracted)

## Important: Shared Database

The `psypi` database has **97 tables**, but psypi's Gleam code only touches **22 tables**. The other 75 tables belong to other projects (nezha, nupi, piano, xcom, etc.).

**Tables psypi actually uses** (from Gleam source code analysis):

| Table | Has project_id | Used by |
|-------|---------------|---------|
| agent_identities | No | agents.gleam |
| agent_jobs | No | agent_identity.gleam, a_db_reader.gleam, s_db_reader.gleam |
| agent_prefixes | No | seed.gleam |
| agent_sessions | No | a_db_reader.gleam |
| agent_souls | No | agent_identity.gleam, a_db_reader.gleam, s_db_reader.gleam, seed.gleam |
| activity_log | No | monitor.gleam, monitor_ai.gleam |
| code_versions | No | code_version.gleam, monitor_ai.gleam |
| inter_reviews | No | inter_review.gleam, monitor_ai.gleam |
| issues | Yes | issue_db.gleam, areflect.gleam, monitor_ai.gleam, a_db_reader.gleam, stats.gleam |
| learning_insights | Yes | areflect.gleam |
| meeting_opinions | No | meeting.gleam |
| meetings | Yes | meeting.gleam, stats.gleam |
| memory | Yes | memory.gleam, learning.gleam, monitor_ai.gleam |
| notifications | No | monitor.gleam |
| project_communications | Yes | broadcast.gleam |
| provider_api_keys | No | monitor.gleam |
| psypi_config | No | psypi_config.gleam, seed.gleam |
| psypi_event_hooks | No | event_hooks.gleam |
| review_findings | No | system_review_db.gleam |
| skills | Yes | skill.gleam, monitor_ai.gleam, stats.gleam |
| system_reviews | Yes | system_review_db.gleam |
| tasks | Yes | task.gleam, areflect.gleam, monitor_ai.gleam, a_db_reader.gleam, stats.gleam |

**Implication**: When verifying findings, only check these 22 tables. Tables like `users`, `payments`, `conversations`, `soul`, etc. are NOT psypi's concern.

## Quick Start

### 1. Read the findings

```sql
-- All open findings, sorted by severity
SELECT finding_number, severity, category, module, title, status
FROM review_findings
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837'
  AND status = 'open'
ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 END, finding_number;
```

### 2. Verify a specific finding

Each finding has an `evidence` field that points to specific source code or SQL queries.

**Example: Finding #215** — "monitor_ai record_tool_error: INSERT uses type instead of issue_type"

```sql
-- Read the finding
SELECT title, description, evidence, impact
FROM review_findings
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837'
  AND finding_number = 215;
```

The evidence says: `monitor_ai.gleam:561 INSERT INTO issues with wrong column names`

**Verify against source code:**
```bash
grep -n "INSERT INTO issues" src/monitor_ai.gleam
# Output: 561: INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment)
```

**Verify against database schema:**
```sql
SELECT column_name FROM information_schema.columns
WHERE table_name = 'issues' AND column_name IN ('type', 'issue_type')
ORDER BY column_name;
-- Output: issue_type (NOT "type")
```

**Result**: Finding CONFIRMED — `type` column doesn't exist, should be `issue_type`.

### 3. Record your verification

```sql
-- Confirm a finding
UPDATE review_findings
SET status = 'confirmed', updated_at = now()
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837'
  AND finding_number = 215;

-- Dispute a finding (with counter-evidence)
UPDATE review_findings
SET status = 'disputed',
    impact = 'Counter-evidence: the column DOES exist, see information_schema.columns',
    updated_at = now()
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837'
  AND finding_number = 999;
```

## Verification Methods by Category

### `missing_cast` findings (most common)

These claim that a SQL query selects a uuid/timestamptz/jsonb column without `::text` cast, causing Gleam decode failures.

**How to verify:**
1. Read the finding's `evidence` field for the file and line number
2. Open the Gleam source file at that line
3. Check if the SELECT includes `::text` for uuid/timestamptz columns
4. Cross-check: `SELECT data_type FROM information_schema.columns WHERE table_name = 'X' AND column_name = 'id';`
   - If `data_type` is `uuid` and there's no `::text` cast → CONFIRMED
   - If `data_type` is `text` → DISPUTED (no cast needed)

### `type_mismatch` findings

These claim that Gleam type variants don't match PostgreSQL CHECK constraints.

**How to verify:**
1. Read the finding for the Gleam type and module name
2. Check the Gleam source for the type definition
3. Check the DB constraint: `SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = 'tablename'::regclass AND contype = 'c';`
4. Compare the variants/values

**Known mismatches (verified):**

| Module | Gleam Type | DB CHECK | Missing in Gleam |
|--------|-----------|----------|-----------------|
| skill | SkillSource | clawhub/local/generated/imported/ai-built | `ai-built` |
| task | TaskStatus | PENDING/RUNNING/COMPLETED/FAILED/FAKE_COMPLETE | `FAKE_COMPLETE` |
| issue_types | IssueStatus | open/acknowledged/in_progress/resolved/wont_fix/duplicate | `acknowledged`, `wont_fix`, `duplicate`; Gleam has `Closed` which DB doesn't have |

### `wrong_column` findings

These claim that an INSERT/UPDATE uses a column name that doesn't exist.

**How to verify:**
1. Read the finding for the file, line, and wrong column name
2. Check the source: `grep -n "INSERT INTO tablename" src/module.gleam`
3. Check the schema: `SELECT column_name FROM information_schema.columns WHERE table_name = 'tablename' ORDER BY ordinal_position;`
4. If the column is missing from the schema → CONFIRMED

### `design_flaw` findings

These are architectural issues that require judgment. Verify by:
1. Reading the description and impact
2. Checking if the described behavior actually exists in the code
3. Assessing whether the impact is accurately described

## Pi TUI Tools

If you're running inside the Pi TUI (not Trae), use these tools:

| Tool | Purpose |
|------|---------|
| `psypi-review-list` | List all reviews |
| `psypi-review-get <id>` | Get review details |
| `psypi-findings <id>` | List findings |
| `psypi-finding-count <id>` | Severity/category breakdown |
| `psypi-finding-update <id> <number> <status>` | Confirm/dispute/fix a finding |
| `psypi-finding-add <id>` | Add a new finding |
| `psypi-review-severity <id>` | Severity breakdown |

## Generating Reports

```bash
# Generate markdown from database
python3 scripts/generate_review_md.py > docs/SYSTEM-REVIEW-DB-$(date +%Y-%m-%d).md
```

## Finding Status Lifecycle

```
open → confirmed (verified by independent check)
open → disputed (counter-evidence found)
open → fixed (code has been corrected)
confirmed → fixed
disputed → retracted (original reviewer agrees it was wrong)
open → duplicate (same as another finding)
```

## Spot-Check Results (2026-05-28)

| Finding | Claim | Verified | Result |
|---------|-------|----------|--------|
| #100 | inter_review requested_at missing ::text | Source line 148, 283: no ::text | CONFIRMED |
| #116 | areflect.save_issue omits project_id (NOT NULL) | Source line 224: no project_id; DB: NOT NULL | CONFIRMED |
| #118 | auto_file_issue uses "type" not "issue_type" | Source line 561: uses "type"; DB: column is "issue_type" | CONFIRMED |
| #121 | get_config returns JS null/string not Gleam Option | FFI line 154: returns null or raw string | CONFIRMED |
| #124 | ctx_is_idle returns JS boolean not Gleam Bool | FFI line 27: returns ctx.isIdle() | CONFIRMED |
| #126 | seed.gleam 300000 vs DB 900000 | Source line 49: 300000; DB: 900000 | CONFIRMED |
| #128 | areflect.save_learning ignores agent_id | Source line 182: _agent_id prefixed with _ | CONFIRMED |
| #139 | broadcast.stats: bigint decode, text>=int, no status column | Source: decode.int on COUNT(*); priority is text; no status column | CONFIRMED |
| #215 | monitor_ai INSERT uses "type" not "issue_type" | Source line 561: uses "type" | CONFIRMED (corrected: discovered_by/environment DO exist) |
| #226 | SkillSource missing ai-built | Source: 4 variants; DB CHECK: 5 values | CONFIRMED |
| #227 | TaskStatus missing FAKE_COMPLETE | Source: 4 variants; DB CHECK: 5 values | CONFIRMED |
| #229 | IssueStatus mismatch | Source: Open/InProgress/Resolved/Closed; DB: open/acknowledged/in_progress/resolved/wont_fix/duplicate | CONFIRMED |

**Errors found during spot-check**: Finding #215 originally claimed `discovered_by` and `environment` columns don't exist in the `issues` table. They DO exist. Corrected to: only `type` → `issue_type` is wrong, severity reduced from critical to high. Finding #236 was retracted — memory.gleam uses `created_at` correctly, the `saved_at` reference was from monitor_ai.gleam querying `code_versions`.

## Gap Analysis: Gleam Code vs Database Schema (Findings #231-#243)

A bidirectional gap analysis was performed comparing what Gleam code expects vs what the database actually has.

### Methodology

1. Extracted all table names from Gleam `SELECT`, `INSERT INTO`, and `UPDATE` statements
2. Extracted all column names referenced in those SQL statements
3. Compared against `information_schema.columns` for each table
4. Identified: unused tables, unused columns, wrong column references, missing `::text` casts

### Gap 1: Tables in DB but Never Used by psypi Gleam Code

| Table | Rows | Has project_id | Likely Owner |
|-------|------|----------------|-------------|
| agent_configs | 0 | Yes | nezha/nupi |
| agent_identity | 0 | No (agent_name is uuid!) | unknown |
| agent_moods | 0 | No | unknown |
| agent_scores | 0 | No | nezha |

All 4 tables are empty. None are documented in `table_documentation`. None are referenced by any Gleam source file.

### Gap 2: Tables Referenced in Gleam but Missing from DB

**None found.** All 22 tables referenced by Gleam code exist in the database.

### Gap 3: Column Mismatches (Gleam expects columns that don't exist)

| Finding# | Module | Wrong Column | Correct Column | Severity |
|----------|--------|-------------|----------------|----------|
| #237 | broadcast | `status` | doesn't exist | high |
| #139 | broadcast | `priority >= 2` | priority is text, not int | medium |

### Gap 4: Massive Unused DB Columns

| Table | DB Columns | Gleam Handles | Unused | Finding# |
|-------|-----------|--------------|--------|----------|
| tasks | 60 | 14 | 46 | #232 |
| skills | 60+ | ~10 | 45+ | #233 |
| issues | 30+ | ~15 | 15+ | #234 |
| inter_reviews | 30+ | 6 | 27+ | #235 |
| learning_insights | 13 | 4 (INSERT only) | 9 (never read) | #238 |
| psypi_event_hooks | 14 | 7 | 7 | #240 |
| project_communications | 12 | 8 | 4 | #241 |
| meetings | 10 | 6 | 4 | #242 |
| provider_api_keys | 10 | 3 | 7 | #239 |
| system_reviews | 17 | 14 | 3 (legacy JSONB) | #243 |

**Key insight**: The database schema is far richer than what psypi's Gleam code uses. Many columns are written by other projects (nezha, nupi) but psypi can't read them. This is a design gap, not necessarily a bug.

### Gap 5: Write-Only Tables

| Table | Writes | Reads | Finding# |
|-------|--------|-------|----------|
| learning_insights | areflect.gleam (INSERT 4 cols) | **NONE** | #238 |

Learning insights are stored but never consumed. No feedback loop exists.

### How to Verify Gap Findings

```sql
-- Verify unused columns for any table
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'tasks' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Cross-reference with Gleam decoder
-- Read the Gleam source file's decoder function and compare field names

-- Check if a table is truly unused by psypi
SELECT table_name FROM table_documentation
WHERE table_name IN ('agent_configs', 'agent_identity', 'agent_moods', 'agent_scores')
AND notes LIKE '%psypi%';

-- Verify table_documentation has gap info
SELECT table_name, notes FROM table_documentation
WHERE table_name = 'tasks' AND notes LIKE '%GAP%';
```

## Using table_documentation for Verification

The `table_documentation` table now contains gap analysis notes for all 22 psypi tables plus the 4 unused agent_* tables. Any AI can:

1. **Find which tables psypi uses**: `SELECT table_name FROM table_documentation WHERE notes LIKE '%GAP%' OR purpose LIKE '%psypi%';`
2. **Check column gaps**: Read the `notes` field — it lists unused columns and missing `::text` casts
3. **Understand shared DB context**: Tables tagged `shared-db` belong to other projects
4. **Verify findings**: Use `example_queries` in `table_documentation` for `review_findings` and `system_reviews`

```sql
-- Get full documentation for a table
SELECT table_name, purpose, key_columns, notes, example_queries
FROM table_documentation
WHERE table_name = 'tasks';

-- List all tables with gap notes
SELECT table_name, substring(notes, 1, 80) as gap_summary
FROM table_documentation
WHERE notes LIKE '%GAP%' OR notes LIKE '%needs ::text%'
ORDER BY table_name;
```
