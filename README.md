# psypi = Psyche + Pi

AI coordination system built on Pi TUI with Gleam-generated extensions.

## Quick Start

```bash
# Run psypi (spawns Pi TUI with Gleam extension)
psypi

# Inside Pi, use psypi tools:
# /psypi-my-id        - Get current agent ID
# /psypi-tasks        - List tasks
# /psypi-commit "msg" - Commit with Monitor review
# /psypi-monitor-consult "question" - Ask Monitor for advice
```

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
| `src/*.gleam`     | Gleam source code            |
| `extension.js`    | Generated Pi extension       |
| `node_ffi.mjs`    | Node.js interop (single FFI) |
| `docs/MONITOR.md` | Monitor system docs          |
| `AGENTS.md`       | Developer guide              |

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