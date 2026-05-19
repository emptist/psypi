# Workflow: Build New Gleam Module

<required_reading>
**Read these reference files NOW before building:**
1. references/syntax-basics.md
2. references/pattern-matching.md
3. references/custom-types.md
4. references/js-interop.md (if targeting JavaScript)
5. references/testing-gleeunit.md
</required_reading>

<process>
## Step 1: Plan the Module

Decide:
- **Module name:** (e.g., `my_module`)
- **Purpose:** What will it do?
- **Target:** Erlang BEAM or JavaScript (Node.js/browser)?
- **Dependencies:** Any Gleam packages needed?

```bash
# Navigate to Gleam project
cd /path/to/gleam/project

# Check current packages
cat gleam.toml
```

## Step 2: Create the Module File

```bash
# Create new module file
touch src/my_module.gleam
```

**Basic module structure:**
```gleam
// src/my_module.gleam
import gleam/result

pub type MyType {
  Variant1
  Variant2(String)
  Variant3(Int, Bool)
}

pub fn do_something(input: String) -> Result(String, String) {
  case input {
    "" -> Error("Empty input")
    s -> Ok("Processed: " <> s)
  }
}
```

## Step 3: Add Dependencies (if needed)

```bash
# Add Gleam package
gleam add some_package

# Add dev dependency (e.g., gleeunit)
gleam add gleeunit --dev

# Check gleam.toml updated
cat gleam.toml
```

## Step 4: Compile

```bash
# Clean build
rm -rf build/ && gleam build

# If targeting JavaScript:
gleam build --target javascript
```

**If build fails:**
- Read the error message carefully — Gleam errors are very helpful
- Check all `case` patterns are exhaustive
- Check type annotations
- Check imports

## Step 5: Write Tests

Create test file:
```bash
touch test/my_module_test.gleam
```

**Test example:**
```gleam
// test/my_module_test.gleam
import my_module
import gleam/should

pub fn do_something_test() {
  my_module.do_something("")
  |> should.equal(Error("Empty input"))

  my_module.do_something("hello")
  |> should.equal(Ok("Processed: hello"))
}
```

Run tests:
```bash
gleam test
```

## Step 6: Document

Add documentation comments:
```gleam
//// This module provides functionality for processing strings.

/// Processes input string.
/// Returns Ok with processed string, or Error if input empty.
///
/// ## Examples
///
/// ```gleam
/// do_something("hi") // Ok("Processed: hi")
/// do_something("")   // Error("Empty input")
/// ```
pub fn do_something(input: String) -> Result(String, String) {
  // ...
}
```
</process>

<anti_patterns>
**DON'T:**
- Use null/undefined (use custom types)
- Forget to handle all patterns in `case`
- Use `_` catch-all when you should enumerate variants
- Skip writing tests
- Use `panic` in library code (use `Result`)
- Use unqualified function imports (prefer `list.reverse` over `reverse`)

**DO:**
- Let compiler guide you (if it compiles, usually works!)
- Use pipe operator `|>` for readability
- Use `use` for chaining Result/Option operations
- Write type annotations for public functions
- Test all variants of custom types
- Make invalid states impossible with custom types
</anti_patterns>

<success_criteria>
New Gleam module is complete when:

- [ ] Module compiles without errors (`gleam build` ✅)
- [ ] All public functions have type annotations
- [ ] Tests written and passing (`gleam test` ✅)
- [ ] Documentation comments added (`///` for functions, `////` for module)
- [ ] No compiler warnings
- [ ] Works in target (Erlang/JavaScript) as expected
</success_criteria>
