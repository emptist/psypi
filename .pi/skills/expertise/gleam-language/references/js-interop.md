<overview>
Gleam compiles to JavaScript for psypi. All Gleam code in psypi becomes .mjs files that TypeScript imports. This reference covers JS interop patterns.
</overview>

<js_interop_methods>
## Method 1: @external (Direct JS FFI)

Call JavaScript functions directly:

```gleam
@external(javascript, "console", "log")
fn console_log(msg: String) -> Nil

@external(javascript, "Date", "now")
fn date_now() -> Float

// Usage
pub fn log_time() {
  let time = date_now()
  console_log("Current time: " <> float.to_string(time))
}
```

## Method 2: gleam_javascript Package

Import JS promises and objects:

```gleam
import gleam/javascript/promise
import gleam/dynamic

// Call JS function that returns Promise
@external(javascript, "taskModule", "add")
pub fn add_task(title: String) -> promise.Promise(dynamic.Dynamic)
```

## Method 3: node_pg for PostgreSQL (psypi uses this!)

```gleam
// In psypi, database calls use node_pg package
import gleam/node_pg

pub fn query(conn, sql: String, params: List(dynamic.Dynamic)) {
  node_pg.query(conn, sql, params)
}
```
</js_interop_methods>

<psypi_pattern>
## psypi Interop Pattern

**Gleam module** (`gleam/psypi_core/src/psypi_cli/task.gleam`):
```gleam
import gleam/javascript/promise

pub fn add(title: String) -> promise.Promise(Result(String, TaskError)) {
  // Call JS function via interop
  // ... implementation
}
```

**Compiled to JS** (`build/dev/javascript/psypi_core/psypi_cli/task.mjs`):
```javascript
export function add(title) {
  // Compiled JavaScript
}
```

**TypeScript imports** (`src/agent/extension/extension.ts`):
```typescript
const { add } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/task.mjs");
```
</psypi_pattern>

<decision_tree>
## When to Use Each Method

**Use @external for:**
- Simple JS function calls (console.log, Math.random)
- Existing JS libraries with simple APIs

**Use gleam_javascript for:**
- Promises and async operations
- Complex JS objects
- node_pg database calls (psypi's approach)

**Use port/actor model for:**
- Erlang interop (not used in psypi currently)
</decision_tree>

<code_examples>
## Complete Example: Database Query

**Gleam** (`db.gleam`):
```gleam
import gleam/javascript/promise
import gleam/dynamic
import gleam/node_pg

pub fn with_connection(fn(conn) {
  let sql = "SELECT * FROM tasks"
  promise.try_await(node_pg.query(conn, sql, []))
})
```

**TypeScript import**:
```typescript
const { with_connection } = await import("./gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/db.mjs");

await with_connection(async (conn) => {
  // Use connection
});
```
</code_examples>

<anti_patterns>
## What NOT to Do

<anti_pattern name="Mix TS and Gleam in same module">
Gleam and TypeScript are separate. Gleam compiles to JS, TS imports the JS.
</anti_pattern>

<anti_pattern name="Direct DOM access in Gleam">
Gleam has no DOM access. Use @external to call JS DOM functions.
</anti_pattern>

<anti_pattern name="Throwing exceptions in Gleam">
Gleam doesn't have exceptions. Use `Result` type for errors.
</anti_pattern>

<anti_pattern name="Forgetting to compile before importing">
Always run `gleam build` before importing .mjs files in TypeScript!
</anti_pattern>
</anti_patterns>

<platform_considerations>
## psypi-Specific Notes

**Build path:** `gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/*.mjs`

**Import pattern in psypi:**
```typescript
// Relative to src/agent/extension/extension.ts
const { func } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/module.mjs");
```

**Hot reload:** Gleam changes require `gleam build` then restart Pi.
</platform_considerations>
