# Workflow: Migrate TypeScript to Gleam

<required_reading>
**Read these reference files NOW before migrating:**
1. references/syntax-basics.md
2. references/js-interop.md
3. references/functional-patterns.md
</required_reading>

<intake>
**What do you want to migrate?**

Tell me your intent - for example:
- "Migrate the entire task.ts file to Gleam"
- "Convert just the types/interfaces from this file"
- "Migrate only the add() function"
- "Show me how to migrate database calls"
- "Check if my Gleam migration is correct"
- "Migrate this pattern: [describe pattern]"

**Wait for user's intent before proceeding.**
</intake>

<routing>
| Intent Pattern | Action |
|---------------|--------|
| "Migrate entire file", "convert whole module" | Follow full migration process below |
| "Migrate types", "convert interfaces" | Skip to Step 2: Design Gleam Types |
| "Migrate function", "convert function X" | Skip to Step 3: Rewrite Functions |
| "Migrate database", "DB calls" | Skip to Step 4: Handle Side Effects |
| "Check my Gleam", "review migration" | Jump to Verify section |
| "How to migrate X pattern" | Read pattern-specific reference, provide guidance |
</routing>

<process>
## Step 1: Analyze TypeScript Module (if migrating entire file)

Read the TypeScript file completely. Identify:
- Imports and dependencies
- Functions and their signatures
- Data types (interfaces, types)
- Side effects (DB calls, API calls, console.log)
- Error handling patterns

```bash
# Read the TS file
read /path/to/module.ts
```

## Step 2: Design Gleam Types (if migrating types)

Convert TypeScript types to Gleam custom types:

**TypeScript:**
```typescript
interface Task {
  id: string;
  title: string;
  status: 'pending' | 'completed';
}
```

**Gleam:**
```gleam
pub type TaskStatus {
  Pending
  Completed
}

pub type Task {
  Task(
    id: String,
    title: String,
    status: TaskStatus,
  )
}
```

## Step 3: Rewrite Functions (if migrating functions)

Convert each function to Gleam:

**Rules:**
- Pure functions only (no side effects)
- Use `Result` type for errors (not throwing)
- Use `Option` type (not null/undefined)
- Pattern match with `case` (not if/else)
- Pipe operator `|>` for chaining

**TypeScript:**
```typescript
function add(a: number, b: number): number {
  return a + b;
}
```

**Gleam:**
```gleam
pub fn add(a: Int, b: Int) -> Int {
  a + b
}
```

## Step 4: Handle Side Effects (if migrating side effects)

For database calls, API calls, etc. - use JS interop or `gleam_javascript`:

**Gleam with @external:**
```gleam
@external(javascript, "taskModule", "add")
pub fn add(title: String, description: String) -> Promise(Result(String, TaskError))
```

**Or use gleam_javascript promise:**
```gleam
import gleam/javascript/promise

pub fn add(title: String) -> promise.Promise(Result(String, TaskError)) {
  // Call JS function via interop
}
```

## Step 5: Compile and Test (verify Gleam compiles)

```bash
# Compile Gleam to JS
cd /Users/jk/gits/hub/tools_ai/psypi/gleam/psypi_core
gleam build

# Check output
ls build/dev/javascript/psypi_core/psypi_cli/
```

## Step 6: Update TypeScript Import (connect TS to Gleam)

Update the TS file that imports this module:

```typescript
// Old TS import
// import { add } from './task.js';

// New Gleam import (compiled to JS)
const { add } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/task.mjs");
```

## Step 7: Deprecate Old TypeScript (use .ts.deprecated)

```bash
# Deprecate (don't delete!)
mv /path/to/old-module.ts /path/to/old-module.ts.deprecated
```

## Step 8: Verify (test full functionality)

```bash
# Build entire project
cd /Users/jk/gits/hub/tools_ai/psypi
pnpm build

# Test the functionality
psypi task-add "Test task"
```
</process>

<anti_patterns>
Avoid:
- Copying TS logic line-by-line (think functionally!)
- Using classes in Gleam (Gleam has no classes)
- Throwing errors (use Result type)
- Using null/undefined (use Option)
- Mixing TS and Gleam in same module
</anti_patterns>

<success_criteria>
Migration is complete when:
- [ ] Gleam module compiles without errors
- [ ] All functions have proper Gleam types
- [ ] Side effects handled via interop
- [ ] TypeScript imports the compiled .mjs file
- [ ] Old TS file deprecated (.ts.deprecated)
- [ ] `pnpm build` succeeds
- [ ] Functionality works via psypi command
</success_criteria>
