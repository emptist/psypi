<overview>
Testing Gleam code with gleeunit (Erlang target) and gleam_stdlib (JavaScript target).
Write tests in `test/` directory.
</overview>

<gleeunit_setup>
## Gleeunit (Erlang Target)

Install gleeunit:
```bash
gleam add gleeunit
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

<gleam_stdlib_testing>
## Gleamstdlib (JavaScript Target)

For JS target, use `gleam/should`:

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

**No gleeunit needed for JS target!**
</gleam_stdlib_testing>

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

### Testing with Mocks (use Result!)
```gleam
// No mocks in Gleam! Use Result to simulate failures:
pub fn fetch_data_test() {
  my_module.fetch_data(Ok("data"))
  |> should.equal("Processed: data")

  my_module.fetch_data(Error("Network error"))
  |> should.equal("Failed: Network error")
}
```
</test_patterns>

<test_workflow>
## Test Workflow

```bash
# 1. Write test in test/ directory
vim test/my_module_test.gleam

# 2. Run tests
gleam test

# 3. If fails, check:
#    - Function signature matches test
#    - Types are correct
#    - All patterns covered

# 4. Repeat until ✅
```
</test_workflow>

<anti_patterns>
## What NOT to Do

<anti_pattern name="Forgetting test file naming">
Test files MUST end with `_test.gleam`!

**Wrong:** `test/my_module_tests.gleam`  
**Right:** `test/my_module_test.gleam`
</anti_pattern>

<anti_pattern name="Testing private functions">
Only test public functions!

**Wrong:** Testing `my_private_func()` (not exported)  
**Right:** Testing `pub fn do_something()` only
</anti_pattern>

<anti_pattern name="Not running gleam test">
Compiler catches type errors, NOT logic errors!

**Wrong:** "It compiled, so it works!"  
**Right:** Always run `gleam test`!
</anti_pattern>
</anti_patterns>

<exercises>
## Practice Testing

1. Write a test for a `Result` function
2. Test a custom type with 2+ fields
3. Test error cases (Error branch)
4. Use `should.equal` for assertions
</exercises>
