# TECH NOTE: Gleam Import Path Patterns (Corrected)

**Date**: 2026-05-03  
**Research Source**: traenupi project (`../traenupi`)  
**Correction**: Previous note had errors about "double-nesting" - this is NORMAL Gleam behavior!

---

## 1. Gleam Build Output Structure (NORMAL)

### Standard Gleam Output Pattern:
```
gleam/project_name/
├── src/
│   └── project_name/          ← Subdirectory (matches project name)
│       ├── module1.gleam
│       └── module2.gleam
└── build/
    └── dev/
        └── javascript/
            ├── project_name/      ← Output directory
            │   ├── project_name/  ← SUBDIRECTORY (matches src structure)
            │   │   ├── module1.mjs
            │   │   └── module2.mjs
            │   ├── project_name.mjs    ← Main module
            │   └── gleam.mjs          ← Rerouted from stdlib
            ├── gleam_stdlib/
            └── gleeunit/
```

### Why Double-Nesting?
- `src/project_name/*.gleam` → `build/.../project_name/project_name/*.mjs`
- This is **correct Gleam behavior**!
- The subdirectory in `src/` creates matching output structure

---

## 2. Correct Import Paths (from TypeScript)

### For traenupi:
```typescript
// From: src/common/gleam-bridge.ts
// To: gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/state.mjs

import {
  new_activity_stats,
  increment_questions,
} from "../../gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/state.mjs";
//    ^^^^^^-- Relative from TS file to gleam build output
```

### For psypi (CORRECTED):
```typescript
// From: src/kernel/services/partner_wrapper.ts (or gleam-bridge.ts)
// To: gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core/partner.mjs

import { get_or_create } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core/partner.mjs";
//    ^^^^^^-- Relative from TS file to gleam build output
```

---

## 3. Key Issue Found: partner.gleam Location

### Current (PROBLEMATIC):
```
gleam/psypi_core/src/psypi_core/partner.gleam
```
Outputs to:
```
build/dev/javascript/psypi_core/psypi_core/partner.mjs
```

### Problem:
- `partner.gleam` is nested inside `psypi_core/psypi_core/`
- This creates confusing double-nesting
- Should probably be at `src/partner.gleam` for simpler imports

### Suggested Restructure:
```
gleam/psypi_core/src/
├── psypi_core.gleam          ← Main module (types, etc.)
├── partner.gleam             ← Move here (not nested)
├── utils.gleam
└── ... other modules
```

Then imports become:
```typescript
import { get_or_create } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/partner.mjs";
// No double-nesting!
```

---

## 4. Comparison: traenupi vs psypi

### traenupi structure:
```
src/traenupi_core/
├── traenupi_core.gleam       ← Main module
├── state.gleam
├── utils.gleam
└── ... (all in same directory)
```

**Import**:
```typescript
import { ... } from "../../gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/state.mjs";
```

### psypi structure (CURRENT):
```
src/psypi_core/
├── psypi_core.gleam
└── psypi_core/
    └── partner.gleam         ← Nested unnecessarily?
```

**Import** (more complex):
```typescript
import { ... } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core/partner.mjs";
```

---

## 5. Recommended Fix

### Option A: Restructure Gleam Source (RECOMMENDED)
```bash
# Move partner.gleam up one level
cd gleam/psypi_core/src
mv psypi_core/partner.gleam ./
mv psypi_core/partner_ffi.mjs ./

# Rebuild
gleam build
```

Now imports are simpler:
```typescript
import { get_or_create } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/partner.mjs";
```

### Option B: Keep Structure, Fix Import Paths
Just use the correct nested path in TypeScript:
```typescript
import { get_or_create } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core/partner.mjs";
```

---

## 6. Other Issues Found

### ❌ Issue: Custom PResult Type
**Current**: Custom `PResult(a, e)` type in partner.gleam  
**Fix**: Use `gleam/result.{Result, Ok, Error}`

### ❌ Issue: Missing gleam_stdlib Imports
**Current**: No imports from gleam_stdlib  
**Fix**: Import and use stdlib types/functions

### ❌ Issue: FFI Tries to Use Pi SDK
**Current**: `partner_ffi.mjs` imports `@mariozechner/pi-coding-agent`  
**Fix**: FFI should be minimal, use Node.js APIs only

### ❌ Issue: Unnecessary Wrapper Files
**Current**: `partner_wrapper.js`, `PermanentPartnerService.ts`  
**Fix**: Create single `gleam-bridge.ts` like traenupi

---

## 7. Action Plan

1. **Fix partner.gleam location** (restructure or fix imports)
2. **Rewrite to use gleam_stdlib** (Result, Option, etc.)
3. **Create single gleam-bridge.ts** file
4. **Fix FFI to be minimal** (no Pi SDK in FFI)
5. **Test with `pnpm build`**

---

**Correction**: Double-nesting is NORMAL Gleam behavior, not a bug!  
**Real Issue**: Import paths need to match actual build output structure.
