# Modify an Existing Pi Tool

## Required Reading
- `references/pi-toolcall-type.md` — PiToolCall type and helpers
- `references/result-format.md` — ResultFormat variants
- `references/fn-argument.md` — FnArgument + ParamSrc structured types

## Process

### Step 1: Locate the PiToolCall Value

Find the module that exports the tool. Common locations:
- `agent_identity.gleam` — `my_id_tool()`, `partner_id_tool()`
- `task.gleam` — `task_add_tool()`, `task_list_tool()`
- `system_review_tools.gleam` — review and finding tools
- `issue_tools.gleam` — issue management tools

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
  param("title", Some("")),      // required param with default
  opt_param("status"),            // optional param (nullable)
  int_param("limit", 50),         // integer param with default
  str("psypi"),                   // hardcoded string constant
  ctx(),                          // Pi context object
  pi(),                           // Pi API object
],
```

**Change result format:**
```gleam
result_format: raw_json()       // JSON.stringify(gleamValueToJson(r.value))
result_format: template("...")  // template string
// NOTE: custom_js() NO LONGER EXISTS — use raw_json() or template()
```

### Step 3: Build and Generate

```bash
gleam clean && gleam build
```

### Step 4: Verify

Run `./bin/ppi.mjs` and check:
- Changes reflected in the generated `pi.registerTool({...})` block
- All `pi.*` calls still inside `export default function(pi)`
- No duplicate imports

## Common Mistakes

- **Using `lit()` or `from_param()`** — these functions NO LONGER EXIST. Use `param()`, `opt_param()`, `int_param()`, `str()`, `int_val()`, `ctx()`, `pi()`
- **Using `custom_js()`** — this function NO LONGER EXISTS. Use `raw_json()` or `template()`
- **Forgot to import constructor** — `import pi_tool_call.{PiToolCall, ...}` (not just `type PiToolCall`)
- **Args order doesn't match function signature** — must match exactly
- **Stale build** — always `gleam clean && gleam build` after changes

## Success Criteria
- [ ] `gleam clean && gleam build` succeeds
- [ ] `./bin/ppi.mjs` starts without error
- [ ] Changes reflected in generated extension.js
- [ ] No `lit()`, `from_param()`, or `custom_js()` used
