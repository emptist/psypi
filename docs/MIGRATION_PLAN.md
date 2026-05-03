# Psypi Gleam Migration Plan

## ⚠️ IMPORTANT: Migration Starting Point

**Branch**: `new-start`

All changes are based on the `new-start` branch. Do not confuse with other branches!

---

## Why Gleam Rewrite?

**TypeScript Problems:**
- Too flexible → AI creates middlemen, caches, bad patterns
- Dynamic typing → Easy to break tracking chain
- Verbose → "又臭又长" (long and messy)
- No enforcement → Rules in docs are ignored

**Gleam Advantages:**
- Strong typing → Forces correct data flow
- Functional → Functions receive parameters, no global state access
- Immutable → No caching variables
- Concise → Small modules (< 100 lines)
- Compile-time checks → Architecture violations caught early

**Example:**
```typescript
// TypeScript - AI can easily do this (WRONG!)
let cachedId = null;  // Mutable, can cache
function getId() {
  if (!cachedId) cachedId = getIdentity();  // Breaks tracking!
  return cachedId;
}
```

```gleam
// Gleam - Impossible to cache (RIGHT!)
pub fn get_resolved_identity(permanent, session_id) {
  // Must receive parameters, no global state
  // Every call executes FFI → tracking preserved
  resolve(permanent, model, session_id)
}
```

---

## Core Principles

### 1. New Runtime Mode
- **No CLI commands** - All converted to Pi Agent Tools
- **Interactive mode only** - `psypi` runs without arguments, interacts with user
- **Self-sufficient** - No external thinkers, no delegate mode, no thinker slot

### 2. Flat Architecture (CRITICAL!)
```
WRONG (old): user → CLI → Command → Service → Kernel → DB (multiple middlemen)
RIGHT (new): user → Pi Agent Tool → Gleam → DB (direct to truth)
```

**Key insight**: Each layer in the old architecture is a "middleman" that adds bugs. Go directly to the source of truth.

### 3. Ultimate Truth Functions

#### Agent ID
```typescript
AgentIdentityService.getResolvedIdentity()
```
- Does many things, not just returns an ID
- **No intermediate layers allowed**
- Must call directly, no caching
- **Called in TypeScript layer, passed to Gleam as parameter**

**Why it's the Ultimate Truth:**
- Every call generates/looks up agent ID
- Every call accesses database to record AI behavior
- Tracks: session_id, project, git_hash, machine_fingerprint, created_at
- **If cached or middlemen involved → tracking is broken!**

**The Closed Loop:**
```
AI takes action → needs ID → calls Ultimate Truth Function
                                  ↓
                           Database records:
                           - who (agent_id)
                           - when (created_at)
                           - where (project, git_hash)
                           - which session (session_id)
                                  ↓
                           AI behavior fully tracked ✓
```

**This is why:**
1. AI action → must register ID
2. Need ID → must call Ultimate Truth Function
3. Call Ultimate Truth → database records
4. **Closed loop - no escape!**

**General Rule: NO CACHING**
- ❌ Caching agent ID → breaks tracking
- ❌ Caching session ID → stale data
- ❌ Caching database results → inconsistent state
- ❌ Caching any "truth" → defeats the purpose

**Why caching is bad:**
- Truth changes over time
- Caching = snapshot of past, not current truth
- Every call should get fresh data from source
- Performance is NOT an excuse for broken architecture

**Functional Programming = No Caching by Design:**
- Gleam: No mutable variables → impossible to cache
- Pure functions → same input, same output, no hidden state
- Immutability → every call is fresh
- This is why Gleam rewrite is necessary!

#### Session ID (Pi Session ID)

**Used in Pi Agent Tools only** - no process isolation issue!

```typescript
// In Pi extension, at session_start event
pi.on("session_start", async (_event, ctx) => {
  const sessionId = ctx.sessionManager.getSessionId();  // Ultimate truth!
  // No need to set process.env.AGENT_SESSION_ID
  // Pi tools use ctx directly
});

// In Pi tool execute function
async execute(toolCallId, params, signal, onUpdate, ctx) {
  const sessionId = ctx.sessionManager.getSessionId();
  // Pass to Gleam function as parameter
}
```

- Access via `ctx.sessionManager.getSessionId()` in Pi extension
- **`process.env.AGENT_SESSION_ID` is AI HALLUCINATION - does not exist!**
- **No process isolation issue** - all code runs inside Pi's process
- Reference: commit `c1674d8` (try4 branch) - "uses ctx.sessionManager.getSessionId() directly"
- Reference: `docs/pi-session-id-truth.md` (from commit c1674d8)
- Reference: `docs/CODE_REVIEW.md` (from commit c1674d8)

### 4. Import Pattern: `#gleam/prelude`

Already configured in `package.json`:
```json
{
  "imports": {
    "#gleam/prelude": "./gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam.mjs",
    "#gleam/option": "./gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam/option.mjs",
    "#psypi/task": "./gleam/psypi_core/build/dev/javascript/psypi_core/psypi_cli/task.mjs"
  }
}
```

Reference: `@chouquette/vite` package pattern

---

## Correct Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Pi Extension (ctx has sessionManager)                      │
│       ↓                                                     │
│  TypeScript Pi Tool Handler                                 │
│    - Get agent_id: AgentIdentityService.getResolvedIdentity()│
│    - Get session_id: ctx.sessionManager.getSessionId()      │
│       ↓                                                     │
│  Gleam Function (receives parameters, pure business logic)  │
│    - task.add(title, desc, priority, created_by)            │
│       ↓                                                     │
│  FFI (uses DatabaseClient singleton, direct PostgreSQL)     │
│       ↓                                                     │
│  PostgreSQL (single source of truth)                        │
└─────────────────────────────────────────────────────────────┘
```

**Key Points:**
1. Agent ID is obtained in TypeScript layer, NOT in Gleam/FFI
2. FFI uses existing `DatabaseClient.getInstance()` connection pool
3. Gleam functions receive all context as parameters

---

## Mistakes I Made (DON'T REPEAT!)

### ❌ Mistake 1: Creating session_ffi.gleam/mjs
```gleam
// WRONG - Don't do this!
@external(javascript, "./session_ffi.mjs", "get_agent_id")
pub fn get_agent_id() -> String
```

**Why wrong**: 
- `process.env.AGENT_SESSION_ID` doesn't exist (AI hallucination)
- Agent ID should be obtained via `AgentIdentityService.getResolvedIdentity()` in TS layer
- Gleam should receive it as a parameter, not fetch it itself

### ❌ Mistake 2: Creating new PostgreSQL pool in FFI
```javascript
// WRONG - Don't do this!
let pool = null;
function getPool() {
  if (!pool) {
    pool = new Pool({...});  // New pool!
  }
  return pool;
}
```

**Why wrong**:
- Creates duplicate connection pool
- Violates single source of truth
- Should use `DatabaseClient.getInstance()` instead

### ❌ Mistake 3: Thinking "gradual migration" with middlemen
**Why wrong**:
- User explicitly said: delete ALL middlemen
- Go directly to source of truth
- No "phased" approach that keeps old layers

---

## Migration Phases (Revised: Hardest Last)

### Phase 1: Infrastructure ✅ DONE
- [x] Configure `#gleam/prelude` imports in package.json
- [x] Document patterns in `docs/GLEAM_INTEGRATION_PATTERNS.md`
- [x] Extract reference docs: `pi-session-id-truth.md`, `CODE_REVIEW.md`

### Phase 2: Pilot Module - Task (Easy, Foundation)
- [ ] Fix `task.gleam` - receive `created_by` parameter
- [ ] Fix `task_ffi.mjs` - use `DatabaseClient.getInstance()`
- [ ] **Create `psypi-commit` Pi Tool FIRST** (for committing changes)
  - Get `session_id`: `ctx.sessionManager.getSessionId()`
  - Get `agent_id`: `AgentIdentityService.getResolvedIdentity()`
  - Execute git commit with proper tracking
  - Trigger "God in the sky" monitor review
- [ ] Create other TypeScript Pi Tool wrappers
  - Pass session_id and agent_id to Gleam functions
- [ ] Test: `psypi-task-add`, `psypi-tasks`, `psypi-task-complete`

### Phase 3: Core Modules (Medium)
- [ ] `agent_identity.gleam` + `agent_identity_ffi.mjs` (already created)
- [ ] `issue.gleam` + `issue_ffi.mjs`
- [ ] `areflect.gleam` + `areflect_ffi.mjs`

### Phase 4: Pi Agent Tools Wrapper (Medium)
- [ ] Update `extension.ts` with new Gleam-based tools
- [ ] Each tool:
  - Gets `session_id` from `ctx.sessionManager.getSessionId()`
  - Gets `agent_id` from `AgentIdentityService.getResolvedIdentity()`
  - Calls Gleam function with parameters
- [ ] Test all tools in Pi

### Phase 5: Natural Cleanup (Easy)
- [ ] Old middlemen code becomes unused (no calls to them)
- [ ] Delete when clearly dead code:
  - `src/kernel/index.ts` (Kernel class)
  - `src/kernel/services/*.ts` (most services)
  - `src/kernel/cli/*.ts` (CLI commands)
  - `src/kernel/utils/session.ts` (session ID middleman)

### Phase 6: Monitor AI - Real Pi Agent (Hard, LAST)
**Important but NOT urgent. Complex. Do this LAST.**

Current state: "Inner AI: Working but fake" (stateless API)

**What needs to be done:**
- [ ] Replace fake AI with real Pi agent via `createAgentSession()`
- [ ] Integrate with existing `review.gleam` monitor
- [ ] Test: "God in the sky" reviews all commits

**Why last:**
- Requires deep understanding of Pi SDK
- Complex agent lifecycle management
- Can work with fake AI in the meantime
- Other phases are more foundational

### Phase 7: Documentation Cleanup (Easy)
**From CODE_REVIEW.md recommendations:**

- [ ] Simplify `AGENTS.md` - remove contradictory rules
- [ ] Remove "15+ NEVER rules" - replace with clear examples
- [ ] Fix contradiction: "never use AGENT_SESSION_ID" vs code that uses it
- [ ] Document architecture clearly:
  ```
  Pi Extension Tools (run inside Pi):
    ✅ Use ctx.sessionManager.getSessionId()
    ✅ Registered via pi.registerTool()
    ✅ Called by Pi's LLM
  
  psypi CLI (separate process):
    ⚠️ Legacy/historical commands
    ⚠️ Don't need Pi's session ID
    🎯 Being replaced by Pi tools anyway
  ```
- [ ] Update README.md with current status

---

## Issues from CODE_REVIEW.md (All Addressed)

| Issue                              | Status    | Phase     |
| ---------------------------------- | --------- | --------- |
| Session ID handling broken         | ✅ Fixed   | Phase 2   |
| Process isolation misunderstanding | ✅ Fixed   | Phase 2   |
| Contradictory documentation        | 📝 Pending | Phase 7   |
| Gleam/TypeScript split             | ✅ Keeping | Phase 2-3 |
| "God in the sky" fake AI           | 📝 Pending | Phase 6   |
| Over-engineered rules              | 📝 Pending | Phase 7   |
| Legacy CLI commands                | 📝 Pending | Phase 5   |

---

## Priority Matrix

| Phase               | Complexity | Urgency | Order |
| ------------------- | ---------- | ------- | ----- |
| 1. Infrastructure   | Low        | High    | 1st ✅ |
| 2. Task Module      | Low        | High    | 2nd   |
| 3. Core Modules     | Medium     | High    | 3rd   |
| 4. Pi Tools Wrapper | Medium     | High    | 4th   |
| 5. Cleanup          | Low        | Low     | 5th   |
| 6. Monitor AI       | High       | Low     | 6th   |
| 7. Documentation    | Low        | Low     | 7th   |

---

## Important: Don't Create More Middlemen!

**Before Every Function Call, Ask:**
1. Is this the ultimate truth?
2. If not, why am I using it?
3. Why am I reselling (转手倒卖)?

**The Danger:**
- ❌ Using existing middlemen (Kernel, Services)
- ❌ Creating NEW middlemen on top of old ones (三道贩子, 四道贩子)

**The Right Way:**
- ✅ New code goes DIRECTLY to source of truth
- ✅ Skip middlemen, don't call them
- ✅ They become unused naturally, then delete

**Example:**
```typescript
// WRONG - Using middlemen
const taskId = await kernel.addTask(title, desc, priority);  // kernel is middleman

// WRONG - Creating new middleman
class TaskService {
  async addTask(...) {
    return kernel.addTask(...);  // just forwarding, useless!
  }
}

// WRONG - Caching agent ID (breaks tracking!)
let cachedAgentId = null;
async function getAgentId() {
  if (!cachedAgentId) {
    cachedAgentId = (await AgentIdentityService.getResolvedIdentity()).id;
  }
  return cachedAgentId;  // ❌ No tracking on subsequent calls!
}

// RIGHT - Direct to truth (every call is tracked!)
const identity = await AgentIdentityService.getResolvedIdentity();
const result = await db.query(
  `INSERT INTO tasks (id, title, created_by) VALUES (...)`,
  [title, identity.id]
);
```

---

## Files to Keep

| File                                          | Purpose                          |
| --------------------------------------------- | -------------------------------- |
| `src/agent/extension/extension.ts`            | Pi extension entry point         |
| `src/kernel/services/AgentIdentityService.ts` | Ultimate truth for agent ID      |
| `src/kernel/db/DatabaseClient.ts`             | PostgreSQL connection singleton  |
| `gleam/psypi_core/src/**/*.gleam`             | Core business logic              |
| `gleam/psypi_core/src/**/*_ffi.mjs`           | FFI bridges (use DatabaseClient) |

## Files That Will Become Unused (Don't Delete Yet)

| File                       | Will be unused when                       |
| -------------------------- | ----------------------------------------- |
| `src/kernel/index.ts`      | New Pi Tools call DatabaseClient directly |
| `src/kernel/services/*.ts` | New code skips them                       |
| `src/kernel/cli/*.ts`      | Replaced by Pi Agent Tools                |
