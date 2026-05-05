# Gleam Migration Plan - 2026-05-05 (Valid 12 Hours)

**Created**: 2026-05-05 08:31  
**Updated**: 2026-05-05 08:45 (Added learning from ../refers/gleam)  
**Valid Until**: 2026-05-05 20:31  
**Philosophy**: Small + Pure = Resilience (Gleam modules < 100 lines!)  
**Strategy**: Find LONG TS files → Extract to SMALL Gleam modules → TS becomes thin wrapper

---

## 📚 Learning from ../refers/gleam (Gleam Reference)

### Completed Learning Tasks
1. ✅ **Studied Gleam test files** (`test/language/test/language/*.gleam`)
   - Learned: Pattern matching with guards (`if` in `case`)
   - Learned: Recursive functions for list processing
   - Learned: Test structure (public functions with `_test()` suffix)

2. ✅ **Studied benchmark code** (`benchmark/list/src/*.gleam`)
   - Learned: Function definitions with `fn name() { ... }`
   - Learned: Type annotations (optional but helpful)
   - Learned: `case` expressions with catch-all `_` patterns

3. ✅ **Read runtime errors docs** (`docs/runtime-errors.md`)
   - Learned: Structured error handling in Gleam
   - Learned: `todo`, `panic`, `let assert` patterns
   - Learned: Custom error types with fields

4. ✅ **Examined Gleam compiler structure** (`compiler-core/src/`)
   - Learned: Rust implementation (not Gleam), but understand module organization
   - File sizes: 50-500 lines (confirms "small modules" philosophy)

### Key Gleam Patterns Learned
```gleam
// Pattern matching with guards
case value {
  x if x > 0 -> "positive"
  _ -> "non-positive"
}

// Recursive list processing
fn count_ones(list: List(Int), count: Int) -> Int {
  case list {
    [] -> count
    [1, ..tail] -> count_ones(tail, count + 1)
    [_, ..tail] -> count_ones(tail, count)
  }
}

// Error handling
pub type MyError {
  NotFound(String)
  QueryError(String)
}

fn handle_result(result) {
  case result {
    Ok(value) -> value
    Error(NotFound(msg)) -> panic as msg
    Error(QueryError(msg)) -> panic as msg
  }
}
```

---

## 🎯 Current Status

### ✅ Completed
- **Correctly named** `inter_review.gleam` (replaces incorrectly named `review.gleam`)
- **38+ Gleam modules** in `gleam/psypi_core/src/psypi_cli/`
- **CLI commands migrated**: task, issue, skill, meeting, broadcast, context, areflect
- **Core modules**: db, identity, monitor, validation, etc.

### 📊 Code Stats
- **Gleam**: ~10,000 lines (38+ modules in psypi_cli + psypi_core)
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
1. ✅ Created `inter_review.gleam` (basic structure) - NEEDS IMPROVEMENT!
2. Apply learned patterns:
   - Use `case` expressions properly
   - Add proper type annotations
   - Use recursive functions if needed
3. Extract core logic to Gleam:
   - `request_review()` → Improve with proper Gleam patterns
   - `get_review()` → Use `case` with error handling
   - `list_reviews()` → Use list processing patterns
4. Keep DB calls in TS (PostgreSQL-specific)
5. Delete TS fallback logic (old AI code, unused features)

**Estimated Gleam Lines**: ~100 lines (properly written!)  
**TS Reduction**: 1203 → ~300 lines (thin wrapper)

---

### Priority 2: `DatabaseSkillLoader.ts` (913 lines → ~150 lines Gleam)

**Why**:
- Complex skill loading logic
- Pure functions: search, filter, sort
- Perfect for Gleam's pattern matching

**Extract to Gleam**:
- `load_skills()` → `skill_loader.gleam` (use list processing patterns!)
- `search_skills()` → Use `gleam/list` functions learned from benchmarks
- `validate_skill()` → Use pattern matching with guards

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
- `validate_extension()` → `extension.gleam` (use pattern matching!)
- `parse_manifest()` → Use `case` expressions
- `check_capabilities()` → Use `gleam/list` functions

**Estimated Gleam Lines**: ~200 lines  
**TS Reduction**: 1357 → ~500 lines

---

## 📝 Gleam Module Structure (Small & Pure!)

### New Modules to Create (Today)

```
gleam/psypi_core/src/psypi_cli/
├── inter_review.gleam          ✅ Created (basic - NEEDS IMPROVEMENT)
├── skill_loader.gleam          📝 TODO (~150 lines, use list patterns)
├── extension.gleam             📝 TODO (~200 lines, use pattern matching)
├── review_validator.gleam      📝 TODO (~80 lines, use guard patterns)
└── [command]_helpers.gleam     📝 As needed (~50 lines each)
```

**Rule**: Each module < 100 lines (except complex ones → 150-200 max)!

---

## 🛠️ Process (Per Module) - Updated with Learnings!

### Step 1: Analyze TS Code
```bash
# Find the CORE logic (ignore boilerplate)
rg "core logic|essential|important" Service.ts
# Look at function signatures - what does it ACTUALLY do?
```

### Step 2: Extract Pure Logic to Gleam (Using Learned Patterns!)

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

**Gleam Equivalent (Using Learned Patterns)**:
```gleam
// inter_review.gleam - ~100 lines total!
import gleam/list
import gleam/result.{Ok, Error}

pub type ReviewResult {
  ReviewResult(summary: String, score: Int, findings: List(Finding))
}

pub type Finding {
  Finding(type_: String, severity: String, message: String)
}

/// Request inter-review (using proper pattern matching!)
pub fn request_review(db, task_id: String, commit_hash: String) -> Result(String, Error) {
  // Use case expressions with guards if needed
  case task_id {
    "" -> Error(ValidationError("task_id cannot be empty"))
    _ -> {
      // Actual DB call here
      Ok("review-id")
    }
  }
}

/// Process findings (using list functions learned from benchmarks!)
fn process_findings(findings: List(Finding)) -> Int {
  list.fold(findings, 0, fn(acc, f) {
    case f.severity {
      "critical" -> acc + 10
      "high" -> acc + 5
      _ -> acc + 1
    }
  })
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
- **New Gleam**: ~500 lines (5-6 new modules, properly written!)
- **Net Reduction**: ~2500 lines

### Quality (Using Learned Patterns!)
- ✅ Every new Gleam module < 100-200 lines
- ✅ Uses proper pattern matching (`case` with guards)
- ✅ Uses `gleam/list` functions for list processing
- ✅ Proper error handling with custom types
- ✅ TS files become thin wrappers (< 300 lines each)
- ✅ No duplicated functionality (TS vs Gleam)
- ✅ `cli.ts` deprecated (1358 lines gone!)

### Inter-Review
- ✅ `inter_review.gleam` correctly named (not `review.gleam`!)
- ✅ Uses learned Gleam patterns (not just translated TS)
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

## 📚 Ongoing Learning Tasks (From ../refers/gleam)

### Still To Learn
1. **Study more Gleam stdlib usage**
   - Location: `gleam/psypi_core/build/packages/gleam_stdlib/src/`
   - Focus: `gleam/list.gleam`, `gleam/string.gleam`, `gleam/result.gleam`
   - Time: 30 minutes

2. **Study Gleam FFI patterns**
   - Location: `test-package-compiler/cases/*/src/*.gleam`
   - Focus: How Gleam calls JavaScript/Erlang
   - Time: 20 minutes

3. **Study error handling patterns**
   - Re-read: `docs/runtime-errors.md`
   - Focus: When to use `panic`, `todo`, `let assert`
   - Time: 15 minutes

4. **Study test patterns**
   - Location: `test/language/test/language/*_test.gleam`
   - Focus: How to write tests in Gleam
   - Time: 20 minutes

**Total Learning Time**: ~1.5 hours (spread throughout the day)

---

## 🚦 Next Actions (This Hour)

1. ✅ Created `inter_review.gleam` (correctly named!)
2. [ ] **IMPROVE** `inter_review.gleam` with learned patterns
3. [ ] Study `gleam_stdlib/src/gleam/list.gleam` (30 min)
4. [ ] Extract `InterReviewService.ts` core logic to Gleam (using patterns!)
5. [ ] Create `skill_loader.gleam` from `DatabaseSkillLoader.ts`
6. [ ] Deprecate `cli.ts` (replaced by `main.gleam`)
7. [ ] Update this plan as progress is made

---

## 🎉 Fun Facts (Updated!)

> "Small modules (< 100 lines!) survive ANYTHING!"  
> "Touch old TS = rewrite in Gleam (with proper patterns!)"  
> "Debugging Gleam is SO EASY vs TypeScript!"  
> "Most TS lines are bloat—extract the gold, discard the rest!"  
> "Review.gleam was INCORRECT naming - use inter_review.gleam!"  
> "Learn from ../refers/gleam - it's FULL of patterns!"  
> "Use `case` with guards - it's POWERFUL!"  
> "Use `gleam/list` functions - they're OPTIMIZED!"

**The goal isn't to rewrite everything. It's to let Gleam's simplicity and learned patterns naturally replace TS bloat.**

---

**Status**: ACTIVE (expires 2026-05-05 20:31)  
**Next Review**: Update progress by 14:00  
**Learning Progress**: 4/8 tasks completed (50%)  
**Have fun!** 🚀
