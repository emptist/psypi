# Debug Generation Issues

## Required Reading
- `references/pi-toolcall-type.md`
- `references/architecture.md`

## Process

### Step 1: Check Gleam Build

```bash
gleam clean && gleam build
```

If this fails, the issue is in Gleam code, not the generator. Fix the type error first.

Common issues:
- **Unknown type** — forgot to import `PiToolCall` constructor: `import pi_tool_call.{PiToolCall, ...}` (not just `type PiToolCall`)
- **Type mismatch** — `args` list order doesn't match function parameters
- **Unused import** — remove extra imported helpers
- **Unknown function `lit` or `from_param`** — these functions NO LONGER EXIST. Use `param()`, `opt_param()`, `str()`, `int_val()`, `ctx()`, `pi()`

### Step 2: Check Generator

```bash
gleam run -m extension_generator
```

Watch for error messages.

### Step 3: Check Output

```bash
cat extension.js
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
| `Unknown function lit` | Using deleted function | Use `str()` for strings, `int_val()` for integers |
| `Unknown function from_param` | Using deleted function | Use `param()`, `opt_param()`, `int_param()` |
| `Unknown function custom_js` | Using deleted function | Use `raw_json()` or `template()` |
| Duplicate imports | Two tools from same module | Caller should use `list.unique` |
| Missing tool in output | Not added to `all_tools()` | Add tool to list in generator |
| Wrong args order | FnArguments don't match function params | Reorder args to match function signature |
| Build works but file not written | Wrong path from build dir | Check `ppi.mjs` path resolution |

## Success Criteria
- [ ] `gleam clean && gleam build` succeeds
- [ ] `./bin/ppi.mjs` writes `extension.js` without errors
- [ ] All expected tools present in output
