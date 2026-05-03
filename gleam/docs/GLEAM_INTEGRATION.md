# Gleam + TypeScript Integration Patterns

## Overview
Guide for integrating Gleam (functional, statically-typed language) with TypeScript projects, with focus on Pi extensions and psypi ecosystem.

## What is Gleam?
- **Functional language** targeting BEAM (Erlang VM) and JavaScript
- **Static typing** with type inference
- **Syntax**: Similar to Rust/Elixir
- **Key features**: Pattern matching, Result/Option types, immutable data, algebraic data types

## Why Use Gleam with TypeScript?
1. **Type Safety**: Gleam's compiler catches errors at build time
2. **Functional Patterns**: Result/Option types for better error handling
3. **Testability**: Gleam has built-in test framework (gleeunit)
4. **Cross-Platform**: Can run on Node.js (JS target) or BEAM

## Integration Pattern (from traenupi project)

### Project Structure
```
project/
├── gleam/
│   └── traenupi_core/
│       ├── src/           # Gleam source files
│       │   ├── traenupi_core.gleam
│       │   ├── utils.gleam
│       │   ├── state.gleam
│       │   └── ...
│       └── build/         # Compiled output (auto-generated)
│           └── dev/javascript/traenupi_core/*.mjs
├── src/
│   └── common/
│       └── gleam-bridge.ts  # TypeScript bridge to Gleam modules
├── package.json
└── gleam.toml
```

### Build Configuration (package.json)
```json
{
  "scripts": {
    "build:gleam": "cd gleam/traenupi_core && gleam build",
    "build": "npm run build:gleam && tsc"
  },
  "devDependencies": {
    "gleam": "^1.0.0"  // Or install globally: npm install -g gleam
  }
}
```

### TypeScript Bridge (gleam-bridge.ts)
```typescript
// Import compiled Gleam modules (ES modules)
import {
  PromptCategory$Action,
  category_to_string,
  new_driver_state,
} from "../../gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core.mjs";

import {
  is_not_empty,
  is_valid_id,
} from "../../gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/validation.mjs";

// Use Gleam functions in TypeScript
export function demoGleamIntegration(): void {
  console.log("Gleam category:", category_to_string(PromptCategory$Action));
  
  const state = new_driver_state();
  console.log("Driver state:", state);
}
```

## Pi Extension Integration

### Can Pi Extensions Import Gleam Modules?
**Yes**, if:
1. Gleam compiles to ES modules (.mjs files)
2. Pi extension uses ES module imports
3. Compiled Gleam output is accessible relative to extension file

### Steps to Add Gleam to a Pi Extension
1. **Install Gleam**: `npm install -g gleam` or add to project devDependencies
2. **Create Gleam source**: Add `gleam/` directory in extension project
3. **Configure build**: Add `build:gleam` script to compile Gleam to JS
4. **Import in extension**: Use relative paths to compiled .mjs files

### Example Pi Extension with Gleam
```typescript
// psypi extension (src/agent/extension/extension.ts)
import { some_gleam_function } from "../../gleam/my_module/build/dev/javascript/my_module/my_module.mjs";

// Use in extension handlers
const result = some_gleam_function(param);
```

## traenupi's Gleam Modules (Examples)
From `../traenupi/gleam/traenupi_core/src/`:
- `cli.gleam` - CLI argument parsing
- `state.gleam` - State management with type-safe updates
- `validation.gleam` - Input validation with Result types
- `jsonx.gleam` - JSON encoding/decoding
- `http.gleam` - HTTP request utilities
- `async.gleam` - Promise/async utilities
- `fs.gleam` - File system operations (with FFI to JS)

## Benefits for psypi
1. **Type-safe core logic**: Move critical psypi logic to Gleam
2. **Better error handling**: Use Result/Option types instead of try/catch
3. **Testable core**: Gleam's built-in test framework
4. **Cross-project patterns**: Share Gleam modules between psypi, traenupi, nezha

## Getting Started
1. Install Gleam: `gleam --version` (or `npm install -g gleam`)
2. Create new Gleam project: `gleam new my_module`
3. Compile: `cd my_module && gleam build`
4. Import compiled JS in TypeScript

## Resources
- Gleam website: https://gleam.run/
- Gleam JS target docs: https://gleam.run/targets/javascript/
- traenupi project: `../traenupi` (working example with 277+ tests)
- traenupi Gleam core: `../traenupi/gleam/traenupi_core/` (18+ modules)
- traenupi blog post: `../traenupi/gleam/traenupi_core/BLOG_POST.md` (comprehensive migration guide)
- gleeunit (Gleam test framework): https://github.com/gleam-lang/gleeunit

## Trae AI's Key Insights (from BLOG_POST.md)
1. **Gleam advantages**: ML-style type system, pattern matching with exhaustiveness checks, immutable by default
2. **Integration pattern**: `gleam build` → compiles to `.mjs` → import in TypeScript
3. **Configuration**: Set `target = "javascript"` and `typescript_declaration = true` in gleam.toml
4. **Challenges**: Learning curve, ecosystem smaller than JS, some function names differ (e.g., `drop_start` not `drop_left`)
5. **Result type**: Gleam's Result type forces explicit error handling - no forgotten errors
