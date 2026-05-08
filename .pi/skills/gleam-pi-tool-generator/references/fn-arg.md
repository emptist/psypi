# FnArg Reference

## Type Definition

```gleam
pub type FnArg {
  JsLiteral(String)
  FromParam(String)
}
```

## Variants

### JsLiteral(String)
A literal JS expression, passed as-is to the function call.

```gleam
lit("false")              // → false
lit("true")               // → true
lit("5")                  // → 5
lit("\"psypi\"")          // → "psypi"
lit("_sessionId")         // → _sessionId (closure variable from session_start hook)
lit("\"\"")               // → ""
```

Use for: hardcoded values, closure variables, constants.

### FromParam(String)
Reads from the Pi tool's `params` object.

```gleam
from_param("params.title || \"\"")       // → params.title || ""
from_param("params?.status || null")     // → params?.status || null
from_param("params.count")               // → params.count
```

Use for: values provided by the LLM when calling the tool.

## Helpers

```gleam
lit("false")                           // JsLiteral("false")
from_param("params.title || \"\"")     // FromParam("params.title || \"")
```

## Examples

```gleam
// get_resolved_identity(permanent, session_id, project, git_hash, machine_fingerprint, source, model)
args: [
  lit("false"),           // permanent = false (hardcoded)
  lit("_sessionId"),      // session_id from session_start hook
  lit("\"psypi\""),       // project = "psypi" (hardcoded)
  lit("\"\""),            // git_hash = "" (empty)
  lit("\"\""),            // machine_fingerprint = "" (empty)
  lit("\"psypi\""),       // source = "psypi" (hardcoded)
  lit("\"\""),            // model = "" (empty)
]

// add(title, description, priority, created_by)
args: [
  from_param("params.title || \"\""),   // title from tool params
  lit("\"\""),                          // description = "" (empty)
  lit("5"),                             // priority = 5 (default)
  lit("\"cli\""),                       // created_by = "cli" (hardcoded)
]
```

## Key Rules

1. **Order matters** — args must match the Gleam function's parameter order exactly
2. **String literals need escaped quotes** — `lit("\"value\"")` produces `"value"` in JS
3. **Use `_sessionId`** — always use `lit("_sessionId")` for the session ID, the generator creates the `session_start` hook
4. **Optional params** — use `from_param("params?.field || default")` for optional tool parameters
