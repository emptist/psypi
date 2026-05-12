# psypi = Psyche + Pi

**psypi is a Pi extension written in Gleam**, adding identity system and Monitor functionality.

## The Relationship

```
psypi = Pi + Gleam extension + Identity + SOUL + Monitor
```

- **Pi**: Coding agent runtime (from `refers/pi/`)
- **psypi**: Extension that adds:
  - Identity system (`A-`/`S-` IDs based on autonomous parameter)
  - SOUL-based personality in PostgreSQL
  - Event-driven Monitor with system prompt injection

## Quick Start

```bash
# Run psypi (Pi with psypi extension loaded)
psypi

# NOT the same as:
pi           # Bare Pi, no psypi features
```

Inside Pi, use psypi tools:
- `/psypi-my-id` - Get current agent ID (S-)
- `/psypi-monitor-id` - Get autonomous ID (A-)
- `/psypi-tasks` - List tasks
- `/psypi-commit "msg"` - Commit with Monitor review

## Architecture

- **Gleam core** - All logic in Gleam (`src/`)
- **Pi extension** - Auto-generated from Gleam (`extension.js`)
- **Database** - PostgreSQL (one per user home)

## Development

```bash
# Build Gleam
gleam build

# Regenerate extension.js
gleam run -m extension_generator

# The extension.js is auto-generated - NEVER edit manually!
```

## Key Files

| File              | Purpose                      |
| ----------------- | ---------------------------- |
| `bin/psypi.mjs`   | Node.js entry point (hand-written) |
| `src/*.gleam`     | Gleam source code            |
| `extension.js`    | Generated Pi extension       |
| `node_ffi.mjs`    | Node.js interop (single FFI) |
| `docs/MONITOR.md` | Monitor system docs          |
| `AGENTS.md`       | Developer guide              |

## Entry Point: bin/psypi.mjs

`bin/psypi.mjs` is the **hand-written Node.js entry point**. It bridges Gleam-compiled code with Pi:

```
src/extension_generator.gleam  (Gleam source)
         │
         ▼ gleam build
build/dev/javascript/psypi/extension_generator.mjs  (compiled)
         │
         ▼ bin/psypi.mjs imports and calls generate()
extension.js  (generated Pi extension)
         │
         ▼ pi -e extension.js
Pi running with psypi tools
```

**Why hand-written?** Gleam compiles to ES modules, not executables. We need Node.js to:
1. Import Gleam-compiled modules dynamically
2. Generate `extension.js` at runtime
3. Spawn the Pi process

See `docs/architecture/ENTRY_POINT.md` for full documentation.

## Monitor System

See `docs/MONITOR.md` for complete documentation.

- **Mode 1 (Silent)**: Event hooks, safety, auto-backup
- **Mode 2 (Middle)**: `psypi-monitor-consult` for advice
- **Mode 3 (End)**: `psypi-commit` for inter-review

## Pi Tools

18+ tools via Gleam → extension.js generation. Add new tools by:
1. Define `PiToolCall` in Gleam module
2. Add to `all_tools()` in `extension_generator.gleam`
3. Run `gleam run -m extension_generator`