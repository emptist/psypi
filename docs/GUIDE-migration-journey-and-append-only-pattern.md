# Migration Journey & Append-Only Pattern — Complete Guide

**Date:** 2026-06-05
**Status:** Living document
**Scope:** psypi database schema evolution, append-only pattern, and migration best practices

---

## Table of Contents

1. [Migration System Architecture](#1-migration-system-architecture)
2. [The Append-Only Pattern](#2-the-append-only-pattern)
3. [Migration Journey: What We Learned](#3-migration-journey-what-we-learned)
4. [Current State: Table-by-Table Analysis](#4-current-state-table-by-table-analysis)
5. [Remaining Work: Tables to Convert](#5-remaining-work-tables-to-convert)
6. [Migration Template](#6-migration-template)
7. [Gleam + PostgreSQL Conventions](#7-gleam--postgresql-conventions)
8. [Common Pitfalls](#8-common-pitfalls)

---

## 1. Migration System Architecture

### How Migrations Work

psypi uses a simple file-based migration system:

```
src/migrations/
├── 001_initial_schema.sql
├── 002_*.sql
├── ...
└── 047_table_documentation_new_columns.sql
```

**Runner:** `src/simple_migrate.gleam`
**Command:** `gleam run -m simple_migrate` or `make migrate`
**Ordering:** Lexicographic sort on filenames (hence zero-padded numbers: 001, 002, ..., 047)

### Migration File Conventions

```sql
-- Migration NNN: Short description
--
-- Long description explaining what this migration does,
-- why it's needed, and any important considerations.
--
-- DESIGN:
--   Key design decisions and rationale.
--
-- ONLINE-SAFE NOTES:
--   Whether this migration can run while Pi is running.
--   Lock requirements, table sizes, estimated duration.

-- ═══════════════════════════════════════════════════════════════════
-- Section 1: DDL changes
-- ═══════════════════════════════════════════════════════════════════

-- Always use IF NOT EXISTS / IF EXISTS for idempotency
ALTER TABLE foo ADD COLUMN IF NOT EXISTS bar text;

-- ═══════════════════════════════════════════════════════════════════
-- Section 2: Data backfill
-- ═══════════════════════════════════════════════════════════════════

-- Use WHERE conditions for idempotency
UPDATE foo SET bar = 'default' WHERE bar IS NULL;

-- ═══════════════════════════════════════════════════════════════════
-- Section 3: Constraints (after backfill)
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE foo ALTER COLUMN bar SET NOT NULL;
```

### Key Rules

1. **Idempotent:** All DDL uses `IF NOT EXISTS` / `IF EXISTS`
2. **Online-safe:** Document whether Pi can stay running during migration
3. **Ordered:** Zero-padded numbering ensures correct execution order
4. **Self-contained:** Each migration is independent (no cross-file dependencies)
5. **No down migrations:** We don't roll back — we fix forward

---

## 2. The Append-Only Pattern

### What Is It?

Instead of UPDATE-in-place (which loses history), append-only means:
- **Deactivate** the old row (set `is_active = false`)
- **Insert** a new row with the updated data
- **Preserve** the old row for history

### Why Use It?

| Problem | Append-Only Solution |
|---------|---------------------|
| "What was the soul content before the last change?" | Query `WHERE is_active = false ORDER BY created_at DESC` |
| "When did this job's priority change?" | Check `created_at` differences between versions |
| "Who changed this config and when?" | Each version has its own `created_at` and can be audited |
| "Revert to previous version" | Deactivate current, reactivate old (with care) |

### The Two-Flag Pattern

```sql
-- is_active: Points to the CURRENT version (at most one per business key)
-- is_archived: Controls visibility (application-managed)

-- Live row:     is_active = true,  is_archived = false
-- Historical:   is_active = false, is_archived = false
-- Hidden/old:   is_active = false, is_archived = true
```

### Partial Unique Indexes

The critical design decision: uniqueness constraints must use `WHERE is_active = true`:

```sql
-- ✅ CORRECT: Only one active row per key
CREATE UNIQUE INDEX uq_agent_souls_active_id_prefix
  ON agent_souls (id_prefix) WHERE is_active = true;

-- ❌ WRONG: Fails on first save_soul_version() call
CREATE UNIQUE INDEX uq_agent_souls_active_id_prefix
  ON agent_souls (id_prefix) WHERE is_archived = false;
```

**Why:** When deactivating, the old row has `is_active = false, is_archived = false`. With `WHERE is_archived = false`, both old and new rows match the index, causing a duplicate key error.

### SQL Function Pattern

Wrap the deactivate + insert in a plpgsql function for atomicity:

```sql
CREATE OR REPLACE FUNCTION save_<entity>_version(
  p_business_key text,
  p_content       text
) RETURNS uuid AS $$
DECLARE
  v_new_id uuid;
BEGIN
  -- 1. Deactivate current active row
  UPDATE <table>
     SET is_active = false
   WHERE <business_key> = p_business_key
     AND is_active = true;

  -- 2. Insert new version, copying stable fields from most recent row
  INSERT INTO <table> (field1, field2, content, is_active, is_archived)
  SELECT field1, field2, p_content, true, false
  FROM <table>
  WHERE <business_key> = p_business_key
  ORDER BY created_at DESC
  LIMIT 1
  RETURNING id INTO v_new_id;

  IF v_new_id IS NULL THEN
    RAISE EXCEPTION 'save_<entity>_version: no previous row found for key=%', p_business_key;
  END IF;

  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;
```

### Gleam Wrapper Pattern

```gleam
// src/<entity>_version_writer.gleam

pub fn save_<entity>_version(
  business_key: String,
  content: String,
) -> promise.Promise(Result(String, VersionError)) {
  db.with_connection(fn(conn) {
    let sql = "SELECT save_<entity>_version($1, $2) AS new_id"
    let params = [dynamic.string(business_key), dynamic.string(content)]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_version_error(e))
        Ok(result) ->
          case result.rows {
            [] -> Error(NoIdReturned)
            [row, ..] ->
              case decode.run(row, id_decoder()) {
                Ok(id) -> Ok(id)
                Error(e) -> Error(decode_error_to_version_error(e))
              }
          }
      }
    })
  }, db_error_to_version_error)
}
```

### Read Path

Always filter on both flags:

```sql
-- Current active version
SELECT * FROM <table>
WHERE <business_key> = $1
  AND is_active = true
  AND is_archived = false
LIMIT 1;

-- Full history (including archived)
SELECT * FROM <table>
WHERE <business_key> = $1
ORDER BY created_at DESC;

-- Visible history (excludes archived)
SELECT * FROM <table>
WHERE <business_key> = $1
  AND is_archived = false
ORDER BY created_at DESC;
```

---

## 3. Migration Journey: What We Learned

### Phase 1: Schema Foundation (Migrations 001-015)

**What happened:** Basic tables created — `agent_souls`, `agent_jobs`, `tasks`, `issues`, `code_versions`, etc.

**Lesson:** Start with the schema you need, not the schema you think you might need. The initial schema was simple and grew organically.

### Phase 2: Feature Growth (Migrations 016-030)

**What happened:** More tables added — `memory`, `learning_insights`, `inter_reviews`, `review_findings`, `system_reviews`, `meetings`, `skills`.

**Lesson:** Write-once log tables (inter_reviews, review_findings) are naturally append-only. No special pattern needed — just INSERT.

### Phase 3: The Append-Only Awakening (Migrations 038-046)

**What happened:** Realized `agent_souls` and `agent_jobs` were being UPDATE-in-place, losing all history. Created the append-only pattern.

**Key migrations:**
- `038-044`: Various soul/job updates (using old UPDATE pattern — kept for historical accuracy)
- `046`: **The big migration** — converted to append-only with `is_active`/`is_archived` flags

**Lesson:** The append-only pattern is not just about preserving data — it's about making the system **auditable** and **reversible**.

### Phase 4: Cleanup and Documentation (Migrations 046-047+)

**What happened:** Fixed issues from the append-only migration, added documentation columns.

**Lesson:** After a major schema change, always:
1. Verify data integrity (`SELECT COUNT(*) WHERE <flag> IS NULL`)
2. Update documentation (`table_documentation`)
3. Update Gleam code to use new patterns
4. Test the read/write paths end-to-end

---

## 4. Current State: Table-by-Table Analysis

### Already Append-Only ✅

| Table | Pattern | Migration | Notes |
|-------|---------|-----------|-------|
| `agent_souls` | `is_active`/`is_archived` + `save_soul_version()` | 046 | Canonical example |
| `agent_jobs` | `is_active`/`is_archived` + `save_job_version()` | 046 | Same pattern |
| `code_versions` | Append-only by design | 014 | Version history table |
| `inter_reviews` | Write-once log | 024 | Created with data, minimal updates |
| `review_findings` | Write-once log | 027 | Status transitions only |
| `system_reviews` | Write-once log | 027 | Status transitions only |
| `memory`/`memories` | Write-once logs | 017 | Append-only by nature |
| `learning_insights` | Write-once logs | 016 | Append-only by nature |
| `activity_log`/`event_log` | Write-once logs | 023 | Append-only by nature |
| `issue_comments`/`issue_events`/`issue_labels` | Write-once logs | 015 | Append-only by nature |
| `meeting_opinions` | Write-once log | 021 | Append-only by nature |
| `review_comments`/`review_labels` | Write-once logs | 027 | Append-only by nature |
| `skill_audit_log` | Append-only audit log | 020 | Already tracks changes |

### State Machine Tables (UPDATE is Correct) ✅

| Table | Pattern | Notes |
|-------|---------|-------|
| `tasks` | Status transitions (PENDING→RUNNING→COMPLETED) | Content doesn't change, only state |
| `issues` | Status transitions (open→in_progress→resolved) | Resolution added at end |
| `meetings` | Status transitions (active→completed) | Consensus added at end |

### Static Reference Data ✅

| Table | Notes |
|-------|-------|
| `agent_prefixes` | A, S, G — never changes |
| `agent_identities` | Identity records, rarely changes |
| `labels` | Reference data |

### Needs Investigation ⚠️

| Table | Issue |
|-------|-------|
| `skills` | `content` (JSONB) overwritten, `skill_versions` exists but empty |
| `psypi_config` | `ON CONFLICT DO UPDATE` loses history |
| `agent_configs` | Has `version` field but uses UPDATE-in-place |

---

## 5. Remaining Work: Tables to Convert

### Priority 1: `skills` Table

**Current state:** UPDATE-in-place on `content`, `status`, `version` fields.
**Problem:** Old skill definitions are lost when updated.
**Solution:** Use `skill_versions` as the history table.

**Migration plan:**
1. Add `is_active` and `is_archived` columns to `skills`
2. Create partial unique index on `(name) WHERE is_active = true`
3. Create `save_skill_version()` SQL function
4. Create Gleam wrapper `src/skill_version_writer.gleam`
5. Update `src/skill.gleam` to use append-only writes
6. Backfill any existing data

### Priority 2: `psypi_config` Table

**Current state:** `ON CONFLICT DO UPDATE` — overwrites value.
**Problem:** Operational config history (last_wakeup, idle_since) is lost.
**Solution:** Split into two patterns:
- **Static config** (`monitor_debounce_ms`): Keep UPDATE-in-place (rarely changes)
- **Operational state** (`last_wakeup`, `idle_since`): Convert to append-only

**Alternative:** Convert entire table to append-only with `save_config_version()`.

### Priority 3: `agent_configs` Table

**Current state:** Has `version` field but uses UPDATE-in-place.
**Problem:** Agent configuration evolution is not tracked.
**Solution:** Apply standard append-only pattern.

---

## 6. Migration Template

Use this template for new append-only migrations:

```sql
-- Migration NNN: Convert <table> to append-only
--
-- Converts <table> from UPDATE-in-place to append-only pattern.
-- Adds is_active and is_archived columns, partial unique indexes,
-- and save_<entity>_version() SQL function.
--
-- DESIGN:
--   is_active = true → current version (at most one per business key)
--   is_archived = false → visible to application
--   READ PATH: WHERE is_active = true AND is_archived = false
--   WRITE PATH: save_<entity>_version() — never UPDATE in place
--
-- ONLINE-SAFE NOTES:
--   Table size: <N> rows
--   Lock duration: <estimate>
--   Pi can stay running: yes/no

-- ═══════════════════════════════════════════════════════════════════
-- 1. Add columns
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE <table>
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;
ALTER TABLE <table>
  ADD COLUMN IF NOT EXISTS is_archived boolean NOT NULL DEFAULT false;

-- ═══════════════════════════════════════════════════════════════════
-- 2. Drop old unique constraints, create partial unique indexes
-- ═══════════════════════════════════════════════════════════════════

-- Drop the old constraint (if exists)
ALTER TABLE <table> DROP CONSTRAINT IF EXISTS <old_constraint>;

-- Create partial unique index on business key
CREATE UNIQUE INDEX IF NOT EXISTS uq_<table>_active_<business_key>
  ON <table> (<business_key>) WHERE is_active = true;

-- ═══════════════════════════════════════════════════════════════════
-- 3. Backfill (if needed)
-- ═══════════════════════════════════════════════════════════════════

-- Ensure all existing rows have is_active = true, is_archived = false
UPDATE <table> SET is_active = true, is_archived = false
WHERE is_active IS NULL OR is_archived IS NULL;

-- ═══════════════════════════════════════════════════════════════════
-- 4. SQL function for append-only writes
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION save_<entity>_version(
  p_<business_key> text,
  p_content         text
) RETURNS uuid AS $$
DECLARE
  v_new_id uuid;
BEGIN
  -- Deactivate old version
  UPDATE <table>
     SET is_active = false
   WHERE <business_key> = p_<business_key>
     AND is_active = true;

  -- Insert new version, copying stable fields from most recent row
  INSERT INTO <table> (field1, field2, content, is_active, is_archived)
  SELECT field1, field2, p_content, true, false
  FROM <table>
  WHERE <business_key> = p_<business_key>
  ORDER BY created_at DESC
  LIMIT 1
  RETURNING id INTO v_new_id;

  IF v_new_id IS NULL THEN
    RAISE EXCEPTION 'save_<entity>_version: no previous row found for key=%', p_<business_key>;
  END IF;

  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════
-- 5. Verification queries
-- ═══════════════════════════════════════════════════════════════════

-- Verify: no NULL flags
SELECT COUNT(*) FROM <table> WHERE is_active IS NULL OR is_archived IS NULL;

-- Verify: at most one active row per business key
SELECT <business_key>, COUNT(*) as active_count
FROM <table> WHERE is_active = true
GROUP BY <business_key> HAVING COUNT(*) > 1;
```

---

## 7. Gleam + PostgreSQL Conventions

### Type Mapping

| PostgreSQL | Gleam | Notes |
|-----------|-------|-------|
| `uuid` | `String` | UUIDs are strings in Gleam |
| `text` | `String` | |
| `integer` | `Int` | |
| `boolean` | `Bool` | |
| `jsonb` | `Dynamic` | Use `decode` for structured access |
| `text[]` | `List(String)` | |
| `timestamp with time zone` | `String` | ISO 8601 format |
| `uuid[]` | `List(String)` | |

### Error Handling Pattern

```gleam
pub type DbError {
  ConnectionError(String)
  QueryError(String)
}

fn db_error_to_my_error(e: db.DbError) -> MyError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}
```

### Query Pattern

```gleam
pub fn my_query(param: String) -> promise.Promise(Result(MyType, MyError)) {
  db.with_connection(fn(conn) {
    let sql = "SELECT ... FROM ... WHERE col = $1"
    let params = [dynamic.string(param)]
    promise.map(db.query(conn, sql, params), fn(result) {
      case result {
        Error(e) -> Error(db_error_to_my_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, my_decoder()) {
                Ok(value) -> Ok(value)
                Error(_) -> Error(DecodeError("Failed to decode"))
              }
            }
            _ -> Error(NotFound("Not found"))
          }
        }
      }
    })
  }, db_error_to_my_error)
}
```

### Decoder Pattern

```gleam
fn my_decoder() -> decode.Decoder(MyType) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use content <- decode.field("content", decode.string)
  decode.success(MyType(id: id, name: name, content: content))
}
```

---

## 8. Common Pitfalls

### ❌ Wrong Index Condition

```sql
-- WRONG: Fails on first version save
CREATE UNIQUE INDEX uq_foo_active_key
  ON foo (key) WHERE is_archived = false;

-- CORRECT: Only enforces uniqueness for active rows
CREATE UNIQUE INDEX uq_foo_active_key
  ON foo (key) WHERE is_active = true;
```

### ❌ Forgetting to Filter on Read

```sql
-- WRONG: Returns historical rows alongside active
SELECT * FROM agent_souls WHERE id_prefix = 'A';

-- CORRECT: Only returns current version
SELECT * FROM agent_souls
WHERE id_prefix = 'A' AND is_active = true AND is_archived = false
LIMIT 1;
```

### ❌ UPDATE in Append-Only Table

```sql
-- WRONG: Overwrites history
UPDATE agent_souls SET content = 'new' WHERE id_prefix = 'A';

-- CORRECT: Use the version function
SELECT save_soul_version('A', 'new');
```

### ❌ Non-Idempotent Migration

```sql
-- WRONG: Fails on re-run
ALTER TABLE foo ADD COLUMN bar text;

-- CORRECT: Safe to re-run
ALTER TABLE foo ADD COLUMN IF NOT EXISTS bar text;
```

### ❌ Migration Without Verification

```sql
-- Always add verification queries at the end
SELECT COUNT(*) FROM foo WHERE bar IS NULL;  -- expect 0
SELECT key, COUNT(*) FROM foo WHERE is_active = true GROUP BY key HAVING COUNT(*) > 1;  -- expect 0 rows
```

---

## Appendix: Migration Numbering

Current highest: `047`

Next migration: `048_append_only_skills.sql`

When creating a new migration:
1. Use the next number: `048`
2. Use descriptive filename: `048_append_only_skills.sql`
3. Follow the template in Section 6
4. Run `make migrate` to apply
5. Verify with the queries in Section 6
