# AGENTS.md - PsyPI Quick Guide

## Project Overview

**psypi** = Pi TUI + Gleam extension. All functionality via Pi tools (psypi-task-add, psypi-commit, etc.). Never run Pi tools from shell — only inside the TUI.

## Critical Rules

1. **Use Pi tools, not shell commands** — `/psypi-task-add`, not `psql` or CLI
2. **Use `psypi-commit`** for commits (not `git commit`) — mandatory Monitor review
3. **Read files first** — `read` then `edit` with exact match
4. **Never spawn Pi from Pi tools** — infinite loop crash
5. **Gleam types** — Enums are source of truth. Validate at boundary via `string_to_*()` → `Result`, never pass raw strings to SQL
6. **Clean build** — Always `rm -rf build/ && gleam build` before building
7. **pnpm** — Not npm

## Architecture

- `bin/psypi.mjs` → generates `extension.js` from Gleam → spawns Pi
- `extension.js` is AUTO-GENERATED — never hand-edit it
- Gleam `PiToolCall` values define all Pi tools
- Identity: one pure function `get_resolved_identity(ctx)` — A/S prefix emerges from `ctx.isIdle()`

## ⚠️ GOLDEN RULE: No Hand-Written JS in Gleam Code

**99% of all bugs in this codebase were caused by hand-written JS strings embedded in Gleam modules.** This is the #1 thing to avoid.

### The Rule

**NEVER write JavaScript code as Gleam string literals in non-generator modules.** If you need JS interop, use one of these three patterns:

1. **Gleam FFI (`@external`)**: For calling Node.js APIs (filesystem, dates, etc.)
   - Create `src/<module>_ffi.mjs` with `export function`
   - Declare in Gleam: `@external(javascript, "./<module>_ffi.mjs", "fn_name")`
   - Example: `time_utils_ffi.mjs`, `agent_identity_ffi.mjs`

2. **Gleam generator functions**: For emitting JS text into extension.js
   - Write Gleam functions that return JS text strings
   - Compose them in `pi_tool_gen.gleam`, `pi_hook_gen.gleam`, `pi_command_gen.gleam`
   - Example: `hook_import_line()`, `success_action_to_js()`, `params_to_js()`

3. **Pi type constructors**: For building tool/hook/command definitions
   - Use `lit()`, `from_param()`, `event_hook()`, `raw_event_hook()`, `template()`
   - Never hand-write JS object literals or IIFEs

### What NOT To Do

| ❌ Bug Pattern | ✅ Correct Approach |
|---|---|
| `promise.resolve("new Date().toISOString()")` — returns a literal string | FFI function in `*_ffi.mjs` that calls `new Date()` |
| `"(function(){ var cwd = ...; require('fs')... })()"` — JS IIFE in Gleam | Gleam FFI for filesystem + Gleam string operations for logic |
| `"(() => { const t = ...; JSON.parse(t); ... })()"` — JS IIFE for parsing | Pure Gleam string functions (`string.split`, `string.trim`) |
| `custom_js("...${r.value}...")` — raw JS in result format | `template("...${r.value}...")` — uses Gleam Template type |
| Hand-editing `extension.js` | Edit Gleam source, then `gleam run -m extension_generator` |
| `if (!idle) { return; }` early exit in generated hook | Let Gleam handler do all logic checks |

### Why This Matters

Hand-written JS in Gleam is:
- **Invisible to the Gleam compiler** — type errors, syntax errors, and logic bugs pass silently
- **Extremely hard to debug** — the error appears at JS runtime, far from the Gleam source
- **Unnecessary** — Gleam FFI + generator functions cover all use cases cleanly

The ONLY hand-written JS file in the entire repo is `bin/psypi.mjs` (the bootstrapper that spawns Pi). Everything else is auto-generated or uses proper FFI.

## Code Generator Rules (pi_tool_gen, pi_hook_gen, pi_command_gen)

These files are Gleam code that **emits JavaScript text**. They compose Gleam strings into JS templates.

- Build JS text using Gleam string operations (`<>`, `list.map`, `string.join`)
- Use helper functions like `hook_import_line()`, `params_to_js()`, `success_action_to_js()`
- **Gleam escaping ≠ JS escaping.** In Gleam double-quoted strings: `\"` for literal `"`, `\\` for literal `\`. Single quotes need NO escaping.
- **Every list element must end with a comma.** Missing commas cause cryptic parse errors on the *next* line.

## Adding a Pi Tool

1. Define Gleam function in its module
2. Create `PiToolCall` value
3. Import in `extension_generator.gleam`, add to `all_tools()`
4. `rm -rf build/ && gleam build`
5. `gleam run -m extension_generator`

## Build & Migrate

```bash
rm -rf build/ && gleam build
gleam run -m simple_migrate    # DB migrations
gleam run -m extension_generator
```

## Key Files

- `src/extension_generator.gleam` — tool list
- `src/pi_tool_call.gleam` — PiToolCall type
- `docs/AGENT-IDENTITY.md` — identity system
- `docs/DREAM-TEAM-ARCHITECTURE.md` — core architecture

## Identity System

There is no "dual role system." There is one function: `get_resolved_identity(ctx: IdentityContext)`.

The A- or S- prefix is not a role assignment — it emerges from `ctx.isIdle()` at the moment of the call. The same agent can be S- now and A- a millisecond later. The ID is a snapshot of reality, not a label you stick on something.

**NEVER CACHE THE ID.** No variable, no database column, no session state, no "for convenience." The ID must be computed fresh every time because `ctx.isIdle()` is live — it changes moment to moment. A cached ID is a lie about who is acting.

`IdentityContext` fields all come from the live Pi runtime (`ctx`):
- `is_idle` ← `ctx.isIdle()` — determines A/S prefix (THIS IS THE ONLY DIFFERENCE)
- `model` ← `ctx.model.id`
- `source` ← `ctx.model.provider`
- `thinking_level` ← `ctx.model.thinkingLevel`
- `project` ← `ctx.cwd` (directory name when .git exists)
- `global` ← whether no .git found (prepends G- to ID)

**To find your identity, use:**
- `psypi-my-id` — calls `get_resolved_identity` with live `ctx.isIdle()`. Returns `S-` prefix when called by the Somatic Agentbot, `A-` prefix when called by the Autonomic Agentbot.

**Example:** Ask "what is your id?" and the AI should call `psypi-my-id`.

## agent_end Workflow (A-S Communication)

When the S-worker finishes a turn, the `agent_end` event fires. The autonomic hook follows a strict protocol:

### Phase 1: Debounce Wait (in generated JS)
- Read `monitor_debounce_ms` from `system_config` table (default: 180000ms = 3 minutes)
- Start `setTimeout(debounceMs)` — **always**, no early exit
- The generated JS does NOT check `ctx.isIdle()` before starting the timer
- Rationale: idle state at event fire time is meaningless; what matters is idle state after the debounce

### Phase 2: Intelligent Composition (in `hook_on_agent_end.gleam`)
- After debounce, `hook_on_agent_end.gleam` checks `ctx_is_idle()` and `ctx_has_pending_messages()`
- If not idle or has pending messages → skip silently
- If idle → read soul from DB, compose wake-up message via `call_monitor()`
- Send via `pi_send_message(pi, 'autonomic-wakeup', msg, 'persistent')`
- On failure → send error as persistent notification so S-worker can debug

**Critical design point:** The generated JS hook must NOT check `ctx.isIdle()` before starting the debounce timer. The old code had `if (!idle) { return; }` which prevented the timer from ever starting. All idle checking happens in the Gleam handler after the debounce period.

## Commit Workflow (QC Two-Phase)

`psypi-commit` uses a two-phase QC design — no commit lands without a review_id.

**Phase 1 — Review request:** Call `psypi-commit` without `review_id`. This stages changes and sends a code review request to the S-worker. A reviews the diff and responds with PASS/FAIL + score + review_id.

**Phase 2 — Commit with review_id:** Call `psypi-commit` with the `review_id` from Phase 1. This performs the actual git commit. The review_id is the "ticket" proving QC passed.

**Proper flow:** S makes changes → A reviews → A calls `psypi-commit` with review_id → commit lands.

**Gotcha:** S should NOT call `psypi-commit` on its own changes — it creates an infinite self-review loop. For S's own work, use direct `git add` + `git commit`, or let A handle the commit.

## Self-Loading Skills

If a task needs specialized expertise, load the skill yourself:
`read path=".pi/skills/[skill-name]/SKILL.md"`

## Restart Procedure

After debug/build work, restart Pi with a self-test prompt so no human is needed:

1. `rm -rf build/ && gleam build` — clean Gleam build
2. Kill the running Pi process and relaunch with the identity check prompt:

```bash
pkill -f pi-coding-agent; cd /Users/jk/gits/hub/tools_ai/psypi && npx -y @earendil-works/pi-coding-agent --prompt "what is your id?"
```

This kills any running Pi TUI process, then starts a fresh one with the
"what is your id?" prompt so the S-worker boots up and reports its identity
without needing a human to type anything.
