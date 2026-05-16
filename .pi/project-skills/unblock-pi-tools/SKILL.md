---
name: unblock-pi-tools
description: Diagnose, fix, and prevent "tool execution blocked" errors in Pi AI agent systems. Covers root causes in extension.js, Gleam result unwrapping, database schema mismatches, import aliasing, hook failures, and PromiseLayer handling. Use when Pi tools return "blocked", "[object Promise]", or hang indefinitely.
---

<essential_principles>
## How Tool Blocking Works

Pi tools execute through a chain of three layers, each of which can block:

```
Pi Runtime → extension.js (hooks + tool definitions) → Gleam compiled .mjs → Database
                 ↓                         ↓                       ↓
        hook blocks tool         undefined function       DB query error
        or returns error         or wrong Result format   missing column
```

### Layer 1: Event Hooks Can Block
The `tool_call` hook in `extension.js` can return `{ block: true, message: "..." }` to prevent a tool from running. This is used for safety (dangerous patterns) but can also block accidentally.

### Layer 2: Tool Execute Functions Can Fail
Each `pi.registerTool({ execute: async (...) => {...} })` can throw or return an error. A crash in `execute` shows "Error: ..." to the user. A crash in the `tool_call` hook may silently fail for non-edit tools.

### Layer 3: Gleam Functions Return Wrapped Results
Gleam compiled to JS returns `PromiseLayer → native Promise → Ok/Error` objects. The `unwrapGleamResult()` helper in extension.js must handle this correctly or tools silently produce "[object Promise]" or "undefined".

### Major Symptoms & Root Causes

| Symptom | Likely Root Cause |
|---------|-------------------|
| "Tool execution blocked" | Hook returned `{ block: true }` (safety match or hook error) |
| `[object Promise]` | Gleam Promise not awaited, or Result not unwrapped |
| `Error: function X is not defined` | Import aliasing mismatch in extension.js |
| `Error: column X does not exist` | Database schema mismatch |
| Tool hangs / never returns | Gleam PromiseLayer not unwrapped properly (await doesn't resolve) |
| Session crash at start | `session_start` hook failed (DB unavailable or function missing) |
</essential_principles>

<prevention>
## Prevention: Build & Code Hygiene

### Always Clean Build
```bash
cd gleam/psypi_core && rm -rf build/ && gleam build
```
Stale compiled output in `build/` is the #1 cause of "undefined function" errors. The compiler caches old versions — a clean build eliminates this.

### Verify All Imports After Generator Changes
After modifying `extension_generator.gleam`, check:
1. Every imported function name matches the compiled `.mjs` export
2. Every aliased function uses the correct name (e.g., `list as task_list`)
3. Every tool in `all_tools()` list has its import present

### Handle Errors in tool_call Hook
The `tool_call` hook should NEVER silently crash for non-edit tools. Always add a fallback:
```javascript
pi.on('tool_call', async (event, ctx) => {
  try {
    // ... identity resolution, backup logic ...
  } catch (err) {
    // Log error but DON'T block the tool
    console.error('tool_call hook error:', err.message);
    // Do NOT return { block: true } — let the tool proceed
  }
  // Don't return anything = tool proceeds
});
```

### Use unwrapGleamResult for Every Gleam Call
Every Gleam function returns an `Ok/Error` custom type. Always unwrap:
```javascript
async execute(...) {
  const result = await gleamFunction(params);
  const r = unwrapGleamResult(result);
  if (!r.ok) return { content: [{ type: 'text', text: `Error: ${r.error}` }] };
  return { content: [{ type: 'text', text: JSON.stringify(r.value) }] };
}
```

### Register the Monitor's Identity Before Session Start
The `session_start` hook calls `check_system_health()` which queries the DB. If the DB is unreachable, the hook crashes. Ensure DB is running before starting psypi.

### Check DB Schema After Migrations
When a new version of psypi adds columns to DB tables, the old schema won't have them. Always verify:
```bash
psql -d psypi -c "\d issues"  # Check all required columns
```
</prevention>

<workflow>
## Troubleshooting Workflow

### Step 1: Identify the Symptom
Run the blocked tool and note the EXACT error message:
```
"Tool execution was blocked"         → hook returned { block: true }
"[object Promise]" or "undefined"    → Result not unwrapped or not awaited
"function X is not defined"          → import/aliasing mismatch
"column X does not exist"            → DB schema mismatch
Tool hangs forever                   → PromiseLayer not resolved
```

### Step 2: Check Event Hooks (Most Common Cause)
Open `extension.js` and look at the `tool_call` hook:
- Is there a `return { block: true }` path that shouldn't be there?
- Is the dangerous pattern regex matching tool names it shouldn't?
- Is there a catch block that returns `{ block: true }` by accident?

Check: the dangerous patterns regex tests `event.toolName` too — a tool named `bash` with `rm -rf` in its input would match.

### Step 3: Check Build Artifacts
```bash
# 1. Check that compiled modules exist
ls build/dev/javascript/psypi/psypi/*.mjs | wc -l

# 2. Check that extension.js imports match compiled exports
grep "^export function" build/dev/javascript/psypi/psypi/issue.mjs

# 3. Check the import line in extension.js
grep "from.*issue.mjs" extension.js
```

### Step 4: Check unwrapGleamResult
Look at the tool's `execute` function in `extension.js`:
```javascript
const result = await gleamFunction();
const r = unwrapGleamResult(result);  // ← Is this here?
if (!r.ok) ...  // ← Is error handling present?
```

The `unwrapGleamResult` function handles Gleam's `Ok`/`Error` custom types:
```javascript
function unwrapGleamResult(result) {
  if (!result) return { ok: false, error: 'null result' };
  const typeName = result.constructor?.name || '';
  if (typeName === 'Ok') return { ok: true, value: result['0'] };
  if (typeName === 'Error') return { ok: false, error: result['0']?.['0'] || 'Unknown' };
  return { ok: true, value: result };  // Fallback — assumes success
}
```

### Step 5: Check Database Schema
```bash
# List all columns in the issues table
psql -d psypi -c "\d issues"

# Check for missing columns referenced in gleam/psypi_core/src/psypi_cli/issue.gleam
# Common missing columns: created_by, discovered_by, environment, git_branch
```

### Step 6: Regenerate extension.js
```bash
cd gleam/psypi_core && rm -rf build/ && gleam build && gleam run -m psypi_cli/extension_generator
```
Then verify the generated file contains the expected function.

### Step 7: Test the Fix
```bash
# Quick smoke test
psypi --print "Run psypi-issues and show results"
psypi --print "What is my agent ID?"
```
</workflow>

<root_causes>
## Root Cause Catalog

### A. Undefined Functions in extension.js
**Symptom:** "function X is not defined" or tool returns no result.

**Cause:** The import statement in `extension_generator.gleam` uses an alias that doesn't match the actual function export. Or `all_tools()` references a function not imported.

**Fix:**
1. Check the import: `import psypi_cli/my_module as my_module`
2. Check the tool entry: `my_module.my_function()`
3. Verify the function is exported: `grep "^export function my_function" build/.../my_module.mjs`
4. Clean build: `rm -rf build/ && gleam build`
5. Regenerate: `gleam run -m psypi_cli/extension_generator`

### B. Database Schema Mismatch
**Symptom:** "column X does not exist" or tool returns empty results.

**Cause:** A Gleam module queries a column that doesn't exist in the DB.

**Fix:**
```sql
ALTER TABLE issues ADD COLUMN created_by TEXT NOT NULL DEFAULT 'nezha';
ALTER TABLE issues ADD COLUMN discovered_by TEXT NOT NULL DEFAULT 'nezha';
-- Check the Gleam query for the exact column list
```

### C. Import/Aliasing Problems
**Symptom:** Tool works in one context but not another. Intermittent failures.

**Cause:** The Gleam module exports changed (function renamed) but extension.js still uses old name.

**Fix:** Compare exports vs imports:
```bash
# List all exported functions
grep "^export function" build/dev/javascript/psypi/psypi/*.mjs | grep "export function" | sort

# List all imports in extension.js
grep "import.*from.*\.mjs" extension.js | sort
```

### D. Configuration/Connection Issues
**Symptom:** `session_start` hook fails silently. Tools work for a while then fail.

**Cause:** Wrong database name, user, or connection string.

**Fix:**
```bash
echo $PSYPI_DB_NAME        # Should be "psypi"
psql -d psypi -c "SELECT 1"  # Test connection
```

### E. PromiseLayer Blocking
**Symptom:** Tool hangs and never returns a result.

**Cause:** The `await` in the tool's `execute` function receives a `PromiseLayer` object (not a native Promise), so `await` doesn't resolve. Gleam wraps Promises in `PromiseLayer` to prevent `Promise<Promise<T>>` collapsing.

**Fix:** Ensure the Gleam function returns through `$promise.map()` which properly unwraps. In `extension.js`, always `await` Gleam functions — the native Promise is inside the PromiseLayer.

### F. Hook Silent Error
**Symptom:** Tools work but no activity logging, no auto-backup. Error appears in console.

**Cause:** The `tool_call` hook catch block only handles `edit`/`write` tools:
```javascript
catch (err) {
  // Only handles edit/write!
  if (event.toolName === 'edit' || event.toolName === 'write') {
    ctx.ui.setStatus('psypi-autobackup', '✗ Failed: ' + err.message);
  }
  // For other tools: error is silently swallowed
}
```

**Fix:** Add a fallback that logs errors for all tools without blocking them.
</root_causes>

<quick_reference>
## Quick Reference

```bash
# Clean build
cd gleam/psypi_core && rm -rf build/ && gleam build

# Regenerate extension.js
gleam run -m psypi_cli/extension_generator

# Check compiled exports
grep "^export function" build/dev/javascript/psypi/psypi/issue.mjs

# Check extension.js imports
grep "import.*from.*\.mjs" extension.js | head -30

# Check DB schema
psql -d psypi -c "\d issues"

# Smoke test tools
psypi --print "Run psypi-my-id and psypi-issues"

# Test database connection
psql -d psypi -c "SELECT count(*) FROM issues"
```

### Key Files
| File | Purpose |
|------|---------|
| `extension.js` | Pi extension — tool definitions + event hooks |
| `gleam/psypi_core/src/psypi_cli/extension_generator.gleam` | Gleam code that generates extension.js |
| `gleam/psypi_core/src/psypi_cli/pi_tool_call.gleam` | PiToolCall type definition |
| `build/dev/javascript/psypi/psypi/*.mjs` | Compiled Gleam modules imported by extension.js |
| `build/dev/javascript/prelude.mjs` | CustomType, Ok, Error, PromiseLayer definitions |
</quick_reference>

<success_criteria>
This skill is complete when:
- [ ] The blocked tool executes successfully without returning "blocked"
- [ ] Root cause is identified from the catalog (A-F)
- [ ] The specific fix is applied and verified
- [ ] Build artifacts are clean (rm -rf build/ + gleam build + regenerate)
- [ ] Prevention measures are in place (error handling, unwrapGleamResult, clean build habit)
- [ ] Smoke test confirms all core tools work (my-id, tasks, issues)
</success_criteria>
