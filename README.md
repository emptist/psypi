# psypi

Pi TUI extension with dual AI agents (A-bot and S-bot) for autonomous code quality. Built in Gleam, compiled to JavaScript, backed by PostgreSQL.

**A-bot** (Autonomic) reviews S-bot's work between sessions — quality guardian, PDCA's Check phase. **S-bot** (Somatic) executes tasks, writes code, uses tools — PDCA's Plan/Do/Act. They alternate like alternating current, never active simultaneously.

## Quick Start

```bash
gleam clean && gleam build
gleam run -m simple_migrate      # DB migrations
gleam run -m seed                # seed data
node bin/ppi.mjs                 # start Pi with psypi
```

## Architecture

```
Gleam source (src/*.gleam)
  → gleam build
Compiled JS (build/dev/javascript/psypi/*.mjs)
  → gleam run -m extension_generator
extension.js (auto-generated, never hand-edit)
  → Pi TUI loads it
Pi runtime (44 tools, 7 hooks, 2 commands)
```

## Pi Agent Tools (44)

| Category | Tools |
|----------|-------|
| **Identity** | `psypi-my-id`, `psypi-agents` |
| **Tasks** | `psypi-task-add`, `psypi-tasks`, `psypi-task-complete` |
| **Issues** | `psypi-issue-add`, `psypi-issues`, `psypi-issue-count`, `psypi-issue-get`, `psypi-issue-resolve` |
| **Code Versions** | `psypi-doc-save`, `psypi-doc-list` |
| **Skills** | `psypi-skill-list`, `psypi-skill-get`, `psypi-skill-search` |
| **Meetings** | `psypi-meetings`, `psypi-meeting-get`, `psypi-meeting-opinions`, `psypi-meeting-add`, `psypi-meeting-say` |
| **Learning/Memory** | `psypi-learn-save`, `psypi-memory-search` |
| **Broadcast** | `psypi-broadcast-send`, `psypi-broadcasts` |
| **Reflection** | `psypi-areflect` — parse `[LEARN]`/`[ISSUE]`/`[TASK]` markers from text |
| **Autonomic** | `psypi-autonomic-status`, `psypi-autonomic-health`, `psypi-autonomic-alerts`, `psypi-autonomic-stats`, `psypi-autonomic-suggest` |
| **System Review** | `psypi-review-create`, `psypi-review-get`, `psypi-reviews`, `psypi-review-complete`, `psypi-review-severity`, `psypi-finding-add`, `psypi-findings`, `psypi-finding-count`, `psypi-finding-update` |
| **Hooks** | `psypi-hooks-list`, `psypi-hooks-active` |
| **Other** | `psypi-commit`, `psypi-consult-autonomic`, `psypi-stats-show` |

All tools are used inside the Pi TUI, never from shell.

## Identity System

Every agent has a dynamic identity: `(G-)(A|S)-<project>-<source>-<model>[-<thinking_level>]`

- **A/S prefix** emerges from `ctx.isIdle()` at call time — never cached
- **G- prefix** when no `.git` found (global/non-project context)
- Project, model, source derived from live Pi runtime state

## The A/S Dialogue Model

A and S are like **alternating current** — never active simultaneously. When S works, A watches. When S goes idle, A wakes and reviews. When A finishes, S may wake again.

**PDCA cycle:**

| Phase | Agent | What |
|-------|-------|------|
| **Plan** | S (or A suggests) | Decide what to do next |
| **Do** | S | Write code, commit, use tools |
| **Check** | A | Inter-review between S sessions |
| **Act** | S | Address A's findings, improve |

**A-bot** is the doctor — behavior review, code quality, anti-stupidity, follow-up enforcement. Uses `pi.sendMessage()` for errors and wake-ups.

**S-bot** is the patient who can also self-check — executes tasks, uses tools, responds to A's findings.

## Key Files

| File | Purpose |
|------|---------|
| `src/extension_generator.gleam` | Collects tools/hooks/commands, generates extension.js |
| `src/pi_tool_call.gleam` | PiToolCall, PiEventHook types + JS code generators |
| `src/agent_identity.gleam` | Identity resolution (single source of truth) |
| `src/db.gleam` | Database access layer |
| `src/hook_on_agent_end.gleam` | A-bot trigger: debounce + idle detection |
| `src/areflect.gleam` | Marker-parsing reflection tool |
| `AGENTS.md` | Quick guide for AI agents |
| `docs/` | Design docs, reviews, ADRs |

## Build Commands

```bash
gleam clean && gleam build       # compile
gleam run -m simple_migrate      # run DB migrations
gleam run -m seed                # seed agent souls and jobs
gleam run -m extension_generator # regenerate extension.js
node bin/ppi.mjs                 # start Pi with psypi loaded
```
