# psypi = Psyche + Pi

**psypi is a Pi extension written in Gleam**, adding identity system and dual-worker coordination.

## The Relationship

```
psypi = Pi + Gleam extension + Identity + SOUL + Dual Workers
```

- **Pi**: Coding agent runtime
- **psypi**: Extension that adds:
  - Identity system (`A-`/`S-` IDs computed from function call, no cache)
  - SOUL-based personality in PostgreSQL
  - Event-driven Autonomic Worker with system prompt injection
  - Somatic Worker (the normal agent, like OWL) that does the actual work

### SOUL Entries (in `souls` table)

| ID | Name | Focus | Traits |
|----|------|-------|--------|
| `S-psypi-psypi-<model_id>` | Somatic Worker | task-completion | speed:9, quality:7, autonomy:5 |
| `A-psypi-psypi-<model_id>` | Autonomic Worker | system-health | speed:6, quality:10, autonomy:9 |

### ID + SOUL Maintenance

Both identities must maintain themselves:

- **ID** — Computed from function call (no cache, no DB). Format: `(A|S)-source-project-model[-thinking_level]`. Model and thinking level come from `ctx.model` (live reference from Pi SDK). See `docs/AGENT-IDENTITY.md` for details.
- **SOUL** — Stored in `souls` table. Each identity owns its entry and can modify it via meetings or direct DB access.

Autonomic Worker acts as "senior advisor" — if Somatic Worker loses track of identity, Autonomic Worker detects and redirects.

## Quick Start

```bash
psypi
```

Inside Pi, use psypi tools:
- `/psypi-somatic-id` — Get Somatic Worker ID (S-)
- `/psypi-autonomic-id` — Get Autonomic Worker ID (A-)
- `/psypi-tasks` — List tasks
- `/psypi-issues` — List issues
- `/psypi-commit "msg"` — Commit with Autonomic Worker review
- `/psypi-hooks-list` — List all event hooks (Autonomic Worker's awareness)
- `/psypi-hooks-active` — List active event hooks

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  USER → Somatic Worker → Autonomic Worker → Somatic Worker → (User) → Cycling  │
└──────────────────────────────────────────────────────────────────┘

Autonomic Worker directs Somatic Worker via system prompt injection:
  tool_error → tool_result hook → DB notification
                                   ↓
before_agent_start hook → reads DB → injects into system prompt
                                   ↓
Somatic Worker receives [AUTONOMIC ALERT] and acts on it
```

- **Gleam core** — All logic in Gleam (`src/`)
- **Pi extension** — Auto-generated from Gleam (`extension.js`)
- **Database** — PostgreSQL (shared, one per user)

## Development

```bash
# Build Gleam (ALWAYS clean build first!)
rm -rf build/ && gleam build

# Regenerate extension.js
gleam run -m extension_generator

# Run DB migrations
gleam run -m simple_migrate
```

## Entry Point

```
bin/psypi.mjs (hand-written Node.js)
  → imports Gleam compiled extension_generator.mjs
  → calls generate()
  → writes extension.js
  → spawns `pi -e extension.js`
```

**NEVER edit `extension.js` manually** — it's a build artifact, always regenerated from Gleam.

## Dual Worker System

Two identities, one AI:

| Identity | ID Prefix | Role | Driven By |
|----------|-----------|------|-----------|
| **Somatic Worker** | `S-` | Does the actual work (coding, file edits, tool calls) | User prompts |
| **Autonomic Worker** | `A-` | Monitors health, reviews commits, detects errors, redirects | Events |

Autonomic Worker acts on events, Somatic Worker acts on prompts. Autonomic Worker directs Somatic Worker via system prompt injection.

### ⚠️ Current Autonomic Worker Capabilities

Autonomic Worker has **limited tool access**:
- ✅ Event hooks (JS)
- ✅ Gleam DB functions (notifications, issues, activity_log)
- ✅ LLM consultation via `callMonitor()` (text only, no tool execution)
- ❌ NO direct `bash`, `edit`, `write`, `read` tools

Autonomic Worker **directs** Somatic Worker via system prompt injection. Full tool access planned.

### Active Event Hooks

| Event | Autonomic Worker Action | Injection |
|-------|--------------|-----------|
| `session_start` | Health check, record model | ✅ status |
| `before_agent_start` | Read DB notifications | ✅ alerts |
| `tool_call` | Safety check, activity log, auto-backup | ✅ warnings |
| `tool_result` | Detect errors → notification + auto-file issue | ✅ |
| `model_select` | Record model change | — |

### Full Cycle

```
tool error detected
  → tool_result hook
  → create notification (DB)
  → auto_file_issue (DB)
  → next before_agent_start
  → read notifications
  → inject [AUTONOMIC ALERT] into system prompt
  → Somatic Worker sees alert and acts
```

### Autonomic Worker Tools

- `psypi-monitor-status` — Autonomic Worker status
- `psypi-monitor-health` — System health metrics
- `psypi-monitor-alerts` — Active alerts
- `psypi-monitor-suggest` — Work suggestions
- `psypi-consult-autonomic` — LLM-powered consultation
- `psypi-commit` — Commit with Autonomic Worker inter-review

## Pi Tools

29+ tools via Gleam → extension.js generation. Add new tools by:

1. Define `PiToolCall` in Gleam module
2. Add to `all_tools()` in `extension_generator.gleam`
3. `rm -rf build/ && gleam build && gleam run -m extension_generator`

## Key Files

| File | Purpose |
|------|---------|
| `bin/psypi.mjs` | Hand-written entry point (spawns Pi) |
| `src/*.gleam` | Gleam source code |
| `extension.js` | Generated Pi extension |
| `node_ffi.mjs` | Single Node.js FFI |
| `src/migrations/*.sql` | DB schema migrations |
| `.planning/` | Architecture & phase plans |

## Planning Docs

- `.planning/NEXT-PHASES.md` — Phase 1-3 plans
- `.planning/EVENT-TASK-MAPPING.md` — All Pi events mapped
- `.planning/SYSTEM-PROMPT-INJECTION.md` — Injection mechanism
- `.planning/ARCHITECTURE.md` — Architecture docs

## ⚠️ Known Design Issues

### Gleam Type System Underused

This codebase was ported from TypeScript. Many Gleam types (enums, custom types) exist but are **not enforced at the boundaries** — raw strings from user input and DB writes bypass the type system entirely.

**Problem example:** `string_to_severity()` and `string_to_type()` silently defaulted unknown values (e.g., `"task"` → `Bug`). Invalid data could be stored without any error.

**Fix applied (2026-05-15):** Changed `string_to_*` functions to return `Result(IssueType, String)` instead of silently defaulting. Now invalid inputs produce clear error messages at the boundary, and the Gleam enum is the **gatekeeper** — validated at input, used throughout the logic, and converted to canonical strings only at the DB write boundary.

**Correct pattern:**
```
User input (String) → string_to_*() → Result(Enum, Error)
  → Error: reject with clear message
  → Ok(enum_val): use enum throughout → enum_to_string() → DB
```

**Anti-pattern (old code):**
```
User input (String) → string_to_*() → Enum (silently defaults)
  → bypass enum, pass raw string directly to DB
  → DB check constraint catches it (if you're lucky)
```

**Rule:** Gleam enums should be the source of truth. Validate at the boundary, use the enum internally, convert to strings only at the DB edge. Never bypass the enum.

### Database Design: Shared Database Across Projects

ONE PostgreSQL database is shared across ALL projects in `~/gits/hub/tools_ai/` (nezha, traenupi, psypi, nupi, etc.). This means:

- `issues` table contains issues from all projects mixed together
- `psypi-issues` with no `source` filter returns **all** issues (100+ from legacy projects)
- `psypi-areflect [ISSUELIST] N` returns the N most recent issues across **all** projects

**Consequence:** The `psypi-issues` tool is nearly useless for daily work because it dumps the entire shared history. There is no `LIMIT` parameter.

**Recommended fixes:**

1. Add a `LIMIT` parameter to `psypi-issues` (e.g., `psypi-issues --limit 20`)
2. Add a `source` filter to `psypi-issues` (e.g., `psypi-issues --source psypi`)
3. Consider `created_by` filtering to separate psypi-agent issues from legacy nezha issues
4. Long-term: either separate databases per project or add a `project` column to all shared tables
