# Design: project_id as fresh project_url

## Problem

The current system uses a UUID `project_id` stored in the `projects` table. This is wrong because:
- It requires DB lookup/cache — stale data is invisible data
- Hardcoded UUID `0d324e68-...` is sprinkled across 10+ files
- `PSYPI_PROJECT_ID` env var sets it at process start, never changes
- RLS policies depend on session state that doesn't match reality
- Nothing in the codebase even calls `project.gleam:resolve_by_path()`

## New Design

### Type

```gleam
pub type ProjectUrl {
  GitRemote(url: String)
  LocalPath(path: String)
}
```

`ProjectUrl` is the project identifier. It is **always a fresh function call**. No caching. No DB lookup.

### Single source of truth

```gleam
pub fn project_url() -> ProjectUrl {
  case git_remote() {
    Ok(url) -> GitRemote(url)
    Error(_) -> LocalPath(simplifile.current_directory())
  }
}
```

`git_remote()` reads `.git/config` from the real OS working directory (via `simplifile`), parses the `[remote "origin"] url` value. If no valid remote, falls back to `simplifile.current_directory()`.

### Rules

1. **ProjectUrl is always fresh** — no caching, no storing in DB session state, no env var
2. **Called at every use site** — each INSERT, each SELECT filter, each tool call
3. **SQLite column changes** from `uuid` to `text` — stores the URL string or path string
4. **No RLS** — explicit WHERE clauses with `project_url()` result
5. **No hardcoded UUIDs** — all `0d324e68-...` references removed
6. **No DB project table needed** — `projects` table can be dropped or kept for metadata only (name, path mapping), never for ID lookup

### Usage pattern

Every function that previously took `project_id: String` now calls `project_url()` internally:

```gleam
// Before:
pub fn add(title: String, ..., project_id: String) -> ...

// After:
pub fn add(title: String, ...) -> ...
  let assert GitRemote(url) | LocalPath(url) = project_url()
  // use `url` as the project identifier in SQL
```

### Scope of changes

1. New type `ProjectUrl` in `project.gleam`
2. New function `project_url() -> ProjectUrl` 
3. New function `git_remote() -> Result(String, FileError)`
4. Remove `PSYPI_PROJECT_ID` env var usage from `db.gleam` / `node_ffi.mjs`
5. Change all `project_id` columns from `uuid` to `text` in DB
6. Remove or update all hardcoded `0d324e68-...` UUID references (10+ files)
7. Update all Gleam functions that accept `project_id` param to call `project_url()` instead
8. Update all tool registrations in `*_tools.gleam` files
9. Remove `SET app.current_project_id` from `db.gleam` (no RLS needed)
