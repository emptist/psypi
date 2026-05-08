# Add a New Pi Tool

## Required Reading
- `references/pi-toolcall-type.md` — PiToolCall type and helpers
- `references/architecture.md` — Generator flow

## Process

### Step 1: Define the Gleam Function

In the relevant module (e.g., `my_module.gleam`), ensure the function exists:

```gleam
pub fn my_function(param1: String, param2: Int) -> promise.Promise(Result(SomeType, SomeError)) {
  // ... implementation
}
```

### Step 2: Create PiToolCall Value

In the same module, add a public function that returns a `PiToolCall`:

```gleam
import psypi_cli/pi_tool_call.{PiToolCall, raw_json, template, lit, from_param, string_param, opt_string_param}

pub fn my_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-my-tool",
    description: "What this tool does",
    params: [string_param("param1"), opt_string_param("param2")],
    module: "my_module",
    fn_name: "my_function",
    args: [
      from_param("params.param1"),
      from_param("params?.param2 || 0"),
    ],
    result_format: raw_json(),
  )
}
```

**Rules:**
- `module` = filename without `.gleam` extension
- `fn_name` = public function name in that module
- `args` order must match the function's parameter order
- Use `lit()` for hardcoded values, `from_param()` for tool params
- String literals need escaped quotes: `lit("\"value\"")`

### Step 3: Import in Generator

In `extension_generator.gleam`:

```gleam
import psypi_cli/my_module.{my_tool}
```

Add to `all_tools()`:
```gleam
pub fn all_tools() -> List(PiToolCall) {
  [
    my_id_tool(),
    partner_id_tool(),
    task_add_tool(),
    task_list_tool(),
    my_tool(),  // ← new
  ]
}
```

### Step 4: Build and Generate

```bash
cd gleam/psypi_core
gleam build
gleam run -m psypi_cli/extension_generator
```

### Step 5: Verify

Check `src/agent/extension/extension.js`:
- New tool's `pi.registerTool({...})` block present
- Import statement for the module present
- No duplicate imports

## Success Criteria
- [ ] `gleam build` succeeds (type-safe)
- [ ] `gleam run -m psypi_cli/extension_generator` writes `extension.js`
- [ ] New tool appears in `extension.js`
- [ ] No hand-editing of `extension.js`
