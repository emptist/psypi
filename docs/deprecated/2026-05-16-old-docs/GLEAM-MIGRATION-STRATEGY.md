# Gleam Migration Strategy - "The Great Idea"

## Vision
**NO MORE `pnpm build`! Only `gleam build`!** 🚀

## Strategy (Step by Step)

### 1. Save ALL TS Code to PostgreSQL ✅
- **266+ versions** already in `code_versions` table (auto-backup)
- Every TS file is preserved in DB
- Complete history available for reference

### 2. TS → JS Compiled (Permanent Thin Wrapper)
- JS in `dist/` = thin wrapper
- **Same class/function names** as TS
- Interface stays identical
- JS works forever as interface layer

### 3. Use TS from DB → Write Gleam Equivalents
- Query TS code from `code_versions` table
- Example: `SELECT content FROM code_versions WHERE file_path LIKE '%AgentIdentityService%'`
- Write Gleam version with **SAME class/function names**
- Drop-in replacement possible!

### 4. Replace JS with Gleam Gradually
```
BEFORE: extension.ts (1400 lines, TypeScript)
AFTER:  extension.js (thin wrapper) → calls Gleam
FINAL:  Gleam handles everything, JS just wraps
```

## Key Insight 🎯
**Same interface = Same class names + Same function names = Drop-in replacement!**

Example:
```typescript
// TypeScript (in DB)
export class AgentIdentityService {
  static async getResolvedIdentity(permanent: boolean): Promise<AgentIdentity> {
    // ...
  }
}
```

```gleam
// Gleam (new)
pub fn get_resolved_identity(
  permanent: Bool,
  session_id: String,
  // ...
) -> promise.Promise(Result(AgentIdentity, IdentityError)) {
  // ...
}
```

Thin JS wrapper calls Gleam:
```javascript
// extension.js (thin wrapper)
import { get_resolved_identity } from './gleam/agent_identity.mjs';

export class AgentIdentityService {
  static async getResolvedIdentity(permanent) {
    return await get_resolved_identity(permanent, sessionId, ...);
  }
}
```

## Migration Order (Suggested)
1. ✅ AgentIdentityService (already started)
2. DatabaseClient
3. ApiKeyService
4. Other services in `src/kernel/services/`
5. Core modules (EventBus, PluginManager, etc.)
6. Finally: extension.ts → extension.js (thin wrapper)

## Benefits
- ✅ TypeScript code NEVER lost (in DB)
- ✅ Gradual migration (no big bang)
- ✅ Same interface (no breaking changes)
- ✅ PostgreSQL powers the migration!
- ✅ **pnpm build GONE!** Only `gleam build`!

## Current Status (2026-05-06)
- ✅ 266+ TS versions saved in DB
- ✅ Bash protection added (auto-backup before `rm -rf`, `git rm`)
- ✅ Single source of truth established (AgentIdentityService)
- 🔄 Gleam migration started (agent_identity.gleam created)
- ⏳ Next: Complete AgentIdentityService migration, then others

---
**Remember: Save to file first, then implement! Never forget!** 💾
