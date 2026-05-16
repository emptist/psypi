---
name: gleam-pi-extension-patterns
description: CRITICAL patterns for Gleam migration with Pi ExtensionAPI. Covers the #1 mistake: Pi extension MUST be manual .js/.ts (NOT compiled from .gleam!). Includes correct architecture, ExtensionAPI structure, and common pitfalls. NOTE: For the new PiToolCall-based generator approach, see gleam-pi-tool-generator skill.
---

# Gleam Pi Extension Patterns

**CRITICAL patterns for Gleam migration with Pi ExtensionAPI.**

## The #1 Mistake (LEARNT THE HARD WAY!)

> **Pi extension MUST be `.js` or `.ts` MANUALLY created!**
> 
> **CANNOT compile from `extension.gleam` - Pi won't accept it!**
> 
> Pi has STRICT requirements on file name and content - NOT free to change!

---

## Architecture Rules

### ✅ CORRECT: psypi CLI (No Pi Extension!)
```
bin/psypi.mjs (thin wrapper!)
    ↓ imports
gleam/.../main.mjs (Gleam-compiled!)
    ↓ runs
Gleam logic (CLI commands)
```
**This uses Gleam DIRECTLY!** ✅

### ✅ CORRECT: Pi Extension (MUST be .js/.ts manual!)
```
pi -e extension.js  ← Pi REQUIRES this structure!
    ↓
extension.js (MANUAL creation!)
    ↓ imports
gleam/.../*.mjs (Gleam-compiled modules!)
    ↓ registers
Pi tools via pi.registerTool()
```
**This is the ONLY exception!** Pi extension can't be `.gleam`!

### ❌ WRONG: Don't do this!
```bash
# WRONG! Pi can't load .gleam files directly!
pi -e extension.gleam  # ❌ FAILS!

# WRONG! Can't compile extension.gleam → extension.mjs for Pi!
# Pi expects specific ExtensionAPI structure!
```

---

## Pi Extension Structure (REQUIRED!)

### **File: `extension.js`**

```javascript
// MUST have this EXACT structure!
import { Type } from "@sinclair/typebox";

// Import Gleam-compiled modules
import { some_function } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/module.mjs";

// Pi REQUIRES this export!
export default function (pi) {
  // Set up session hooks
  pi.on("session_start", async (_event, ctx) => {
    // Initialize session
  });

  // Register tools with Pi
  pi.registerTool({
    name: "psypi-tool-name",
    description: "Tool description",
    parameters: {
      param1: { type: "string" },
    },
    handler: async (args) => {
      // Call Gleam function
      const result = await some_function(args.param1);
      return { content: [{ type: "text", text: String(result) }] };
    }
  });

  // More tools...
}
```

---

## Key Patterns

### 1. **Importing Gleam Modules in extension.js**

```javascript
// Relative path from extension.js to Gleam build output
import { function_name } from "../../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/module.mjs";

// For functions that return promises:
const result = await function_name(args);
```

### 2. **Tool Registration Pattern**

```javascript
pi.registerTool({
  name: "psypi-tool-name",
  description: "What it does",
  parameters: {
    // Use TypeBox for parameter validation
    title: { type: "string" },
    priority: { type: "number", optional: true },
  },
  handler: async (args) => {
    try {
      const result = await gleam_function(args);
      return { 
        content: [{ type: "text", text: `Success: ${result}` }] 
      };
    } catch (err) {
      return {
        content: [{ type: "text", text: `Error: ${err.message}` }],
        isError: true
      };
    }
  }
});
```

### 3. **Session Hooks Pattern**

```javascript
// Backup files before edit/write
pi.on("tool_call", async (event) => {
  if (event.toolName === "edit" || event.toolName === "write") {
    const input = event.input;
    const filePath = input?.path;
    if (!filePath) return;
    
    // Import Gleam backup function
    const { save_version } = await import("../../../gleam/.../code_version.mjs");
    // Call Gleam function
    await save_version(filePath, content, agentId, '', 'auto-backup');
  }
});
```

---

## Common Pitfalls

### ❌ **Pitfall 1: Creating `extension.gleam`**
```
Gleam compiles to .mjs, but Pi expects ExtensionAPI structure!
Pi won't recognize Gleam's output as valid extension!
```

### ❌ **Pitfall 2: Wrong export pattern**
```javascript
// WRONG! Pi won't load this!
export function tools() { ... }

// CORRECT! Pi expects this!
export default function (pi) { ... }
```

### ❌ **Pitfall 3: Forgetting `pi.registerTool()`**
```
Tools won't show up in Pi without registration!
Must call pi.registerTool() inside the default function!
```

### ❌ **Pitfall 4: Using `pnpm build` after Gleam migration**
```
pnpm build DESTROYS Gleam wrappers!
ONLY use `gleam build` for Gleam changes!
```

---

## Migration Checklist

When migrating TS to Gleam with Pi extension:

- [ ] **Keep `extension.ts` or `extension.js` as MANUAL file!**
- [ ] **Don't create `extension.gleam`!** (Pi can't load it!)
- [ ] Export `default function (pi) { ... }` in extension file
- [ ] Use `pi.registerTool()` for each tool
- [ ] Use `pi.on()` for session hooks
- [ ] Import Gleam `.mjs` modules with relative paths
- [ ] Test with: `pi -e extension.js --help`
- [ ] Verify tools appear: `pi -e extension.js` then ask "what tools do you have?"

---

## References

- **Pi Extension Examples:** `/Users/jk/Library/pnpm/global/5/.pnpm/@earendil-works+pi-coding-agent@*/node_modules/@earendil-works/pi-coding-agent/examples/extensions/`
- **Note:** Pi repo changed from `@mariozechner/pi-coding-agent` to `@earendil-works/pi-coding-agent` (v0.74.0+)
- **Gleam Build Output:** `gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/*.mjs`
- **AGENTS.md Rule:** See "CRITICAL Architecture Rule" section

---

## New Approach: PiToolCall Generator

The old way was hand-editing `extension.js`. The new way uses Gleam `PiToolCall` types:

- **Skill:** `gleam-pi-tool-generator` — complete guide to the new approach
- **Key file:** `gleam/psypi_core/src/psypi_cli/pi_tool_call.gleam` — PiToolCall type
- **Key file:** `gleam/psypi_core/src/psypi_cli/extension_generator.gleam` — text composer
- **Generated:** `extension.js` — auto-generated, never hand-edit

**For new tools, use the `gleam-pi-tool-generator` skill instead of this one.**

---

**NEVER GIVE UP!** 🧘  
**Saved: 2026-05-07 (After surviving disaster!)** 😊
