# Debug Generation Issues

## Required Reading
- `references/pi-toolcall-type.md`
- `references/architecture.md`

## Process

### Step 1: Check Gleam Build

```bash
cd gleam/psypi_core
gleam build
```

If this fails, the issue is in Gleam code, not the generator. Fix the type error first.

Common issues:
- **Unknown type** — forgot to import `PiToolCall` constructor: `import psypi_cli/pi_tool_call.{PiToolCall, ...}` (not just `type PiToolCall`)
- **Type mismatch** — `args` list order doesn't match function parameters
- **Unused import** — remove extra imported helpers

### Step 2: Check Generator

```bash
gleam run -m psypi_cli/extension_generator
```

Watch for `Error writing extension.js` messages.

### Step 3: Check Output

```bash
cat src/agent/extension/extension.js
```

Verify:
- `export default function(pi)` present
- All expected `pi.registerTool({...})` blocks present
- Import statements for each module
- No duplicate imports
- `unwrapGleamResult` helper present
- `session_start` hook present

### Step 4: Common Problems

| Symptom | Cause | Fix |
|---------|-------|-----|
| `PiToolCall is a type, cannot be used as a value` | Forgot to import constructor | Add `PiToolCall` (without `type`) to import |
| `Unknown type PiToolCall` | Only imported value, not type | Add `type PiToolCall` to import |
| Duplicate imports | Two tools from same module | Caller should use `list.unique` |
| Missing tool in output | Not added to `all_tools()` | Add tool to list in generator |
| Wrong args order | FnArgs don't match function params | Reorder args to match function signature |
| Build works but file not written | Wrong path from build dir | Check `extension_generator_ffi.mjs` path resolution |

## Success Criteria
- [ ] `gleam build` succeeds
- [ ] Generator writes `extension.js` without errors
- [ ] All expected tools present in output
