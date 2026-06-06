# Bug: Identity Resolution Returns Static CWD — Project Never Updates

**Date:** 2026-06-06  
**Severity:** Medium  
**Component:** `agent_identity.gleam` → `psypi-my-id` tool  

## Summary

`psypi-my-id` always returns the project from the directory where Pi was launched. If the user `cd`s to a different project directory within the same Pi session, the identity (and all project-scoped tool operations) still reflect the original directory.

## Root Cause

`agent_identity.gleam` resolves the project from the current working directory using `simplifile.current_directory()`:

```gleam
/// Get the current working directory from the OS.
/// NEVER use ctx.cwd — it is captured at session start and never updates.
fn current_cwd() -> String {
  case simplifile.current_directory() {
    Ok(dir) -> dir
    Error(_) -> ""
  }
}
```

The comment says "NEVER use ctx.cwd" — but **both return the same stale value**.

### Chain of calls

1. `agent_identity.gleam` → `current_cwd()` → `simplifile.current_directory()`
2. `simplifile` (JS target) → FFI to `simplifile_js.mjs` → `currentDirectory()`
3. `simplifile_js.mjs` → `process.cwd()` (Node.js)
4. `process.cwd()` returns the working directory of the Node.js process, set once at process start

Meanwhile, `ctx.cwd` is also captured at Pi session start and never updated.

**Result:** Both paths return the identical stale directory. The comment in the code is misleading — `simplifile` does not solve the problem it claims to solve.

## Impact

- `psypi-my-id` returns wrong project after user navigates to a different directory
- All project-scoped tools (task-add, issue-add, commit, etc.) tag data with the wrong project
- The ID is a lie about which project context the agent is actually working in

## What Cannot Be Fixed in psypi

`process.cwd()` in a long-running Node.js process is static. It cannot reflect the user's actual shell/TUI directory without platform-level support.

## What Needs to Happen in Pi (the TUI)

Pi needs to expose the real current directory to extensions. Options:

1. Update `ctx.cwd` in real-time as the user navigates directories
2. Add `ctx.getCurrentDir()` that reads from the TUI's tracked directory
3. Document that `ctx.cwd` is static so extensions don't rely on it for identity resolution

## Workaround

Restart Pi from the correct project directory. The identity will be correct for that session.

## Files Involved

- `src/agent_identity.gleam` — `current_cwd()` function, `get_enriched_identity()`
- `build/dev/javascript/simplifile/simplifile_js.mjs` — `currentDirectory()` → `process.cwd()`
- `src/agent_identity_types.gleam` — `IdentityContext` type, `semantic_id()`
