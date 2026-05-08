# Psypi — 100% Gleam AI Coordination System

> **Psy**che + **Pi** = AI coordination system, built entirely in Gleam

## What Is Psypi?

Psypi is a Pi TUI extension written in **pure Gleam**. It provides Pi tools for:
- Agent identity management
- Task management
- Project statistics
- And more...

The entire tool logic is Gleam code. The only non-Gleam piece is a 20-line `bin/psypi.mjs` entry point.

## Architecture

```
psypi/
├── bin/psypi.mjs              # Entry point (20 lines, imports Gleam generator)
├── gleam/psypi_core/
│   ├── src/psypi_cli/
│   │   ├── pi_tool_call.gleam       # PiToolCall type (tool metadata)
│   │   ├── extension_generator.gleam # Text composer (the cook)
│   │   ├── agent_identity.gleam     # Identity tools
│   │   ├── task.gleam               # Task tools
│   │   ├── stats.gleam              # Stats tools
│   │   └── ... (other modules)
│   └── build/dev/javascript/        # Compiled .mjs output
├── .pi/skills/                      # Pi skills
└── docs/                            # Documentation
```

## How It Works

1. **Define tools in Gleam** — each module exports `PiToolCall` values
2. **`gleam build`** — compiles Gleam to `.mjs` (validates all types)
3. **`psypi`** — imports the compiled generator, generates `extension.js`, spawns Pi

```bash
# After changing Gleam source:
cd gleam/psypi_core && rm -rf build/ && gleam build

# Run psypi (auto-generates extension.js and starts Pi):
psypi
```

## Pi Tools

| Tool | Description |
|------|-------------|
| `psypi-my-id` | Get current agent ID |
| `psypi-partner-id` | Get partner/monitor ID |
| `psypi-task-add` | Add a new task |
| `psypi-tasks` | List tasks |
| `psypi-stats-show` | Show project statistics |

## Adding a New Tool

1. Define a `PiToolCall` value in a Gleam module:

```gleam
// In my_module.gleam
import psypi_cli/pi_tool_call.{PiToolCall, raw_json, lit}

pub fn my_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-my-tool",
    description: "What this tool does",
    params: [],
    module: "my_module",
    fn_name: "my_function",
    args: [],
    result_format: raw_json(),
  )
}
```

2. Import it in `extension_generator.gleam`
3. Add to `all_tools()` list
4. Build: `cd gleam/psypi_core && rm -rf build/ && gleam build`
5. Run: `psypi`

See the [gleam-pi-tool-generator skill](.pi/skills/gleam-pi-tool-generator/SKILL.md) for full documentation.

## Key Design Principles

- **100% Gleam** — all tool logic is Gleam code
- **Type-safe** — Gleam compiler validates everything before JS generation
- **No hand-editing** — `extension.js` is auto-generated at every `psypi` start
- **No stale extensions** — fresh `extension.js` every time
- **AI can't bypass** — adding a tool requires Gleam types, not JS editing

## Development

```bash
# Build Gleam
cd gleam/psypi_core
rm -rf build/ && gleam build

# Run psypi
cd /Users/jk/gits/hub/tools_ai/psypi
psypi
```

## Documentation

- [gleam-pi-tool-generator skill](.pi/skills/gleam-pi-tool-generator/) — how to add/modify tools
- [Architecture](.pi/skills/gleam-pi-tool-generator/references/architecture.md) — generator architecture
- [Handover](docs/HANDOVER-2026-05-09.md) — session summary
