# Workflow: Migrate TypeScript to Gleam

<required_reading>
**Read these reference files NOW before migrating:**
1. references/syntax-basics.md
2. references/custom-types.md
3. references/pattern-matching.md
4. references/js-interop.md
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
## Step 1: Analyze TypeScript Module

Read the TypeScript file completely. Identify:
- Imports and dependencies
- Functions and their signatures
- Data types (interfaces, types, enums)
- Side effects (DB calls, API calls, console.log)
- Error handling patterns (try/catch, null checks)

## Step 2: Design Gleam Types

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
  Task(id: String, title: String, status: TaskStatus)
}
```

**Key conversions:**
- `interface` → `type` (custom type with labelled fields)
- `type Status = 'a' | 'b'` → `type Status { A B }` (custom type variants)
- `string | null` → `Option(String)` or a custom type
- `Promise<T>` → depends on target (use `@external` for JS interop)

## Step 3: Rewrite Functions

**Rules:**
- Functions are private by default — use `pub fn` to export
- Use `Result` type for errors (not throwing)
- Use `Option` type (not null/undefined)
- Pattern match with `case` (Gleam has no if/else)
- Use `use` for chaining Result operations
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

**TypeScript with error handling:**
```typescript
function parseAge(input: string): number {
  const n = parseInt(input);
  if (isNaN(n)) throw new Error("Invalid age");
  return n;
}
```

**Gleam:**
```gleam
pub fn parse_age(input: String) -> Result(Int, String) {
  case int.parse(input) {
    Ok(n) -> Ok(n)
    Error(_) -> Error("Invalid age")
  }
}
```

## Step 4: Handle Side Effects

For database calls, API calls, etc. — use `@external`:

```gleam
@external(javascript, "taskModule", "add")
pub fn js_add(title: String) -> Promise(Result(String, TaskError))
```

Or wrap in a Gleam-friendly API:

```gleam
pub fn add(title: String) -> Result(Task, TaskError) {
  // Call external, convert to Result
}
```

## Step 5: Compile and Test

```bash
rm -rf build/ && gleam build
gleam test
```

## Step 6: Verify

- [ ] Gleam module compiles without errors
- [ ] All functions have proper Gleam types
- [ ] Side effects handled via interop
- [ ] Tests pass
- [ ] No `panic` in library code
</process>

<anti_patterns>
Avoid:
- Copying TS logic line-by-line (think functionally!)
- Using classes in Gleam (Gleam has no classes)
- Throwing errors (use Result type)
- Using null/undefined (use Option or custom types)
- Mixing TS and Gleam in same module
- Using `Dynamic` for FFI types (create specific external types)
- Using `_` catch-all in case expressions (enumerate all variants)
</anti_patterns>
