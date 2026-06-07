# PiToolCall Type Reference

## Type Definition

```gleam
pub type PiToolCall {
  PiToolCall(
    name: String,              // Pi tool name, e.g. "psypi-my-id"
    description: String,       // Shown to the LLM
    params: List(PiParam),     // Pi tool parameters
    module: String,            // Gleam module name (without .gleam), e.g. "agent_identity"
    fn_name: String,           // Function name in that module, e.g. "get_resolved_identity"
    args: List(FnArgument),    // Arguments passed to the function
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

## FnArgument — Function Arguments

See `references/fn-argument.md` for full details.

```gleam
pub type FnArgument {
  FromParam(ParamSrc)    // Extract from Pi callback params/event/ctx
  Ctx                    // Pass Pi ctx object
  Pi                     // Pass Pi pi object
  StringConst(String)    // String constant
  IntConst(Int)          // Integer constant
  NullConst              // null
}
```

Constructor quick reference:
```gleam
param("title", Some(""))       // params.title ?? ""
opt_param("status")            // params?.status ?? null
int_param("limit", 50)         // parseInt(params?.limit ?? "50")
event_field("toolName", None)  // event?.toolName ?? null
event_json_field("result")     // JSON.stringify(event?.result ?? '')
event_file_path()              // event?.input?.path || event?.input?.filePath || ''
ctx_field("model")             // ctx.model
args_field()                   // args || ''
ctx()                          // ctx
pi()                           // pi
str("psypi")                   // "psypi"
int_val(5)                     // 5
null_val()                     // null
```

## ResultFormat — Output Formatting

```gleam
pub type ResultFormat {
  RawJson              // JSON.stringify(gleamValueToJson(r.value))
  Template(String)     // Template string, e.g. `Task: ${r.value}`
}
```

Helpers:
```gleam
raw_json()                  // JSON.stringify(gleamValueToJson(r.value))
template("Task: ${r.id}")   // `Task: ${r.id}`
```

Note: `CustomJs(String)` has been **DELETED**. There is no escape hatch for arbitrary JS.

## Example: Complete Tool Definition

In `task.gleam`:
```gleam
import pi_tool_call.{
  PiToolCall, string_param, opt_string_param, param, opt_param, int_param,
  str, int_val, null_val, raw_json, template,
}

pub fn task_add_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-task-add",
    description: "Add a new task",
    params: [
      string_param("title"),
      opt_string_param("description"),
      opt_string_param("priority"),
    ],
    module: "task",
    fn_name: "add",
    args: [
      param("title", Some("")),
      param("description", Some("")),
      int_param("priority", 5),
      str("psypi"),
    ],
    result_format: template("Task added: ${r.value}"),
  )
}
```

This generates:
```javascript
pi.registerTool({
  name: "psypi-task-add",
  description: "Add a new task",
  parameters: { ... },
  async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    try {
      const result = await task_add(
        params.title ?? "", parseInt(params?.priority ?? "5"), "psypi"
      );
      const r = unwrapGleamResult(result);
      return r.ok
        ? { content: [{ type: "text", text: `Task added: ${r.value}` }] }
        : { content: [{ type: "text", text: `Error: ${r.error}` }] };
    } catch(e) {
      ctx.ui.notify('Tool psypi-task-add error: ' + e.message, 'error');
      return { content: [{ type: "text", text: `Error: ${e.message}` }] };
    }
  }
});
```

## Key Rules

1. **Module name** = the `.gleam` filename without extension (e.g., `agent_identity` for `agent_identity.gleam`)
2. **fn_name** = the public function name in that module
3. **args order** must match the Gleam function's parameter order
4. **Use structured constructors** (`param()`, `str()`, `int_val()`) — NOT raw JS strings
5. **No `lit()` or `from_param()`** — these functions no longer exist
6. **No `custom_js()`** — use `raw_json()` or `template()` instead
