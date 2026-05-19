<overview>
Gleam's custom types (tagged unions / algebraic data types).
Define your own types with variants that can hold data.
Official reference: https://tour.gleam.run/
</overview>

<basic_syntax>
## Defining Custom Types

```gleam
// Variants without data (atoms)
type Color {
  Red
  Green
  Blue
}

// Variants with positional fields
type Status {
  Active
  Inactive(String)  // reason
  Pending
}

// Variants with labelled fields (records)
type User {
  User(id: Int, name: String, email: String)
}
```

**Key points:**
- Type name starts with `PascalCase`
- Variant names start with `PascalCase`
- Fields can be positional or labelled
- No null/undefined needed!
</basic_syntax>

<record_access>
## Record Field Access

Variants with labelled fields get dot-accessor syntax:

```gleam
let user = User(id: 1, name: "Alice", email: "alice@example.com")
user.id     // 1
user.name   // "Alice"
user.email  // "alice@example.com"
```

You can also use `..` spread syntax to update fields:

```gleam
let updated = User(..user, name: "Bob")
```
</record_access>

<pattern_matching>
## Pattern Matching (Exhaustive)

```gleam
let my_color = RGB(255, 0, 128)

case my_color {
  Red -> "Stop!"
  Green -> "Go!"
  Blue -> "Info"
  RGB(r, g, b) -> "Mixed: " <> int.to_string(r) <> ",..."
}
```

**The compiler REQUIRES all variants to be covered.** This is exhaustiveness checking — one of Gleam's most powerful features.
</pattern_matching>

<type_parameters>
## Type Parameters (Generics)

```gleam
type Box(a) {
  Box(a)
}

let int_box = Box(42)
let string_box = Box("hello")

// Use in functions:
pub fn contents(box: Box(a)) -> a {
  let Box(value) = box
  value
}
```

**Common parameterized types:**
- `Result(value, error)` — success or failure
- `Option(a)` — some value or None
- `List(a)` — homogeneous list
</type_parameters>

<nested_types>
## Nested Custom Types

```gleam
type Point {
  Point(x: Float, y: Float)
}

type Shape {
  Circle(center: Point, radius: Float)
  Rectangle(top_left: Point, bottom_right: Point)
}

let shape = Circle(Point(0.0, 0.0), 5.0)

case shape {
  Circle(center: p, radius: r) ->
    "Circle at (" <> float.to_string(p.x) <> ", " <> float.to_string(p.y) <> ")"
  Rectangle(top_left: tl, bottom_right: br) ->
    "Rectangle"
}
```
</nested_types>

<type_aliases>
## Type Aliases

Create a new name for an existing type:

```gleam
type UserName = String
type UserAge = Int

// With parameters:
type MyResult(a) = Result(a, String)
```

Type aliases are fully interchangeable with the original type. They serve as documentation and can make refactoring easier.
</type_aliases>

<opaque_types>
## Opaque Types

Hide the internal representation of a type:

```gleam
pub opaque type UserId {
  UserId(Int)
}
```

With `opaque`, the constructor `UserId` is not exported. External code can only:
- Create values through the module's public API functions
- Pattern match through the module's public functions

This enforces invariants — e.g., ensuring IDs are always positive:

```gleam
pub opaque type UserId {
  UserId(Int)
}

pub fn new(id: Int) -> Result(UserId, String) {
  case id > 0 {
    True -> Ok(UserId(id))
    False -> Error("ID must be positive")
  }
}

pub fn to_string(id: UserId) -> String {
  let UserId(value) = id
  int.to_string(value)
}
```
</opaque_types>

<result_type>
## Result Type (Built-in)

Gleam's built-in `Result` type for error handling:

```gleam
pub type Result(value, error) {
  Ok(value)
  Error(error)
}

pub fn divide(a: Float, b: Float) -> Result(Float, String) {
  case b {
    0.0 -> Error("Division by zero")
    _ -> Ok(a /. b)
  }
}

// Usage:
case divide(10.0, 2.0) {
  Ok(result) -> "Result: " <> float.to_string(result)
  Error(msg) -> "Error: " <> msg
}
```

**Chain Result operations:**

```gleam
// With result.try and use:
use value <- result.try(parse_input(input))
use validated <- result.try(validate(value))
process(validated)
```
</result_type>

<option_type>
## Option Type (Common Pattern)

A typical optional value type (not built-in, but conventional):

```gleam
pub type Option(a) {
  Some(a)
  None
}

pub fn find_user(id: Int) -> Option(User) {
  case id {
    1 -> Some(User(id: 1, name: "Alice", email: "a@b.com"))
    _ -> None
  }
}

// Usage:
case find_user(1) {
  Some(user) -> "Found: " <> user.name
  None -> "User not found"
}
```
</option_type>

<make_invalid_states_impossible>
## Make Invalid States Impossible

The most important pattern with custom types. Design types so invalid states cannot be constructed:

```gleam
// BAD: can construct invalid states
pub type Visitor {
  Visitor(id: Option(Int), email: Option(String))
}
// This is invalid but compiles:
let invalid = Visitor(id: Some(123), email: None)

// GOOD: invalid states are impossible
pub type Visitor {
  LoggedInUser(id: Int, email: String)
  Guest
}
// Can't have an id without an email — the type system prevents it.
```

See Richard Feldman's talk: [Making Impossible States Impossible](https://www.youtube.com/watch?v=IcgmSRJHu_8)
</make_invalid_states_impossible>

<anti_patterns>
## What NOT to Do

<anti_pattern name="Using null/undefined">
Gleam has NO null or undefined! Use a custom type.

**Wrong:**
```gleam
let x = null // ERROR!
```

**Right:**
```gleam
let x = None  // Using Option type
let y = Some("value")
```
</anti_pattern>

<anti_pattern name="Not covering all variants">
Compiler REQUIRES exhaustive patterns!

**Wrong:**
```gleam
case result {
  Ok(v) -> process(v)  // ERROR: Missing Error case!
}
```

**Right:**
```gleam
case result {
  Ok(v) -> process(v)
  Error(e) -> handle_error(e)  // Must handle ALL variants
}
```
</anti_pattern>

<anti_pattern name="Mutation">
Custom type instances are IMMUTABLE!

**Wrong:**
```gleam
let p = Point(1.0, 2.0)
p.x = 3.0  // ERROR! Can't mutate
```

**Right:**
```gleam
let p = Point(1.0, 2.0)
let p2 = Point(3.0, p.y)  // New instance
// Or with spread syntax:
let p2 = Point(..p, x: 3.0)
```
</anti_pattern>

<anti_pattern name="Using Dynamic for FFI types">
Never use `Dynamic` to represent external types. Create a specific external type instead.

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
</anti_patterns>
