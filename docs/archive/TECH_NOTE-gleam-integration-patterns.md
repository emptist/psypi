# TECH NOTE: Gleam Integration Patterns

**Date**: 2026-05-03  
**Research Source**: traenupi project (`../traenupi`)  
**Purpose**: Document correct Gleam + TypeScript integration patterns for psypi

---

## 1. Package Dependencies in Gleam Project

### traenupi's `gleam.toml`:
```toml
name = "traenupi_core"
version = "1.0.0"
target = "javascript"

[javascript]
typescript_declarations = true  # ← KEY: Generates .d.ts files!
runtime = "nodejs"

[dependencies]
gleam_stdlib = ">= 0.44.0 and < 2.0.0"  # ← ONLY dependency!

[dev-dependencies]
gleeunit = ">= 1.0.0 and < 2.0.0"
```

### Key Findings:
- **Only `gleam_stdlib` as dependency** - no extra packages needed!
- **`typescript_declarations = true`** - Critical! Generates `.d.ts` type declarations
- **`runtime = "nodejs"`** - Targets Node.js runtime
- **No external database/HTTP packages** - FFI handles external calls

---

## 2. How TypeScript Imports from Gleam Modules

### Import Pattern (from `traenupi/src/common/gleam-bridge.ts`):

```typescript
// Import TYPES from Gleam module
import {
  PromptCategory$Action,
  PromptCategory$Verify,
  type PromptCategory$,
  type ActivityStats$,
  type DriverState$,
} from "../../gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core.mjs";

// Import FUNCTIONS from specific Gleam modules
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

// Import from gleam_stdlib
import { toList, Ok, Error as GleamError, type Result } 
  from "../../gleam/traenupi_core/build/dev/javascript/gleam_stdlib/gleam.mjs";
```

### Key Patterns:
| Pattern | Description |
|---------|-------------|
| **Direct `.mjs` imports** | TypeScript imports directly from `build/dev/javascript/` |
| **Module splitting** | Each Gleam file becomes separate `.mjs` file |
| **Type exports** | Use `type` keyword for Gleam types |
| **Constructor exports** | `TypeName$Constructor` pattern for type constructors |
| **Function exports** | Snake_case functions exported directly |

---

## 3. Gleam Module Structure

### traenupi's Gleam files (`gleam/traenupi_core/src/traenupi_core/`):
```
├── traenupi_core.gleam      # Main module, types
├── utils.gleam              # Utility functions
├── state.gleam              # State management
├── cli.gleam                # CLI parsing
├── validation.gleam         # Validation functions
├── json.gleam               # JSON encoding/decoding
├── jsonx.gleam              # Extended JSON utils
├── http.gleam               # HTTP types
├── cache.gleam              # Caching
├── schema.gleam             # Schema definitions
├── async.gleam              # Async utilities
├── datetime.gleam           # Date/time
├── resultx.gleam            # Result extensions
├── str.gleam                # String utilities
├── collection.gleam         # Collection utilities
├── property.gleam           # Property types
├── logger.gleam             # Logging
├── fs.gleam                 # File system
└── json_path.gleam          # JSON path queries
```

### Build Output (`build/dev/javascript/traenupi_core/`):
```
├── traenupi_core.mjs        # Main module
├── traenupi_core.d.mts       # TypeScript declarations
├── traenupi_core/
│   ├── utils.mjs
│   ├── utils.d.mts
│   ├── state.mjs
│   ├── state.d.mts
│   ├── cli.mjs
│   ├── cli.d.mts
│   └── ... (one .mjs + .d.mts per Gleam file)
└── gleam.mjs                # From gleam_stdlib
```

---

## 4. Key Issues in psypi's Current Gleam Implementation

### ❌ Issue 1: Wrong Import Path in TypeScript
**Current (WRONG)**:
```typescript
// src/kernel/services/partner_wrapper.js
const { get_or_create } = await import('/absolute/path/...');
```

**Correct (from traenupi)**:
```typescript
// Should import from build output, relative to TS file
import { get_or_create } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/partner.mjs";
```

---

### ❌ Issue 2: Custom PResult Type (Unnecessary)
**Current (WRONG)**:
```gleam
// Custom Result type in partner.gleam
type PResult(a, e) {
  POK(value: a)
  PERROR(error: e)
}
```

**Correct (from traenupi)**:
```gleam
// Use gleam_stdlib's Result type
import gleam/result.{type Result, Ok, Error}

pub fn get_or_create(id: String, prefix: String) -> Result(String, String) {
  // ... use Ok(value) and Error(error)
}
```

---

### ❌ Issue 3: FFI Implementation Pattern
**Current (WRONG)**:
```javascript
// partner_ffi.mjs - trying to import Pi SDK directly
import { createAgentSession } from "@mariozechner/pi-coding-agent";
```

**Correct Pattern (from traenupi)**:
- FFI should be **minimal** - only bridge to JS runtime
- Complex logic stays in Gleam
- Database calls should use **Node.js pg** or **HTTP calls** in FFI, not Pi SDK

---

### ❌ Issue 4: Missing `typescript_declarations = true`
**Current (WRONG)**:
```toml
# psypi's gleam.toml (if exists)
# Missing typescript_declarations setting
```

**Correct (from traenupi)**:
```toml
[javascript]
typescript_declarations = true  # ← Generate .d.ts files!
runtime = "nodejs"
```

---

### ❌ Issue 5: No Gleam Stdlib Usage
**Current (WRONG)**:
```gleam
// partner.gleam - custom types, no stdlib usage
```

**Correct (from traenupi)**:
```gleam
import gleam/result.{type Result, Ok, Error}
import gleam/option.{type Option, None, Some}
import gleam/list
import gleam/string

// Use stdlib types and functions!
```

---

### ❌ Issue 6: Unnecessary Wrapper Files
**Current (WRONG)**:
```
src/kernel/services/
├── PermanentPartnerService.ts  # Wrapper
└── partner_wrapper.js         # Another wrapper
```

**Correct (from traenupi)**:
```
src/common/
└── gleam-bridge.ts  # Single bridge file, imports directly from Gleam build output
```

---

## 5. Correct Implementation Plan for psypi

### Step 1: Fix `gleam.toml`
```toml
name = "psypi_core"
version = "0.1.0"
target = "javascript"

[javascript]
typescript_declarations = true
runtime = "nodejs"

[dependencies]
gleam_stdlib = ">= 0.44.0 and < 2.0.0"
```

### Step 2: Rewrite `partner.gleam` with Stdlib
```gleam
import gleam/result.{type Result, Ok, Error}
import gleam/option.{type Option, None, Some}

pub type SessionState {
  Active(id: String, identity: String)
  Inactive
  Error(reason: String)
}

pub fn get_or_create(identity: String) -> Result(String, String) {
  // Use gleam_stdlib Result type!
  case check_existing(identity) {
    Ok(session_id) -> Ok(session_id)
    Error(_) -> create_new(identity)
  }
}
```

### Step 3: Create Single Bridge File
```typescript
// src/common/gleam-bridge.ts
export {
  get_or_create,
  type SessionState,
  Active,
  Inactive,
  Error as SessionError,
} from "../../gleam/psypi_core/build/dev/javascript/psypi_core/partner.mjs";
```

### Step 4: Use Bridge in Services
```typescript
// src/kernel/services/PermanentPartnerService.ts
import { get_or_create } from "../common/gleam-bridge.js";

export class PermanentPartnerService {
  async createSession(identity: string) {
    const result = get_or_create(identity);
    // Handle Result type
  }
}
```

---

## 6. Summary of Critical Fixes Needed

| Issue | Current State | Fix Needed |
|-------|---------------|------------|
| **Import paths** | Absolute paths in wrapper | Relative paths to `build/dev/javascript/` |
| **Result type** | Custom `PResult` | Use `gleam/result.Result` |
| **Type declarations** | Missing | Add `typescript_declarations = true` |
| **FFI pattern** | Trying to use Pi SDK | Minimal FFI, use Node.js pg/HTTP |
| **Wrapper files** | Multiple unnecessary | Single `gleam-bridge.ts` |
| **Stdlib usage** | None | Import and use `gleam_stdlib` |

---

## 7. Testing the Correct Pattern

### Build Gleam:
```bash
cd gleam/psypi_core
gleam build  # Generates .mjs and .d.mts files
```

### Check Output:
```bash
ls -la build/dev/javascript/psypi_core/
# Should see:
# - psypi_core.mjs
# - psypi_core.d.mts
# - partner.mjs
# - partner.d.mts
```

### Import in TypeScript:
```typescript
// Use relative path from TS file to Gleam build output
import { get_or_create } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/partner.mjs";
```

---

**Next Steps**:
1. Fix `gleam.toml` with correct settings
2. Rewrite `partner.gleam` to use `gleam_stdlib`
3. Create `src/common/gleam-bridge.ts` (single bridge file)
4. Delete unnecessary wrapper files
5. Test with `pnpm build`

---

**Research Completed**: 2026-05-03  
**Researcher**: Coder AI (S-psypi-psypi)  
**Source Project**: traenupi (`../traenupi`)
