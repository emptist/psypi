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

**To find your identity, use the identity tools:**
- `psypi-somatic-id` — calls `get_resolved_identity` with live `ctx.isIdle()`
- `psypi-autonomic-id` — calls `get_resolved_identity` with live `ctx.isIdle()`

**Example:** Ask "what is your id?" and the AI should call `psypi-somatic-id` (it IS the somatic worker).

## Self-Loading Skills

If a task needs specialized expertise, load the skill yourself:
`read path=".pi/skills/[skill-name]/SKILL.md"`
