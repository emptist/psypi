<overview>
Gleam's powerful pattern matching with `case` expressions.
No if/else in Gleam - use pattern matching for all control flow.
</overview>

<basic_case>
## Simple Pattern Matching

```gleam
case some_value {
  Ok(inner) -> inner
  Error(e) -> "Error: " <> e
}

case status {
  1 -> "Active"
  0 -> "Inactive"
  _ -> "Unknown"
}
```

**Key:** `_` is the catch-all pattern (like default).
</basic_case>

<pattern_guards>
## Guards (Conditions in Patterns)

```gleam
case age {
  a if a > 18 -> "Adult"
  a if a > 13 -> "Teen"
  _ -> "Child"
}

case list {
  [] -> "Empty"
  [one] -> "Single: " <> one
  [first, second] -> "Pair: " <> first <> ", " <> second
  _ -> "Many items"
}
```
</pattern_guards>

<destructuring>
## Destructuring Custom Types

```gleam
type Point {
  Point(x: Int, y: Int)
}

let p = Point(3, 4)
case p {
  Point(x, y) -> "X: " <> int.to_string(x) <> ", Y: " <> int.to_string(y)
}

// Nested destructuring
type Shape {
  Circle(radius: Float)
  Rectangle(width: Float, height: Float)
}

case shape {
  Circle(r) -> "Circle with radius " <> float.to_string(r)
  Rectangle(w, h) -> "Rectangle " <> float.to_string(w) <> "x" <> float.to_string(h)
}
```
</destructuring>

<result_pattern>
## Result Type Patterns

Gleam's `Result` type is used for errors:

```gleam
pub type Result(value, error) {
  Ok(value)
  Error(error)
}

// Common pattern:
case operation() {
  Ok(value) -> {
    // Continue with value
    process(value)
  }
  Error(err) -> {
    // Handle error
    "Failed: " <> err
  }
}

// Chain operations with Result:
let result = Ok(10)
|> result.try(fn(x) { Ok(x * 2) })
|> result.try(fn(x) { if x > 10 { Ok(x) } else { Error("Too small") } })
```
</result_pattern>

<option_pattern>
## Option Type Patterns

Gleam's `Option` type for nullable values:

```gleam
pub type Option(a) {
  Some(a)
  None
}

case maybe_name {
  Some(name) -> "Hello, " <> name <> "!"
  None -> "Hello, anonymous!"
}

// Use option functions:
let value = option.unwrap(maybe_value, default)
let mapped = option.map(maybe_value, fn(x) { x * 2 })
```
</option_pattern>

<anti_patterns>
## What NOT to Do

<anti_pattern name="Using if/else">
Gleam has NO if/else! Use `case`.

**Wrong:**
```gleam
if x > 0 { ... } else { ... } // ERROR!
```

**Right:**
```gleam
case x > 0 {
  True -> ...
  False -> ...
}
```
</anti_pattern>

<anti_pattern name="Not covering all patterns">
Compiler requires exhaustive patterns.

**Wrong:**
```gleam
case result {
  Ok(v) -> ... // ERROR: Missing Error case!
}
```

**Right:**
```gleam
case result {
  Ok(v) -> ...
  Error(e) -> ... // Must handle all cases
}
```
</anti_pattern>

<anti_pattern name="Using null/undefined">
Gleam has NO null/undefined! Use `Option`.

**Wrong:** `let x = null` // ERROR!

**Right:** `let x = None` or `let x = Some(value)`
</anti_pattern>
</anti_patterns>

<exercises>
## Practice Patterns

1. Match on `Result` and extract value or return default
2. Destructure a custom type with 3+ fields
3. Use pattern guards to check multiple conditions
4. Chain `Result` operations with `result.try`
</exercises>
