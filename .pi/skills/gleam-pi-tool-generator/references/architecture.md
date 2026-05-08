# Generator Architecture

## The Problem

Pi Extension API requires:
```javascript
export default function(pi) {
  pi.registerTool({ name, description, parameters, execute });
}
```

Gleam **cannot** compile directly to this. Pi won't load `.gleam` or `.mjs` as an extension.
A manual `extension.js` bridge is required.

## The Solution: Text Composition + Self-Generating Entry Point

The architecture has two parts:

### 1. Gleam Generator (compile-time)

```
Gleam Source                    Compiled JS (by gleam build)
─────────────                   ──────────────────────────
pi_tool_call.gleam      →       pi_tool_call.mjs
  PiToolCall type                 PiToolCall class
  to_js_text()                    to_js_text() function
  to_import_line()                to_import_line() function

agent_identity.gleam    →       agent_identity.mjs
  my_id_tool()                    my_id_tool() → PiToolCall instance
  get_resolved_identity()         get_resolved_identity() → Promise

task.gleam              →       task.mjs
  task_add_tool()                 task_add_tool() → PiToolCall instance
  add()                           add() → Promise

stats.gleam             →       stats.mjs
  stats_show_tool()               stats_show_tool() → PiToolCall instance
  stats()                         stats() → Promise

extension_generator.gleam →     extension_generator.mjs
  all_tools()                     all_tools() → List of PiToolCall
  generate()                      generate() → JS source text string
```

### 2. psypi Entry Point (runtime)

```
bin/psypi.mjs
    ↓ import { generate } from
extension_generator.mjs
    ↓ generate() returns string
writeFileSync("extension.js", content)
    ↓ spawn
pi -e extension.js
```

`psypi` generates `extension.js` at every startup — no stale extension possible.

## Text Composition Flow

```
generate()
  │
  ├─ all_tools()
  │   ├─ my_id_tool()         → PiToolCall value
  │   ├─ partner_id_tool()    → PiToolCall value
  │   ├─ task_add_tool()      → PiToolCall value
  │   ├─ task_list_tool()     → PiToolCall value
  │   └─ stats_show_tool()    → PiToolCall value
  │   └─ doc_save_tool()      → PiToolCall value
  │
  ├─ all_event_hooks()
  │   └─ auto_backup_hook()   → PiEventHook value
  │
  ├─ imports_text(tools)
  │   ├─ to_import_line(tool) for each tool
  │   ├─ list.unique (dedup)
  │   └─ → "import { get_resolved_identity } from "...agent_identity.mjs";\n..."
  │
  ├─ helpers_text()
  │   └─ → "  function unwrapGleamResult() {...}\n  pi.on('session_start', ...) {...}\n"
  │
  ├─ event_hooks_text(hooks)
  │   ├─ event_hook_to_js(hook) for each hook
  │   └─ → "  pi.on('tool_call', async (event, ctx) => {...});\n"
  │
  ├─ tools_text(tools)
  │   ├─ to_js_text(tool) for each tool
  │   └─ → "  pi.registerTool({ name: ..., ... });\n\n  ..."
  │
  └─ Concatenate:
      imports + "\nexport default function(pi) {\n" + helpers + event_hooks + tools + "}\n"
```

## Critical Rules

### All pi.* Calls Must Be Inside the Factory

**Bug discovered 2026-05-08**: If `pi.on()` or `pi.registerTool()` is emitted outside `export default function(pi)`, Pi crashes with "pi is not defined".

### Single Source of Truth

`write_extension()` calls `generate()` — it never composes text itself.
This prevents mismatched output between stdout and file write.

### Build Cache

Always `rm -rf build/` before `gleam build` after source changes.
Gleam caches compiled output — stale cache causes old code to run.

## File Locations

| File | Purpose |
|------|---------|
| `bin/psypi.mjs` | Entry point: imports generator, writes extension.js, spawns Pi |
| `gleam/psypi_core/src/psypi_cli/pi_tool_call.gleam` | PiToolCall type + text conversion functions |
| `gleam/psypi_core/src/psypi_cli/extension_generator.gleam` | Generator: collects tools, composes text |
| `gleam/psypi_core/src/psypi_cli/agent_identity.gleam` | Exports `my_id_tool()`, `partner_id_tool()` |
| `gleam/psypi_core/src/psypi_cli/task.gleam` | Exports `task_add_tool()`, `task_list_tool()` |
| `gleam/psypi_core/src/psypi_cli/stats.gleam` | Exports `stats_show_tool()` |
| `gleam/psypi_core/src/psypi_cli/code_version.gleam` | Exports `doc_save_tool()` |
| `src/agent/extension/extension.js` | **Generated at psypi startup** — do not hand-edit |

## How psypi Starts

```bash
cd /Users/jk/gits/hub/tools_ai/psypi
psypi
```

Behind the scenes:
1. `bin/psypi.mjs` imports compiled `extension_generator.mjs`
2. `generate()` produces JS text from all `PiToolCall` values
3. Writes to `src/agent/extension/extension.js`
4. Spawns `pi -e extension.js`

Every start produces a fresh extension from the latest compiled Gleam code.
