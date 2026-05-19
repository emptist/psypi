<overview>
Gleam syntax basics - the building blocks of Gleam programs.
Official reference: https://tour.gleam.run/
</overview>

<comments>
## Comments

```gleam
// Line comment

/// Doc comment (documents the following statement)

//// Module comment (documents the current module)
```
</comments>

<variable_binding>
## Let Bindings

```gleam
let name = "Gleam"
let age = 25
let is_cool = True
```

Variables are immutable. `let` creates a new binding — you can shadow the same name:

```gleam
let x = 5
let x = x + 1  // x is now 6 (new binding, not mutation)
```

**Type annotations** (optional):

```gleam
let items: List(Int) = [1, 2, 3]
```
</variable_binding>

<let_assert>
## Let Assert (Partial Patterns)

`let assert` allows partial pattern matching — crashes at runtime if the pattern doesn't match:

```gleam
let assert Ok(value) = some_result
let assert [first, ..rest] = some_list
```

Use this when you're confident the value matches. For untrusted data, use `case` instead.
</let_assert>

<constants>
## Constants

```gleam
const answer: Int = 42
```

Constants can be referenced from other modules (unlike variables):

```gleam
// In other_module.gleam
pub const the_answer: Int = 42

// In main.gleam
import other_module

fn main() {
  other_module.the_answer
}
```
</constants>

<data_types>
## Basic Types

| Type | Examples |
|------|---------|
| `Int` | `1`, `2`, `-5` |
| `Float` | `1.0`, `2.5` |
| `Bool` | `True`, `False` |
| `String` | `"hello"`, `"Gleam"` |
| `BitArray` | `<<30, 56, 10>>` |
| `List` | `[1, 2, 3]`, `[]` |
| `Tuple` | `#(1, "hello")` |
| `Result` | `Ok(value)`, `Error(error)` |

**Gleam has NO null, NO undefined!**
Use custom types like `Option` for optional values.

**Int vs Float operators are separate:**

| Int | Float |
|-----|-------|
| `+` | `+.` |
| `-` | `-.` |
| `*` | `*.` |
| `/` | `/.` |
| `%` (remainder) | N/A |
| `>` | `>.` |
| `<` | `<.` |
| `>=` | `>=.` |
| `<=` | `<=.` |
</data_types>

<functions>
## Functions

```gleam
// Public function (exported)
pub fn add(x: Int, y: Int) -> Int {
  x +  y
}

// Private function (default)
fn multiply(x: Int, y: Int) -> Int {
  x * y
}

// Anonymous function
let double = fn(x) { x * 2 }
double(21)  // No .() needed!
```

**Type annotations are optional** but recommended for public functions. The compiler infers types.
</functions>

<pipe_operator>
## Pipe Operator `|>`

Chain operations left-to-right:

```gleam
// Instead of:
function3(function2(function1(value)))

// Use pipe:
value |> function1 |> function2 |> function3

// Pipe works with anonymous functions too:
value |> fn(x) { x + 1 } |> fn(x) { x * 2 }
```
</pipe_operator>

<labelled_arguments>
## Labelled Arguments

Arguments can have labels for clarity at the call site:

```gleam
pub fn replace(inside string, each pattern, with replacement) {
  // string, pattern, replacement are the internal names
}

// Call with labels in any order:
replace(each: ",", with: " ", inside: "A,B,C")
```

Labels are compile-time only — no runtime cost. Arguments can also have default values by combining with `let assert` inside the function body.
</labelled_arguments>

<pattern_matching>
## Case Expressions (Pattern Matching)

```gleam
case some_value {
  Ok(inner) -> inner
  Error(e) -> "Error: " <> e
}

// Guards:
case age {
  a if a >= 18 -> "Adult"
  a if a >= 13 -> "Teen"
  _ -> "Child"
}

// List patterns:
case list {
  [] -> "Empty"
  [one] -> "Single"
  [first, second] -> "Pair"
  [first, ..rest] -> "Many"
}

// Named patterns with `as`:
case list {
  [first as f, ..rest] -> "First: " <> f
}
```

**Exhaustiveness:** The compiler checks that ALL variants are covered. No catch-all `_` needed if you enumerate everything.
</pattern_matching>

<use_expressions>
## Use Expressions

`use` is Gleam's solution for callback-heavy code. It eliminates indentation from nested callbacks:

```gleam
// Without use (nested callbacks):
pub fn login(credentials) {
  case authenticate(credentials) {
    Error(e) -> Error(e)
    Ok(user) ->
      case fetch_profile(user) {
        Error(e) -> Error(e)
        Ok(profile) -> render_welcome(user, profile)
      }
  }
}

// With use (flat structure):
pub fn login(credentials) {
  use user <- result.try(authenticate(credentials))
  use profile <- result.try(fetch_profile(user))
  render_welcome(user, profile)
}
```

`use` desugars into a callback function. The right-hand side is a function that takes a callback, and `use` provides that callback. This is commonly used with `result.try`, `option.some`, and custom APIs.
</use_expressions>

<panic_todo>
## Panic and Todo

```gleam
// todo: marks incomplete code (compiles but crashes at runtime)
fn not_implemented() {
  todo as "implement this later"
}

// panic: crashes immediately with a message
fn unreachable() {
  panic as "this should never happen"
}
```

`panic` is appropriate for unrecoverable errors at the application level. Libraries should use `Result` instead.
</panic_todo>

<custom_types>
## Custom Types

```gleam
// Simple custom type (variants without data = atoms)
type Color {
  Red
  Green
  Blue
}

// Variants with data
type Shape {
  Circle(radius: Float)
  Rectangle(width: Float, height: Float)
}

// Type parameters (generics)
type Box(a) {
  Box(a)
}

// Record field access (dot syntax)
let c = Circle(radius: 5.0)
c.radius  // 5.0
```

**Pattern matching is exhaustive** — compiler checks all variants are covered.
</custom_types>

<type_aliases>
## Type Aliases

```gleam
type UserName = String
type Age = Int

// With type parameters:
type MyResult(a) = Result(a, String)
```

Type aliases are interchangeable with the original type — they're documentation, not new types.
</type_aliases>

<opaque_types>
## Opaque Types

```gleam
pub opaque type UserId {
  UserId(Int)
}
```

Opaque types hide the internal representation. The constructor is not exported, so external code can only create values through the module's public API. This enforces invariants.
</opaque_types>

<modules>
## Modules

```gleam
// Import module
import gleam/list
import gleam/string as str

// Qualified function call
list.reverse([1, 2, 3])

// Unqualified import of types/constructors
import gleam/option.{type Option, Some, None}

// Unqualified import of functions (generally discouraged)
import gleam/list.{reverse}
```

**File = Module.** Each `.gleam` file is one module. Module path matches file path: `src/my_app/user.gleam` → `import my_app/user`.

**Import conventions:**
- Functions: always use qualified syntax (`list.reverse`, not `reverse`)
- Types: can be unqualified (`type Option`)
- Constructors: can be unqualified (`Some`, `None`)
</modules>

<anti_patterns>
## What NOT to Do

<anti_pattern name="Using null/undefined">
Gleam has NO null or undefined! Use a custom type.

**Wrong:**
```gleam
let value = null // ERROR!
```

**Right:**
```gleam
let value = None  // Using a custom Option type
let value = Some("something")
```
</anti_pattern>

<anti_pattern name="Mutation">
Variables are immutable! Rebinding is not mutation.

**Wrong:**
```gleam
let x = 5
x = 10 // ERROR! Can't reassign
```

**Right:**
```gleam
let x = 5
let x = 10 // New binding (shadowing), not mutation
```
</anti_pattern>

<anti_pattern name="Catch-all patterns in case">
Avoid `_` when you should enumerate variants — exhaustiveness checking is Gleam's superpower.

**Wrong:**
```gleam
case role {
  Student -> handle_student()
  _ -> handle_teacher()  // Bug if new variant added!
}
```

**Right:**
```gleam
case role {
  Student -> handle_student()
  Teacher -> handle_teacher()
}
```
</anti_pattern>

<anti_pattern name="Panicking in libraries">
Libraries must NOT use `panic` or `let assert`. Return `Result` instead.
```
</anti_pattern>
</anti_patterns>
