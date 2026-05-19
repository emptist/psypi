<overview>
Gleam's pattern matching with `case`, `let`, `let assert`, and `use`.
Pattern matching is the primary control flow mechanism in Gleam.
Official reference: https://tour.gleam.run/
</overview>

<case_expression>
## Case Expressions

```gleam
case some_value {
  Ok(inner) -> inner
  Error(e) -> "Error: " <> e
}

// Multiple patterns, guards, and catch-all:
case status {
  1 -> "Active"
  0 -> "Inactive"
  _ -> "Unknown"  // catch-all
}
```

**Exhaustiveness:** The compiler verifies all variants are covered. If you add a variant to a custom type, the compiler will flag every `case` that doesn't handle it.
</case_expression>

<guards>
## Guards (Conditions in Patterns)

```gleam
case age {
  a if a >= 18 -> "Adult"
  a if a >= 13 -> "Teen"
  _ -> "Child"
}

// Guards with lists:
case list {
  [] -> "Empty"
  [one] -> "Single: " <> one
  [first, second] -> "Pair"
  [first, ..rest] -> "Many items"
}
```
</guards>

<list_patterns>
## List Patterns

```gleam
// Empty list
[]

// Specific number of elements
[first, second, third]

// Head and tail (cons)
[head, ..tail]

// First N elements + rest
[first, second, ..rest]

// Named pattern with `as`:
[first as f, ..rest]
```

**List spread syntax:** `[1, 2, ..existing_list]` prepends elements.
</list_patterns>

<destructuring>
## Destructuring

```gleam
// Custom type variants
type Point {
  Point(x: Float, y: Float)
}

let p = Point(3.0, 4.0)
case p {
  Point(x, y) -> "X: " <> float.to_string(x)
  // Or with labels:
  Point(x: x_val, y: y_val) -> "X: " <> float.to_string(x_val)
}

// Nested destructuring:
type Shape {
  Circle(center: Point, radius: Float)
  Rectangle(top_left: Point, bottom_right: Point)
}

case shape {
  Circle(center: Point(x:, y:), radius: r) ->
    "Circle at (" <> float.to_string(x) <> ", " <> float.to_string(y) <> ")"
  Rectangle(top_left: tl, bottom_right: br) ->
    "Rectangle"
}

// Tuples:
let #(name, age) = #("Alice", 30)

// Records with let:
let Point(x:, y:) = some_point
```
</destructuring>

<named_patterns>
## Named Patterns with `as`

Bind a name to the whole pattern while also destructuring:

```gleam
case list {
  [first as f, ..rest] -> {
    // f is the first element
    // rest is the remaining list
    "First: " <> f
  }
  [] -> "Empty"
}

// With custom types:
case result {
  Ok(user) as whole_result -> {
    // user is the inner value
    // whole_result is the full Ok(user) value
    process(user)
  }
  Error(e) -> handle_error(e)
}
```
</named_patterns>

<let_assert>
## Let Assert

`let assert` allows partial pattern matching. Crashes at runtime if the pattern doesn't match:

```gleam
let assert Ok(value) = some_result
let assert [first, ..rest] = some_list
let assert Point(x:, y:) = some_point
```

Use when you're confident about the shape. For untrusted data, use `case` instead.
</let_assert>

<use_expression>
## Use Expressions

`use` eliminates callback nesting. It's Gleam's solution for monadic-style flow:

```gleam
// Without use:
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

// With use:
pub fn login(credentials) {
  use user <- result.try(authenticate(credentials))
  use profile <- result.try(fetch_profile(user))
  render_welcome(user, profile)
}
```

**How it works:** `use` desugars into a callback. `result.try` takes a `Result` and a callback. If the result is `Ok`, it calls the callback with the inner value. If `Error`, it short-circuits.

**Custom use patterns:** Any function that takes a callback can be used with `use`:

```gleam
// Custom resource management:
use connection <- database.with_connection()
use transaction <- database.begin_transaction(connection)
// ... use transaction ...
// transaction and connection are automatically cleaned up
```
</use_expression>

<result_patterns>
## Result Type Patterns

```gleam
// Direct pattern matching:
case operation() {
  Ok(value) -> process(value)
  Error(err) -> "Failed: " <> err
}

// With use:
use value <- result.try(operation())
process(value)

// Chaining multiple operations:
use a <- result.try(parse(input))
use b <- result.try(validate(a))
use c <- result.try(transform(b))
Ok(c)
```
</result_patterns>

<option_patterns>
## Option Type Patterns

```gleam
case maybe_name {
  Some(name) -> "Hello, " <> name
  None -> "Hello, anonymous!"
}

// With option functions:
let value = option.unwrap(maybe_value, default)
let mapped = option.map(maybe_value, fn(x) { x * 2 })

// With use:
use value <- option.lazy_or(maybe_value, fn() { compute_default() })
```
</option_patterns>

<anti_patterns>
## What NOT to Do

<anti_pattern name="Check-then-assert">
Don't check a value then assert it — use pattern matching directly.

**Wrong:**
```gleam
case result.is_ok(data) {
  True -> {
    let assert Ok(value) = data
    process(value)
  }
  False -> data
}
```

**Right:**
```gleam
case data {
  Ok(value) -> process(value)
  Error(e) -> Error(e)
}

// Or with use:
use value <- result.try(data)
process(value)
```
</anti_pattern>

<anti_pattern name="Catch-all patterns">
Avoid `_` when you should enumerate variants.

**Wrong:**
```gleam
case role {
  Student -> handle_student()
  _ -> handle_teacher()  // Bug if Admin variant is added!
}
```

**Right:**
```gleam
case role {
  Student -> handle_student()
  Teacher -> handle_teacher()
  Admin -> handle_admin()
}
```
</anti_pattern>

<anti_pattern name="Using null/undefined">
Gleam has NO null/undefined!

**Wrong:** `let x = null` — ERROR!

**Right:** `let x = None` or `let x = Some(value)`
</anti_pattern>
</anti_patterns>
