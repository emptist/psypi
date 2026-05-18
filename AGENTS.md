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
- Dual identity: Worker (S-) and Monitor (A-)

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

psypi has a dual identity system:
- **Somatic Worker (S-)** — Prompt-driven, responds to user requests. `ctx.isIdle() = false`
- **Autonomic Worker (A-)** — Event-driven, monitors and coordinates. `ctx.isIdle() = true`

**Single source of truth:** `get_resolved_identity(ctx: IdentityContext)` — one function, one argument.

`IdentityContext` fields all come from the live Pi runtime (`ctx`):
- `is_idle` ← `ctx.isIdle()` — determines A/S prefix
- `model` ← `ctx.model.id`
- `source` ← `ctx.model.provider`
- `thinking_level` ← `ctx.model.thinkingLevel`
- `project` ← `ctx.cwd` (directory name when .git exists)
- `global` ← whether no .git found (prepends G- to ID)

**Never cache the ID.** Call `get_resolved_identity` when needed — it's pure, no DB, no side effects.

**To find your identity, use the identity tools:**
- `psypi-somatic-id` — Get Somatic Worker ID
- `psypi-autonomic-id` — Get Autonomic Worker ID

**Example:** Ask "what is your id?" and the AI should call `psypi-somatic-id` (it IS the somatic worker).

## Self-Loading Skills

If a task needs specialized expertise, load the skill yourself:
`read path=".pi/skills/[skill-name]/SKILL.md"`
