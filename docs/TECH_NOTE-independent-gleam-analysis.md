# TECH NOTE: Independent Gleam Analysis for psypi

**Date**: 2026-05-03  
**Analyst**: Coder AI (S-psypi-psypi)  
**Sources Studied**: 
- traenupi project (`../traenupi`) - reference implementation
- psypi's own codebase
- Gleam official documentation
**Purpose**: My own conclusions on what needs to be fixed in psypi's Gleam integration

---

## 1. My Own Assessment: What's Actually Wrong?

After studying both projects carefully, here's **my independent assessment**:

### ✅ What's Actually Working Fine:

1. **Gleam build system** - `gleam build` works perfectly
2. **gleam.toml configuration** - matches traenupi exactly (only gleam_stdlib dependency)
3. **Build output structure** - double-nesting is NORMAL Gleam behavior
4. **partner_ffi.mjs has real Pi SDK code** - this is actually valuable!
5. **Documentation is excellent** - plans are detailed and accurate

### ❌ What's Actually Broken (My Opinion):

1. **Gleam modules are ORPHANED** - No TypeScript file imports them
2. **Custom `PResult` type** - Should use Gleam's built-in `Result` (my preference)
3. **No `gleam-bridge.ts` file** - traenupi pattern makes sense, we should adopt it
4. **partner.gleam has placeholder implementations** - 5 TODO comments = incomplete
5. **Over-engineered wrappers** - `partner_wrapper.js` + `PermanentPartnerService.ts` = unnecessary complexity

---

## 2. My Comparison: traenupi vs psypi (Independent View)

| Aspect | traenupi | psypi | My Conclusion |
|--------|----------|-------|---------------|
| **Gleam modules** | 18 modules | 2 modules | ⚠️ psypi needs more modules, BUT maybe not all 18 |
| **Tests** | 343 tests | 1 test | ❌ psypi definitely needs more tests |
| **TypeScript bridge** | ✅ gleam-bridge.ts | ❌ None | ✅ traenupi's pattern is cleaner |
| **FFI approach** | Minimal (Node.js APIs) | Complex (Pi SDK) | ⚠️ Pi SDK in FFI works, but is unconventional |
| **Result type** | Gleam's Result | Custom PResult | ❌ psypi should use Gleam's Result |
| **Stdlib usage** | Heavy | None | ❌ psypi should use gleam_stdlib |

### My Take:
- traenupi is a **good reference**, but psypi doesn't need to copy ALL 18 modules
- psypi should **selectively adopt** what it needs (jsonx, validation, resultx maybe)
- The **core issue** is that Gleam and TypeScript aren't connected, not that psypi is "missing" modules

---

## 3. My Findings: How TypeScript Imports from Gleam (The Correct Way)

After studying traenupi, here's what I understand:

### The Pattern:
```typescript
// In src/common/gleam-bridge.ts (following traenupi's pattern)

// Import from Gleam build output (relative path from TS file)
import { some_function } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core/partner.mjs";

// Import types (if typescript_declarations = true)
import type { SomeType } from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core/partner.d.mts";
```

### Key Points (My Understanding):
1. **Relative paths** - from TS file to `build/dev/javascript/` directory
2. **Double-nesting is normal** - `psypi_core/psypi_core/*.mjs` matches `src/psypi_core/*.gleam`
3. **One bridge file** - cleaner than multiple wrappers
4. **Direct imports** - no need for intermediate wrapper files

### What I'll Do:
Create `src/common/gleam-bridge.ts` following this pattern.

---

## 4. My Findings: Packages Used by traenupi

### traenupi's `gleam.toml`:
```toml
[dependencies]
gleam_stdlib = ">= 0.44.0 and < 2.0.0"  # ONLY runtime dependency

[dev-dependencies]
gleeunit = ">= 1.0.0 and < 2.0.0"      # Test framework
```

### My Conclusion:
- ✅ psypi's dependencies are **IDENTICAL** to traenupi's - this is correct!
- ❌ No need for extra packages (database, HTTP, etc.) - use FFI for those
- ✅ Minimal dependency approach is **good** - less to maintain

---

## 5. My Assessment: Issues in psypi's Gleam Part

### Issue 1: Custom `PResult` Type (My Opinion: Should Fix)

**Current**:
```gleam
pub type PResult(a, e) {
  POk(a)
  PError(e)
}
```

**My Recommendation**:
```gleam
import gleam/result.{type Result, Ok, Error}

// Use Gleam's built-in Result type
// It's standard, well-tested, and has pattern matching support
```

**Why I Think This Matters**:
- Gleam's `Result` is the standard way
- Custom types = maintenance burden
- Less code to maintain

---

### Issue 2: No TypeScript Imports (My Opinion: CRITICAL)

**Current State**:
- `partner.gleam` compiles ✅
- `partner_ffi.mjs` has real Pi SDK ✅
- **BUT no TypeScript file imports these** ❌

**My Recommendation**:
Create `src/common/gleam-bridge.ts`:
```typescript
export {
  get_or_create,
  heartbeat,
  terminate,
} from "../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core/partner.mjs";
```

**Why I Think This Matters**:
- Gleam code is **useless** if TypeScript can't call it
- This is the #1 blocker for the "permanent partner" feature

---

### Issue 3: Over-Engineered Wrappers (My Opinion: Simplify)

**Current**:
```
src/kernel/services/
├── PermanentPartnerService.ts  # Wrapper
├── partner_wrapper.js         # Another wrapper
└── (no gleam-bridge.ts)
```

**My Recommendation**:
```
src/common/
└── gleam-bridge.ts           # Single bridge file (like traenupi)
```

**Why I Think This Matters**:
- Two wrappers = more code to maintain
- traenupi's single bridge file is simpler
- KISS principle

---

### Issue 4: FFI Complexity (My Opinion: Debatable)

**Current**:
```javascript
// partner_ffi.mjs imports Pi SDK directly
import { createAgentSession } from "@mariozechner/pi-coding-agent";
```

**My Thoughts**:
- This **works** (I verified it!)
- It's **unconventional** (traenupi uses minimal FFI)
- BUT: It's **already working**, so maybe keep it?

**My Recommendation**:
- **Option A**: Keep it (it works, why rewrite?)
- **Option B**: Move Pi SDK to TypeScript (cleaner architecture)

I'm leaning toward **Option A** (keep it) because:
1. It already works (verified with `test-pi-sdk.mjs`)
2. Rewriting takes time
3. FFI is supposed to bridge JavaScript ↔ Gleam, and Pi SDK is JavaScript

---

## 6. My Action Plan (Independent Decision)

Based on my own analysis, here's what I think we should do:

### Phase 1: Connect Gleam to TypeScript (Priority: CRITICAL)

1. **Create `src/common/gleam-bridge.ts`** (following traenupi pattern)
2. **Update `tsconfig.json`** to exclude gleam build from compilation
3. **Test import** - verify TypeScript can import Gleam functions
4. **Time estimate**: 30 minutes

### Phase 2: Fix partner.gleam (Priority: HIGH)

1. **Replace `PResult` with Gleam's `Result`** (my preference)
2. **Remove placeholder implementations** - add real FFI calls
3. **Add error types** (SessionError with NotFound, DatabaseError, etc.)
4. **Time estimate**: 1 hour

### Phase 3: Simplify Architecture (Priority: MEDIUM)

1. **Delete unnecessary files** - `partner_wrapper.js`, maybe `PermanentPartnerService.ts`
2. **Use `gleam-bridge.ts`** as single entry point
3. **Time estimate**: 30 minutes

### Phase 4: Add Tests (Priority: MEDIUM)

1. **Add tests for psypi_core.gleam** (SessionID, AgentID)
2. **Add tests for partner.gleam** (get_or_create, heartbeat)
3. **Copy test patterns from traenupi** (but don't need 343 tests immediately)
4. **Time estimate**: 1-2 hours

### What I WON'T Do (My Decision):

❌ **Won't copy all 18 modules from traenupi** - psypi doesn't need all of them yet  
❌ **Won't rewrite partner_ffi.mjs** - it works, keep it simple  
❌ **Won't delete partner_ffi.mjs** - it has valuable Pi SDK integration  

---

## 7. My Key Insights (Original Thinking)

### Insight 1: The Real Problem is Disconnection
- psypi's Gleam code **compiles fine**
- psypi's Gleam code **has working Pi SDK in FFI**
- The problem is **TypeScript can't call Gleam**
- **Fix**: Create the bridge file, not rewrite everything

### Insight 2: Trae's Review is Helpful BUT...
- Trae says "delete & redo" (20-30 hours)
- I think "connect & fix" (3-4 hours)
- **My reasoning**: The FFI already works, just connect it!

### Insight 3: psypi Doesn't Need Everything traenupi Has
- traenupi has 18 modules (jsonx, validation, schema, etc.)
- psypi currently needs: partner.gleam + maybe jsonx + validation
- **My approach**: Add modules as needed, not all at once

---

## 8. My Verification Steps (How I'll Test)

After making changes, I'll verify with:

```bash
# 1. Gleam still builds
cd gleam/psypi_core && gleam build

# 2. TypeScript compiles with new bridge file
cd /Users/jk/gits/hub/tools_ai/psypi && pnpm build

# 3. Test import works
node -e "
import('./dist/common/gleam-bridge.js').then(m => {
  console.log('✅ Import works!');
  console.log('  Functions:', Object.keys(m));
});
"

# 4. Test Pi SDK still works (via FFI)
# (Already verified with test-pi-sdk.mjs)
```

---

## 9. My Summary: What I've Learned

### From Studying traenupi:
✅ **Good patterns**: Single gleam-bridge.ts, minimal FFI, use stdlib  
✅ **Reference point**: 343 tests, 18 modules (but psypi doesn't need all)  
✅ **Import paths**: Relative paths to `build/dev/javascript/`  

### From Studying psypi:
✅ **Documentation is excellent** - plans are detailed  
✅ **partner_ffi.mjs works** - verified with test-pi-sdk.mjs  
❌ **Gleam is orphaned** - no TypeScript imports  
❌ **Custom PResult** - should use Gleam's Result  

### My Independent Conclusion:
**psypi doesn't need a rewrite. It needs a connection.**

The Gleam code is there, it compiles, and the FFI works. Just create the bridge file and connect everything!

---

## 10. Next Steps (My Decision)

I will:

1. ✅ **Create `src/common/gleam-bridge.ts`** (following traenupi pattern)
2. ✅ **Fix `partner.gleam`** to use Gleam's Result type
3. ✅ **Test the connection** between TypeScript ↔ Gleam
4. ✅ **Keep `partner_ffi.mjs`** (it works, why rewrite?)
5. ✅ **Delete unnecessary wrappers** (simplify architecture)

I will NOT:
❌ Copy all 18 modules from traenupi (unnecessary)  
❌ Rewrite working FFI code (waste of time)  
❌ Delete and redo everything (Trae's suggestion - too extreme)  

---

**Analysis Completed**: 2026-05-03  
**Analyst**: Coder AI (S-psypi-psypi)  
**My Conclusion**: Connect, don't rewrite!  
**Time Estimate**: 3-4 hours to full integration (not 20-30 hours)
