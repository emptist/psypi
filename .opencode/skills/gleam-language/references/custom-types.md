<overview>
Gleam's custom types (also called "custom types" or "tagged unions").
Define your own types with variants that can hold data.
</overview>

<basic_syntax>
## Defining Custom Types

```gleam
type Color {
  Red
  Green
  Blue
  RGB(Int, Int, Int)
}

type Status {
  Active
  Inactive(String) // Reason
  Pending
}
```

**Key points:**
- Start with UPPERCASE letter
- Variants can hold data (like RGB)
- No null/undefined needed!
</basic_syntax>

<using_types>
## Using Custom Types

```gleam
let my_color = RGB(255, 0, 128)

case my_color {
  Red -> "Stop!"
  Green -> "Go!"
  Blue -> "Info"
  RGB(r, g, b) -> "Mixed: " <> int.to_string(r) <> ",..."
}
```

**Pattern matching is REQUIRED!**  
Gleam compiler checks ALL variants are covered.
</using_types>

<type_parameters>
## Type Parameters (Generics)

Types can have parameters:

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
- `Result(value, error)` - Success or failure
- `Option(a)` - Some value or None
- `List(a)` - List of any type
</type_parameters>

<nested_types>
## Nested Custom Types

Types can contain other custom types:

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
  Circle(p, r) -> "Circle at (" <> float.to_string(p.x) <> ",...)"
  Rectangle(tl, br) -> "Rectangle from (" <> float.to_string(tl.x) <> ",...)"
}
```
</nested_types>

<result_type>
## Result Type (Special!)

Gleam's `Result` type for error handling:

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
let result = Ok(10)
|> result.try(fn(x) { Ok(x * 2) })
|> result.try(fn(x) { if x > 10 { Ok(x) } else { Error("Too small") } })
```
</result_type>

<option_type>
## Option Type (For "Nullable" Values)

Gleam's `Option` type (instead of null/undefined):

```gleam
pub type Option(a) {
  Some(a)
  None
}

pub fn find_user(id: Int) -> Option(User) {
  case id {
    1 -> Some(User("Alice"))
    _ -> None
  }
}

// Usage:
case find_user(1) {
  Some(user) -> "Found: " <> user.name
  None -> "User not found"
}

// Use option functions:
let maybe_name = Some("Bob")
let name = option.unwrap(maybe_name, "Anonymous") // "Bob"
let uppercase = option.map(maybe_name, string.uppercase) // Some("BOB")
```
</option_type>

<anti_patterns>
## What NOT to Do

<anti_pattern name="Using null/undefined">
Gleam has NO null or undefined! Use `Option`.

**Wrong:**
```gleam
let x = null // ERROR!
```

**Right:**
```gleam
let x = None
let y = Some("value")
```
</anti_pattern>

<anti_pattern name="Not covering all variants">
Compiler REQUIRES exhaustive patterns!

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
  Error(e) -> ... // Must handle ALL variants
}
```
</anti_pattern>

<anti_pattern name="Mutation">
Custom type instances are IMMUTABLE!

**Wrong:**
```gleam
let p = Point(1.0, 2.0)
p.x = 3.0 // ERROR! Can't mutate
```

**Right:**
```gleam
let p = Point(1.0, 2.0)
let p2 = Point(3.0, p.y) // New instance
```
</anti_pattern>
</anti_patterns>

<exercises>
## Practice Custom Types

1. Define a `PaymentMethod` type (Card, Cash, Transfer)
2. Create a `User` type with id, name, email (optional)
3. Write a function that pattern matches on `Result` and returns default on Error
4. Nest custom types (e.g., `Address` inside `User`)
</exercises>
