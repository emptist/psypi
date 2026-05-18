# psypi — Pi TUI + Gleam Extension

Pi extension that provides task management, code versioning, identity tracking, and autonomic monitoring — all built in Gleam and compiled to JavaScript.

## Architecture

```
Gleam source (src/*.gleam)
  ↓ gleam build
Compiled JS (build/dev/javascript/psypi/*.mjs)
  ↓ gleam run -m extension_generator
extension.js (auto-generated, never hand-edit)
  ↓ Pi TUI loads it
Pi runtime (tools, hooks, commands)
```

## Core Principle: ID is Everything

Every agent has an identity derived from `get_resolved_identity(ctx: IdentityContext)` — a pure function, one argument, no DB, no side effects. Gleam's type system guarantees this purity at compile time.

There is no "dual role system." The A- or S- prefix emerges from `ctx.isIdle()` at the moment of the call. The same agent can be S- now and A- a millisecond later. The ID is a snapshot of reality, not a label you stick on something.

```
IdentityContext:
  is_idle ← ctx.isIdle()        → A or S (THIS IS THE ONLY DIFFERENCE)
  model   ← ctx.model.id        → which intelligence is operating
  source  ← ctx.model.provider   → where it comes from
  project ← ctx.cwd              → which project context
  global  ← no .git found        → G- prefix for non-project dirs
```

**NEVER CACHE THE ID.** No variable, no database column, no session state, no "for convenience." The ID must be computed fresh every time because `ctx.isIdle()` is live — it changes moment to moment. A cached ID is a lie about who is acting.

## Build

```bash
rm -rf build/ && gleam build
gleam run -m simple_migrate      # DB migrations
gleam run -m extension_generator # regenerate extension.js
```

## Pi Tools

All functionality is exposed as Pi tools — use them inside the TUI, never from shell.

| Tool | Description |
|------|-------------|
| `psypi-somatic-id` | Get Somatic Worker ID |
| `psypi-autonomic-id` | Get Autonomic Worker ID |
| `psypi-task-add` | Add a task |
| `psypi-task-list` | List tasks |
| `psypi-task-complete` | Complete a task |
| `psypi-doc-save` | Save file version |
| `psypi-doc-list` | List file versions |
| `psypi-direct-worker` | Direct the Somatic Worker |
| `psypi-issue-add` | Report an issue |

## Adding a Pi Tool

1. Define Gleam function in its module
2. Create `PiToolCall` value in that module
3. Import in `extension_generator.gleam`, add to `all_tools()`
4. `rm -rf build/ && gleam build`
5. `gleam run -m extension_generator`

## Key Files

- `src/extension_generator.gleam` — collects tools/hooks/commands, generates extension.js
- `src/pi_tool_call.gleam` — PiToolCall, PiEventHook, PiCommandReg types
- `src/agent_identity.gleam` — identity resolution (single source of truth)
- `src/agent_identity_types.gleam` — IdentityContext, AgentIdentity types
- `src/db.gleam` — database access layer (all DB ops go through here)

## Docs

- `docs/AGENT-IDENTITY.md` — identity system design
- `docs/ARCHITECTURE.md` — core architecture
- `AGENTS.md` — quick guide for AI agents
test change
