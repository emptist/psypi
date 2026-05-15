# Psypi Gleam Patterns — Lessons Learned

## 1. Module Imports Use `/` Not `.`

```gleam
// ✅ CORRECT
import generator/tool_call
import generator/before_agent_start

// ❌ WRONG — dots are for record fields, not modules
import generator.tool_call
```

## 2. String Literals in Lists Need Careful Escaping

When building JS code as Gleam string literals:

```gleam
// ✅ CORRECT — each line is a separate string
[
  "    try {\n",
  "      const x = 1;\n",
  "    }\n",
]

// ❌ WRONG — missing closing quote
[
  "    try {",
  "      const x = 1;",  // Missing closing quote!
]
```

## 3. Every Module Must Import Its Dependencies

```gleam
// ✅ CORRECT — import what you use
import gleam/list
import gleam/string

pub fn handler_body() -> String {
  ["hello"]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

// ❌ WRONG — forgot to import gleam/list
pub fn handler_body() -> String {
  ["hello"]
  |> list.map(fn(s) { s <> "\n" })  // Error: Unknown module 'list'
}
```

## 4. Small Modules Prevent Edit Failures

**Rule: Keep modules under 100 lines.**

Large files cause:
- Edit tool failures (can't match exact text)
- Old code accumulation (edits append instead of replace)
- Build errors that are hard to find

**Pattern: One module, one responsibility**

```
src/generator/
├── tool_call.gleam       (31 lines) — tool_call hook
├── before_agent_start.gleam (36 lines) — directive injection
├── session_start.gleam   (20 lines) — health check
├── model_select.gleam    (19 lines) — model change tracking
├── tool_result.gleam     (34 lines) — error detection
└── agent_lifecycle.gleam (20 lines) — start/end logging
```

## 5. Gleam is the Bridge, JS is the Runtime

Gleam compiles to JavaScript. At runtime, only JS exists.

**Mental model:**
- Gleam = the "cook" that prepares ingredients (JS text strings)
- `extension.js` = the final dish (assembled by Gleam)
- Pi runtime = the "restaurant" that serves the dish

**Pattern: Gleam composes JS text, never executes it**

```gleam
// Gleam's job: compose JS source code as strings
pub fn generate() -> String {
  imports_text()
  <> "export default function(pi) {\n"
  <> event_hooks_text()
  <> tools_text()
  <> "}\n"
}
```

## 6. Clean Build After Source Changes

```bash
# Always clean build after changing Gleam source
rm -rf build/ && gleam build

# Then regenerate extension.js
gleam run -m extension_generator
```

Stale compiled output in `build/` causes "undefined function" errors.

## 7. Read Before Edit

The `edit` tool requires reading the file first. Always:

```gleam
# 1. Read the file
read path="src/module.gleam"

# 2. Then edit with EXACT match
edit path="src/module.gleam" edits=[{oldText: "...", newText: "..."}]
```

## 8. Pattern: Thin Hooks, Thick LLM

**Hooks should be THIN** — just record events, no blocking logic.

```javascript
// ✅ CORRECT — thin hook, just auto-backup
pi.on('tool_call', async (event, ctx) => {
  try {
    if (event.toolName === 'edit') {
      // backup logic only
    }
  } catch (err) {
    // Non-blocking
  }
});

// ❌ WRONG — thick hook with blocking logic
pi.on('tool_call', async (event, ctx) => {
  const dangerousPatterns = [...];
  for (const { pattern, message } of dangerousPatterns) {
    if (pattern.test(event.toolName) || pattern.test(inputStr)) {
      return { block: true, message: message };  // Blocks tools!
    }
  }
});
```

**Intelligence should live in the LLM, not in JavaScript regex patterns.**

## 9. Pattern: Alternating Current (A-worker ↔ S-worker)

```
A-worker (events) → DB/hooks → S-worker (prompts)
     ↑                                    ↓
     └──────────── directives ←───────────┘
```

- **A-worker output** (events, DB writes) = **S-worker input**
- **S-worker output** (directives in system prompt) = **A-worker input**
- They alternate — never run at the same time

## 10. Communication: Two Prompt Types

| Type | Channel | Visibility |
|------|---------|------------|
| System prompt | `before_agent_start` hook | Invisible to user |
| User message | `ctx.ui.notify()` | Visible on screen |

Both are just "prompts" to the S-worker — one is system-level, one is user-level.
