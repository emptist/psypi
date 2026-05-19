# Gleam FFI Pitfalls — Lessons Learned

## The Core Problem

Hand-written FFI files (`pi_extension_ffi.mjs`) that return `{ ok: false, value: "..." }` objects are **not** automatically converted to Gleam `Ok`/`Error` types when the FFI function returns `Promise(Result(...))`.

### What happens

1. Gleam declares: `pub fn call_monitor(...) -> promise.Promise(Result(String, String))`
2. The FFI is `async` and returns `{ ok: false, value: "undefined" }`
3. The Promise resolves to the raw JS object `{ ok: false, value: "undefined" }`
4. Gleam-compiled code checks `result instanceof Ok` → `false`
5. Falls to `else` branch: `let e = result[0]` → `undefined` (no `0` property on plain objects)
6. Error message: `"callMonitor failed: undefined"`

### Why synchronous FFIs work

For synchronous `@external` functions returning `Result(String, String)`, the Gleam compiler generates conversion code at the call site that converts `{ ok: true, value: x }` → `Ok(x)` and `{ ok: false, value: x }` → `Error(x)`.

For async FFIs (returning `Promise`), this conversion does NOT happen. The Promise resolves to the raw JS object.

## The Right Way: Don't Return Result from Async FFI

### Pattern 1: Return raw value, throw on error

```gleam
// Gleam side
@external(javascript, "./ffi.mjs", "call_monitor")
pub fn call_monitor(ctx: a, user_prompt: String, system_prompt: String) -> promise.Promise(String)

// Usage with rescue
promise.rescue(
  call_monitor(ctx, user_prompt, system_prompt),
  fn(error) {
    // error is a Dynamic value
    let error_string = case dynamic.decode1(error, dynamic.string) {
      Ok(s) -> s
      Error(_) -> "Unknown error"
    }
    notify_error(ctx, "callMonitor failed: " <> error_string)
    Ok(Nil)
  }
)
```

```js
// FFI side — throw on error, never return { ok, value }
export async function call_monitor(ctx, userPrompt, systemPrompt) {
  const model = ctx.model || getModel();
  const result = await complete(model, messages, { modelRegistry });
  if (!result) {
    throw "callMonitor: complete() returned null/undefined result";
  }
  const text = /* extract text */;
  if (!text) {
    throw "callMonitor: LLM produced no output";
  }
  return text;  // Just return the string
}
```

### Pattern 2: Use Gleam's `Dynamic` type for unsafe JS values

```gleam
@external(javascript, "./ffi.mjs", "call_monitor")
pub fn call_monitor(ctx: a, user_prompt: String, system_prompt: String) -> promise.Promise(dynamic.Dynamic)

// Usage
let dynamic_result = call_monitor(ctx, user_prompt, system_prompt)
case dynamic.decode1(dynamic_result, dynamic.string) {
  Ok(text) -> // success
  Error(_) -> // handle error
}
```

### Pattern 3: Keep FFI synchronous, wrap in Promise in Gleam

```gleam
// Synchronous FFI — Gleam handles Result conversion
@external(javascript, "./ffi.mjs", "call_monitor_sync")
pub fn call_monitor_sync(ctx: a, user_prompt: String, system_prompt: String) -> Result(String, String)

// Wrap in Promise in Gleam if needed
pub fn call_monitor(ctx, user_prompt, system_prompt) -> promise.Promise(Result(String, String)) {
  promise.resolve(call_monitor_sync(ctx, user_prompt, system_prompt))
}
```

## Key Rules

1. **Never hand-write `{ ok, value }` objects in FFI** — the conversion to Gleam `Result` only works for synchronous functions
2. **For async FFI, throw on error** — use `promise.rescue` in Gleam to catch
3. **Keep FFI thin** — just call JS APIs, let Gleam handle types
4. **Use `Dynamic` for unsafe JS values** — decode with `dynamic.decode*` functions
5. **Prefer synchronous FFI** — wrap in Promise in Gleam if needed

## What Went Wrong in psypi

- `call_monitor` FFI was `async` and returned `{ ok, value }` objects
- The Gleam code expected `Promise(Result(String, String))` with proper `Ok`/`Error` instances
- The conversion only works for synchronous FFIs, not async ones
- Result: `result instanceof Ok` was always `false`, `result[0]` was always `undefined`
- The error value `"undefined"` was the JS `undefined` coerced to string, not a real error message

## The Fix

Change `call_monitor` FFI to:
- Return `String` on success (not `{ ok: true, value: string }`)
- `throw` on error (not `return { ok: false, value: error }`)

Change Gleam code to:
- Use `promise.rescue` to catch errors
- Remove `Result` from the FFI return type
