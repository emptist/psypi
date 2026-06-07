# Zero Hand-Written JS in Node.js with Gleam

How to run a Node.js project without writing a single line of JavaScript by hand — using Gleam's type system to mechanically generate all JS code.

## The Principle

**Every line of JavaScript in this project falls into exactly one of three categories:**

1. **Compiled from Gleam** — `gleam build` produces `.mjs` files in `build/`
2. **FFI bridge files** — `*_ffi.mjs` with `@external(javascript, ...)` declarations
3. **Generated at runtime** — the extension generator produces `extension.js` from structured Gleam types

**There is no fourth category.** No JS strings embedded in Gleam code. No hand-written `extension.js`. No inline JS expressions.

## Why This Matters

When you embed JS strings in Gleam code (`"params.title || \"\""`), the Gleam compiler cannot verify them. Typos, wrong field names, missing null checks — all invisible until runtime. Low-quality AIs are especially prone to this: given any escape hatch, they will embed arbitrary JS and bypass the type system entirely.

The solution: **replace every JS string with a structured Gleam type**, then mechanically generate the JS from those types. The compiler catches mistakes. AIs cannot bypass what doesn't exist.

## The Three-Layer Architecture

### Layer 1: FFI — The Only Hand-Written JS

Gleam cannot access Node.js APIs or Pi runtime objects directly. FFI is the **only** justified hand-written JS.

```
src/<module>_ffi.mjs  +  @external(javascript, "./<module>_ffi.mjs", "fn_name")
```

**Valid FFI (unavoidable):**
- Accessing `ctx.*`, `pi.*` — Pi runtime objects (JS objects, no Gleam equivalent)
- `fs`, `child_process` — Node.js APIs (no Gleam equivalent)
- `Date.now()` — no time module in Gleam stdlib

**Invalid FFI (do NOT create):**
- String manipulation → use Gleam stdlib
- ID generation → use pure Gleam
- Config storage → use DB-backed Gleam code
- Any logic expressible in Gleam

### Layer 2: Extension Generator — Type-Driven JS Generation

The generator produces `extension.js` at runtime from **structured Gleam types**. It composes text strings — it never constructs JS objects or evaluates JS expressions.

The key insight: instead of writing JS strings, you declare **what you want** using structured types, and the generator **mechanically converts** each type variant to the corresponding JS text.

#### The Structured Types

**ParamSrc** — WHERE to get a value:

| Variant | Gleam | Generated JS |
|---------|-------|-------------|
| Required param | `ParamField("title", Some(""))` | `params.title ?? ""` |
| Optional param | `OptionalParamField("status")` | `params?.status ?? null` |
| Integer param | `IntParamField("limit", 50)` | `parseInt(params?.limit ?? "50")` |
| Event property | `EventField("toolName", None)` | `event?.toolName ?? null` |
| JSON event prop | `EventJsonField("result")` | `JSON.stringify(event?.result ?? '')` |
| File path | `EventFilePath` | `event?.input?.path \|\| event?.input?.filePath \|\| ''` |
| Context property | `CtxField("model")` | `ctx.model` |
| Command args | `ArgsField` | `args \|\| ''` |

**FnArgument** — WHAT to pass to the handler:

| Variant | Gleam | Generated JS |
|---------|-------|-------------|
| From params | `FromParam(ParamSrc)` | (delegates to ParamSrc) |
| Context object | `Ctx` | `ctx` |
| Pi API object | `Pi` | `pi` |
| String constant | `StringConst("psypi")` | `"psypi"` |
| Integer constant | `IntConst(5)` | `5` |
| Null | `NullConst` | `null` |

**HookGuard** — WHEN a hook executes:

| Variant | Gleam | Generated JS |
|---------|-------|-------------|
| Context check | `CtxFieldExists("model")` | `if (ctx.model) {` |
| Event check | `EventFieldExists("model")` | `if (event.model) {` |
| No condition | `NoGuard` | (no if-statement) |

**ResultFormat** — HOW to format output:

| Variant | Gleam | Generated JS |
|---------|-------|-------------|
| JSON | `RawJson` | `JSON.stringify(gleamValueToJson(r.value))` |
| Template | `Template("Result: ${r.value}")` | `` `Result: ${r.value}` `` |

Note: there is **no** `CustomJs(String)` variant. It was deliberately deleted. There is no escape hatch.

#### Constructor Functions — The Developer API

Developers and AIs interact with constructor functions, not raw type variants:

```gleam
// FnArgument constructors
param("title", Some(""))       // required param with default
opt_param("status")            // optional param (nullable)
int_param("limit", 50)         // integer param with default
event_field("toolName", None)  // event property
event_json_field("result")     // JSON-stringified event property
event_file_path()              // file path from edit/write events
ctx_field("model")             // Pi context property
args_field()                   // command arguments string
ctx()                          // Pi context object
pi()                           // Pi API object
str("psypi")                   // string constant
int_val(5)                     // integer constant
null_val()                     // null constant

// HookGuard constructors
CtxFieldExists("model")        // guard: ctx.model must exist
EventFieldExists("model")      // guard: event.model must exist
NoGuard                        // no guard condition

// ResultFormat constructors
raw_json()                     // JSON output
template("Result: ${r.value}") // template string output
```

#### Example: Complete Tool Definition

```gleam
pub fn task_add_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-task-add",
    description: "Add a new task",
    params: [string_param("title"), opt_string_param("priority")],
    module: "task",
    fn_name: "add",
    args: [
      param("title", Some("")),       // title from params
      int_param("priority", 5),       // integer with default
      str("psypi"),                   // hardcoded string constant
    ],
    result_format: template("Task added: ${r.value}"),
  )
}
```

This Gleam value mechanically generates the corresponding `pi.registerTool({...})` JS block. No hand-written JS involved.

### Layer 3: Business Logic — Pure Gleam

All tool implementations, database operations, and business logic are pure Gleam. The Gleam compiler produces the JS — no human writes it.

## The Deleted Types

These types and functions were **deleted** because they allowed hand-written JS strings:

| Deleted | Replaced By | Why Deleted |
|---------|------------|-------------|
| `FnArg` type | `FnArgument` | Old type had string-based variants |
| `JsLiteral(String)` | `StringConst(String)`, `IntConst(Int)` | Allowed arbitrary JS expressions |
| `FromParam(String)` | `FromParam(ParamSrc)` | Allowed arbitrary JS access expressions |
| `CustomJs(String)` | `Template(String)` only | Allowed arbitrary JS in result formatting |
| `lit()` | `str()`, `int_val()` | Bridge to JsLiteral |
| `from_param()` | `param()`, `opt_param()`, etc. | Bridge to FromParam(String) |
| `new_arg()` | Direct `FnArgument` values | Temporary bridge |
| `custom_js()` | `raw_json()`, `template()` | Escape hatch for arbitrary JS |
| `guard: Option(String)` | `HookGuard` | Allowed arbitrary JS guard expressions |

**If you see any of these in code or documentation, they are stale and wrong.**

## Lessons Learned

### 1. Type-Driven Code Generation > String Templating

When you encode "where to get a value" as a structured type (`ParamSrc`), the compiler catches mistakes at build time. When you encode it as a string (`"params.title || \"\""`), nothing catches it until runtime.

### 2. Delete Escape Hatches Aggressively

As long as `JsLiteral(String)` existed, AIs would use it instead of the structured types. Only by deleting it entirely did we force correct usage. **The absence of the escape hatch IS the safety guarantee.**

### 3. Constructor Functions Are the API Surface

Developers and AIs interact with `param()`, `opt_param()`, `str()` — never with the raw type constructors. The constructors encode the mapping from intent to JS output. If a new JS pattern is needed, add a new constructor — never a raw string.

### 4. The Generator Is a Cook, Not a Code Generator

It doesn't construct JS objects or evaluate JS expressions. It composes text strings from structured inputs. This makes it deterministic, testable, and safe.

### 5. Documentation Cleanup Is Mandatory

After deleting types, any remaining reference in docs or comments becomes a trap — low-quality AIs will read the old pattern and reproduce it. We had to scrub all references from skill docs, code comments, and agent guides.

### 6. Migration Is Incremental

We migrated one module at a time: identify all JS string usage → design structured replacement → migrate each file → verify with `gleam build` → delete old types → clean up docs. Each step is verifiable.

## What to Do When You Need a New JS Pattern

1. **Check if an existing constructor covers it** — `ParamSrc` has 8 variants, `FnArgument` has 6
2. **If not, add a new variant to the structured type** — e.g., add `BoolParamField` to `ParamSrc`
3. **Add a constructor function** — e.g., `bool_param(name, default)`
4. **Add the JS generation case** — in `param_src_to_js()` or `fn_argument_to_js()`
5. **Write a test** — verify the generated JS text matches expectations
6. **NEVER add a string escape hatch** — no `JsLiteral`, no `CustomJs`, no raw JS strings

## Verification Checklist

After any change to tool/hook definitions:

1. `gleam clean && gleam build` — 0 errors, 0 warnings
2. `gleam test` — all tests pass
3. `./bin/ppi.mjs` — starts successfully, all tools registered
4. No `from_param`, `lit`, `JsLiteral`, `CustomJs`, `custom_js` in source code
5. No `Option(String)` for guard fields — must use `HookGuard`
