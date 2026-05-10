# Gleam Code Quality Guidelines

## Why Quality Matters

Gleam's type system is powerful but only if we use it correctly. Weak types = runtime bugs that Gleam should catch.

## Common Quality Issues

### 1. String Types for IDs (Anti-pattern)

**Bad:**
```gleam
fn get_agent(agent_id: String) -> Agent { ... }
```

**Good:**
```gleam
pub type AgentId { AgentId(String) }

fn get_agent(agent_id: AgentId) -> Agent { ... }
```

**Why:** AgentId as a wrapper makes it impossible to confuse agent IDs with other strings. The compiler catches type mismatches.

### 1a. DO NOT Duplicate ID Types

Before creating new ID types, CHECK if similar type already exists!

- ✅ Use existing `AgentId` from `agent_identity_types.gleam`
- ❌ Don't create new `SessionId`, `UserId`, etc. if AgentId works

**How to check:**
```bash
grep -r "pub type.*Id" src/psypi/
```

If ID type exists, use it or extend it. Don't create competing types.

### 2. Unused Imports

**Bad:**
```gleam
import gleam/list
import gleam/string  // never used
```

**Fix:** Remove unused imports. Run `gleam build` - compiler warns about unused imports.

### 2a. Import Aliasing (Avoid Name Collisions)

When two modules export the same function name (e.g., `task.add` and `issue.add`), use aliases:

```gleam
import psypi/task.{add as task_add}
import psypi/issue.{add as issue_add}
```

**Why:** Without aliases, you get "Identifier 'add' has already been declared" error at extension generation.

### 2b. Labeled Arguments Rule

After using a labeled argument, ALL subsequent arguments must also be labeled:

```gleam
// BAD - labeled then unlabeled
template("foo"),  // ERROR!

// GOOD - all labeled
result_format: template("foo"),
```

**Why:** Gleam enforces this. Error: "Unexpected positional argument ... has been supplied after a labelled argument."

### 3. Magic Strings

**Bad:**
```gleam
let status = "Open"
```

**Good:**
```gleam
pub type Status {
  Open
  InProgress
  Closed
}

let status = Open
```

### 4. Empty Records

**Bad:**
```gleam
pub type Config { Config }
```

**Better:**
```gleam
pub type Config { Config(run_tests: Bool, verbose: Bool) }
```

### 5. No Custom Result Types

**Bad:**
```gleam
fn query(sql: String) -> Result(List(Row), String)
```

**Good:**
```gleam
pub type QueryError {
  ConnectionFailed(String)
  InvalidQuery(String)
  Timeout
}

fn query(sql: String) -> Result(List(Row), QueryError)
```

### 6. Parameter Types Match Return Types

**Bad:**
```gleam
pub fn list(status: Option(String))  // String, not MeetingStatus!
```

**Good:**
```gleam
pub fn list(status: Option(MeetingStatus))  // Type-safe!
```

**Why:** When function takes enum parameter but DB needs string, provide helper to convert both directions.

**Example:** meeting.gleam has `string_to_status()` but lacks reverse (MeetingStatus → String). Add both for round-trip safety.

## Quality Checklist

Before calling a module "done":

- [ ] No `String` types for IDs - use custom types (AgentId, TaskId, IssueId)
- [ ] No unused imports (check `gleam build` warnings)
- [ ] No magic strings - use custom types with variants
- [ ] Custom error types (not `String` for errors)
- [ ] All modules < 100 lines (split if larger)
- [ ] Pure functions where possible (no side effects in Gleam code)

## Applying to Existing Code

When improving existing Gleam modules:

1. **Start small** - fix one module at a time
2. **Build often** - `rm -rf build/ && gleam build` catches issues early
3. **Don't break working code** - verify after each change
4. **Commit after each improvement** - small, focused commits

## Related

- See `agent_identity_types.gleam` for AgentId type example
- See `issue.gleam` for custom error types