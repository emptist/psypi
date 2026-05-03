# TECH NOTE: My Gleam Integration Findings

**Date**: 2026-05-03  
**Researcher**: Coder AI (S-psypi-psypi)  
**Source Project**: traenupi (`../traenupi`)  
**Purpose**: Document findings from studying traenupi's Gleam integration to fix psypi

---

## 1. Packages Used by traenupi for Gleam in TypeScript Project

### Gleam Dependencies (from `traenupi/gleam/traenupi_core/gleam.toml`):
```toml
[dependencies]
gleam_stdlib = ">= 0.44.0 and < 2.0.0"  # ← ONLY dependency!

[dev-dependencies]
gleeunit = ">= 1.0.0 and < 2.0.0"      # Test framework
```

### Key Finding:
- **NO extra packages** for database, HTTP, or Pi SDK
- **ONLY `gleam_stdlib`** as runtime dependency
- **FFI (Foreign Function Interface)** handles all external calls
- This is a **minimal, clean approach**

### psypi's Current Dependencies:
```toml
# gleam/psypi_core/gleam.toml (same as traenupi)
[dependencies]
gleam_stdlib = ">= 0.44.0 and < 2.0.0"

[dev-dependencies]
gleeunit = ">= 1.0.0 and < 2.0.0"
```

**✅ Good**: psypi's dependencies match traenupi's exactly!

---

## 2. How TypeScript Imports from Gleam Modules

### traenupi's Pattern (from `src/common/gleam-bridge.ts`):

```typescript
// ✅ CORRECT PATTERN: Direct import from build output
import {
  PromptCategory$Action,
  PromptCategory$Verify,
  type PromptCategory$,
  type ActivityStats$,
  type DriverState$,
} from "../../gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core.mjs";

// ✅ Import functions from SPECIFIC modules (not just main module)
import {
  category_to_string,
  category_from_string,
  category_icon,
} from "../../gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/utils.mjs";

import {
  new_activity_stats,
  increment_questions,
  total_activity,
} from "../../gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/state.mjs";

// ✅ Import from gleam_stdlib (available in build output)
import { toList, Ok, Error as GleamError, type Result } 
  from "../../gleam/traenupi_core/build/dev/javascript/gleam_stdlib/gleam.mjs";
```

### Key Import Patterns:

| Pattern | Example | Purpose |
|---------|---------|---------|
| **Type imports** | `type PromptCategory$` | Import Gleam types to TypeScript |
| **Constructor imports** | `PromptCategory$Action` | Import type constructors |
| **Function imports** | `category_to_string` | Import Gleam functions |
| **Stdlib imports** | `Ok, Error from gleam.mjs` | Use Gleam's built-in types |
| **Module-specific imports** | `from ".../state.mjs"` | Import from specific Gleam file |

---

## 3. Gleam Build Output Structure

### traenupi's Build Output:
```
gleam/traenupi_core/build/dev/javascript/
├── traenupi_core/              ← Project directory
│   ├── traenupi_core.mjs       ← Main module
│   ├── traenupi_core.d.mts     ← TypeScript declarations
│   ├── gleam.mjs               ← Rerouted stdlib (for convenience)
│   ├── state.mjs               ← state.gleam output
│   ├── state.d.mts
│   ├── utils.mjs               ← utils.gleam output
│   ├── utils.d.mts
│   └── ... (one .mjs + .d.mts per Gleam file)
├── gleam_stdlib/               ← Copied stdlib
│   ├── gleam/
│   │   ├── result.mjs
│   │   ├── string.mjs
│   │   └── ...
│   └── gleam.mjs
└── gleeunit/                   ← Test framework
    └── ...
```

### psypi's Build Output (CURRENT):
```
gleam/psypi_core/build/dev/javascript/
├── psypi_core/                 ← Project directory
│   ├── psypi_core.mjs          ← Main module
│   ├── psypi_core/             ← SUBDIRECTORY (matches src structure)
│   │   ├── partner.mjs         ← partner.gleam output
│   │   └── partner_ffi.mjs    ← FFI file
│   └── gleam.mjs
├── gleam_stdlib/
└── gleeunit/
```

### Key Finding:
- **Double-nesting is NORMAL** Gleam behavior!
- `src/psypi_core/partner.gleam` → `build/.../psypi_core/psypi_core/partner.mjs`
- This matches traenupi's pattern exactly

---

## 4. Key Issues in psypi's Gleam Part

### ❌ Issue 1: Custom `PResult` Type (Should Use Gleam's `Result`)

**Current (WRONG)**:
```gleam
// partner.gleam
pub type PResult(a, e) {
  POk(a)
  PError(e)
}
```

**Correct (from traenupi)**:
```gleam
// Use gleam_stdlib's Result type
import gleam/result.{type Result, Ok, Error}

pub type SessionError {
  NotFound
  DatabaseError(String)
  PiSDKError(String)
}

pub fn get_or_create(...) -> Result(String, SessionError) {
  // Use Ok(value) and Error(error)
}
```

**Why This Matters**:
- Gleam's `Result` type is standard, well-tested
- Has pattern matching support
- Compatible with `gleam/result` module functions

---

### ❌ Issue 2: No `typescript_declarations = true` in gleam.toml

**Current (WRONG)**:
```toml
# psypi's gleam.toml (if missing)
[javascript]
# Missing typescript_declarations = true
runtime = "nodejs"
```

**Correct (from traenupi)**:
```toml
[javascript]
typescript_declarations = true  # ← Generates .d.ts files!
runtime = "nodejs"
```

**Check**:
```bash
cat /Users/jk/gits/hub/tools_ai/psypi/gleam/psypi_core/gleam.toml | grep -A2 "\[javascript\]"
```

**Why This Matters**:
- Without `.d.ts` files, TypeScript can't type-check Gleam imports
- traenupi generates `.d.mts` files for each `.mjs` file

---

### ❌ Issue 3: FFI Tries to Use Pi SDK Directly

**Current (PROBLEMATIC)**:
```javascript
// partner_ffi.mjs
import { createAgentSession } from "@mariozechner/pi-coding-agent";

export async function create_pi_session(identity) {
  // Calls Pi SDK directly in FFI
  const result = await createAgentSession({...});
}
```

**Correct Pattern (from traenupi)**:
```javascript
// Trae AI's FFI files are MINIMAL:
// fs_ffi.mjs - uses Node.js fs module
// http_ffi.mjs - uses Node.js http module

// FFI should be a THIN bridge, not contain business logic!
```

**Why This Matters**:
- FFI should only bridge JavaScript ↔ Gleam
- Complex logic should stay in Gleam or TypeScript
- Pi SDK should be called from TypeScript, not FFI

---

### ❌ Issue 4: Unnecessary Wrapper Files

**Current (OVER-ENGINEERED)**:
```
src/kernel/services/
├── PermanentPartnerService.ts  # Wrapper
├── partner_wrapper.js         # Another wrapper
└── GleamBridge.ts            # (doesn't exist yet)
```

**Correct (from traenupi)**:
```
src/common/
└── gleam-bridge.ts           # Single bridge file, imports directly
```

**Why This Matters**:
- Multiple wrappers add complexity
- Single bridge file is easier to maintain
- Follows KISS principle

---

### ❌ Issue 5: No Gleam Stdlib Usage

**Current (WRONG)**:
```gleam
// partner.gleam
// No imports from gleam_stdlib!

pub fn get_or_create(...) {
  // Custom implementation
}
```

**Correct (from traenupi)**:
```gleam
import gleam/result.{type Result, Ok, Error}
import gleam/option.{type Option, None, Some}
import gleam/list
import gleam/string

pub fn get_or_create(...) -> Result(String, String) {
  // Use stdlib functions!
}
```

**Why This Matters**:
- Gleam stdlib has many useful functions
- Reimplementing stdlib functions is wasteful
- Stdlib is well-tested and optimized

---

### ❌ Issue 6: Gleam Not Actually Connected to TypeScript

**Current State**:
```
Gleam Layer (ORPHANED)           TypeScript Layer (WORKING)
├── partner.gleam                ├── InnerAgentExecutor.ts
├── partner_ffi.mjs              ├── InterReviewService.ts
└── (compiles ✓)                 └── (uses fake AI ❌)

        ❌ NO CONNECTION ❌
```

**What's Missing**:
1. No `import` from Gleam in any TypeScript file
2. `partner_ffi.mjs` has real Pi SDK, but never called
3. `PermanentPartnerService.ts` created but doesn't import Gleam

---

## 5. Specific Code Examples: Wrong vs Right

### Example 1: Gleam Type Definitions

**❌ WRONG (psypi)**:
```gleam
pub type PResult(a, e) {
  POk(a)
  PError(e)
}

pub type SessionStatus {
  Alive
  Dead
  Pending
}
```

**✅ RIGHT (traenupi)**:
```gleam
import gleam/result.{type Result, Ok, Error}

pub type PromptCategory {
  Action
  Verify
  Reflect
  AntiWeakness
  Checkpoint
  Completion
}

// Uses Gleam's built-in Result type!
pub fn some_function() -> Result(String, String) {
  Ok("value")
}
```

---

### Example 2: FFI Pattern

**❌ WRONG (psypi)**:
```javascript
// partner_ffi.mjs
import { createAgentSession } from "@mariozechner/pi-coding-agent";

export async function create_pi_session(identity) {
  // Complex logic in FFI
  const result = await createAgentSession({...});
  return { type: "POK", value: result.session?.id };
}
```

**✅ RIGHT (traenupi)**:
```javascript
// fs_ffi.mjs
import * as fs from 'fs/promises';

export function read_file(path) {
  return fs.readFile(path, 'utf-8');
}

// Minimal FFI - just bridges to Node.js APIs!
```

---

### Example 3: TypeScript Import Pattern

**❌ WRONG (psypi - doesn't exist)**:
```typescript
// No imports from Gleam anywhere!
// PermanentPartnerService.ts doesn't import Gleam
```

**✅ RIGHT (traenupi)**:
```typescript
// gleam-bridge.ts
export {
  get_or_create,
  type SessionStatus,
  Alive,
  Dead,
  Pending,
} from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core/partner.mjs";

// Then use in other files:
import { get_or_create } from '../common/gleam-bridge.js';
```

---

## 6. Comparison Table: traenupi vs psypi

| Aspect | traenupi | psypi | Status |
|--------|----------|-------|--------|
| **Gleam modules** | 18+ modules | 2 modules | ❌ psypi missing 16 modules |
| **Tests** | 343 tests | 1 test | ❌ psypi needs 342 more tests |
| **TypeScript imports** | ✅ Single bridge file | ❌ None | ❌ Not connected |
| **FFI complexity** | ✅ Minimal | ❌ Complex (Pi SDK) | ❌ Over-engineered |
| **Result type** | ✅ Gleam's Result | ❌ Custom PResult | ❌ Non-standard |
| **Stdlib usage** | ✅ Heavy | ❌ None | ❌ Missing |
| **Build output** | ✅ .d.mts files | ❌ Unknown | ⚠️ Check needed |
| **Documentation** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ psypi better |

---

## 7. Files I Need to Create/Modify (Action Plan)

### Step 1: Fix `gleam.toml` (5 min)
```bash
# Verify typescript_declarations = true
cat gleam/psypi_core/gleam.toml | grep -A2 "\[javascript\]"
```

### Step 2: Rewrite `partner.gleam` (30 min)
- Remove custom `PResult` type
- Import and use `gleam/result`
- Use proper error types
- Add actual FFI calls (not placeholders)

### Step 3: Create `src/common/gleam-bridge.ts` (15 min)
- Single bridge file following traenupi pattern
- Export all needed types and functions
- Use correct import paths

### Step 4: Fix `partner_ffi.mjs` (20 min)
- Remove Pi SDK import (move to TypeScript)
- Make FFI minimal (only bridge to Node.js APIs)
- Or keep Pi SDK but document why it's there

### Step 5: Delete Unnecessary Files (10 min)
- Remove `partner_wrapper.js` (if using gleam-bridge.ts)
- Simplify `PermanentPartnerService.ts`

### Step 6: Build and Test (15 min)
```bash
cd gleam/psypi_core && gleam build
cd /Users/jk/gits/hub/tools_ai/psypi && pnpm build
```

---

## 8. Hidden Gem: `partner_ffi.mjs` Has Working Pi SDK!

### Current State:
```javascript
// partner_ffi.mjs has WORKING Pi SDK code:
import { createAgentSession, initTheme } from "@mariozechner/pi-coding-agent";

export async function create_pi_session(identity) {
  await initTheme();  // ✅ Correct initialization
  const result = await createAgentSession({...});  // ✅ Works!
  return { type: "POK", value: result.session?.id };
}
```

### Problem:
- This file is **NEVER IMPORTED** by any TypeScript file!
- It's a **hidden gem** that's orphaned

### Solution:
- Either: Import it properly from TypeScript
- Or: Move Pi SDK logic to TypeScript, keep FFI minimal

---

## 9. Summary of My Findings

### What traenupi Does Right:
1. ✅ **Single gleam-bridge.ts** file for all imports
2. ✅ **Minimal FFI** - only bridges to Node.js APIs
3. ✅ **Uses Gleam stdlib** extensively
4. ✅ **343 comprehensive tests**
5. ✅ **Correct import paths** (relative to build output)

### What psypi Does Wrong:
1. ❌ **No gleam-bridge.ts** - Gleam not connected to TypeScript
2. ❌ **Custom PResult type** - should use Gleam's Result
3. ❌ **Complex FFI** - Pi SDK in FFI (should be in TS)
4. ❌ **No stdlib usage** - reinventing the wheel
5. ❌ **Only 1 test** - needs 342+ more tests
6. ❌ **Orphaned FFI** - partner_ffi.mjs never imported

### Key Insight:
**psypi doesn't need to write new Gleam code from scratch**. It needs to:
1. **Connect** existing Gleam to TypeScript
2. **Fix** the custom types (use stdlib)
3. **Simplify** the FFI layer
4. **Add** missing utility modules from traenupi

---

## 10. Next Steps (Prioritized)

### 🔴 Critical (Do First):
1. Create `src/common/gleam-bridge.ts` (following traenupi pattern)
2. Verify `typescript_declarations = true` in gleam.toml
3. Build Gleam and verify `.d.mts` files are generated
4. Import Gleam in one TypeScript file and test

### 🟡 Important (Do Next):
1. Rewrite `partner.gleam` to use `gleam/result`
2. Simplify `partner_ffi.mjs` (or document why Pi SDK is there)
3. Delete unnecessary wrapper files
4. Add tests (copy from traenupi as starting point)

### 🟢 Nice to Have (Do Later):
1. Copy missing modules from traenupi (jsonx, validation, schema, etc.)
2. Add comprehensive test suite (343 tests like traenupi)
3. Document the integration pattern for future AI agents

---

**Research Completed**: 2026-05-03  
**Researcher**: Coder AI (S-psypi-psypi)  
**Time Spent**: ~2 hours studying traenupi  
**Key Takeaway**: psypi's documentation is excellent, but implementation is disconnected. Fix the connection, don't rewrite everything!
