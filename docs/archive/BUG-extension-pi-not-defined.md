# BUG: "pi is not defined" when loading extension.js

## Status
- **Discovered**: 2026-05-08
- **Severity**: 🔴 Critical — `psypi` command crashes immediately
- **Fixed**: 2026-05-08

---

## Error

```
Error: Failed to load extension "/Users/jk/gits/hub/tools_ai/psypi/src/agent/extension/extension.js":
  Failed to load extension: pi is not defined
```

Triggered by: `psypi` (which spawns `pi -e src/agent/extension/extension.js`)

---

## Root Cause

**Two bugs combined:**

### Bug 1: `pi.on()` outside factory function

The generator emitted `pi.on('session_start', ...)` at module top-level, **outside** the `export default function(pi)` factory:

```javascript
// ❌ BROKEN — pi is not defined at module scope
let _sessionId = null;
pi.on('session_start', async (_event, ctx) => {  // ← CRASH
  _sessionId = ctx.sessionManager.getSessionId() || '';
});

export default function(pi) {
  pi.registerTool({...});
}
```

`pi` only exists as a parameter inside the factory function.

### Bug 2: `write_extension()` had stale code

The `write_extension()` function in `extension_generator.gleam` had a different (older) text composition order than `generate()`:

```gleam
// generate() — NEW order (correct)
imports <> "\nexport default function(pi) {\n" <> helpers <> tools <> "}\n"

// write_extension() — OLD order (broken)
imports <> "\n" <> helpers <> "\nexport default function(pi) {\n" <> tools <> "}\n"
```

So `generate()` (stdout) produced correct output, but `write_extension()` (file write) produced broken output.

---

## Fix

**File**: `gleam/psypi_core/src/psypi_cli/extension_generator.gleam`

Both `generate()` and `write_extension()` must use the same composition order:

```gleam
let content =
  imports_text(tools)
  <> "\nexport default function(pi) {\n"
  <> helpers_text()
  <> tools_text(tools)
  <> "}\n"
```

This ensures all `pi.*` calls are inside the factory function body.

---

## Additional Issue: Stale Build Cache

After editing Gleam source, `gleam run` sometimes uses stale compiled output from `build/`.

**Symptom**: Generator prints correct output to stdout, but file on disk has old content.

**Fix**: Delete `build/` directory before rebuilding:

```bash
rm -rf build/ && gleam build
```

---

## Verification Steps

1. `cd gleam/psypi_core && rm -rf build/ && gleam build`
2. `gleam run -m psypi_cli/extension_generator`
3. Verify `src/agent/extension/extension.js` has all `pi.*` calls inside the factory
4. `cd /Users/jk/gits/hub/tools_ai/psypi && psypi` — should start without error

---

## Key Files

| File | Role |
|------|------|
| `src/agent/extension/extension.js` | Generated output (build artifact, do NOT hand-edit) |
| `gleam/psypi_core/src/psypi_cli/extension_generator.gleam` | Text composition logic — **both `generate()` and `write_extension()` must match** |
| `gleam/psypi_core/src/psypi_cli/pi_tool_call.gleam` | PiToolCall type definition |
| `bin/psypi.mjs` | Entry point that spawns `pi -e extension.js` |
