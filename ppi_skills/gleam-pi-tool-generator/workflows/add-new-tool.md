# Add a New Pi Tool

## Required Reading
- `references/pi-toolcall-type.md` — PiToolCall type and helpers
- `references/fn-argument.md` — FnArgument + ParamSrc structured types
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
import pi_tool_call.{
  PiToolCall, raw_json, template, string_param, opt_string_param,
  param, opt_param, int_param, str, int_val, null_val,
}

pub fn my_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-my-tool",
    description: "What this tool does",
    params: [string_param("param1"), opt_string_param("param2")],
    module: "my_module",
    fn_name: "my_function",
    args: [
      param("param1", Some("")),     // required param with default
      opt_param("param2"),            // optional param (nullable)
      int_param("limit", 50),         // integer param with default
      str("psypi"),                   // hardcoded string constant
    ],
    result_format: raw_json(),
  )
}
```

**Rules:**
- `module` = filename without `.gleam` extension
- `fn_name` = public function name in that module
- `args` order must match the function's parameter order
- Use `param()` for required params, `opt_param()` for optional params
- Use `str()` for string constants, `int_val()` for integer constants
- Use `int_param()` for integer params from tool input
- **NEVER use `lit()` or `from_param()`** — these functions no longer exist
- **NEVER use `custom_js()`** — use `raw_json()` or `template()` instead

### Step 3: Import in Generator

In `extension_generator.gleam`:

```gleam
import my_module.{my_tool}
```

Add to `all_tools()`:
```gleam
pub fn all_tools() -> List(PiToolCall) {
  [
    // ... existing tools
    my_tool(),  // ← new
  ]
}
```

### Step 4: Build and Generate

```bash
gleam clean && gleam build
```

### Step 5: Verify

Run `./bin/ppi.mjs` and check:
- New tool's `pi.registerTool({...})` block present in generated extension.js
- Import statement for the module present
- No duplicate imports

## Success Criteria
- [ ] `gleam clean && gleam build` succeeds (type-safe)
- [ ] `./bin/ppi.mjs` starts without error
- [ ] New tool appears in Pi
- [ ] No hand-editing of `extension.js`
- [ ] No `lit()`, `from_param()`, or `custom_js()` used
