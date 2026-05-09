# TypeScript to Gleam Migration Strategy

**Date**: 2026-05-03  
**Status**: ACTIVE - Natural Growth Strategy  
**Philosophy**: Small + Pure = Resilience (Gleam modules < 100 lines!)

---

## 🎯 Executive Summary

**Current State:**
- **Gleam**: 380 lines (1.4%) - Critical core logic
- **TypeScript**: 26,493 lines (98.6%) - Bloated, duplicated, legacy

**Key Insight**: Most TS code is unnecessary bloat. Gleam proves that `review.gleam` (12 lines) replaces hundreds of TS lines for review logic. The migration isn't about rewriting everything—it's about **extracting essential logic** into small, pure Gleam modules.

---

## 🏛️ psypi Core Principles (NON-NEGOTIABLE)

### 1. psypi is STANDALONE and SELF-CONTAINED
- **NO external thinkers** - psypi does NOT delegate thinking to external services
- **NO "think" commands** - All thinking happens within psypi/Pi ecosystem
- **Any code for external delegation = SHIT** → DELETE IMMEDIATELY

### 2. psypi Uses Pi HEAVILY
- Pi is the **runtime environment**, not an external service
- All agent operations run **inside Pi** (TUI, extension system)
- Pi provides: event hooks, session management, tool execution
- **Gleam runs inside Pi** via compiled JavaScript modules

### 3. Shared Database Across Projects
- **ONE database** per user home (`~/.psypi/` or configured path)
- Database is **shared among ALL projects** in user home
- Pi instances connect to this shared database
- **Tables**: `agent_identities`, `tasks`, `issues`, `skills`, `meetings`, `memory`, etc.
- **No per-project databases** - single source of truth!

### 4. Core Features (Must Preserve in Gleam)

| Feature | Description | Status |
|---------|-------------|--------|
| **Task Management** | Create, track, complete tasks across projects | ✅ TS → Gleam |
| **Issue Tracking** | Report, discuss, resolve issues | ✅ TS → Gleam |
| **Skill System** | Collect, review, manage, auto-import skills | ✅ TS → Gleam |
| **AI Meetings** | Discussions, opinions, voting across agents | ✅ TS → Gleam |
| **Learning System** | Capture insights, reflections, memory | ✅ TS → Gleam |
| **Permanent Monitor** | Pi agent (God in sky) reviews all commits | ✅ Gleam (`review.gleam`) |
| **Pi Event Hooks** | Skills respond to Pi events (tool_result, etc.) | 🚀 Migrating |
| **Shared Context** | Agents share database, learnings, skills | ✅ Working |

### 5. What psypi is NOT
- ❌ **NOT a distributed system** - runs locally per user
- ❌ **NOT using external AI services** for core logic (God = Gleam!)
- ❌ **NOT delegating thinking** - standalone agent!
- ❌ **NOT per-project database** - shared across projects!

---

## 📊 Code Quality Analysis

### The "Shit" Assessment

| Category | TS Lines | Estimated Bloat | Reality |
|----------|----------|-----------------|---------|
| **CLI Commands** | ~3,000 | 70% | Duplicated in `cli.ts` AND `kernel/cli/index.ts` |
| **Services** | ~12,730 | 60% | Heavy OOP, event emitters, complex state |
| **InterReviewService** | 1,209 | 80% | Most is fallback logic for "old AI" (removed) |
| **DatabaseSkillLoader** | 913 | 50% | Could be 100 lines of pure functions |
| **MeetingCommands** | 619 | 60% | Complex state management, could be simple |
| **Config** | ~1,000 | 40% | Necessary but could be simpler |

### Gleam Proof Points

| Functionality | TS Lines | Gleam Lines | Ratio |
|---------------|----------|-------------|-------|
| Review logic | ~500 (InterReviewService) | 12 (review.gleam) | 41:1 |
| Session mgmt | ~200 (multiple files) | 26 (partner.gleam) | 7.7:1 |
| CLI routing | ~1,095 (cli/index.ts) | 80 (main.gleam) | 13.7:1 |
| Task commands | ~60 (TaskCommands.ts) | 26 (task.gleam) | 2.3:1 |

**Conclusion**: Gleam typically needs **5-40x fewer lines** for the same functionality.

---

## 🚀 Migration Strategy: "Natural Growth"

**Core Principle**: Don't rewrite everything. Let Gleam **grow naturally** by:
1. **Touch TS = Rewrite in Gleam**
2. **New features → Gleam first**
3. **Bug fixes → Gleam if touching old code**
4. **Delete TS after Gleam replacement works**

### Phase 1: COMPLETE ✅ (Current State)

```
gleam/psypi_core/src/
├── psypi_core.gleam          # 48 lines - Types + utils
├── psypi_core/
│   ├── partner.gleam          # 26 lines - Session management
│   └── review.gleam           # 12 lines - Review logic (God in the sky!)
└── psypi_cli/
    ├── main.gleam             # 80 lines - CLI entry point
    ├── task.gleam             # 26 lines - Task commands
    ├── issue.gleam            # 24 lines - Issue commands
    ├── skill.gleam            # 35 lines - Skill commands
    ├── meeting.gleam          # 40 lines - Meeting commands
    ├── areflect.gleam         # 42 lines - Reflection
    ├── broadcast.gleam        # 24 lines - Broadcasts
    └── context.gleam          # 23 lines - Identity/session commands
```

**Total**: 380 lines of Gleam doing what TS does in ~5,000 lines.

---

## 📋 Phase 2: Services Migration (Next Priority)

### DELETE (External Thinker Code - NOT Migrating!)

| Service | TS Lines | Action | Reason |
|---------|----------|--------|--------|
| **PiExecutor.ts** | 214 | ❌ **DELETE** | External delegation - SHIT! |
| **PiSDKExecutor.ts** | 107 | ❌ **DELETE** | External SDK calls - SHIT! |
| **Any "think" code** | ~500+ | ❌ **DELETE** | External thinkers - ALL SHIT! |

### Priority Ranking (What to migrate next)

| Service | TS Lines | Priority | Reason | Est. Gleam Lines |
|---------|----------|----------|--------|------------------|
| **AgentIdentityService** | 228 | **HIGH** | Core identity, shared DB across projects | ~40 |
| **BroadcastService** | 295 | **HIGH** | Pub/sub across agents (shared DB) | ~50 |
| **MeetingHandler** | 273 | **HIGH** | AI meetings, shared across projects | ~60 |
| **ContextBuilder** | 294 | **MEDIUM** | Context assembly, pure logic | ~50 |
| **SkillBuilder** | 416 | **MEDIUM** | Skill mgmt (collect, review, manage) | ~80 |
| **DatabaseSkillLoader** | 913 | **MEDIUM** | Load skills from shared DB | ~100 |
| **InterReviewService** | 1,209 | **LOW** | Uses Gleam review, rest is bloat | ~100 |

### Services to Keep in TS (For Now)

| Service | Reason |
|---------|--------|
| **DatabaseClient** | PostgreSQL-specific, FFI not worth it yet |
| **Embedding services** | Local Ollama/API calls (Node.js fetch) |
| **GitHub services** | API integration (Node.js fetch) |
| **Encryption services** | Node.js crypto dependency |

**Rule**: If it needs Node.js-specific APIs, keep in TS. If it's **pure logic**, move to Gleam.

**Exception**: Anything that delegates to external thinkers → DELETE (not migrate)!

---

## 🗑️ DELETE IMMEDIATELY: External Thinker Code

**PRINCIPLE**: psypi is standalone - any code delegating to external thinkers is SHIT!

### Candidates for IMMEDIATE Deletion

| File/Feature | Lines | Reason |
|--------------|-------|--------|
| `psypi think` command | ~200 | ❌ Delegates to external thinker - DELETE! |
| `src/kernel/services/PiExecutor.ts` | 214 | ❌ External AI execution - DELETE! |
| `src/kernel/services/PiSDKExecutor.ts` | 107 | ❌ External SDK calls - DELETE! |
| Any "thinker" / "think" code | ~500+ | ❌ External delegation - ALL SHIT! |
| `src/cli.ts` | 1,330 | **DUPLICATED** by Gleam `psypi_cli` - DELETE! |
| `src/kernel/cli/process-guardian.ts` | 272 | Unclear purpose - DELETE! |
| Old migration scripts in `scripts/` | ~500 | Migration complete - DELETE! |
| `src/kernel/services/SoulService.ts` | 98 | Unused? DELETE! |

### Code Patterns to DELETE (External Delegation)
```typescript
// ❌ ALL OF THIS IS SHIT - DELETE!
import { someExternalAI } from 'external-service';
import { thinker } from './thinker';
// Any code that sends "thinking" to external service
// Any "think" command implementations
// Any delegation to non-Pi systems
```

**Replacement**: Use **Gleam pure functions** + **Pi runtime** instead!

### Bloat Patterns to Eliminate

1. **Duplicate Command Definitions**
   - `cli.ts` AND `kernel/cli/index.ts` define same commands
   - **Fix**: Use ONE CLI entry point (Gleam `psypi_cli/main.gleam`)

2. **Over-Engineered Services**
   - `InterReviewService`: 1,209 lines for what's essentially calling Gleam `review()`
   - **Fix**: Delete TS fallback logic, keep only Gleam bridge

3. **Unnecessary Abstractions**
   - Event emitters for simple request/response
   - Complex class hierarchies for stateless operations
   - **Fix**: Pure functions in Gleam

---

## 🛠️ Migration Process (Per Module)

### Step 1: Analyze TS Code
```bash
# Find the essential logic (ignore boilerplate)
rg "core logic|important|essential" service.ts
# Look at function signatures - what does it ACTUALLY do?
```

### Step 2: Extract Pure Logic
**TS Bloat Example:**
```typescript
// 50 lines of class boilerplate
export class TaskService extends EventEmitter {
  private db: DatabaseClient;
  private emitter: EventEmitter;
  constructor(db: DatabaseClient) {
    super();
    this.db = db;
    this.emitter = new EventEmitter();
  }
  async addTask(title: string, desc: string, priority: number) {
    // 20 lines of validation
    // 30 lines of event emission
    // Actual logic:
    const result = await this.db.query(
      'INSERT INTO tasks (title, description, priority) VALUES ($1, $2, $3)',
      [title, desc, priority]
    );
    return result.rows[0];
  }
}
```

**Gleam Equivalent:**
```gleam
// task.gleam - 26 lines total!
pub fn add_task(db, title: String, desc: String, priority: Int) -> Result(Task, DbError) {
  // Pure function, no boilerplate
  db.query(
    "INSERT INTO tasks (title, description, priority) VALUES ($1, $2, $3)",
    [title, desc, priority]
  )
}
```

### Step 3: Write Gleam Module (< 100 lines!)
```bash
cd gleam/psypi_core
# Create new module
cat > src/psypi_services/identity.gleam << 'EOF'
// identity.gleam - Agent identity logic (~40 lines)
pub fn resolve_identity(project: String, session: String) -> String {
  // Pure logic here
}
EOF

# Build (Gleam errors are CRYSTAL clear!)
gleam build
```

### Step 4: Bridge Update
```typescript
// src/common/gleam-bridge.ts (already exists, just add exports)
export { resolve_identity } from '../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_services/identity.mjs';
```

### Step 5: Delete TS Code
```bash
# Once Gleam works, DELETE the TS file
rm src/kernel/services/AgentIdentityService.ts

# Commit with God's review
psypi commit "feat: Migrate identity service to Gleam"
```

---

## 📏 Size Rules (Non-Negotiable)

| Gleam Module | Max Lines | Current Status |
|--------------|-----------|----------------|
| **Core logic** (review, partner) | 50 | ✅ 12-26 lines |
| **CLI commands** (task, issue) | 50 | ✅ 24-42 lines |
| **Services** (identity, broadcast) | 80 | To be verified |
| **Complex services** (skill builder) | 100 | Absolute max! |

**If a Gleam module exceeds 100 lines → SPLIT IT!**

---

### Success Metrics

### Code Reduction Goals
- **Target**: 2,000 lines Gleam (10x growth) vs 10,000 lines TS (60% reduction)
- **Ratio**: From 1:70 (Gleam:TS) to 1:5 (much healthier!)
- **DELETE**: ~1,000 lines of external thinker SHIT

### Quality Metrics
- ✅ Every Gleam module < 100 lines
- ✅ Zero duplicated functionality (TS vs Gleam)
- ✅ Pure functions (no hidden state)
- ✅ Clear error messages (Gleam's compiler)
- ✅ `psypi commit` triggers God's review (Gleam review.gleam)
- ✅ **ZERO external thinker code** (psypi is standalone!)
- ✅ **Shared database** across all projects in user home
- ✅ **Pi event hooks** to skills working
- ✅ **Permanent monitor AI** (God in sky) reviewing all commits

---

## 🗂️ Document Cleanup Plan

### DELETE (Outdated/Complete)
- `docs/MIGRATION-COMPLETE.md` - Migration done, irrelevant
- `docs/migration-plan-nezha-to-psypi.md` - Done
- `docs/migration-report-2026-05-03.md` - Done
- `docs/schema-differences-nezha-psypi.md` - Done
- `docs/PLAN-inner-ai-to-pi-agent.md` - Replaced by Gleam
- `docs/PLAN-inner-ai-to-pi-agent-GLEAM.md` - Superseded by this doc
- `docs/RESEARCH-REPORT-inner-ai-to-pi-agent.md` - Done
- `docs/SUMMARY-inner-ai-to-pi-agent-FEATURE.md` - Done
- `docs/SUGGESTION-inner-ai-use-gleam.md` - Implemented
- `docs/vision-permanent-ai-partner.md` - Implemented (God in sky)
- `docs/RESEARCH-Why-GitHub-found-secrets.md` - One-time research
- `docs/session-summary-2026-05-02.md` - Old session
- `docs/migration-plan-session-id-cleanup.md` - Done
- `docs/GLEAM-REWRITE-PLAN.md` - Superseded by this doc
- `docs/TECH_NOTE-gleam-*.md` - Consolidate into this doc

### KEEP (Still Relevant)
- `docs/AGENTS.md` - Main agent instructions (UPDATE with new ratio)
- `docs/PNPM_USAGE.md` - Build system docs
- `docs/HOW_TO_JOIN_MEETING_7b3e9f1a.md` - Keep latest meeting guide
- `docs/BOOK-What-I-Wish-I-Knew-When-Starting-Pi.md` - General Pi advice
- `docs/AI_GUIDE-requesting-pi-extensions.md` - Extension guide
- `docs/PROJECT_CONTEXT.md` - Project overview (UPDATE)

### ARCHIVE (Move to `docs/archive/`)
- `docs/HOW_TO_JOIN_MEETING_57d7aab4.md` - Old meeting guide
- All migration plans from 2026-05-03 and earlier

---

## 🚦 Next Actions

### Immediate (This Week)
1. ✅ Create this document
2. [ ] Clean up old docs (delete/archve as listed above)
3. [ ] Migrate `AgentIdentityService` to Gleam (~40 lines)
4. [ ] Delete `src/cli.ts` (use Gleam CLI only)

### Short Term (Next 2 Weeks)
1. [ ] Migrate `BroadcastService` to Gleam
2. [ ] Migrate `MeetingHandler` logic to Gleam
3. [ ] Simplify `DatabaseSkillLoader` (reduce from 913 to ~300 lines)

### Medium Term (Next Month)
1. [ ] Reach 2,000 lines of Gleam
2. [ ] Reduce TS to 10,000 lines (delete bloat)
3. [ ] Achieve 1:5 Gleam:TS ratio

---

## 🎉 Philosophy Reminder

> "Small modules (< 100 lines!) survive ANYTHING!"  
> "Touch old TS = rewrite in Gleam"  
> "Debugging Gleam is SO EASY vs TypeScript!"  
> "Most TS lines are shit—extract the gold, discard the rest!"

**The goal isn't to rewrite everything. It's to let Gleam's simplicity naturally replace TS bloat.**

---

**Status**: This document is the NEW source of truth for TS→Gleam migration.  
**Next Review**: 2026-05-10 (check progress, update ratios).
