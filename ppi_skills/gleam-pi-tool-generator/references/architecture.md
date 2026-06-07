# Generator Architecture

## The Problem

Pi Extension API requires:
```javascript
export default function(pi) {
  pi.registerTool({ name, description, parameters, execute });
}
```

Gleam **cannot** compile directly to this. Pi won't load `.gleam` or `.mjs` as an extension.
A **generated** `extension.js` file is required.

## The Solution: Text Composition + Self-Generating Entry Point

The architecture has two parts:

### 1. Gleam Generator (compile-time)

```
Gleam Source                    Compiled JS (by gleam build)
─────────────                   ──────────────────────────
pi_tool_call.gleam      →       pi_tool_call.mjs
  PiToolCall type                 PiToolCall class
  FnArgument type                 FnArgument class
  ParamSrc type                   ParamSrc class
  HookGuard type                  HookGuard class
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
  all_event_hooks()               all_event_hooks() → List of PiEventHook
  generate()                      generate() → JS source text string
```

### 2. ppi Entry Point (runtime)

```
bin/ppi.mjs
    ↓ import { generate } from
extension_generator.mjs
    ↓ generate() returns string
writeFileSync("extension.js", content)
    ↓ spawn
pi -e extension.js
```

`ppi` generates `extension.js` at every startup — no stale extension possible.

## Text Composition Flow

```
generate()
  │
  ├─ all_tools()
  │   ├─ my_id_tool()         → PiToolCall value
  │   ├─ task_add_tool()      → PiToolCall value
  │   └─ ...                   → PiToolCall values
  │
  ├─ all_event_hooks()
  │   ├─ tool_call_hook()     → PiEventHook value
  │   ├─ agent_end_hook()     → PiDebouncedHook value
  │   └─ ...                   → PiEventHook values
  │
  ├─ imports_text(tools + hooks)
  │   ├─ to_import_line(tool) for each tool/hook
  │   ├─ list.unique (dedup)
  │   └─ → "import { add } from "...task.mjs";\n..."
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

## Zero Hand-Written JS Strings

All JS text in the generator is mechanically produced from structured Gleam types:
- `FnArgument` + `ParamSrc` → parameter extraction code
- `HookGuard` → guard condition code
- `ResultFormat` → result formatting code
- `PiParam` → parameter schema code

There are NO hand-written JS strings. The following have been deleted:
- `JsLiteral(String)`, `FromParam(String)` → replaced by `FnArgument` + `ParamSrc`
- `CustomJs(String)` → deleted, no escape hatch
- `lit()`, `from_param()`, `new_arg()` → replaced by structured constructors
- `guard: Option(String)` → replaced by `HookGuard`

## Critical Rules

### All pi.* Calls Must Be Inside the Factory

If `pi.on()` or `pi.registerTool()` is emitted outside `export default function(pi)`, Pi crashes with "pi is not defined".

### Single Source of Truth

`ppi.mjs` calls `generate()` — it never composes text itself.
This prevents mismatched output between stdout and file write.

### Build Cache

Always `gleam clean && gleam build` after source changes.
Gleam caches compiled output — stale cache causes old code to run.

## File Locations

| File | Purpose |
|------|---------|
| `bin/ppi.mjs` | Entry point: imports generator, writes extension.js, spawns Pi |
| `src/pi_tool_call.gleam` | PiToolCall, PiEventHook, FnArgument, ParamSrc, HookGuard types + text conversion |
| `src/extension_generator.gleam` | Generator: collects tools/hooks, composes text |
| `src/task.gleam`, `skill.gleam`, etc. | Tool definitions using PiToolCall |
| `extension.js` | **Generated at ppi startup** — do not hand-edit |

## How ppi Starts

```bash
./bin/ppi.mjs
```

Behind the scenes:
1. `bin/ppi.mjs` imports compiled `extension_generator.mjs`
2. `generate()` produces JS text from all `PiToolCall` and `PiEventHook` values
3. Writes to `extension.js`
4. Spawns `pi -e extension.js`

Every start produces a fresh extension from the latest compiled Gleam code.
