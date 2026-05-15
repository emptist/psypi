---
name: gleam-language
description: Gleam language expertise for building type-safe, reliable systems. Covers syntax, patterns, JS/Erlang interop, testing, and deployment. Use when working with Gleam code, migrating from TypeScript, or building Gleam modules.
---

<essential_principles>
## How Gleam Works

Gleam is a type-safe language that compiles to Erlang and JavaScript. It's small, fast, and catches errors at compile time.

### 1. Small + Pure = Resilience
Keep modules under 100 lines. Pure functions only - no side effects in Gleam code. Side effects happen at the boundary (JavaScript interop).

### 2. Type System First
Gleam's type system catches most errors. If it compiles, it usually works. Use custom types extensively.

### 3. JavaScript Interop via @external
Gleam calls JavaScript using `@external(erlang, "module", "function")` or `gleam_javascript` package. All psypi Gleam code compiles to JS.

### 4. Pattern Matching Over Conditionals
Use `case` expressions, not if/else. Gleam has no null, no undefined - use `Option` type.

### 5. Pipe Operator for Readability
Chain operations with `|>` pipe operator. Gleam reads left-to-right.

### 6. Module Imports Use `/` Not `.`
Gleam module paths use `/` for submodules: `import generator/tool_call`, NOT `import generator.tool_call`. Dots are for record field access.

### 7. String Literals in Lists Need Careful Escaping
When building JS code as Gleam string literals in a list, each line must be a separate string with proper escaping. Use `\n` for newlines within strings, and ensure each list item is properly closed with `",`.

### 8. Every Module Must Import Its Dependencies
Unlike some languages, Gleam requires explicit imports for every module used. `list.map` requires `import gleam/list`. The compiler will tell you exactly what's missing.

### 9. Small Modules Prevent Edit Failures
Keep modules under 100 lines. Large files cause edit tool failures and old code accumulation. Split into focused modules: one file, one responsibility.

### 10. Gleam is the Bridge, JS is the Runtime
Gleam compiles to JavaScript. At runtime, only JS exists. Gleam's job is to compose text (JS source code) that gets written to `extension.js`. Think of Gleam as the "cook" that prepares ingredients (JS text) and assembles the final dish (extension.js).
</essential_principles>

<intake>
What would you like to do with Gleam?

1. Build a new Gleam module
2. Migrate TypeScript to Gleam
3. Debug Gleam code
4. Add Gleam-JS interop
5. Run tests
6. Optimize Gleam performance
7. Something else

**Wait for response before proceeding.**
</intake>

<routing>
| Response | Workflow |
|----------|----------|
| 1, "new", "create", "build module" | `workflows/build-new-module.md` |
| 2, "migrate", "TS to Gleam", "rewrite" | `workflows/migrate-ts-to-gleam.md` |
| 3, "broken", "fix", "debug", "error" | `workflows/debug-gleam.md` |
| 4, "interop", "JS", "javascript" | `workflows/gleam-js-interop.md` |
| 5, "test", "tests" | `workflows/run-tests.md` |
| 6, "optimize", "performance" | `workflows/optimize-gleam.md` |
| 7, other | Clarify, then route to workflow or reference |
</routing>

<reference_index>
## Domain Knowledge

All in `references/`:

**Syntax:** syntax-basics.md (NEW), pattern-matching.md, custom-types.md (NEW)
**Pattern Matching:** pattern-matching.md
**Custom Types:** custom-types.md (NEW)
**Interop:** js-interop.md (NEW), erlang-interop.md, gleam-packages.md
**Interop:** js-interop.md, erlang-interop.md, gleam-packages.md
**Patterns:** functional-patterns.md, error-handling.md, async-patterns.md
**Database:** postgresql-interop.md (psypi uses node_pg)
**Path:** filepath.md — join, split, base_name, extension, etc.
**Build:** build-compile.md, project-structure.md
**Testing:** testing-gleeunit.md (NEW), test-patterns.md
**Anti-patterns:** what-not-to-do.md
**Quality:** gleam-quality-guidelines.md — type safety, custom ID types (check first!), error handling
**Psypi-Specific:** psypi-gleam-patterns.md — lessons learned from psypi development
</reference_index>

<workflows_index>
## Workflows

All in `workflows/`:

| File | Purpose |
|------|---------|
| build-new-module.md | Create new Gleam module from scratch (NEW) |
| migrate-ts-to-gleam.md | Convert TypeScript module to Gleam |
| improve-type-safety.md | Add types without duplication (check first!) |
| debug-gleam.md | Find and fix Gleam compilation/runtime errors |
| gleam-js-interop.md | Call JavaScript from Gleam |
| run-tests.md | Run Gleam tests with gleeunit |
| optimize-gleam.md | Optimize Gleam performance |
</workflows_index>
