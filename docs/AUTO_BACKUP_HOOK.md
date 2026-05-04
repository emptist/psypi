# Auto-Backup Hook Mechanism
**Date**: 2026-05-04  
**Goal**: Prevent "stupid AI" disasters (like commit `119b981`) by auto-saving files BEFORE AI edits them!

## Problem

AI (like me) can make terrible mistakes:
- Commit `119b981` ("AI has gone mad") **deleted ALL Pi tools** from extension.ts!
- No way to recover without git history
- Takes time to rebuild what was lost

## Solution: Auto-Backup via `code_versions` Table

### 1. Database Table Created
```sql
CREATE TABLE code_versions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  file_path TEXT NOT NULL,
  content TEXT NOT NULL,
  version_hash VARCHAR(64) NOT NULL, -- SHA-256 hash
  saved_by VARCHAR(255) NOT NULL,
  saved_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  commit_hash VARCHAR(255),
  reason TEXT, -- Why was this saved?
  project_name VARCHAR(100) DEFAULT 'psypi',
  file_size INTEGER,
  line_count INTEGER,
  CONSTRAINT unique_file_version UNIQUE(file_path, version_hash)
);
```

### 2. Gleam Functions (Core Logic)
**File**: `gleam/psypi_core/src/psypi_cli/code_version.gleam`

```gleam
// Save a file version
pub fn save_version(
  file_path: String, content: String, saved_by: String,
  commit_hash: String, reason: String,
) -> promise.Promise(Result(String, DbError))

// Get version history
pub fn get_versions(
  file_path: String, limit: Int,
) -> promise.Promise(Result(List(dynamic.Dynamic), DbError))

// Restore a specific version
pub fn restore_version(
  version_id: String,
) -> promise.Promise(Result(String, DbError))
```

### 3. Pi Tool (Thin TS Wrapper)
**File**: `src/agent/extension/extension.ts`

```typescript
pi.registerTool({
  name: "psypi-doc-save",
  label: "PsyPI Doc Save",
  description: "Save a file version to code_versions table (auto-backup before AI edits)",
  parameters: Type.Object({
    file_path: Type.String({ description: "File path to save" }),
    content: Type.Optional(Type.String({ description: "File content (leave empty to read from disk)" })),
    reason: Type.Optional(Type.String({ description: "Reason for saving" })),
  }),
  async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
    // Imports compiled Gleam JS directly (no FFI!)
    const { save_version } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/code_version.mjs");
    
    let content = params.content;
    if (!content) {
      const fs = await import('fs');
      content = fs.readFileSync(params.file_path, 'utf-8');
    }
    
    const identity = await AgentIdentityService.getResolvedIdentity();
    const result = await save_version(
      params.file_path, content, identity.id, '', params.reason || 'manual save'
    );
    
    return { content: [{ type: "text", text: `Saved version: ${result}` }], details: { versionId: result } };
  },
});
```

---

## Auto-Backup Hook (Pi `tool_call` Event)

### Approach: Intercept `edit` and `write` Tool Calls

Pi provides `tool_call` event that lets extensions intercept tool calls BEFORE they execute!

```typescript
// src/agent/extension/extension.ts

export default function (pi: ExtensionAPI) {
  // ... other setup ...

  // AUTO-BACKUP HOOK: Save file BEFORE edit/write!
  pi.on("tool_call", async (event, ctx) => {
    // Only intercept file modification tools
    if (event.toolName === "edit" || event.toolName === "write") {
      const filePath = event.input.path || event.input.filePath || event.input.target;
      
      if (!filePath) return; // No path, let it through
      
      try {
        // Check if already backed up recently (avoid duplicates)
        const fs = await import('fs');
        const content = fs.readFileSync(filePath, 'utf-8');
        
        // Import Gleam function
        const { save_version } = await import("../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/code_version.mjs");
        const identity = await AgentIdentityService.getResolvedIdentity();
        
        // Save BEFORE edit
        await save_version(
          filePath, content, identity.id, '', 'auto-backup before edit'
        );
        
        if (VERBOSE) {
          console.log(`[Auto-Backup] Saved ${filePath} before ${event.toolName}`);
        }
      } catch (err) {
        // Log but don't block (file might not exist yet for `write`)
        if (VERBOSE) {
          console.log(`[Auto-Backup] Failed to save ${filePath}: ${err.message}`);
        }
      }
    }
  });
}
```

---

## Usage Patterns

### Manual Backup (AI calls Pi tool directly)
```bash
# AI can manually save before editing
psypi-doc-save --file_path "src/agent/extension/extension.ts" --reason "before refactoring"
```

### Automatic Backup (via `tool_call` hook)
- AI calls `edit` tool → Pi intercepts → auto-saves file → then executes edit
- AI calls `write` tool → Pi intercepts → auto-saves file → then executes write

### Restore After Disaster
```bash
# If AI breaks something (like commit 119b981), restore from database!
psql psypi -c "SELECT * FROM get_code_versions('src/agent/extension/extension.ts', 5);"

# Get the version_id, then restore
psql psypi -c "SELECT restore_code_version('version-uuid-here');"
```

Or via future `psypi-doc-restore` Pi tool!

---

## Benefits

1. ✅ **Prevents disasters** - Files saved BEFORE AI edits them
2. ✅ **Easy recovery** - Restore any previous version from database
3. ✅ **Audit trail** - See who saved what, when, and why
4. ✅ **Deduplication** - Same content hash not saved twice
5. ✅ **Gleam core** - Type-safe, compiled, no FFI needed!

---

## TODO

- [ ] Add `psypi-doc-restore` Pi tool (restore version by ID)
- [ ] Add `psypi-doc-list` Pi tool (list versions for a file)
- [ ] Implement `tool_call` hook for auto-backup (in extension.ts)
- [ ] Add skill: "Always backup before editing" (triggered by `edit`/`write` tools)
- [ ] Consider auto-backup for `git commit` too (save all changed files before commit)

---

## Example: Recovering from "AI has gone mad" (Commit 119b981)

```bash
# 1. Find the last good version of extension.ts
psql psypi -c "
  SELECT id, saved_at, reason 
  FROM get_code_versions('src/agent/extension/extension.ts', 10);
"

# 2. Restore it
psql psypi -c "
  SELECT restore_code_version('uuid-from-above');
"

# 3. Write restored content back to file
# (or create psypi-doc-restore tool that does this automatically!)
```

**Never again lose work to "stupid AI" mistakes!** 🛡️
