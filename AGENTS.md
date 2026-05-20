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

**Example:** Ask "what is your id?" and the AI should call `psypi-somatic-id` (it IS the somatic agentbot).

## agent_end Workflow (A-S Communication)

When the S-worker finishes a turn, the `agent_end` event fires. The autonomic hook follows a strict 3-phase protocol:

### Phase 1: Immediate Feedback (debugging)
- `agent_end` fires → check `ctx.isIdle()` immediately
- If `True` → call `ctx.ui.notify()` right away with `[AUTONOMIC] S-worker is idle`
- This gives the user instant visual feedback that the autonomic worker detected the idle state
- **This is the debugging phase** — it confirms the hook fired and idle was detected

### Phase 2: Debounce Wait
- Read `monitor_debounce_ms` from `system_config` table (default: 300000ms = 5 minutes)
- Wait via `setTimeout(debounceMs)`
- Rationale: S-worker might receive a new prompt immediately. No need to wake it if it's already busy.

### Phase 3: Intelligent Composition
- After debounce, check `ctx.isIdle()` again
- If `False` → S-worker is busy, skip silently
- If `True` → call Monitor LLM via `callMonitor()` to compose a wake-up message
- Send via `pi_send_message(pi, 'autonomic-wakeup', msg, 'persistent')` with `triggerTurn: true`
- On LLM failure → send error message as persistent notification so S-worker can debug

**Key insight:** Phase 1 uses `ctx.ui.notify()` (transient toast) for immediate human feedback. Phase 3 uses `pi_send_message()` (persistent message) because by then the TUI session may be dormant and transient toasts are invisible.

**Current bug:** Phase 1 is missing from the code. The hook jumps straight to Phase 2 (debounce), so there's no immediate feedback. Additionally, `ctx.ui.notify()` calls in Phase 3 fire when the TUI is already dormant, making them invisible. The `pi_send_message` persistent messages still work but the LLM call (`callMonitor`) is returning empty output.

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
