# Implementation Plan: Append-Only Migration for Remaining Tables

**Date:** 2026-06-05
**Status:** Ready for review
**Scope:** Convert `skills`, `psypi_config`, and `agent_configs` to append-only pattern

---

## Overview

Three tables in psypi still use UPDATE-in-place, losing historical data when values change. This plan converts them to the append-only pattern established by migration 046 for `agent_souls` and `agent_jobs`.

**Priority order:**
1. `skills` — Most valuable (skill definitions evolve, history matters)
2. `psypi_config` — Operational state (debugging needs history)
3. `agent_configs` — Currently empty, but designed for versioning

---

## Architecture Decisions

1. **Reuse the established pattern** — `is_active`/`is_archived` flags + partial unique indexes + `save_*_version()` SQL functions. No new patterns needed.

2. **Skills uses `skill_versions` as history table** — The table already exists (0 rows). Instead of adding `is_active`/`is_archived` to `skills`, we populate `skill_versions` on each change. The `skills` table stays as the "current version" table.

3. **psypi_config splits into two patterns** — Operational keys (`last_wakeup`, `idle_since`) get append-only. Static config (`monitor_debounce_ms`) stays as UPDATE-in-place (rarely changes, no history needed).

4. **agent_configs uses standard pattern** — Add `is_active`/`is_archived` like `agent_souls`.

---

## Task List

### Phase 1: Skills Table

#### Task 1: Create migration 048 — Skills append-only

**Description:** Convert `skills` table to use `skill_versions` as history. The `skills` table holds only the current version; `skill_versions` captures every change.

**Acceptance criteria:**
- [ ] `skill_versions` table has `is_active` column (for potential future use)
- [ ] `save_skill_version()` SQL function exists and works
- [ ] `skill_version_writer.gleam` Gleam wrapper exists
- [ ] `skill.gleam` uses append-only writes for content changes
- [ ] Status changes (approve/reject) still use UPDATE-in-place (state machine)

**Verification:**
- [ ] `psql -d psypi -c "SELECT save_skill_version('test-skill', '{}')"` returns a UUID
- [ ] `psql -d psypi -c "SELECT COUNT(*) FROM skill_versions"` increases
- [ ] Gleam build succeeds: `gleam clean && gleam build`

**Dependencies:** None

**Files likely touched:**
- `src/migrations/048_append_only_skills.sql`
- `src/skill_version_writer.gleam` (new)
- `src/skill.gleam` (modify)

**Estimated scope:** Medium (3-5 files)

---

#### Task 2: Create skill_version_writer.gleam

**Description:** Create the Gleam wrapper for `save_skill_version()` SQL function.

**Acceptance criteria:**
- [ ] `save_skill_version(skill_name, content)` returns `Result(String, SkillVersionError)`
- [ ] Error types follow the established pattern (`ConnectionError`, `QueryError`, `DecodeError`, `NoIdReturned`)
- [ ] Decoder works for the `new_id` return value

**Verification:**
- [ ] `gleam build` succeeds
- [ ] Function can be called from Gleam code

**Dependencies:** Task 1 (SQL function must exist)

**Files likely touched:**
- `src/skill_version_writer.gleam` (new)

**Estimated scope:** Small (1-2 files)

---

#### Task 3: Update skill.gleam for append-only writes

**Description:** Modify `skill.gleam` to use `save_skill_version()` when skill content changes. Status changes (approve/reject) remain as UPDATE-in-place since they are state machine transitions.

**Acceptance criteria:**
- [ ] Skill creation inserts into both `skills` and `skill_versions`
- [ ] Skill content updates call `save_skill_version()` instead of UPDATE
- [ ] Status changes (approve, reject, install) still use UPDATE-in-place
- [ ] Read path queries `skills` for current version (unchanged)

**Verification:**
- [ ] `gleam build` succeeds
- [ ] Creating a skill populates both tables
- [ ] Updating skill content creates a new `skill_versions` row

**Dependencies:** Task 1, Task 2

**Files likely touched:**
- `src/skill.gleam` (modify)

**Estimated scope:** Medium (1 file, complex changes)

---

#### Task 4: Verify skills migration

**Description:** End-to-end verification of the skills append-only pattern.

**Acceptance criteria:**
- [ ] Create a skill → appears in `skills` and `skill_versions`
- [ ] Update skill content → new row in `skill_versions`, `skills` updated
- [ ] Approve skill → status changes in `skills` only (no `skill_versions` row)
- [ ] Query history → `skill_versions` shows all content changes

**Verification:**
- [ ] Manual test via `psql -d psypi`
- [ ] All existing Gleam tests pass (if any)

**Dependencies:** Task 3

**Files likely touched:** None (verification only)

**Estimated scope:** Small

---

### Checkpoint: Skills Migration
- [ ] All tasks complete
- [ ] `gleam build` succeeds
- [ ] `make migrate` runs without errors
- [ ] Skill creation/update/approve flows work end-to-end
- [ ] Review with human before proceeding

---

### Phase 2: psypi_config Table

#### Task 5: Create migration 049 — psypi_config append-only

**Description:** Convert `psypi_config` to append-only for operational keys. Static config stays as UPDATE-in-place.

**Acceptance criteria:**
- [ ] `save_config_version()` SQL function exists
- [ ] `config_version_writer.gleam` Gleam wrapper exists
- [ ] `psypi_config.gleam` uses append-only writes for all keys
- [ ] `config_history` table created for explicit history (optional: reuse pattern from `skill_versions`)

**Verification:**
- [ ] `psql -d psypi -c "SELECT save_config_version('test-key', 'test-value')"` returns
- [ ] Gleam build succeeds

**Dependencies:** None

**Files likely touched:**
- `src/migrations/049_append_only_psypi_config.sql`
- `src/config_version_writer.gleam` (new)
- `src/psypi_config.gleam` (modify)

**Estimated scope:** Medium (3-5 files)

---

#### Task 6: Update psypi_config.gleam for append-only writes

**Description:** Modify `psypi_config.gleam` to use `save_config_version()` instead of `ON CONFLICT DO UPDATE`.

**Acceptance criteria:**
- [ ] `set()` function calls `save_config_version()` instead of INSERT...ON CONFLICT DO UPDATE
- [ ] `get()` function reads current version (WHERE is_active = true)
- [ ] History is preserved in the table

**Verification:**
- [ ] `gleam build` succeeds
- [ ] Setting a config value creates a new row
- [ ] Getting a config value returns the current version

**Dependencies:** Task 5

**Files likely touched:**
- `src/psypi_config.gleam` (modify)

**Estimated scope:** Small (1-2 files)

---

#### Task 7: Verify psypi_config migration

**Description:** End-to-end verification of the psypi_config append-only pattern.

**Acceptance criteria:**
- [ ] Set config value → new row in `psypi_config`
- [ ] Set same key again → second row, first row deactivated
- [ ] Get config value → returns current active version
- [ ] History query → shows all previous values

**Verification:**
- [ ] Manual test via `psql -d psypi`
- [ ] Gleam build succeeds

**Dependencies:** Task 6

**Files likely touched:** None (verification only)

**Estimated scope:** Small

---

### Checkpoint: psypi_config Migration
- [ ] All tasks complete
- [ ] `gleam build` succeeds
- [ ] `make migrate` runs without errors
- [ ] Config set/get flows work end-to-end
- [ ] Review with human before proceeding

---

### Phase 3: agent_configs Table

#### Task 8: Create migration 050 — agent_configs append-only

**Description:** Convert `agent_configs` to append-only pattern.

**Acceptance criteria:**
- [ ] `is_active` and `is_archived` columns added
- [ ] Partial unique index on `(agent_id) WHERE is_active = true`
- [ ] `save_agent_config_version()` SQL function exists
- [ ] `agent_config_version_writer.gleam` Gleam wrapper exists

**Verification:**
- [ ] `psql -d psypi -c "SELECT save_agent_config_version('test-agent', '{}')"` returns
- [ ] Gleam build succeeds

**Dependencies:** None

**Files likely touched:**
- `src/migrations/050_append_only_agent_configs.sql`
- `src/agent_config_version_writer.gleam` (new)

**Estimated scope:** Medium (2-3 files)

---

#### Task 9: Verify agent_configs migration

**Description:** End-to-end verification of the agent_configs append-only pattern.

**Acceptance criteria:**
- [ ] Create agent config → appears with `is_active = true`
- [ ] Update config → new row, old row deactivated
- [ ] Query history → shows all previous versions

**Verification:**
- [ ] Manual test via `psql -d psypi`
- [ ] Gleam build succeeds

**Dependencies:** Task 8

**Files likely touched:** None (verification only)

**Estimated scope:** Small

---

### Checkpoint: Complete
- [ ] All migrations run successfully
- [ ] `gleam build` succeeds
- [ ] All three tables use append-only pattern
- [ ] Documentation updated (this plan, AGENTS.md if needed)
- [ ] Ready for review

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `skill_versions` table has 0 rows — schema may need adjustment | Medium | Review schema before migration, adjust if needed |
| `psypi_config` operational keys change frequently — table growth | Low | PostgreSQL handles this well; consider archival after N versions |
| `agent_configs` is empty — no backfill needed | Low | Simple DDL-only migration |
| Breaking existing Gleam code that uses UPDATE | High | Test each task thoroughly before proceeding |
| Partial unique index conflicts with existing data | Medium | Backfill before creating indexes |

---

## Open Questions

1. **Should `skill_versions` have its own `is_active`/`is_archived`?** Currently it's a pure history table (append-only by nature). Adding flags would be over-engineering unless we need to "promote" an old version.

2. **Should `psypi_config` split into two tables?** One for static config (UPDATE-in-place), one for operational state (append-only). This adds complexity but clarifies intent.

3. **Should we archive old `skill_versions` rows?** If the table grows large, we could add a cleanup job. For now, it's fine to keep all history.
