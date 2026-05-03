# Gleam Rewrite Plan - Say Goodbye to TypeScript Mess!

**Date**: 2026-05-03  
**Status**: DRAFT - Awaiting Approval  
**Philosophy**: Small + Pure = Resilience (Gleam modules < 100 lines!)

---

## 🎯 Why Rewrite in Gleam?

### Proof Gleam Works Better:
- `partner.gleam` = **26 lines** (UNBREAKABLE session management)
- `review.gleam` = **~15 lines** (PURE review logic)
- `index.ts` = **1000+ lines** with 101+ hardcoded "nezha" bugs!
- `extension.ts` = **1400+ lines** of messy TypeScript

### Benefits:
- ✅ **Small modules** (< 100 lines) = Unbreakable!
- ✅ **Pure functions** = Easy to reason about
- ✅ **Clear errors** = Exact line + pointer (vs TypeScript's cryptic TS2305!)
- ✅ **Type safety** = Result types, pattern matching
- ✅ **Debugging is SO EASY** vs TypeScript!

---

## 📊 Current State Analysis

### Gleam Modules (Already Done - Small & Perfect):
- `gleam/psypi_core/src/psypi_core/partner.gleam` = 26 lines
- `gleam/psypi_core/src/psypi_core/review.gleam` = ~15 lines
- `gleam/psypi_core/src/psypi_core/psypi_core.gleam` = ~50 lines

### TypeScript Mess That Needs Rewriting:

| File | Lines | "nezha" Bugs | Priority |
|------|-------|--------------|----------|
| `src/kernel/cli/index.ts` (CLI) | 1000+ | 101+ (fixed) | **HIGH** |
| `src/agent/extension/extension.ts` | 1400+ | ? | **HIGH** |
| `src/kernel/cli/process-guardian.ts` | ~200 | 1 | MEDIUM |
| `src/kernel/services/OpenCodeSessionManager.ts` | ~150 | 3 | MEDIUM |
| `src/kernel/services/SkillBuilder.ts` | ~300 | 3 | LOW |
| `src/kernel/cli/MeetingCommands.ts` | ~500 | 0 | MEDIUM |

### Remaining "nezha" References (After Fixes):
- `src/kernel/config/Config.ts:131` - comment only
- `src/kernel/cli/process-guardian.ts:80` - grep pattern
- `src/kernel/db/types.ts:3` - comment
- `src/kernel/services/MarkdownKnowledgeLoader.ts:66` - dir path

---

## 🎯 Gleam Rewrite Strategy

**Principle**: Each module < 100 lines, pure functions, clear purpose!

---

### Phase 1: Core CLI (Replaces `index.ts` 1000+ lines)

```
gleam/psypi_core/src/psypi_cli/
├── task.gleam         (~50 lines) - task-add, tasks, task-complete
├── issue.gleam        (~50 lines) - issue-add, issue-list, issue-resolve
├── meeting.gleam      (~80 lines) - discuss, opinion, search, summary
├── skill.gleam        (~60 lines) - list, show, search, build
├── context.gleam      (~40 lines) - my-id, partner-id, my-session-id
├── areflect.gleam     (~50 lines) - all-in-one reflection
├── broadcast.gleam    (~30 lines) - announcements
└── main.gleam         (~90 lines) - CLI entry point + routing
```

**Total**: ~450 lines of Gleam (vs 1000+ TypeScript)

---

### Phase 2: Services (Replaces Messy Services)

```
gleam/psypi_core/src/psypi_services/
├── session.gleam      (~60 lines) - session management (enhance partner.gleam)
├── broadcast.gleam    (~40 lines) - announcements
├── identity.gleam     (~50 lines) - agent identity (from AgentIdentityService)
├── checkpoint.gleam   (~30 lines) - state management
└── guardian.gleam     (~50 lines) - process guardian (replaces process-guardian.ts)
```

**Total**: ~230 lines of Gleam

---

### Phase 3: Extension (Replaces `extension.ts` 1400+ lines)

```
gleam/psypi_core/src/psypi_extension/
├── tools.gleam        (~80 lines) - tool registration
├── commands.gleam     (~60 lines) - command registration
├── hooks.gleam        (~70 lines) - event hooks
└── main.gleam         (~50 lines) - extension entry point
```

**Total**: ~260 lines of Gleam (vs 1400+ TypeScript)

---

### Phase 4: Keep TypeScript as THIN BRIDGE Only

```
src/common/gleam-bridge.ts  (already exists - 206 bytes!)
└── Just imports Gleam modules, nothing else!

src/agent/extension/extension.ts  (REWRITE)
└── Import from gleam-bridge.ts, 50 lines max!
```

---

## 🚀 Migration Strategy

### Step 1: Build Gleam Modules
- One module at a time
- Each < 100 lines (preferably under 100!)
- Pure functions only
- Test independently

### Step 2: Compile
```bash
cd gleam/psypi_core && gleam build
```
- Fix any compilation errors (Gleam's errors are CRYSTAL clear!)

### Step 3: Test Each Module
- Unit test each Gleam module
- Verify it works correctly
- Commit with `psypi commit` (God in the sky reviews!)

### Step 4: Bridge Updates
- Update `gleam-bridge.ts` to export new modules
- Keep it thin (just re-exports)

### Step 5: Delete Old TypeScript
- Remove old TypeScript files
- Verify everything still works
- Run `psypi commit` for review

### Step 6: Verify
- `psypi commit` works with God in the sky (Gleam review!)
- All commands work
- Zero "nezha" references
- All modules < 100 lines

---

## ✅ Success Metrics

- ✅ **Zero "nezha" references** (Gleam doesn't have them!)
- ✅ **Each module < 100 lines** (Small = Unbreakable!)
- ✅ **Pure functions** (Easy to reason about)
- ✅ **Clear Gleam errors** (vs TypeScript's cryptic ones)
- ✅ **`psypi commit` works** with God in the sky (Gleam review!)
- ✅ **All CLI commands functional**
- ✅ **Extension loads properly**

---

## 📝 Notes

- **NO PLAN = NO ACTION** - Waiting for approval before starting!
- **Gleam Philosophy**: Small + Pure = Resilience!
- **Trust Gleam's simplicity** - Small modules survive ANYTHING!
- **Debugging Gleam is SO EASY** vs TypeScript!

---

**Status**: Plan saved. Awaiting approval to start implementation.

**Next Action**: User reviews plan and says "APPROVED - START" or modifies plan.

**I will NOT write a single line of code until approved!**
