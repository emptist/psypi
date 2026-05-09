# Workflow: Build New Gleam Module

<required_reading>
**Read these reference files NOW before building:**
1. references/syntax-basics.md
2. references/pattern-matching.md
3. references/js-interop.md (if targeting JavaScript)
4. ../awesome-gleam.md (ecosystem overview)
</required_reading>

<process>
## Step1: Plan the Module

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

## Step2: Create the Module File

```bash
# Create new module file
touch src/my_module.gleam
```

**Basic module structure:**
```gleam
// src/my_module.gleam
import gleam/result
import gleam/option

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

## Step3: Add Dependencies (if needed)

```bash
# Add Gleam package
gleam add some_package

# Check gleam.toml updated
cat gleam.toml
```

## Step4: Compile and Test

```bash
# Build the project
gleam build

# If targeting JavaScript:
gleam build --target=javascript
```

**If build fails:**
- Check syntax errors (Gleam compiler is very helpful!)
- Ensure all patterns covered in `case` expressions
- Check type annotations

## Step5: Write Tests

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

## Step6: Document

Add documentation comments:
```gleam
/// Processes input string.
/// Returns Ok with processed string, or Error if input empty.
/// Example: do_something("hi") -> Ok("Processed: hi")
pub fn do_something(input: String) -> Result(String, String) {
  // ...
}
```
</process>

<anti_patterns>
**DON'T:**
- Use if/else (use `case` instead!)
- Use null/undefined (use `Option` type)
- Forget to handle all patterns in `case`
- Mutation (variables are immutable)
- Skip writing tests

**DO:**
- Let compiler guide you (if it compiles, usually works!)
- Use pipe operator `|>` for readability
- Write type annotations for public functions
- Test all variants of custom types
</anti_patterns>

<success_criteria>
New Gleam module is complete when:

- [ ] Module compiles without errors (`gleam build` ✅)
- [ ] All public functions have type annotations
- [ ] Tests written and passing (`gleam test` ✅)
- [ ] Documentation comments added
- [ ] No compiler warnings
- [ ] Works in target (Erlang/JavaScript) as expected
- [ ] Added to `gleam.toml` if it's a package
</success_criteria>
