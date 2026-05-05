# Gleam Migration Plan - 2026-05-05 (Valid 12 Hours)

**Created**: 2026-05-05 08:31  
**Valid Until**: 2026-05-05 20:31  
**Philosophy**: Small + Pure = Resilience (Gleam modules < 100 lines!)  
**Strategy**: Find LONG TS files → Extract to SMALL Gleam modules → TS becomes thin wrapper

---

## 🎯 Current Status

### ✅ Completed
- **Correctly named** `inter_review.gleam` (replaces incorrectly named `review.gleam`)
- **38 Gleam modules** in `gleam/psypi_core/src/psypi_cli/`
- **CLI commands migrated**: task, issue, skill, meeting, broadcast, context, areflect
- **Core modules**: db, identity, monitor, validation, etc.

### 📊 Code Stats
- **Gleam**: ~10,000 lines (38 modules in psypi_cli + psypi_core)
- **TypeScript**: 27,580 lines (target: reduce to ~10,000)
- **Current Ratio**: 1:2.7 (Gleam:TS) - Goal: 1:1

---

## 🚀 Migration Priority (Next 12 Hours)

### Priority 1: `InterReviewService.ts` (1203 lines → ~100 lines Gleam)

**Why**: 
- Largest service file
- Contains inter-review logic that should be in `inter_review.gleam`
- Has 80% bloat (fallback logic, event emitters, complex state)

**Action**:
1. ✅ Created `inter_review.gleam` (basic structure)
2. Extract core logic to Gleam:
   - `request_review()` → Gleam
   - `get_review()` → Gleam  
   - `list_reviews()` → Gleam
   - `submit_review_response()` → Gleam
3. Keep DB calls in TS (PostgreSQL-specific)
4. Delete TS fallback logic (old AI code, unused features)

**Estimated Gleam Lines**: ~100 lines  
**TS Reduction**: 1203 → ~300 lines (thin wrapper)

---

### Priority 2: `DatabaseSkillLoader.ts` (913 lines → ~150 lines Gleam)

**Why**:
- Complex skill loading logic
- Pure functions: search, filter, sort
- Perfect for Gleam's pattern matching

**Extract to Gleam**:
- `load_skills()` → `skill_loader.gleam`
- `search_skills()` → Gleam
- `validate_skill()` → Gleam

**Estimated Gleam Lines**: ~150 lines  
**TS Reduction**: 913 → ~300 lines

---

### Priority 3: `cli.ts` (1358 lines) - DEPRECATE!

**Why**:
- DUPLICATED by `gleam/psypi_core/src/psypi_cli/main.gleam`
- Old CLI entry point (replaced by Gleam)
- Should be deleted after verification

**Action**:
1. Verify `main.gleam` handles ALL commands from `cli.ts`
2. `mv cli.ts cli.ts.deprecated` (correct deprecation!)
3. Update any imports/references

**Result**: Delete 1358 lines!

---

### Priority 4: `extension.ts` (1357 lines → ~200 lines Gleam)

**Why**:
- Extension loading/handling logic
- Can extract: validation, metadata parsing, capability checking

**Extract to Gleam**:
- `validate_extension()` → `extension.gleam`
- `parse_manifest()` → Gleam
- `check_capabilities()` → Gleam

**Estimated Gleam Lines**: ~200 lines  
**TS Reduction**: 1357 → ~500 lines

---

## 📝 Gleam Module Structure (Small & Pure!)

### New Modules to Create (Today)

```
gleam/psypi_core/src/psypi_cli/
├── inter_review.gleam          ✅ Created (basic)
├── skill_loader.gleam          📝 TODO (~150 lines)
├── extension.gleam             📝 TODO (~200 lines)
├── review_validator.gleam      📝 TODO (~80 lines)
└── [command]_helpers.gleam     📝 As needed (~50 lines each)
```

**Rule**: Each module < 100 lines (except complex ones → 150-200 max)!

---

## 🛠️ Process (Per Module)

### Step 1: Analyze TS Code
```bash
# Find the CORE logic (ignore boilerplate)
rg "core logic|essential|important" Service.ts
# Look at function signatures - what does it ACTUALLY do?
```

### Step 2: Extract Pure Logic to Gleam
**TS Bloat Example**:
```typescript
// 50 lines of class boilerplate
export class InterReviewService extends EventEmitter {
  private db: DatabaseClient;
  constructor(db: DatabaseClient) {
    super();
    this.db = db;
  }
  // Actual logic is only 10 lines!
}
```

**Gleam Equivalent**:
```gleam
// inter_review.gleam - ~100 lines total!
pub fn request_review(db, task_id, commit_hash) -> Result(String, Error) {
  // Pure function, no boilerplate
  db.query("SELECT request_inter_review(...)")
}
```

### Step 3: Build & Test
```bash
cd gleam/psypi_core
gleam build  # Gleam errors are CRYSTAL clear!
```

### Step 4: Update TS to Use Gleam
```typescript
// Thin wrapper in TS
import { request_review } from '../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/inter_review.mjs';

export class InterReviewService {
  async requestReview(...) {
    return request_review(db, taskId, commitHash);
  }
}
```

### Step 5: Delete TS Bloat
```bash
# Once Gleam works, DELETE the TS file (or parts of it)
# Keep only the thin wrapper (~200 lines max)
```

---

## 🎯 Success Metrics (Next 12 Hours)

### Code Reduction
- **Target**: 3000+ lines TS deleted
- **New Gleam**: ~500 lines (5-6 new modules)
- **Net Reduction**: ~2500 lines

### Quality
- ✅ Every new Gleam module < 100-200 lines
- ✅ TS files become thin wrappers (< 300 lines each)
- ✅ No duplicated functionality (TS vs Gleam)
- ✅ `cli.ts` deprecated (1358 lines gone!)

### Inter-Review
- ✅ `inter_review.gleam` correctly named (not `review.gleam`!)
- ✅ Integrates with existing TS `InterReviewService`
- ✅ No FFI nonsense (unless absolutely necessary)

---

## 🗑️ DELETE Immediately (Today!)

### Files to Deprecate
| File | Lines | Action |
|------|-------|--------|
| `src/cli.ts` | 1358 | `mv cli.ts cli.ts.deprecated` |
| `src/deprecated/*` | ~1104 | Already deprecated, delete? |

### Code Patterns to Delete
- Event emitters for simple request/response
- Complex class hierarchies for stateless operations
- Fallback logic for "old AI" (removed features)
- Duplicate CLI definitions (`cli.ts` vs `main.gleam`)

---

## 📚 Gleam Learning (From `../refers/gleam`)

### Key Concepts Learned
1. **Small modules**: Gleam files are typically < 100 lines
2. **Pure functions**: No hidden state, easy to test
3. **Pattern matching**: Perfect for validation/parsing
4. **Type safety**: Compiler catches errors early
5. **FFI**: Use JavaScript interop ONLY when necessary

### Reference Examples
- `../refers/gleam/compiler-core/src/` - Large Gleam/Rust codebase
- Study how they structure modules
- Learn pattern matching techniques

---

## 🚦 Next Actions (This Hour)

1. ✅ Created `inter_review.gleam` (correctly named!)
2. [ ] Test `gleam build` with new `inter_review.gleam`
3. [ ] Extract `InterReviewService.ts` core logic to Gleam
4. [ ] Create `skill_loader.gleam` from `DatabaseSkillLoader.ts`
5. [ ] Deprecate `cli.ts` (replaced by `main.gleam`)
6. [ ] Update this plan as progress is made

---

## 🎉 Fun Facts

> "Small modules (< 100 lines!) survive ANYTHING!"  
> "Touch old TS = rewrite in Gleam"  
> "Debugging Gleam is SO EASY vs TypeScript!"  
> "Most TS lines are bloat—extract the gold, discard the rest!"  
> "Review.gleam was INCORRECT naming - use inter_review.gleam!"

**The goal isn't to rewrite everything. It's to let Gleam's simplicity naturally replace TS bloat.**

---

**Status**: ACTIVE (expires 2026-05-05 20:31)  
**Next Review**: Update progress by 14:00  
**Have fun!** 🚀
