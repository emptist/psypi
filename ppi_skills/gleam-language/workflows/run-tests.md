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
import gleeunit
import gleeunit/should
import my_module

pub fn main() {
  gleeunit.main()
}

pub fn my_function_test() {
  my_module.my_function("input")
  |> should.equal(Ok("expected output"))
}

pub fn my_function_error_test() {
  my_module.my_function("")
  |> should.equal(Error("Empty input"))
}
```

**Key rules:**
- File name ends with `_test.gleam` (singular)
- Each test is `pub fn xxx_test()` — auto-discovered by gleeunit
- `pub fn main() { gleeunit.main() }` required in every test file
- Test the public API only (`pub fn`), not private functions
- Test behavior, not implementation details

## Step 2: Build Before Testing

```bash
# If source code changed, rebuild first
gleam clean && gleam build
```

**Critical:** Always rebuild after changing Gleam source. Stale `build/` output causes
misleading test failures. If a test fails unexpectedly, try rebuilding first.

## Step 3: Run Tests

```bash
# All tests
gleam test

# Specific module (matches test file prefix)
gleam test my_module
```

## Step 4: Fix Failures

When a test fails:

1. **Read the panic message** — it shows expected vs actual
2. **Check rebuild** — did you `gleam clean && gleam build` after source changes?
3. **Check test matches source** — does the test reflect the current code behavior?
4. **Check for removed features** — are you testing strings/functions that no longer exist?
5. **Check types** — Int vs Float? Result vs raw value?

## Step 5: Verify Coverage

Ensure you test:
- Every `pub fn` in the source module
- Every variant of custom types
- Every conditional branch (both paths)
- Error cases (not just success cases)
- Edge cases: empty strings, zero, empty lists, large values
- Conditional inclusion AND omission (e.g., section appears when input provided, omitted when empty)

## Step 6: Commit

```bash
git add -A && git commit -m "..."
```
</process>
