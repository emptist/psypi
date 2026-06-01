<overview>
Testing Gleam code with gleeunit. This project compiles to JavaScript target but uses
gleeunit for test discovery — any `pub fn` in `test/` ending in `_test` is auto-discovered.
Official reference: https://tour.gleam.run/
</overview>

<project_setup>
## Project Setup (psypi)

gleeunit is already added as a dev dependency. Test files live in `test/`.

```bash
# Run all tests
gleam test

# Run tests for a specific module (matches test file prefix)
gleam test a_prompt_builder

# After changing Gleam source, rebuild first
gleam clean && gleam build
gleam test
```

**Important:** Always run `gleam build` before `gleam test` when source files have changed.
Stale compiled output in `build/` causes confusing errors.
</project_setup>

<test_discovery>
## Test Discovery

Gleeunit auto-discovers tests by naming convention:

```gleam
// test/my_module_test.gleam
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Any pub fn ending in _test is auto-discovered
pub fn my_function_test() {
  // ...
}

pub fn my_function_error_test() {
  // ...
}
```

**Rules:**
- Test file MUST be in `test/` directory
- Test file name MUST end with `_test.gleam`
- Each test function MUST be `pub fn` and end with `_test`
- `pub fn main() { gleeunit.main() }` bootstraps the test runner
- No manual test registration needed — discovery is automatic
</test_discovery>

<test_file_structure>
## Test File Structure

```gleam
// test/my_module_test.gleam

// 1. Imports: gleeunit, gleeunit/should, module under test, helpers
import gleeunit
import gleeunit/should
import my_module
import gleam/string

// 2. Main entry point (required)
pub fn main() {
  gleeunit.main()
}

// 3. One pub fn per test case, named <what>_<scenario>_test
pub fn parse_valid_input_test() { ... }
pub fn parse_empty_input_test() { ... }
pub fn parse_invalid_input_test() { ... }
```

**Naming convention:** `<function>_<scenario>_test` — descriptive, no `test_` prefix duplication.
</test_file_structure>

<should_assertions>
## Should Assertions

```gleam
import gleam/should

// Equality (most common)
value |> should.equal(expected)

// Inequality
value |> should.not_equal(expected)

// Booleans
value |> should.be_true
value |> should.be_false

// Result type
result |> should.be_ok
result |> should.be_error

// Option type
option |> should.be_some
option |> should.be_none

// String containment
string |> should.contain("substring")

// Comparison (Int/Float)
value |> should.be_greater_than(threshold)
value |> should.be_less_than(threshold)

// List
list |> should_not.be_empty
```

**Note:** `should.equal` uses structural equality. For floats, use exact values or compare with tolerance.
</should_assertions>

<test_patterns>
## Common Test Patterns

### Testing Public Functions Only
```gleam
// ✅ Test public API
pub fn parse_valid_test() {
  my_module.parse("123")
  |> should.equal(Ok(123))
}

// ❌ Don't test private functions — they're implementation details
```

### Testing Result Types (Ok + Error)
```gleam
pub fn parse_valid_test() {
  my_module.parse("123")
  |> should.equal(Ok(123))
}

pub fn parse_invalid_test() {
  my_module.parse("abc")
  |> should.be_error()
}

pub fn parse_empty_test() {
  my_module.parse("")
  |> should.equal(Error("Empty input"))
}
```

### Testing Custom Type Variants
```gleam
pub fn area_circle_test() {
  let circle = my_module.Circle(5.0)
  my_module.area(circle)
  |> should.equal(78.54)
}

pub fn area_rectangle_test() {
  let rect = my_module.Rectangle(3.0, 4.0)
  my_module.area(rect)
  |> should.equal(12.0)
}
```

### Testing String Output (Prompt Builders, Generators)
```gleam
pub fn build_includes_content_test() {
  let output = my_module.build("hello world")
  should.be_true(string.contains(output, "hello world"))
}

pub fn build_omits_when_empty_test() {
  let output = my_module.build("")
  should.be_false(string.contains(output, "--- section"))
}
```

### Testing List Operations
```gleam
pub fn all_items_have_names_test() {
  let items = my_module.get_items()
  should.be_true(list.all(items, fn(i) { string.length(i.name) > 0 }))
}

pub fn items_are_unique_test() {
  let items = my_module.get_items()
  let names = list.map(items, fn(i) { i.name })
  list.length(names) |> should.equal(list.length(list.unique(names)))
}
```

### Testing Conditional Inclusion/Omission
```gleam
// Test that a section appears when input is provided
pub fn with_cwd_includes_directory_test() {
  let text = my_module.build(path: "/home/user")
  should.be_true(string.contains(text, "Working directory: /home/user"))
}

// Test that the section is omitted when input is empty
pub fn empty_cwd_omits_directory_test() {
  let text = my_module.build(path: "")
  should.be_false(string.contains(text, "Working directory:"))
}
```

### Testing Truncation
```gleam
pub fn long_input_gets_truncated_test() {
  let long = string.repeat("x", 5000)
  let text = my_module.format(long)
  should.be_true(string.contains(text, "...[truncated]"))
  should.be_true(string.length(text) < string.length(long))
}
```
</test_patterns>

<test_organization>
## Test Organization

### One Test File Per Source Module
```
src/a_prompt_builder.gleam    → test/a_prompt_builder_test.gleam
src/pi_tool_call.gleam        → test/pi_tool_call_test.gleam
src/extension_generator.gleam → test/extension_generator_test.gleam
```

### Group Related Tests
Keep tests for the same function/area together:
```gleam
// --- build_system_prompt: soul content ---
pub fn build_system_prompt_includes_soul_test() { ... }
pub fn build_system_prompt_empty_soul_omits_section_test() { ... }

// --- build_system_prompt: jobs ---
pub fn build_system_prompt_includes_jobs_test() { ... }
pub fn build_system_prompt_no_jobs_omits_section_test() { ... }

// --- build_user_prompt: cwd ---
pub fn build_user_prompt_with_cwd_test() { ... }
pub fn build_user_prompt_empty_cwd_omits_directory_test() { ... }
```

### Test Count Guidelines
- Every `pub fn` in the source module should have at least one test
- Every variant of a custom type should be tested
- Every conditional branch should have a test for each path
- Error cases are as important as success cases
- Edge cases: empty strings, zero, empty lists, max values
</test_organization>

<anti_patterns>
## What NOT to Do

<anti_pattern name="Testing implementation details">
Test the public contract, not internal structure.

**Wrong:**
```gleam
// Testing internal string format that could change
should.be_true(string.contains(text, "--- soul [critical] ---"))
```

**Right:**
```gleam
// Testing behavior: soul content appears in output
should.be_true(string.contains(text, "You are A-bot."))
```
</anti_pattern>

<anti_pattern name="Vacuous tests">
Don't test that empty input doesn't contain a random string.

**Wrong:**
```gleam
// This tells you nothing useful
let comp = a_prompt_builder.build_system_prompt("", "", 128000)
let text = compose(comp)
should.be_false(string.contains(text, "Autonomic Agentbot"))
```

**Right:**
```gleam
// Test the actual contract: empty soul omits the soul section
let comp = a_prompt_builder.build_system_prompt("", "", 128000)
let text = compose(comp)
should.be_false(string.contains(text, "--- soul"))
```
</anti_pattern>

<anti_pattern name="Testing removed features">
When code is removed, update tests to match. Don't keep testing for strings/functions that no longer exist.

**Wrong:**
```gleam
// The "polite reminder" text was removed from the source
should.be_true(string.contains(text, "polite reminder"))  // Will always fail
```

**Right:**
```gleam
// Test what the code actually does now
should.be_true(string.contains(text, "Recent Conversation"))
```
</anti_pattern>

<anti_pattern name="Overly specific assertions">
Don't assert exact positions or lengths unless that's the contract.

**Wrong:**
```gleam
string.length(text) |> should.equal(4100)  // Brittle
```

**Right:**
```gleam
should.be_true(string.length(text) < string.length(long_input))  // Tests the property
```
</anti_pattern>

<anti_pattern name="Testing private functions">
Only test `pub fn` functions. Private functions are implementation details.

**Wrong:**
```gleam
// fn internal_helper() is not pub
my_module.internal_helper("input") |> should.equal("output")
```
</anti_pattern>

<anti_pattern name="Wrong test file naming">
Test files MUST end with `_test.gleam` (singular).

**Wrong:** `test/my_module_tests.gleam`
**Right:** `test/my_module_test.gleam`
</anti_pattern>

<anti_pattern name="Forgetting gleeunit.main()">
Every test file needs the main entry point.

**Wrong:**
```gleam
// Missing main — tests won't run
pub fn my_test() { ... }
```

**Right:**
```gleam
pub fn main() {
  gleeunit.main()
}

pub fn my_test() { ... }
```
</anti_pattern>

<anti_pattern name="Trusting compilation alone">
Compiler catches type errors, NOT logic errors. Always run `gleam test`!

Code that compiles can still be logically wrong. Tests verify behavior.
</anti_pattern>
</anti_patterns>

<test_workflow>
## Test Workflow

```bash
# 1. Write/update test file in test/ directory
vim test/my_module_test.gleam

# 2. Build first (if source changed)
gleam clean && gleam build

# 3. Run all tests
gleam test

# 4. Run specific test module
gleam test my_module

# 5. If test fails:
#    - Read the panic message carefully
#    - Check: does the test match the current source code?
#    - Check: was the source code rebuilt before testing?
#    - Check: are you testing behavior or implementation details?

# 6. After all tests pass, commit
git add -A && git commit -m "..."
```

**Critical rule:** If you change Gleam source, you MUST `gleam clean && gleam build` before `gleam test`.
Running tests against stale compiled output produces misleading failures.
</test_workflow>
