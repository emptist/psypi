# PiToolCall Type Reference

## Type Definition

```gleam
pub type PiToolCall {
  PiToolCall(
    name: String,           // Pi tool name, e.g. "psypi-my-id"
    description: String,     // Shown to the LLM
    params: List(PiParam),   // Pi tool parameters
    module: String,          // Gleam module name (without .gleam), e.g. "agent_identity"
    fn_name: String,         // Function name in that module, e.g. "get_resolved_identity"
    args: List(FnArg),       // Arguments passed to the function
    result_format: ResultFormat,  // How to format the tool result
  )
}
```

## PiParam — Parameter Schema

```gleam
pub type PiParam {
  PiParam(name: String, param_type: String, required: Bool)
}
```

Helpers:
```gleam
string_param("title")              // required string: { "title": { type: "string" } }
opt_string_param("status")         // optional:       { "status": { type: "string", optional: true } }
number_param("count")              // required number: { "count": { type: "number" } }
```

Generated JS TypeBox schema:
- Required: `{ "name": { type: "string" } }`
- Optional: `{ "name": { type: "string", optional: true } }`

## FnArg — Function Arguments

```gleam
pub type FnArg {
  JsLiteral(String)    // Literal JS expression, e.g. "false", "\"psypi\"", "_sessionId"
  FromParam(String)    // Read from tool params, e.g. "params.title || \"\""
}
```

Helpers:
```gleam
lit("false")                        // → false
lit("_sessionId")                   // → _sessionId (closure variable)
lit("\"psypi\"")                    // → "psypi"
from_param("params.title || \"\"")  // → params.title || ""
from_param("params?.status || null") // → params?.status || null
```

## ResultFormat — Output Formatting

```gleam
pub type ResultFormat {
  RawJson           // JSON.stringify(r.value)
  Template(String)  // Template string, e.g. "Task: ${r.value}"
  CustomJs(String)  // Custom JS expression
}
```

Helpers:
```gleam
raw_json()              // JSON.stringify(r.value)
template("Task: ${r.id}")  // `Task: ${r.id}`
custom_js("r.value.map(t => t.title).join(', ')")  // arbitrary JS
```

## Example: Complete Tool Definition

In `agent_identity.gleam`:
```gleam
pub fn my_id_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-my-id",
    description: "Get current agent ID",
    params: [],
    module: "agent_identity",
    fn_name: "get_resolved_identity",
    args: [
      lit("false"),           // permanent = false
      lit("_sessionId"),      // from session_start hook
      lit("\"psypi\""),       // project
      lit("\"\""),            // git_hash
      lit("\"\""),            // machine_fingerprint
      lit("\"psypi\""),       // source
      lit("\"\""),            // model
    ],
    result_format: raw_json(),
  )
}
```

This generates:
```javascript
pi.registerTool({
  name: "psypi-my-id",
  description: "Get current agent ID",
  parameters: {},
  async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
    try {
      const result = await get_resolved_identity(false, _sessionId, "psypi", "", "", "psypi", "");
      const r = unwrapGleamResult(result);
      return r.ok ? { content: [{ type: "text", text: JSON.stringify(r.value) }] }
                 : { content: [{ type: "text", text: `Error: ${r.error}` }] };
    } catch(e) { return { content: [{ type: "text", text: `Error: ${e.message}` }] }; }
  }
});
```

## Key Rules

1. **Module name** = the `.gleam` filename without extension (e.g., `agent_identity` for `agent_identity.gleam`)
2. **fn_name** = the public function name in that module
3. **args order** must match the Gleam function's parameter order
4. **Use `lit()`** for hardcoded values, **`from_param()`** for values from tool params
5. **Session ID** — always use `lit("_sessionId")`, the generator creates the `session_start` hook
6. **String literals** need escaped quotes: `lit("\"psypi\"")` produces `"psypi"` in JS
