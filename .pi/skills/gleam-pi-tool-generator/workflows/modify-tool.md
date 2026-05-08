# Modify an Existing Pi Tool

## Required Reading
- `references/pi-toolcall-type.md` — PiToolCall type and helpers
- `references/result-format.md` — ResultFormat variants
- `references/fn-arg.md` — FnArg variants

## Process

### Step 1: Locate the PiToolCall Value

Find the module that exports the tool. Common locations:
- `agent_identity.gleam` — `my_id_tool()`, `partner_id_tool()`
- `task.gleam` — `task_add_tool()`, `task_list_tool()`

### Step 2: Make Changes

**Change tool name or description:**
```gleam
PiToolCall(
  name: "psypi-new-name",        // ← change this
  description: "New description", // ← change this
  ...
)
```

**Change parameters:**
```gleam
params: [
  string_param("title"),         // required
  opt_string_param("status"),    // optional
],
```

**Change arguments:**
```gleam
args: [
  from_param("params.title || \"\""),  // from tool params
  lit("false"),                        // hardcoded
  lit("_sessionId"),                   // from session_start hook
],
```

**Change result format:**
```gleam
result_format: raw_json()       // JSON.stringify(r.value)
result_format: template("...")  // template string
result_format: custom_js("...") // custom JS expression
```

### Step 3: Build and Generate

```bash
cd gleam/psypi_core
rm -rf build/ && gleam build
gleam run -m psypi_cli/extension_generator
```

### Step 4: Verify

Check `src/agent/extension/extension.js`:
- Changes reflected in the generated `pi.registerTool({...})` block
- All `pi.*` calls still inside `export default function(pi)`
- No duplicate imports

## Common Mistakes

- **Forgot to import `PiToolCall` constructor** — `import psypi_cli/pi_tool_call.{PiToolCall, ...}` (not just `type PiToolCall`)
- **Args order doesn't match function signature** — must match exactly
- **Missing escaped quotes** — `lit("\"value\"")` not `lit("value")` for string literals
- **Stale build** — always `rm -rf build/` before `gleam build` after changes

## Success Criteria
- [ ] `gleam build` succeeds
- [ ] Generator produces valid `extension.js`
- [ ] Changes reflected in output
- [ ] `psypi` command starts without error
