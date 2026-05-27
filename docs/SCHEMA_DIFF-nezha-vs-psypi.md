# Schema Diff: nezha vs psypi

**Date:** 2026-05-24  
**Purpose:** Document structural differences between nezha and psypi databases for future migration reference.

---

## `issues` table

| Feature            | nezha                                | psypi                                                  | Notes                                                                  |
| ------------------ | ------------------------------------ | ------------------------------------------------------ | ---------------------------------------------------------------------- |
| `project_id`       | ❌ missing                            | ✅ uuid, NOT NULL, FK → projects                        | nezha never had project scoping on issues [must have;remove if absent] |
| `created_by`       | NOT NULL, default `'S-nezha-system'` | nullable, default `'nezha'`                            | [NOT NULL, no default]                                                 |
| `issue_type` check | includes `'proposal'`                | no `'proposal'`                                        | nezha had more types [should include]                                  |
| RLS policy         | ❌ none                               | ✅ `issues_project_isolation`                           | nezha had no RLS                                                       |
| project_id indexes | ❌ none                               | ✅ `idx_issues_project_id`, `idx_issues_project_status` |                                                                        |
| Row count          | 139 (old nezha data)                 | 0 (cleaned — all had fake project_id from backfill)    |                                                                        |

## `tasks` table

| Feature                | nezha                                                                  | psypi                      | Notes                                                                        |
| ---------------------- | ---------------------------------------------------------------------- | -------------------------- | ---------------------------------------------------------------------------- |
| `project_id`           | NOT NULL, default `'00000000-0000-0000-0000-000000000001'` (fake UUID) | nullable, no default       | nezha used a fake default UUID [yes, no default; no, should not be nullable] |
| `result`               | `text`                                                                 | `jsonb`                    | Type changed in psypi                                                        |
| `created_by`           | NOT NULL, default `'human'`                                            | nullable, no default       | [psypi is right]                                                             |
| `source`               | ✅ present                                                              | ❌ missing                  | Dropped in psypi   [wrong! should be present]                                |
| `delegate_to`          | ❌ missing                                                              | ✅ present                  | Added in psypi                                                               |
| `delegated_from`       | ❌ missing                                                              | ✅ present                  | Added in psypi                                                               |
| `template_id`          | ❌ missing                                                              | ✅ uuid                     | Added in psypi                                                               |
| `executor_source`      | ❌ missing                                                              | ✅ present                  | Added in psypi                                                               |
| `session_id` index     | ✅ `idx_tasks_session_id`                                               | ❌ missing                  | Dropped in psypi                                                             |
| `status` check         | includes `'PAUSED'`                                                    | includes `'FAKE_COMPLETE'` | Different status values                                                      |
| Default config trigger | ❌ missing                                                              | ✅ present                  | Added in psypi                                                               |

## Config tables — consolidated (FIXED)

| Table | `monitor_debounce_ms` | Notes |
| --- | --- | --- |
| `psypi_config` | 900000 (15 min) | Single config table. `system_config` table dropped, module renamed to `psypi_config.gleam`. |

**History:** nezha had two config tables (`system_config` and `psypi_config`) with different debounce values, causing A-bot to fire too quickly. Merged into one.

## Tables in nezha but NOT in psypi

These tables existed in nezha but were not carried over to psypi:

| Table                  | Purpose                                         |
| ---------------------- | ----------------------------------------------- |
| `agent_soul`           | Old single-row soul (replaced by `agent_souls`) |
| `long_tasks_pause`     | Long-running task pause tracking  [should add]  |
| `stuck_tasks_tracking` | Stuck task monitoring  [should add]             |
| `failure_alerts`       | Failure alert system  [should add]              |
| `failure_patterns`     | Pattern detection  [should add]                 |
| `failure_root_causes`  | Root cause analysis [should add]                |
| `heartbeat_configs`    | Agent heartbeat configuration                   |
| `insert_reminders`     | Insert reminder system                          |
| `knowledge_links`      | Knowledge base links [should add]               |
| `labels`               | Label system                                    |
| `learning_insights`    | Learning insights [should add]                  |
| `mcp_configs`          | MCP tool configs                                |
| `mcp_tools`            | MCP tool registry                               |
| `meeting_opinions`     | Meeting opinions [should add]                   |
| `memories`             | Agent memories [should add]                     |

## Tables in psypi but NOT in nezha

| Table                 | Purpose                                 |
| --------------------- | --------------------------------------- |
| `agent_prefixes`      | A/S/G prefix definitions                |
| `agent_tasks`         | Agent-specific tasks                    |
| `agent_souls`         | New soul system (replaces `agent_soul`) |
| `code_versions`       | File version history                    |
| `email_verifications` | Email verification                      |

---

## Issue Tools — project_id Enforcement (Fixed This Session)

All issue tools now enforce project_id scoping:

| Tool                  | Before                                  | After                                                           |
| --------------------- | --------------------------------------- | --------------------------------------------------------------- |
| `psypi-issue-add`     | No project_id in INSERT → always failed | Defaults to current project UUID                                |
| `psypi-issues` (list) | No filter = show all projects           | Defaults to current project; pass `project_id=ALL` to show all  |
| `psypi-issue-count`   | No filter = count all projects          | Defaults to current project; pass `project_id=ALL` to count all |
| `psypi-issue-get`     | No project check                        | Filters by current project                                      |
| `psypi-issue-resolve` | No project check                        | Filters by current project                                      |

**`build_where` logic (issue_db.gleam):**
- `project_id = None` → filter by current project (default)
- `project_id = Some("ALL")` → no project filter (show all)
- `project_id = Some(uuid)` → filter by specific project

## Failed Issue Creation — ROOT CAUSE FOUND

`psypi-issue-add` was broken because:
1. `issue_db.add()` did NOT include `project_id` in its INSERT statement
2. `project_id` column was added as `NOT NULL` with no default
3. Therefore every INSERT failed silently — the tool could never create issues
4. The Gleam side also didn't decode `project_id` from the DB (not in `issue_decoder()`)

**Fixed this session:**
- Added `project_id` to `issue_db.add()` INSERT (6 params now)
- Added `project_id` param to `issue_add_tool()` with default project UUID
- Build passes

**Still needed:**
- Add `project_id` to `issue_decoder()` so issues can be read back with their project
- The `psypi-issue-resolve` and `psypi-issue-get` tools may also need project_id filtering
- `psypi-issues` list tool accepts project_id as filter param but it was never tested

*Created by S-bot during schema audit. For human review.*

---

## `system_reviews` + `review_findings` (psypi-only, 2026-05-27)

These tables are psypi-only (not in nezha). Created for database-first system review strategy.

| Feature | system_reviews | review_findings |
|---------|---------------|-----------------|
| Purpose | Track system-level reviews | Individual findings within a review |
| Key columns | id, review_type, status, scope, methodology, project_id, git_hash | id, review_id (FK), finding_number, severity, category, module, title, status |
| Severity values | N/A | critical, high, medium, low, cosmetic |
| Finding status | N/A | open, confirmed, disputed, fixed, wont_fix, duplicate, retracted |
| Review status | pending, in_progress, completed, follow_up, closed | N/A |
| Related Gleam types | `system_review_types.gleam`: SystemReview, ReviewType, ReviewStatus | `system_review_types.gleam`: ReviewFinding, FindingSeverity, FindingStatus |
| Related Gleam DB | `system_review_db.gleam` | `system_review_db.gleam` |
| Related Pi tools | `system_review_tools.gleam` (9 tools) | Same |

**Current review**: `ca9e914c-cce6-4db4-b3b1-29779d8e1837` — 96 findings (94 active, 2 retracted)
