---
name: gleam-language
description: Gleam language expertise for building type-safe, reliable systems. Covers syntax, patterns, JS/Erlang interop, testing, and deployment. Use when working with Gleam code, migrating from TypeScript, or building Gleam modules.
---

<essential_principles>
## How Gleam Works

Gleam is a type-safe language that compiles to Erlang and JavaScript. It's small, fast, and catches errors at compile time.

### 1. Small + Pure = Resilience
Keep modules small. Pure functions preferred — side effects happen at the boundary (FFI/interop).

### 2. Type System First
Gleam's type system catches most errors. If it compiles, it usually works. Use custom types extensively to make invalid states impossible.

### 3. Exhaustiveness Checking
The compiler verifies all `case` expressions cover every variant. This is Gleam's superpower — adding a new variant to a type flags every incomplete `case` at compile time.

### 4. Pattern Matching Over Conditionals
Use `case` expressions for control flow. Gleam has no `if/else` — use `case` with `True`/`False` guards for boolean conditions.

### 5. Use Expressions for Callback Chaining
`use` eliminates nested callbacks. It's the idiomatic way to chain `Result`, `Option`, and other monadic patterns.

### 6. Pipe Operator for Readability
Chain operations with `|>` pipe operator. Gleam reads left-to-right.

### 7. Module Imports Use `/` Not `.`
Gleam module paths use `/` for submodules: `import generator/tool_call`, NOT `import generator.tool_call`. Dots are for record field access.

### 8. Functions Are Private by Default
Use `pub fn` to export. Unqualified function imports are discouraged — prefer qualified calls like `list.reverse`.

### 9. Int and Float Operators Are Separate
`+`, `-`, `*`, `/`, `%` work on Ints. `+.` , `-.`, `*.`, `/.` work on Floats. No implicit conversion.

### 10. Every Module Must Import Its Dependencies
`list.map` requires `import gleam/list`. The compiler tells you exactly what's missing.

### 11. Small Modules Prevent Edit Failures
Keep modules focused. Large files cause edit tool failures. Split into focused modules: one file, one responsibility.

### 12. Gleam is the Bridge, JS/Erlang is the Runtime
Gleam compiles to JavaScript or Erlang. At runtime, only the target exists. Gleam's job is to compose correct code for the target.
</essential_principles>

<intake>
What would you like to do with Gleam?

1. Build a new Gleam module
2. Migrate TypeScript to Gleam
3. Debug Gleam code
4. Add Gleam-JS/Erlang interop
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
| 4, "interop", "JS", "javascript", "FFI" | `workflows/gleam-js-interop.md` |
| 5, "test", "tests" | `workflows/run-tests.md` |
| 6, "optimize", "performance" | `workflows/optimize-gleam.md` |
| 7, other | Clarify, then route to workflow or reference |
</routing>

<reference_index>
## Domain Knowledge

All in `references/`:

**Syntax:** syntax-basics.md — variables, functions, types, `case`, `use`, `let assert`, `const`, `panic`, `todo`, modules, pipes, labelled args
**Pattern Matching:** pattern-matching.md — `case`, guards, list patterns, `as`, `let assert`, `use` expressions
**Custom Types:** custom-types.md — variants, records, type params, type aliases, opaque types, `Option`, `Result`
**Interop:** js-interop.md — `@external`, external types, multi-target, Erlang/JS type mapping, API design
**Build:** build-compile.md, project-structure.md
**Testing:** testing-gleeunit.md — gleeunit, `gleam/should`, assertions, test patterns
**Conventions:** conventions-patterns-anti-patterns (from official docs)
**Anti-patterns:** what-not-to-do.md
**Quality:** gleam-quality-guidelines.md — type safety, custom ID types, error handling
**Psypi-Specific:** psypi-gleam-patterns.md — lessons learned from psypi development
**Ecosystem:** awesome-gleam.md — package index, tools, resources
**File Paths:** filepath.md — join, split, base_name, extension
</reference_index>

<workflows_index>
## Workflows

All in `workflows/`:

| File | Purpose |
|------|---------|
| build-new-module.md | Create new Gleam module from scratch |
| migrate-ts-to-gleam.md | Convert TypeScript module to Gleam |
| improve-type-safety.md | Add types without duplication (check first!) |
| debug-gleam.md | Find and fix Gleam compilation/runtime errors |
| gleam-js-interop.md | Call JavaScript/Erlang from Gleam |
| run-tests.md | Run Gleam tests with gleeunit |
| optimize-gleam.md | Optimize Gleam performance |
</workflows_index>

<official_resources>
## Official Resources

- **Language Tour:** https://tour.gleam.run/ (interactive, covers entire language)
- **Documentation:** https://gleam.run/documentation/
- **Package Index:** https://packages.gleam.run/
- **Cheat Sheets:** Elixir users, Erlang users (on gleam.run)
- **GitHub:** https://github.com/gleam-lang/gleam
</official_resources>
