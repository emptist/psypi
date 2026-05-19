# Workflow: Run Gleam Tests

<required_reading>
**Read these reference files first:**
1. references/testing-gleeunit.md
</required_reading>

<process>
## Step 1: Write Test File

Create a file in `test/` ending with `_test.gleam`:

```gleam
// test/my_module_test.gleam
import my_module
import gleam/should

pub fn my_function_test() {
  my_module.my_function("input")
  |> should.equal(Ok("expected output"))
}

pub fn my_function_error_test() {
  my_module.my_function("")
  |> should.equal(Error("Empty input"))
}
```

For Erlang target with gleeunit:
```gleam
import gleeunit
import gleam/should

pub fn all_tests() {
  gleeunit.with_tests([
    my_function_test(),
  ])
}
```

## Step 2: Run Tests

```bash
# All tests
gleam test

# Specific module
gleam test my_module

# With JS target
gleam test --target javascript
```

## Step 3: Fix Failures

- Check function signatures match
- Verify all `case` branches are covered
- Ensure types align (Int vs Float matters!)

## Step 4: Verify Coverage

Test all variants of custom types:
- Every `Ok` and `Error` branch
- Every custom type variant
- Edge cases (empty strings, zero, empty lists)
</process>
