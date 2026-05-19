<overview>
Testing Gleam code with gleeunit (Erlang target) and built-in assertions (JavaScript target).
Write tests in `test/` directory.
Official reference: https://tour.gleam.run/
</overview>

<gleeunit_setup>
## Gleeunit (Erlang Target)

Add gleeunit:
```bash
gleam add gleeunit --dev
```

**Test file structure:**
```gleam
// test/my_module_test.gleam
import gleeunit
import my_module
import gleam/should

pub fn all_tests() {
  gleeunit.with_tests([
    do_something_test(),
  ])
}

fn do_something_test() {
  my_module.do_something("hello")
  |> should.equal(Ok("Processed: hello"))
}
```

Run tests:
```bash
gleam test
```
</gleeunit_setup>

<js_target_testing>
## JavaScript Target

For JS target, use `gleam/should` directly (no gleeunit needed):

```gleam
// test/my_module_test.gleam
import my_module
import gleam/should

pub fn do_something_test() {
  my_module.do_something("")
  |> should.equal(Error("Empty input"))

  my_module.do_something("hi")
  |> should.equal(Ok("Processed: hi"))
}
```
</js_target_testing>

<should_assertions>
## Should Assertions

```gleam
import gleam/should

// Equality
value |> should.equal(expected)

// Inequality
value |> should.not_equal(expected)

// Booleans
value |> should.be_true
value |> should.be_false

// Result
result |> should.be_ok
result |> should.be_error

// Option
option |> should.be_some
option |> should.be_none

// Containment (strings)
string |> should.contain("substring")
```
</should_assertions>

<test_patterns>
## Common Test Patterns

### Testing Result Types
```gleam
pub fn parse_test() {
  my_module.parse("123")
  |> should.equal(Ok(123))

  my_module.parse("abc")
  |> should.equal(Error("Not a number"))
}
```

### Testing Custom Types
```gleam
pub fn shape_test() {
  let circle = my_module.Circle(5.0)
  my_module.area(circle)
  |> should.equal(78.53981633974483)
}
```

### Testing with Use in Tests
```gleam
pub fn fetch_data_test() {
  // Use result.try to test Result chains
  let result = fetch_data("input")
  use value <- result.try(result)
  value |> should.equal("expected")
}
```

### Testing Error Cases
```gleam
pub fn divide_by_zero_test() {
  divide(10.0, 0.0)
  |> should.be_error

  divide(10.0, 0.0)
  |> should.equal(Error("Division by zero"))
}
```
</test_patterns>

<test_workflow>
## Test Workflow

```bash
# 1. Write test in test/ directory (must end with _test.gleam)
vim test/my_module_test.gleam

# 2. Run all tests
gleam test

# 3. Run tests for a specific module
gleam test my_module

# 4. If fails, check:
#    - Function signature matches test
#    - Types are correct
#    - All patterns covered
```
</test_workflow>

<anti_patterns>
## What NOT to Do

<anti_pattern name="Wrong test file naming">
Test files MUST end with `_test.gleam`!

**Wrong:** `test/my_module_tests.gleam`
**Right:** `test/my_module_test.gleam`
</anti_pattern>

<anti_pattern name="Testing private functions">
Only test public (`pub`) functions!
</anti_pattern>

<anti_pattern name="Trusting compilation alone">
Compiler catches type errors, NOT logic errors. Always run `gleam test`!
</anti_pattern>
</anti_patterns>
