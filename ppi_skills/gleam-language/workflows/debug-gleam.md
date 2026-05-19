# Workflow: Debug Gleam Code

<required_reading>
**Read these reference files first:**
1. references/syntax-basics.md
2. references/pattern-matching.md
</required_reading>

<process>
## Step 1: Read the Error Message

Gleam compiler errors are very detailed. Read them carefully — they usually tell you exactly what's wrong and where.

Common error patterns:

| Error | Meaning | Fix |
|-------|---------|-----|
| "Unknown variable" | Variable not in scope | Check spelling, add import |
| "Unknown module" | Module not imported | Add `import` statement |
| "Type mismatch" | Expected A, got B | Check function signature |
| "Incomplete case expression" | Missing variant in `case` | Add missing pattern |
| "Module name segments do not match directory structure" | File path ≠ module path | Rename file or move it |
| "This field does not exist" | Accessing non-existent record field | Check field name, check type |
| "The module is not a valid target for this expression" | Using JS-only code in Erlang target (or vice versa) | Add multi-target externals |

## Step 2: Clean Build

Stale build artifacts cause confusing errors:

```bash
rm -rf build/ && gleam build
```

## Step 3: Check Imports

Every used module must be imported:

```gleam
// Error: Unknown function 'list.map'
// Fix: add import
import gleam/list
```

Check `gleam.toml` for missing dependencies:

```bash
gleam add missing_package
```

## Step 4: Check Type Annotations

Add explicit type annotations to narrow down type errors:

```gleam
// If you get a type error, annotate to help the compiler tell you what it inferred:
let result: Result(Int, String) = some_function()
```

## Step 5: Handle All Variants

If you get "Incomplete case expression", the compiler lists the missing patterns:

```gleam
// Error: This case expression does not have a pattern for the following values:
//   - Error(Nil)
// Add the missing pattern!
```

## Step 6: Check Target Compatibility

If targeting both Erlang and JavaScript:

```gleam
// Error on Erlang: "The module 'console' does not exist"
// Fix: add Erlang external or use conditional compilation
@external(javascript, "console", "log")
@external(erlang, "io", "format")
pub fn log(msg: String) -> Nil
```
</process>

<anti_patterns>
- Don't ignore compiler warnings — they're always meaningful
- Don't use `_` catch-all to silence exhaustiveness errors — fix the actual pattern
- Don't skip `rm -rf build/` when debugging strange errors
</anti_patterns>
