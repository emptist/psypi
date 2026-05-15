# psypi = Psyche + Pi

**psypi is a Pi extension written in Gleam**, adding identity system and Monitor functionality.

## The Relationship

```
psypi = Pi + Gleam extension + Identity + SOUL + Monitor
```

- **Pi**: Coding agent runtime
- **psypi**: Extension that adds:
  - Identity system (`A-`/`S-` IDs computed from function call, no cache)
  - SOUL-based personality in PostgreSQL
  - Event-driven Monitor with system prompt injection

### SOUL Entries (in `souls` table)

| ID | Name | Focus | Traits |
|----|------|-------|--------|
| `S-psypi-psypi-unknown` | Somatic Worker | task-completion | speed:9, quality:7, autonomy:5 |
| `A-psypi-psypi` | Atonomic Worker | system-health | speed:6, quality:10, autonomy:9 |

### ID + SOUL Maintenance

Both identities must maintain themselves:

- **ID** — Computed from function call (no cache, no DB). `generate_semantic_id()` returns `Error` if missing `session_id`.
- **SOUL** — Stored in `souls` table. Each identity owns its entry and can modify it via meetings or direct DB access.

Monitor acts as "senior advisor" — if Worker loses track of identity, Monitor detects and redirects.

## Quick Start

```bash
psypi
```

Inside Pi, use psypi tools:
- `/psypi-my-id` — Get current agent ID (S-)
- `/psypi-monitor-id` — Get autonomous ID (A-)
- `/psypi-tasks` — List tasks
- `/psypi-issues` — List issues
- `/psypi-commit "msg"` — Commit with Monitor review
- `/psypi-hooks-list` — List all event hooks (Monitor's awareness)
- `/psypi-hooks-active` — List active event hooks

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  USER → Worker → Monitor → Worker → (User) → Cycling  │
└──────────────────────────────────────────────────────┘

Monitor directs Worker via system prompt injection:
  tool_error → tool_result hook → DB notification
                                   ↓
before_agent_start hook → reads DB → injects into system prompt
                                   ↓
Worker receives [MONITOR ALERT] and acts on it
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

## Monitor System

Monitor acts on events, Worker acts on prompts. Monitor directs Worker via system prompt injection.

### ⚠️ Current Monitor Capabilities

Monitor has **limited tool access**:
- ✅ Event hooks (JS)
- ✅ Gleam DB functions (notifications, issues, activity_log)
- ✅ LLM consultation via `callMonitor()` (text only, no tool execution)
- ❌ NO direct `bash`, `edit`, `write`, `read` tools

Monitor **directs** Worker via system prompt injection. Full tool access planned.

### Active Event Hooks

| Event | Monitor Action | Injection |
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
  → inject [MONITOR ALERT] into system prompt
  → Worker sees alert and acts
```

### Monitor Tools

- `psypi-monitor-status` — Monitor status
- `psypi-monitor-health` — System health metrics
- `psypi-monitor-alerts` — Active alerts
- `psypi-monitor-suggest` — Work suggestions
- `psypi-monitor-consult` — LLM-powered consultation
- `psypi-commit` — Commit with Monitor inter-review

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
