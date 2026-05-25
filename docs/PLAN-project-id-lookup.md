# Plan: project_id Lookup from (path, git_remote)

## Problem
- `projects` table exists but Gleam code never queries it
- `project_id` is hardcoded as `0d324e68-b399-4b85-bd8a-6b1ef7b46168` across 57 locations in Gleam code
- `fingerprint` column exists but is unused — no stable identity mechanism
- When path or git_remote changes, there's no logic to detect it or create a new project

## Goal
- On each DB connection, look up `project_id` by `(path, git_remote)`
- If found → reuse existing `project_id`, update `last_seen`
- If not found → INSERT new row, use new `project_id`
- Remove hardcoded UUIDs from all Gleam code
- Remove `fingerprint` column

## Design

### 1. New file: `src/project.gleam`

Define a `Project` type matching the `projects` table:

```gleam
pub type Project {
  Project(
    id: String,
    name: String,
    path: String,
    git_remote: String,
    language: Option(String),
    framework: Option(String),
    status: String,
  )
}
```

Functions:
- `project_decoder()` — decode DB row into `Project`
- `lookup(conn, path, git_remote)` — SELECT by (path, git_remote), return `Option(Project)`
- `create(conn, name, path, git_remote)` — INSERT new project, return `Project`
- `update_last_seen(conn, project_id)` — UPDATE last_seen = NOW()
- `lookup_or_create(conn, path, git_remote)` — combined lookup + create if missing

### 2. Modified: `src/db.gleam`

In `connect()`, after establishing the connection:
1. Get `path` from `get_cwd()` FFI
2. Get `git_remote` from `get_git_remote()` FFI
3. Call `project.lookup_or_create(conn, path, git_remote)`
4. `SET app.current_project_id = <project.id>`

Remove hardcoded `0d324e68-...` fallback.

### 3. New FFI: `src/node_ffi.mjs`

Add:
- `get_cwd()` — returns `process.cwd()`
- `get_git_remote()` — runs `git remote get-url origin`, returns empty string on failure

### 4. Migration: `src/migrations/027_project_refactor.sql`

```sql
-- Drop fingerprint (replaced by path+git_remote natural key)
ALTER TABLE projects DROP COLUMN IF EXISTS fingerprint;

-- Add unique constraint on natural key
ALTER TABLE projects ADD CONSTRAINT projects_path_git_remote_unique UNIQUE (path, git_remote);

-- Make git_remote nullable (not all projects have remotes)
ALTER TABLE projects ALTER COLUMN git_remote DROP NOT NULL;
```

### 5. Gleam SQL changes — use session variable

Replace all hardcoded `0d324e68-...` in SQL with `current_setting('app.current_project_id')::uuid`:

**`src/task.gleam`:**
- `add()`: INSERT uses `current_setting('app.current_project_id')::uuid` for project_id
- `sql_with_filters()`: WHERE clause uses `current_setting('app.current_project_id')::uuid` when project_id param is null

**`src/issue_db.gleam`:**
- `add()`: INSERT uses session variable
- `get()`: WHERE uses session variable
- `resolve()`: WHERE uses session variable
- `list()`: WHERE uses session variable (default when no project_id param)
- `count()`: WHERE uses session variable (default when no project_id param)

**`src/broadcast.gleam`:**
- INSERT uses session variable

### 6. Tool parameter changes

**`src/task.gleam` — `task_add_tool()`:**
- Remove `project_id` from params (auto-resolved from session)

**`src/issue_tools.gleam` — `issue_add_tool()`:**
- Remove `project_id` from params (auto-resolved from session)

**`src/issue_tools.gleam` — `issue_list_tool()`, `issue_count_tool()`:**
- Keep `project_id` as optional param (for filtering by specific project or ALL)

**`src/task.gleam` — `task_list_tool()`:**
- Keep `project_id` as optional param (for filtering)

### 7. Files NOT changed
- `inter_review.gleam` — inter_reviews table has no project_id column
- `meeting.gleam` — meetings have project_id but that's for future work
- `skill.gleam` — skills have project_id but that's for future work

## Execution Order
1. Write `src/project.gleam` (type + decoder + lookup/create functions)
2. Add FFI functions to `src/node_ffi.mjs`
3. Modify `src/db.gleam` `connect()` to do project lookup
4. Write migration `027_project_refactor.sql`
5. Update `src/task.gleam` — SQL + tool params
6. Update `src/issue_db.gleam` — SQL
7. Update `src/issue_tools.gleam` — tool params
8. Update `src/broadcast.gleam` — SQL
9. Run migration
10. Rebuild: `gleam clean && gleam build && gleam run -m extension_generator`
11. Run tests: `gleam test`

## Verification
1. `psypi-task-add title="test"` → creates task with correct project_id
2. `psypi-tasks` → lists tasks for current project
3. `psypi-issue-add title="test"` → creates issue with correct project_id
4. `psypi-issues` → lists issues for current project
5. Move to a different directory → new project_id created automatically
6. Return to original directory → original project_id reused
