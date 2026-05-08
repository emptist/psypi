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

## The Solution: Text Composition

The generator is a **text composer** (a cook), not a code generator:

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

extension_generator.gleam →     extension_generator.mjs
  all_tools()                     all_tools() → List of PiToolCall
  imports_text()                  imports_text() → JS import statements as string
  helpers_text()                  helpers_text() → JS helper code as string
  tools_text()                    tools_text() → JS registerTool blocks as string
```

## Composition Flow

```
1. gleam build
   Validates ALL Gleam code
   Produces .mjs files

2. gleam run -m psypi_cli/extension_generator
   │
   ├─ all_tools()
   │   ├─ my_id_tool()         → PiToolCall value
   │   ├─ partner_id_tool()    → PiToolCall value
   │   ├─ task_add_tool()      → PiToolCall value
   │   └─ task_list_tool()     → PiToolCall value
   │
   ├─ imports_text(tools)
   │   ├─ to_import_line(tool) for each tool
   │   ├─ list.unique (dedup)
   │   └─ → "import { get_resolved_identity } from "...agent_identity.mjs";\n..."
   │
   ├─ helpers_text()
   │   └─ → "  function unwrapGleamResult() {...}\n  pi.on('session_start', ...) {...}\n"
   │
   ├─ tools_text(tools)
   │   ├─ to_js_text(tool) for each tool
   │   └─ → "  pi.registerTool({ name: ..., ... });\n\n  ..."
   │
   └─ Concatenate all text:
       imports + "export default function(pi) {\n" + helpers + tools + "}"
       → Write to extension.js via simplifile.write
```

## Critical: All pi.* Calls Must Be Inside the Factory

**Bug discovered 2026-05-08**: If `pi.on()` or `pi.registerTool()` is emitted outside `export default function(pi)`, Pi crashes with "pi is not defined".

The correct structure:
```javascript
export default function(pi) {
  function unwrapGleamResult(result) { ... }
  let _sessionId = null;
  pi.on('session_start', async (_event, ctx) => { ... });
  pi.registerTool({ ... });
}
```

Both `generate()` and `write_extension()` must use the **same** composition order.

## Path Handling

The generator writes `extension.js` using a **relative path** from `gleam/psypi_core/` (where `gleam run` executes):

```gleam
let extension_path = "../../src/agent/extension/extension.js"
```

This works because `simplifile.write` resolves relative to `process.cwd()`.

**Do NOT** use `path.join(PSYPI_ROOT, relativePath)` — this causes path doubling when the relative path contains `..` segments.

## Why This Design Is Safe

1. **Gleam compiler validates everything** — if a function signature changes, `my_id_tool()` won't compile
2. **No hand-editing** — `extension.js` is 100% generated
3. **No AI bypass** — an AI can't add a tool by editing JS; it must go through Gleam types
4. **Everything is text** — the generator never constructs JS objects, only concatenates strings
5. **Two sources, one truth** — compiled `.mjs` for imports, `PiToolCall.to_js_text()` for tool blocks

## File Locations

| File | Purpose |
|------|---------|
| `gleam/psypi_core/src/psypi_cli/pi_tool_call.gleam` | PiToolCall type + text conversion functions |
| `gleam/psypi_core/src/psypi_cli/agent_identity.gleam` | Exports `my_id_tool()`, `partner_id_tool()` |
| `gleam/psypi_core/src/psypi_cli/task.gleam` | Exports `task_add_tool()`, `task_list_tool()` |
| `gleam/psypi_core/src/psypi_cli/extension_generator.gleam` | Generator: collects tools, composes text, writes file |
| `gleam/psypi_core/src/psypi_cli/extension_generator_ffi.mjs` | FFI helpers (path resolution) |
| `src/agent/extension/extension.js` | **Generated output** — do not edit by hand |

## Adding a New Tool (Summary)

1. Add `PiToolCall` value in the relevant Gleam module
2. Import it in `extension_generator.gleam`
3. Add to `all_tools()` list
4. Run `rm -rf build/ && gleam build && gleam run -m psypi_cli/extension_generator`
5. `extension.js` is regenerated automatically
