<overview>
Gleam's JavaScript interop using `@external` and `gleam_javascript` package.
Call JavaScript functions from Gleam when you need browser/Node.js APIs.
</overview>

<external_annotation>
## @external Attribute

Call JavaScript functions directly:

```gleam
@external(javascript, "Date", "now")
pub fn js_date_now() -> Float

// Usage:
let timestamp = js_date_now()
```

**How it works:**
- At compile time, Gleam replaces the function with JS call
- For JavaScript target: calls `Date.now()`
- For Erlang target: needs Erlang implementation too!
</external_annotation>

<gleam_javascript_package>
## gleam_javascript Package

Import functions from `gleam_javascript`:

```gleam
import gleam_javascript as js

// Get global object (globalThis/window)
let global = js.global()

// Check if value is undefined
case js.is_undefined(some_value) {
  True -> // Handle undefined
  False -> // Value exists
}

// Throw/panic
js.throw("Something went wrong")
```

**Common functions:**
- `js.global()` - Get global object
- `js.is_undefined(value)` - Check for undefined
- `js.throw(message)` - Throw exception
</gleam_javascript_package>

<calling_js_functions>
## Calling JavaScript Functions

Example: Call `console.log`:

```gleam
@external(javascript, "console", "log")
pub fn js_console_log(msg: String) -> Nil

// Usage:
js_console_log("Hello from Gleam!")
```

**For Node.js:**
```gleam
@external(javascript, "fs", "readFileSync")
pub fn js_read_file(path: String) -> String

let content = js_read_file("./data.txt")
```

**For Browser:**
```gleam
@external(javascript, "document", "getElementById")
pub fn js_get_element(id: String) -> JsObject
```
</calling_js_functions>

<handling_js_values>
## Handling JavaScript Values

JavaScript values aren't type-safe! Use careful patterns:

```gleam
@external(javascript, "someLib", "getValue")
pub fn js_get_value() -> Dynamic

// Safely decode JS value:
let value = js_get_value()
case dynamic.decode1(value, dynamic.string) {
  Ok(s) -> "Got string: " <> s
  Error(_) -> "Not a string!"
}
```

**Use `gleam/dynamic` to decode JS values safely!**
</handling_js_values>

<erlang_target>
## Erlang Target (Bonus)

If targeting Erlang too, provide Erlang implementation:

```gleam
@external(javascript, "console", "log")
@external(erlang, "io", "format")
pub fn log(msg: String) -> Nil

// Erlang implementation (pseudo):
// io:format("~s~n", [Msg])
```

**For cross-platform:** Provide both JS and Erlang implementations!
</erlang_target>

<anti_patterns>
## What NOT to Do

<anti_pattern name="Forgetting Erlang">
If targeting Erlang, you MUST provide Erlang implementation too!

**Wrong:**
```gleam
@external(javascript, "console", "log")
pub fn log(msg: String) -> Nil // ERROR on Erlang!
```

**Right:**
```gleam
@external(javascript, "console", "log")
@external(erlang, "io", "format")
pub fn log(msg: String) -> Nil
```
</anti_pattern>

<anti_pattern name="Unsafe JS calls">
JavaScript values aren't typed!

**Wrong:**
```gleam
@external(javascript, "someFunc", "getValue")
pub fn get_value() -> String // Might not be string!
```

**Right:**
```gleam
pub fn get_value() -> Result(String, String) {
  let dynamic_val = js_get_value()
  case dynamic.decode1(dynamic_val, dynamic.string) {
    Ok(s) -> Ok(s)
    Error(_) -> Error("Not a string")
  }
}
```
</anti_pattern>

<anti_pattern name="Directly using JS objects">
Gleam can't directly use JS objects!

**Wrong:**
```gleam
let obj = js_get_object()
let x = obj.property // ERROR! Gleam doesn't know JS objects
```

**Right:**
```gleam
@external(javascript, "someObj", "getProperty")
pub fn get_property(obj: JsObject, prop: String) -> Dynamic
```
</anti_pattern>
</anti_patterns>

<exercises>
## Practice JS Interop

1. Call `Math.random()` from JavaScript
2. Read a file using Node.js `fs.readFileSync`
3. Safely decode a JS value using `gleam/dynamic`
4. Write a cross-platform function (JS + Erlang)
</exercises>
