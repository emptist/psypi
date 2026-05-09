# Gleam Integration Patterns

## Import Pattern: `#gleam/prelude`

Based on `@chouquette/vite` package pattern, we can use Node.js subpath imports for cleaner Gleam FFI imports.

### Configuration in package.json

```json
{
  "imports": {
    "#gleam/prelude": "./gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam.mjs",
    "#gleam/option": "./gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam/option.mjs",
    "#gleam/result": "./gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam/result.mjs",
    "#psypi/task": "./gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/task.mjs"
  }
}
```

### Usage in FFI Files

Instead of:
```javascript
import { Ok, Error } from "../../gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam.mjs";
```

Use:
```javascript
import * as gleam from "#gleam/prelude";

export function divide(x, y) {
  if (y === 0) return gleam.Error();
  return gleam.Ok(x / y);
}
```

### Reference

- Package: `@chouquette/vite` (https://www.npmjs.com/package/@chouquette/vite)
- GitHub: https://github.com/ghivert/gleam-forge
- Pattern: Uses `package.json` `imports` field for subpath resolution

### Benefits

1. **Cleaner imports** - No more long relative paths
2. **Single source of truth** - Path defined once in package.json
3. **No extra dependency** - Just use Node.js built-in subpath imports
4. **Works without Vite** - This is a Node.js feature, not Vite-specific

## Key Learnings

### Agent ID

**Ultimate Truth Function**: `AgentIdentityService.getResolvedIdentity()`

- Does many things, not just returns an ID
- No intermediate layers allowed
- Must call directly, no caching

### Session ID (Pi Session ID)

**Ultimate Truth Function**: `ctx.sessionManager.getSessionId()`

- Access via ExtensionContext in Pi extension
- **`process.env.AGENT_SESSION_ID` is AI HALLUCINATION - does not exist!**

Reference: `docs/pi-session-id-truth.md` (from commit c1674d8)

### Architecture Principle

```
WRONG (old): user → CLI → Command → Service → Kernel → DB (multiple middlemen)
RIGHT (new): user → Pi Agent Tool → Gleam → DB (direct to truth)
```

- Delete CLI commands, convert to Pi Agent Tools
- Delete delegate mode, thinker slot, external thinkers
- Gleam modules receive parameters, do pure business logic
- FFI directly operates on PostgreSQL
