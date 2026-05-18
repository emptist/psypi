<overview>
Gleam syntax basics - the building blocks of Gleam programs.
</overview>

<variable_binding>
## Let Bindings

```gleam
let name = "Gleam"
let age = 25
let is_cool = True
```

Variables are immutable by default. Use `let` for binding.
</variable_binding>

<data_types>
## Basic Types

| Type | Examples |
|------|---------|
| `Int` | `1`, `2`, `-5` |
| `Float` | `1.0`, `2.5` |
| `Bool` | `True`, `False` |
| `String` | `"hello"`, `"Gleam"` |
| `List` | `[1, 2, 3]`, `[]` |
| `Result` | `Ok(value)`, `Error(error)` |
| `Option` | `Some(value)`, `None` |

**Gleam has NO null, NO undefined!**
Use `Option` type instead:
```gleam
type Option(a) {
  Some(a)
  None
}
```
</data_types>

<functions>
## Functions

```gleam
// Define function
pub fn add(x: Int, y: Int) -> Int {
  x + y
}

// Call function
let result = add(3, 4) // 7

// Pipe operator (chain functions)
let final = value
  |> function1
  |> function2
  |> function3
```

**Pipe operator `|>` reads left-to-right:**
```gleam
// Instead of:
function3(function2(function1(value)))

// Use pipe:
value |> function1 |> function2 |> function3
```
</functions>

<pattern_matching>
## Pattern Matching (NOT if/else!)

Gleam uses `case` expressions for control flow:

```gleam
case some_value {
  Ok(inner) -> inner
  Error(e) -> "Error: " <> e
}

// With guards:
case age {
  a if a > 18 -> "Adult"
  _ -> "Child"
}

// Multiple patterns:
case status {
  "active" -> 1
  "inactive" -> 0
  _ -> -1
}
```

**No if/else in Gleam! Use `case` for everything.**
</pattern_matching>

<custom_types>
## Custom Types

```gleam
// Define type
type Color {
  Red
  Green
  Blue
  RGB(Int, Int, Int)
}

// Use in pattern matching
case color {
  Red -> "Red"
  Green -> "Green"
  Blue -> "Blue"
  RGB(r, g, b) -> "RGB(" <> int.to_string(r) <> ",...)"
}
```

**Types can have parameters:**
```gleam
type Box(a) {
  Box(a)
}

let int_box = Box(42)
let string_box = Box("hello")
```
</custom_types>

<modules>
## Modules

```gleam
// Import module
import gleam/list
import gleam/string as str

// Use functions
let reversed = list.reverse([1, 2, 3])
let greeting = str.append("Hello", " World")
```

**File = Module** (in Gleam, each file is a module)
</modules>

<anti_patterns>
## What NOT to Do

<anti_pattern name="Using if/else">
Gleam has NO if/else! Use `case` expressions.

**Wrong:**
```gleam
// This doesn't work!
if x > 0 {
  "positive"
} else {
  "negative"
}
```

**Right:**
```gleam
case x > 0 {
  True -> "positive"
  False -> "negative"
}
```
</anti_pattern>

<anti_pattern name="Using null/undefined">
Gleam has NO null or undefined! Use `Option` type.

**Wrong:**
```gleam
let value = null // ERROR!
```

**Right:**
```gleam
let value = None
let value = Some("something")
```
</anti_pattern>

<anti_pattern name="Mutation">
Variables are immutable! Can't reassign.

**Wrong:**
```gleam
let x = 5
x = 10 // ERROR!
```

**Right:**
```gleam
let x = 5
let x_new = 10 // New binding, not mutation
```
</anti_pattern>
</anti_patterns>
