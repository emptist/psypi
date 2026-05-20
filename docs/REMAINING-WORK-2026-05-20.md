# Remaining Work — 2026-05-20

This document tracks work that was identified but NOT completed during the 2026-05-20 session. These items should be picked up in future sessions.

## Critical: A-Bot Not Working

**Status**: Diagnostics added, root cause NOT yet confirmed — needs Pi restart to observe

The Autonomic Agentbot (A-bot) does not appear to be sending wake-up messages to the S-bot. The `agent_end` hook fires (confirmed by `[AUTONOMIC] isIdle=` notifications), but the wake-up message never arrives.

### Completed

1. ✅ **Debug `call_monitor` using `ctx.ui.notify()`** — Added diagnostic notifications inside `call_monitor` in `src/pi_extension_ffi.mjs` at every step (model check, auth, LLM call, response parsing, text extraction, exceptions)
2. ✅ **Check `system_config` table** — `monitor_debounce_ms` exists with value 300000 (5 min). Reduced to 5000 for testing.
3. ✅ **Check `ctx.model` availability** — Added diagnostic that logs `ctx.model?.id` and `ctx.modelRegistry` presence
4. ✅ **Test `completeSimple` response format** — Added diagnostic that logs stopReason, content types, and text extraction result
5. ✅ **Added setTimeout callback diagnostic** — Confirms the debounced callback actually fires (`pi_tool_call.gleam`)
6. ✅ **Added `on_agent_end` entry/exit diagnostics** — Logs handler entry and `pi_send_message` calls

### What still needs to be done

1. **Restart Pi and observe diagnostics** — After restart, wait for agent_end + 5 sec debounce, observe which diagnostic notifications appear to identify the failing step
2. **Remove diagnostic notifications** — After root cause is found and fixed, remove all `[DIAG]` and `[AUTONOMIC]` diagnostic calls from `call_monitor`, `on_agent_end`, and the generated debounced hook

5. **Verify `pi_send_message` delivery** — Even if `call_monitor` succeeds, `pi_send_message` might not deliver. The message uses `customType: 'autonomic-wakeup'` and `deliverAs: 'steer'`. Need to verify this actually triggers a new turn for the S-bot.

### Files to modify for debugging
- `src/pi_extension_ffi.mjs` — add `ctx.ui.notify()` calls in `call_monitor`
- After debugging, remove the diagnostic notifications

### Pi debugging patterns (from ../refers/pi/AGENTS.md)
- Use `ctx.ui.notify(message, "info|warning|error")` for transient toast messages
- Use `ctx.ui.setStatus(key, text)` for persistent status bar info
- Use `pi.sendMessage({customType, content, display}, {triggerTurn, deliverAs})` for injecting messages
- Never use `console.log` — it goes to stderr, not visible in TUI

## High: psypi-tasks Tool Broken

**Status**: Fix applied but NOT verified (Pi restart required)

`psypi-tasks` returns "Failed to decode task row". Fixed `task.gleam` `string_to_status()` to handle both uppercase and lowercase status values. But Pi TUI is still running old compiled code.

### What needs to be done
1. Restart Pi to pick up the new build:
   ```bash
   pkill -f pi-coding-agent
   cd /Users/jk/gits/hub/tools_ai/psypi
   npx -y @earendil-works/pi-coding-agent --prompt "what is your id?"
   ```
2. After restart, test `psypi-tasks` to verify the fix works
3. If it still fails, the issue is in the Gleam list decoding, not just status

## High: psypi-issue-count Returns 0

**Status**: Reported, not investigated

`psypi-issue-count` returns Count: 0 for all filters, but `psypi-autonomic-health` shows 84 open issues.

### What needs to be done
1. Check what status values are actually stored in the issues table:
   ```sql
   SELECT DISTINCT status FROM issues;
   ```
2. The `count` function in `issue_db.gleam` uses `SELECT COUNT(*)::INT as cnt` with `decode.int`. The decode might be failing silently (returns 0 as fallback).
3. Check if the `WHERE status = $1` clause matches the actual DB values.

## Medium: Code Duplication

**Status**: Reported, not fixed

### `decode_all_results` duplicated in 6+ modules
Files: `agents.gleam`, `areflect.gleam`, `meeting.gleam`, `skill.gleam`, `inter_review.gleam`, `issue_db.gleam`

**Fix**: Create `src/decode_utils.gleam`:
```gleam
pub fn decode_all_results(results: List(Result(a, b))) -> Result(List(a), b) {
  case results {
    [] -> Ok([])
    [Ok(v), ..rest] -> {
      case decode_all_results(rest) {
        Error(e) -> Error(e)
        Ok(vs) -> Ok([v, ..vs])
      }
    }
    [Error(e), .._] -> Error(e)
  }
}
```
Then import it in each module instead of defining it locally.

### `db_error_to_*` duplicated in ~17 modules
Every module defines its own error mapper from `db.DbError` to module-specific error type.

**Fix**: Consider using a generic error type, or at least a shared mapper that returns `db.DbError` directly instead of wrapping in module-specific types.

## Medium: Dead Code Cleanup

**Status**: Identified, not verified or removed

~30 modules in `src/` appear to be dead code (not imported by `extension_generator.gleam` or any other module). See `docs/CODE-QUALITY-AUDIT-2026-05-20.md` for the full list.

### What needs to be done
1. For each candidate module, check if it's imported anywhere:
   ```bash
   grep -r "module_name" src/ --include="*.gleam" | grep -v "^src/module_name.gleam"
   ```
2. If not imported, move to `.deprecated/`
3. Run `rm -rf build/ && gleam build` after removal to verify nothing breaks

## Medium: config.gleam get_env Stub

**Status**: Reported, not fixed

`src/config.gleam` has `get_env(_key)` that always returns `""`. The `node_ffi.mjs` already has a working `get_env` function.

**Fix**: Either implement the FFI in config.gleam:
```gleam
@external(javascript, "./node_ffi.mjs", "get_env")
fn get_env(key: String) -> String
```
Or remove config.gleam entirely if it's not used.

## Medium: housekeeping() Test Stub

**Status**: Reported, not fixed

`src/monitor_ai.gleam` `housekeeping()` inserts hardcoded test values into code_versions table.

**Fix**: Remove the function or implement proper housekeeping logic.

## Medium: db.gleam Hardcoded project_id

**Status**: Reported, not fixed

`src/db.gleam` hardcodes `project_id = "0d324e68-b399-4b85-bd8a-6b1ef7b46168"` for RLS policies.

**Fix**: Read from environment variable via `node_ffi.mjs` `get_env("PSYPI_PROJECT_ID")`.

## Low: tool_commit.gleam Shell Escaping

**Status**: Reported, not fixed

Commit message is interpolated into shell command with only double-quote escaping. Other shell metacharacters (backticks, $, semicolons, newlines) are not handled.

**Fix**: Use proper shell escaping or pass arguments as array to child_process.exec.

## Low: hook_on_agent_end.gleam JSON Parsing

**Status**: Reported, not fixed

`parse_context_window()` manually parses JSON by string splitting instead of using `gleam_json`.

**Fix**: Use `gleam_json` decoder to properly parse the context usage JSON.

## Low: broadcast.gleam Unused Types

**Status**: Reported, not fixed

`BroadcastPriority`, `BroadcastStatus`, `Broadcast` types defined but never used in function signatures.

**Fix**: Either use them properly or remove them.

## Low: meeting.gleam Unused position Parameter

**Status**: Reported, not fixed

`add_opinion()` accepts `position: Option(String)` that's always passed as `null` from `meeting_say_tool()`.

**Fix**: Remove the parameter or implement it properly.

## Study References Not Completed

**Status**: Skimmed but not deeply studied

The following reference materials were identified but not thoroughly studied:
- `../refers/gleam-language/references/` — Gleam syntax, patterns, anti-patterns, quality guidelines
- `../refers/gleam-language/workflows/` — Build, migrate, debug, test workflows
- `../refers/pi/.pi/prompts/` — Pi prompt patterns (cl.md, is.md, pr.md, wr.md)
- `ppi_skills/gleam-language/references/psypi-gleam-patterns.md` — Psypi-specific Gleam patterns
- `ppi_skills/gleam-pi-tool-generator/references/` — PiToolCall type reference

### What needs to be done
1. Read `psypi-gleam-patterns.md` for lessons learned from previous psypi development
2. Read `gleam-quality-guidelines.md` for quality standards
3. Read `what-not-to-do.md` for anti-patterns
4. Study `pi-toolcall-type.md` and `pi-eventhook-type.md` for proper tool definitions
5. Read Pi prompt patterns for standard workflows

## Pi Patterns to Learn (from ../refers/pi/AGENTS.md)

Key patterns for working with Pi:
- **Debugging**: Use `ctx.ui.notify(message, "info|warning|error")` — never `console.log`
- **Status bar**: Use `ctx.ui.setStatus(key, text)` for persistent info
- **Message injection**: Use `pi.sendMessage({customType, content, display}, {triggerTurn: true, deliverAs: 'steer'})`
- **Commit messages**: No emojis, technical prose only, include `fixes #<number>`
- **Git**: Never `git add -A`, never `git reset --hard`, never force push
- **Testing**: Run specific test files, iterate until passing
- **Imports**: Never inline/dynamic imports, always top-level

---

*Created: 2026-05-20 by S-agentbot*
*This document should be read at the start of each session to pick up unfinished work*
