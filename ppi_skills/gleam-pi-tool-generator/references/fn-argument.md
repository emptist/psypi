# FnArgument + ParamSrc Reference

## Type Definitions

```gleam
/// Structured parameter source — describes WHERE to get a value.
pub type ParamSrc {
  ParamField(name: String, default: Option(String))
  OptionalParamField(name: String)
  IntParamField(name: String, default: Int)
  EventField(name: String, default: Option(String))
  EventJsonField(name: String)
  EventFilePath
  CtxField(name: String)
  ArgsField
}

/// Structured function argument — describes WHAT to pass.
pub type FnArgument {
  FromParam(ParamSrc)
  Ctx
  Pi
  StringConst(String)
  IntConst(Int)
  NullConst
}
```

## ParamSrc Variants

### ParamField(name, default) — Required param with default
```gleam
param("title", Some(""))       // → params.title ?? ""
param("name", Some("none"))    // → params.name ?? "none"
```

### OptionalParamField(name) — Optional param (nullable)
```gleam
opt_param("status")            // → params?.status ?? null
opt_param("severity")          // → params?.severity ?? null
```

### IntParamField(name, default) — Integer param from string input
```gleam
int_param("limit", 50)         // → parseInt(params?.limit ?? "50")
int_param("offset", 0)         // → parseInt(params?.offset ?? "0")
int_param("priority", 5)       // → parseInt(params?.priority ?? "5")
```

### EventField(name, default) — Event property
```gleam
event_field("toolName", None)  // → event?.toolName ?? null
event_field("model", None)     // → event?.model ?? null
```

### EventJsonField(name) — JSON-stringified event property
```gleam
event_json_field("result")     // → JSON.stringify(event?.result ?? '')
```

### EventFilePath — File path from edit/write events
```gleam
event_file_path()              // → event?.input?.path || event?.input?.filePath || ''
```

### CtxField(name) — Pi context property
```gleam
ctx_field("model")             // → ctx.model
```

### ArgsField — Command arguments string
```gleam
args_field()                   // → args || ''
```

## FnArgument Variants

### FromParam(ParamSrc) — Extract value from Pi callback
```gleam
param("title", Some(""))       // FromParam(ParamField("title", Some("")))
opt_param("status")            // FromParam(OptionalParamField("status"))
int_param("limit", 50)         // FromParam(IntParamField("limit", 50))
event_field("toolName", None)  // FromParam(EventField("toolName", None))
ctx_field("model")             // FromParam(CtxField("model"))
```

### Ctx — Pass Pi ctx object
```gleam
ctx()                          // → ctx
```

### Pi — Pass Pi pi object
```gleam
pi()                           // → pi
```

### StringConst(String) — String constant
```gleam
str("psypi")                   // → "psypi"
str("")                        // → ""
```

### IntConst(Int) — Integer constant
```gleam
int_val(5)                     // → 5
int_val(0)                     // → 0
```

### NullConst — null constant
```gleam
null_val()                     // → null
```

## Examples

```gleam
// add(title, description, priority, created_by)
args: [
  param("title", Some("")),       // title from tool params
  param("description", Some("")), // description from tool params
  int_param("priority", 5),       // integer priority with default
  str("cli"),                     // hardcoded string constant
]

// on_tool_call(tool_name, file_path, ctx, pi)
args: [
  event_field("toolName", None),  // tool name from event
  event_file_path(),              // file path from event
  ctx(),                          // Pi context object
  pi(),                           // Pi API object
]

// list(status, severity, issue_type, project_id, limit, offset)
args: [
  opt_param("status"),            // optional filter
  opt_param("severity"),          // optional filter
  opt_param("issue_type"),        // optional filter
  opt_param("project_id"),        // optional filter
  int_param("limit", 50),         // integer with default
  int_param("offset", 0),         // integer with default
]
```

## Key Rules

1. **Order matters** — args must match the Gleam function's parameter order exactly
2. **Use `param()` for required params** — with `Some("default")` for the default value
3. **Use `opt_param()` for optional params** — generates `params?.name ?? null`
4. **Use `int_param()` for integer params** — Pi passes all params as strings, parseInt handles conversion
5. **Use `str()` for string constants** — NOT raw JS strings
6. **Use `int_val()` for integer constants** — NOT raw JS numbers
7. **Use `ctx()` and `pi()` for runtime objects** — NOT `lit("ctx")` or `lit("pi")`

## DELETED Types (Do NOT Reintroduce)

| Old | New | Why deleted |
|-----|-----|-------------|
| `JsLiteral(String)` | `StringConst(String)`, `IntConst(Int)` | JsLiteral allowed arbitrary JS expressions |
| `FromParam(String)` | `FromParam(ParamSrc)` | FromParam(String) allowed arbitrary JS access expressions |
| `lit("false")` | `int_val(0)` or `str("false")` | lit() was a bridge to JsLiteral |
| `from_param("params.title \|\| \"\"")` | `param("title", Some(""))` | from_param() embedded JS expressions as strings |
| `new_arg()` | Direct `FnArgument` values | new_arg() was a temporary bridge |
