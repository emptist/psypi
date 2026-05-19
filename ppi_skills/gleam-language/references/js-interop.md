<overview>
Gleam's interop with JavaScript (and Erlang) using `@external` and external types.
Official reference: https://gleam.run/documentation/externals-guide/
</overview>

<when_to_use>
## When to Use Externals

**Always prefer pure Gleam solutions first.** Use externals only when:
- You need a runtime API (e.g., getting memory usage from the VM)
- There's existing code in another language you need to use
- No suitable Gleam package exists

**Disadvantages of externals:**
- No type checking on the external code
- Less editor assistance
- May prevent cross-target compilation (Erlang + JS)
</when_to_use>

<external_functions>
## External Functions

```gleam
@external(javascript, "./my_app/pokemon.mjs", "badge_count")
pub fn pokemon_badge_count() -> Int
```

The `@external` attribute takes 3 arguments:
1. **Target:** `javascript` or `erlang`
2. **Module:** file path (JS) or module name (Erlang)
3. **Function name:** the exported function name

**Type annotations are REQUIRED** for external functions. The Gleam compiler checks all uses but cannot verify the external implementation.
</external_functions>

<multi_target>
## Multi-Target Externals

Provide implementations for both targets:

```gleam
@external(javascript, "./my_app_ffi.mjs", "reverse_list")
@external(erlang, "lists", "reverse")
pub fn reverse_list(list: List(element)) -> List(element)
```

When compiling to JavaScript, the JS implementation is used. When compiling to Erlang, the Erlang implementation is used.
</multi_target>

<gleam_fallback>
## Gleam Fallback

A function can have both a Gleam body and external implementations. The external is used when available; the Gleam body is the fallback:

```gleam
@external(erlang, "lists", "reverse")
pub fn reverse_list(list: List(element)) -> List(element) {
  // Gleam fallback for JS target
  reverse_and_prepend(list, [])
}
```
</gleam_fallback>

<external_types>
## External Types

Define types that represent values from other languages:

```gleam
pub type ErlangReference
pub type JsPromise
```

External types cannot be constructed or inspected directly in Gleam — you need external functions:

```gleam
pub type FileHandle

@external(javascript, "fs", "createReadStream")
pub fn open_file(path: String) -> FileHandle

@external(javascript, "fs", "readFile")
pub fn read_file(handle: FileHandle) -> BitArray
```

**Always create specific external types** rather than using `Dynamic`:

```gleam
// GOOD: specific type
pub type Buffer
pub fn byte_size(data: Buffer) -> Int

// BAD: loses all type safety
import gleam/dynamic.{type Dynamic}
pub fn byte_size(data: Dynamic) -> Int
```
</external_types>

<erlang_externals>
## Erlang Externals

Erlang module and function names are written as atoms:

```gleam
@external(erlang, "lists", "reverse")
pub fn reverse_list(list: List(element)) -> List(element)

@external(erlang, "erlang", "make_ref")
pub fn make_reference() -> ErlangReference
```

**Gleam ↔ Erlang type mapping:**

| Gleam | Erlang |
|-------|--------|
| `True`/`False` | `true`/`false` (atoms) |
| `Int` | integer |
| `Float` | float |
| `String` | UTF-8 binary |
| `Nil` | `nil` (atom) |
| `BitArray` | bit string |
| `List(a)` | list |
| `#(a, b)` | tuple |
| `Ok(v)` / `Error(e)` | `{ok, V}` / `{error, E}` |
| Custom type (no fields) | atom (`snake_case`) |
| Custom type (with fields) | tagged tuple (`{variant_name, ...}`) |

Erlang character lists (`string()` type) are NOT Gleam strings. Use `gleam/erlang/charlist` to convert.
</erlang_externals>

<elixir_externals>
## Elixir Externals

Elixir uses the `erlang` target with the `Elixir.` prefix:

```gleam
@external(erlang, "Elixir.Phoenix", "config")
pub fn phoenix_config(app: atom.Atom, key: String) -> Dynamic
```

Type mappings are the same as Erlang. Elixir macros cannot be used from Gleam.
</elixir_externals>

<javascript_externals>
## JavaScript Externals

For JavaScript, the module path is relative to the Gleam file:

```gleam
// In src/my_app.gleam
@external(javascript, "./my_app/pokemon.mjs", "badge_count")
pub fn pokemon_badge_count() -> Int
```

**Node.js modules** can be imported by name:

```gleam
@external(javascript, "fs", "readFileSync")
pub fn read_file(path: String) -> String
```

**Gleam ↔ JavaScript type mapping:**

| Gleam | JavaScript |
|-------|-----------|
| `True`/`False` | `true`/`false` |
| `Int` | number (whole) |
| `Float` | number |
| `String` | string |
| `Nil` | `undefined` |
| `BitArray` | `Uint8Array` (via `BitArray$BitArray`) |
| `List(a)` | linked list (via `List$Empty`, `List$NonEmpty`) |
| `#(a, b)` | array (immutable) |
| `Ok(v)` / `Error(e)` | (via `Result$Ok`, `Result$Error`) |
| Custom type | constructor functions |

**Working with Gleam data in JavaScript:**

Import from the Gleam prelude (auto-generated):
```javascript
import { BitArray$BitArray, List$Empty, List$NonEmpty, Result$Ok } from '../gleam.mjs';
```

Import custom types from their compiled modules:
```javascript
import { SchoolPerson$Teacher, SchoolPerson$isTeacher } from '../school.mjs';
```
</javascript_externals>

<designing_apis>
## Designing APIs with Externals

**Don't mirror the external API.** Design idiomatic Gleam APIs that make invalid states impossible:

```gleam
// BAD: exposes raw Erlang pid
@external(erlang, "my_zip", "open")
pub fn open(zip: BitString) -> Result(Pid, ZipError)

// GOOD: wraps in a specific type
pub type ZipHandle

@external(erlang, "my_zip", "open")
pub fn open(zip: BitString) -> Result(ZipHandle, ZipError)

@external(erlang, "my_zip", "extract_file")
pub fn extract(zip: ZipHandle, file: String) -> Result(BitArray, ZipError)
```
</designing_apis>

<anti_patterns>
## What NOT to Do

<anti_pattern name="Using Dynamic for external types">
Never use `Dynamic` when you can define a specific external type.

**Wrong:**
```gleam
@external(javascript, "myLib", "open")
pub fn open(path: String) -> Dynamic
```

**Right:**
```gleam
pub type FileHandle
@external(javascript, "myLib", "open")
pub fn open(path: String) -> FileHandle
```
</anti_pattern>

<anti_pattern name="Panicking in libraries">
Libraries must return `Result` for fallible operations, not panic.

**Wrong:**
```gleam
pub fn parse(input: String) -> Int {
  let assert Ok(n) = int.parse(input)
  n
}
```

**Right:**
```gleam
pub fn parse(input: String) -> Result(Int, ParseError) {
  case int.parse(input) {
    Ok(n) -> Ok(n)
    Error(e) -> Error(ParseError(e))
  }
}
```
</anti_pattern>

<anti_pattern name="Vendoring npm packages">
Don't copy-paste npm package code into your project. Use `npm install` and import by name.
</anti_pattern>
</anti_patterns>
