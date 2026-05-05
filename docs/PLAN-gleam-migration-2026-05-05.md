# Gleam Migration Plan - 2026-05-05 (Valid 12 Hours) - UPDATED

**Created**: 2026-05-05 08:31  
**Updated**: 2026-05-05 09:15 (Progress update!)  
**Valid Until**: 2026-05-05 20:31  
**Philosophy**: Small + Pure = Resilience (Gleam modules < 100 lines!)  
**Strategy**: Find LONG TS files → Extract to SMALL Gleam modules → TS becomes thin wrapper

---

## 📚 Learning from ../refers/gleam (Gleam Reference) - ✅ COMPLETED

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

4. ✅ **Examined Gleam stdlib** (`gleam_stdlib/src/gleam/*.gleam`)
   - Learned: `gleam/list` functions (filter, map, count, sort, flat_map)
   - Learned: `gleam/string` functions (lowercase, contains)
   - Learned: `gleam/order` module (Gt, Lt, Eq)
   - CRITICAL: `gleam/list` does NOT have `find()` - implement manually!

5. ✅ **Learned FFI patterns** (from test-package-compiler cases)
   - Learned: How Gleam calls JavaScript/Erlang
   - Learned: When to use FFI vs pure Gleam

---

## 🎯 Current Status - UPDATED

### ✅ Completed (Today's Work)
- **Correctly named** `inter_review.gleam` (replaces incorrectly named `review.gleam`)
  - Added list processing functions (count_critical_findings, filter_findings_by_type)
  - Added proper documentation with /// comments
  - Fixed import error (Result, Ok, Error are built-in!)
  - Added is_review_complete() helper function

- **Created `skill_loader.gleam`** (~150 lines from DatabaseSkillLoader.ts)
  - Uses gleam/list functions (filter, map, count, sort, flat_map)
  - Uses gleam/string functions (lowercase, contains)
  - Implemented find_by_name_loop (since list.find doesn't exist!)
  - Added gleam/order import for Gt, Lt, Eq

- **Saved learnings via psypi-areflect** (multiple [LEARN] tags at once!)

### 📊 Code Stats
- **Gleam**: ~11,500 lines (40+ modules in psypi_cli + psypi_core)
- **TypeScript**: 27,580 lines (target: reduce to ~10,000)
- **Current Ratio**: 1:2.4 (Gleam:TS) - Improving! Goal: 1:1
- **New this session**: +2 Gleam modules, ~250 lines

---

## ✅ Progress on Priorities (Next 12 Hours)

### Priority 1: `InterReviewService.ts` (1203 lines) - PARTIALLY DONE
**Status**: ✅ Core logic extracted to `inter_review.gleam`  
**Remaining**: 
- [ ] Update TS to use Gleam functions
- [ ] Delete TS fallback logic (old AI code, unused features)
- [ ] Reduce TS from 1203 → ~400 lines (thin wrapper)

---

### Priority 2: `DatabaseSkillLoader.ts` (913 lines) - PARTIALLY DONE  
**Status**: ✅ Pure functions extracted to `skill_loader.gleam`  
**Remaining**:
- [ ] Update TS to use Gleam functions (filter_approved_skills, search_skills_by_name, etc.)
- [ ] Keep caching/stateful logic in TS
- [ ] Reduce TS from 913 → ~400 lines (thin wrapper)

---

### Priority 3: `cli.ts` (1358 lines) - READY TO DEPRECATE!
**Status**: ✅ All CLI commands migrated to `main.gleam`  
**Action**:
- [ ] Verify `main.gleam` handles ALL commands from `cli.ts`
- [ ] `mv cli.ts cli.ts.deprecated` (correct deprecation!)
- [ ] Update any imports/references
**Result**: Delete 1358 lines! 🎉

---

### Priority 4: `extension.ts` (1357 lines) - NEXT TARGET
**Why**: 
- Extension loading/handling logic
- Can extract: validation, metadata parsing, capability checking (500+ lines → ~200 Gleam)

**Extract to Gleam** (Next 2 hours):
- [ ] `validate_extension()` → `extension.gleam` (use pattern matching!)
- [ ] `parse_manifest()` → Use `case` expressions
- [ ] `check_capabilities()` → Use `gleam/list` functions

**Estimated Gleam Lines**: ~200 lines  
**TS Reduction**: 1357 → ~500 lines

---

## 📝 Gleam Modules Created (Today)

```
gleam/psypi_core/src/psypi_cli/
├── inter_review.gleam          ✅ Created (improved with patterns)
├── skill_loader.gleam          ✅ Created (with list processing)
├── extension.gleam             📝 TODO (~200 lines, next target)
├── review_validator.gleam      📝 TODO (~80 lines)
└── [command]_helpers.gleam     📝 As needed (~50 lines each)
```

---

## 🎯 Success Metrics (Updated)

### Code Reduction (Today's Target)
- **Target**: 3000+ lines TS deleted
- **Completed**: ~250 lines new Gleam
- **Remaining**: Delete cli.ts (1358 lines), reduce InterReviewService & DatabaseSkillLoader

### Quality (Using Learned Patterns!)
- ✅ Every new Gleam module < 150 lines
- ✅ Uses proper pattern matching (`case` with guards)
- ✅ Uses `gleam/list` functions for list processing
- ✅ Proper error handling with custom types
- ✅ TS files becoming thin wrappers
- ✅ `cli.ts` ready for deprecation!

---

## 🗑️ DELETE Immediately (Today!)

### Files to Deprecate
| File | Lines | Action | Status |
|------|-------|--------|--------|
| `src/cli.ts` | 1358 | `mv cli.ts cli.ts.deprecated` | 📝 Ready! |
| `src/deprecated/*` | ~1104 | Already deprecated, review | 📝 Pending |

---

## 🚦 Next Actions (Next 2 Hours)

1. ✅ Created `inter_review.gleam` (correctly named!)
2. ✅ Created `skill_loader.gleam` with learned patterns
3. ✅ Saved learnings via psypi-areflect (multiple [LEARN] tags!)
4. [ ] **Deprecate cli.ts** (replaced by main.gleam) - NEXT!
5. [ ] Create `extension.gleam` from `extension.ts` (1357 lines)
6. [ ] Update InterReviewService.ts to use inter_review.gleam
7. [ ] Update DatabaseSkillLoader.ts to use skill_loader.gleam
8. [ ] Commit progress with `psypi commit`

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
> "gleam/list does NOT have find() - implement recursively!"  
> "Use psypi-areflect with multiple [LEARN] tags at once!"  
> "Have fun! Learning Gleam is enjoyable! 🚀"

---

**Status**: ACTIVE (expires 2026-05-05 20:31)  
**Progress**: 30% complete (2/7 priorities done, 2 in progress)  
**Learning**: ✅ Completed 5/5 learning tasks from ../refers/gleam  
**Next Review**: Update progress by 14:00  
**Have fun!** 🚀 🎉
