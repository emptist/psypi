# Architecture Analysis: psypi Monitor Design

## Context: What We Discussed

### Original Premise (Paradox Found)
> "Build a Monitor AI with the same power as the Worker AI"

**Problem discovered:** "Monitor" was being built as a SEPARATE AI with `complete()` (text-only) → `psypi-monitor-exec` bridge. This is WEAKER than Worker, not equal.

### Corrected Understanding
- **Worker (no prefix)**: Triggered by user/system prompts
- **Monitor (P- prefix)**: Triggered by EVENTS (hooks), has FULL tool access, finds work nobody asked for

Monitor is the SAME Pi agent, just with a different trigger mechanism + identity.

---

## Reference Projects Analysis

### 1. Pi (coding-agent) - Core Reference

**Architecture:**
- `AgentSession` manages agent lifecycle, event subscription, tool registry
- `Agent` wraps the low-level agent loop, owns state (tools, messages), emits events
- `ExtensionRunner` handles extension loading and event emission
- **Hooks are FIRST-CLASS**: `beforeToolCall`, `afterToolCall` are on the Agent itself

**Key insight from Pi's Extension system:**
```
Agent
  ├── beforeToolCall?: (context, signal) => Promise<BeforeToolCallResult | undefined>
  └── afterToolCall?: (context, signal) => Promise<AfterToolCallResult | undefined>
```

These are NOT extension hooks - they're on the core Agent. Extensions wrap them via `ExtensionRunner`.

**Extension Events (from types.ts):**
```
SessionEvents: session_start, session_before_switch, session_before_fork, session_before_compact,
               session_compact, session_shutdown, session_before_tree, session_tree

AgentEvents: context, before_provider_request, after_provider_response, before_agent_start,
             agent_start, agent_end, turn_start, turn_end,
             message_start, message_update, message_end,
             tool_execution_start, tool_execution_update, tool_execution_end,
             model_select, thinking_level_select, user_bash, input

ToolEvents: tool_call (can BLOCK), tool_result (can MODIFY)
```

**Tool execution model:**
- `ToolDefinition` has `execute()` that receives `ctx: ExtensionContext`
- `ExtensionContext` provides: `ui`, `sessionManager`, `modelRegistry`, `model`, `isIdle()`, `signal`, `abort()`
- Tools can be blocking (`block: true, reason: string`) or result-modifying

**Key Pi SDK patterns:**
```typescript
// Create agent session
const { session } = await createAgentSession({
  authStorage, modelRegistry, tools: codingTools(process.cwd()),
  sessionManager: SessionManager.inMemory(),
});

// Subscribe to events
session.subscribe((event) => { /* handle */ });

// Send messages
await session.prompt(text);
await session.steer(text);    // Interrupt current turn
await session.followUp(text); // Queue for after current turn

// Control tools
session.setActiveToolsByName(['read', 'bash', 'edit', 'write']);

// Send custom messages
await session.sendCustomMessage({ customType: 'monitor', content: [...] }, { triggerTurn: true });
```

**Pi's model for "two modes" (from AgentSession):**
- `steer()` - interrupt current turn with message (steering queue)
- `followUp()` - queue message for after current turn (follow-up queue)
- `sendCustomMessage()` with `deliverAs: "steer" | "followUp" | "nextTurn"`
- These are built-in! The agent already supports multi-mode messaging

### 2. Puter.js - Architecture Patterns

**Observations:**
- Worker-based architecture with sandbox isolation
- Extension system for adding capabilities
- Focus on UI (gui/), services (worker/), and dev-center

**Relevance:** The extension pattern in puter could inspire how psypi extends Pi.

### 3. Lively4-core - Event-Driven Pattern

**Observations:**
- Self-modifying browser environment
- Web Worker system for background processing
- Component-based architecture with event propagation

**Key insight from Lively4:**
> "When a parent component contains child components, state changes must be explicitly propagated"
> "Child components don't automatically inherit instance variables from their container"

This suggests the Monitor needs to PROACTIVELY communicate state changes, not just passively observe.

---

## Current psypi Code Analysis

### What Exists

| Component | Location | Status |
|-----------|----------|--------|
| Extension generator | `src/extension_generator.gleam` (476 lines) | Works - generates extension.js |
| Pi tools | 27 tools in extension.js (752 lines) | Working |
| Session hooks | 6 hooks registered | Partially working |
| Monitor LLM | `callMonitor()` in extension.js | Broken - uses `complete()` text-only |
| `createAgentSession` | `session_start_hook` | Exists but incomplete |

### Hooks Inventory

| Hook | Purpose | Status |
|------|---------|--------|
| `tool_call` | Safety check, activity log, auto-backup | ✅ Working |
| `session_start` | Spawn Monitor via `createAgentSession` | ⚠️ Incomplete - wrong import path |
| `before_agent_start` | Enable all tools + analyze | ❌ DEAD - wrong import path |
| `agent_start` | Track agent activity | ✅ Empty (silent) |
| `agent_end` | No auto-spawning per turn | ✅ Correct |
| `tool_result` | Auto-file issues for errors | ✅ Working |

### Dead Code Found

1. **`before_agent_start_hook`** (extension_generator.gleam:177-193)
   - Imports from `./build/dev/javascript/psypi/monitor_ai.mjs` → path doesn't exist in production
   - `analyze_and_act()` never runs

2. **`analyze_and_act()`** (monitor_ai.gleam:489-539)
   - Called by dead hook, doesn't actually act
   - Returns DB row as JSON, but nothing uses it

3. **`session_start_hook`** (extension_generator.gleam:128-175)
   - Line 153: `import('./build/dev/javascript/psypi/monitor_ai.mjs')` - same wrong path
   - Gleam import will fail in production

4. **`callMonitor`** (extension.js:52-73)
   - Uses `complete()` → text only, no tool calls
   - Monitor LLM can't act directly, needs bridge
   - This is the core architectural problem

---

## Core Problem: Two Architectures Collided

### Architecture A: What We Built
```
Event → Hook → callMonitor (LLM text) → psypi-monitor-exec → Gleam → DB
```

### Architecture B: What We Should Build
```
Event → Hook → P-Monitor (real Pi agent with tools) → DB
```

Architecture A adds unnecessary complexity:
- LLM adds latency and cost for things that are just DB queries
- The `psypi-monitor-exec` bridge is a workaround for the LLM not having tools
- Monitor is WEAKER than Worker because it can't use tools directly

---

## Key Questions for Redesign

### Q1: How does P-Monitor get triggered by events?

Currently: `session_start_hook` tries to spawn a new `createAgentSession` Monitor.

**Questions:**
- Is the Monitor a SEPARATE Pi session, or a mode within the SAME session?
- If separate: how does it communicate with Worker?
- If same: how does it run "in background" without blocking Worker?
- What events should trigger Monitor actions?

### Q2: What is the communication pattern between Worker and P-Monitor?

**Options:**
1. **Shared state**: Both read/write DB, no direct communication
2. **Event bus**: Worker emits events, Monitor subscribes
3. **Tool calls**: Worker calls Monitor tools, Monitor calls Worker tools
4. **One agent**: Same agent handles both, mode is just context

### Q3: How does P-Monitor find its own work?

Current: Generic prompt "Investigate and take action" on session_start.

**Problems:**
- Too vague - LLM won't know what to look for
- No trigger conditions (e.g., "if failed_tasks > 0, create follow-up task")
- No work queue or priority system

### Q4: What's the difference between Worker and P-Monitor identity?

| Aspect | Worker | P-Monitor |
|--------|--------|-----------|
| ID prefix | None | P- |
| Trigger | User/system prompts | Events |
| Purpose | Complete requested tasks | Find unasked-for work |
| Tools | read, bash, edit, etc. | Same tools |
| Context | Current task | System-wide health |

### Q5: How do we avoid "600+ sessions/hour" problem?

Problem: If Monitor acts on every `agent_end`, we spawn too many sessions.

**Solutions considered:**
1. Limit Monitor to session_start only → might miss important events
2. Use same session, share tools → needs careful context management
3. Queue Monitor actions, batch process → adds complexity

---

## Proposed Architecture (Discussion Draft)

```
┌─────────────────────────────────────────────────────────┐
│                    Pi Session                            │
│                                                          │
│  ┌─────────────┐        ┌──────────────────────────┐  │
│  │   Worker     │        │   P-Monitor (same agent)   │  │
│  │  (default)   │        │    (event-triggered)       │  │
│  │              │        │                            │  │
│  │  User prompts│        │  Events:                   │  │
│  │  System      │        │  - session_start          │  │
│  │  prompts     │        │  - tool_error             │  │
│  │              │        │  - agent_idle > X min     │  │
│  │  Uses tools  │        │  - task_failed            │  │
│  │  to complete │        │                            │  │
│  │  tasks       │        │  Finds work:              │  │
│  │              │        │  - File issues            │  │
│  │              │        │  - Create tasks           │  │
│  │              │        │  - Suggest improvements   │  │
│  └─────────────┘        └──────────────────────────┘  │
│           │                      │                      │
│           └──────────┬───────────┘                      │
│                      ↓                                  │
│              ┌──────────────┐                          │
│              │  Shared DB   │                          │
│              │  (PostgreSQL)│                          │
│              └──────────────┘                          │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │                 Event Hooks                        │  │
│  │  - tool_call: safety, auto-backup, activity log   │  │
│  │  - tool_result: error → auto-file-issue         │  │
│  │  - session_start: health check, suggest work    │  │
│  │  - agent_idle: find open issues, prompt worker  │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Key Design Decisions Needed

1. **One agent or two?**
   - Current: `createAgentSession` spawns a SEPARATE Monitor session
   - Question: Is this necessary, or can P-Monitor run in same session?

2. **Event → Action mapping**
   - Current: Generic LLM "decide what to do"
   - Better: Rule-based → if X, do Y (with LLM for complex cases)

3. **Work discovery mechanism**
   - Current: LLM prompted to "investigate"
   - Better: Scheduled queries + event triggers

4. **Tool access for Monitor**
   - Current: `psypi-monitor-exec` (roundabout)
   - Better: Direct tool calls (same as Worker)

---

## Questions for User

### Q1: One agent or two?

Pi's SDK shows TWO patterns:

**Option A: Same AgentSession**
- Worker + Monitor share same session, tools, model
- Monitor uses `steer()`/`followUp()` to inject context
- Monitor hooks run via extension events (async, doesn't block)
- Simple, no coordination overhead
- Problem: Monitor actions might interfere with Worker

**Option B: Two AgentSessions**
- Worker: primary session (prompt-driven)
- Monitor: separate `createAgentSession` (event-driven)
- Monitor has its own tools, identity, context
- Problem: Expensive (2x resources), needs coordination

**Recommendation:** Option A first. Use Pi's built-in `steer()`/`followUp()` mechanisms.

### Q2: How does P-Monitor find work?

**Pi pattern: Event → Hook → Action (90%) + LLM (10%)**

Most Monitor actions should be RULE-BASED:
```
tool_error → auto_file_issue(tool_name, error_msg)
session_start → check_health → notify_if_needed
agent_idle > 5min → find_open_issues → suggest_work
task_failed → analyze → create_followup_task
```

LLM only for COMPLEX decisions:
```
session_start → "What should I prioritize?"
task_failed → "Should I retry or escalate?"
```

### Q3: What events trigger Monitor?

Pi's available events (from types.ts):
- `session_start` - Session initialization
- `before_agent_start` - Before LLM call (can modify prompt!)
- `agent_start` / `agent_end` - Turn lifecycle
- `turn_start` / `turn_end` - Each LLM turn
- `tool_execution_start` / `tool_execution_end` - Tool lifecycle
- `tool_call` / `tool_result` - Before/after tool (tool_call CAN BLOCK!)

**Minimal set for Monitor:**
1. `session_start` - Health check, suggest work
2. `tool_result` (if isError) - Auto-file issue
3. `agent_end` - If idle too long, check for work

### Q4: Communication between Worker and Monitor?

Pi's mechanisms:
1. **DB**: Both read/write shared PostgreSQL (simple, eventual consistency)
2. **Session messages**: `sendCustomMessage()` with `customType: 'monitor-*'`
3. **Tool calls**: Worker calls Monitor tools, Monitor calls Worker tools

**Recommendation:** DB-first. Session messages for real-time notifications.

### Q5: P- identity meaning?

"P-" is a naming convention for Monitor, but the REAL question is:

Does Monitor have a SEPARATE identity (different agent_id, model, tools)?
- If yes: `createAgentSession` with different config
- If no: Just use same session with different "mode" or "context"

The "P-" prefix might just mean: "This is a Monitor-type agent, not a Worker-type agent" - it's about ROLE, not necessarily separate infrastructure.

### Q6: What does "finds work nobody asked for" mean exactly?

Worker does: User asks → Worker executes → Done
Monitor does: ???

Monitor could:
- Periodically scan DB for: failed tasks, stale issues, unindexed skills
- React to events: tool_error → file issue, session_start → health check
- Proactively suggest: "Found 3 stale tasks, want me to clean them up?"

The key is: Monitor's actions should be VISIBLE to Worker but not BLOCK Worker.

---

## Files to Review Further

- `src/monitor_ai.gleam` - What actions can Monitor take?
- `src/activity_log.gleam` - How does Monitor track activity?
- `src/areflect.gleam` - How does Monitor learn from text?
- Database schema - What tables does Monitor interact with?

---

## Summary

| Aspect | Current (Broken) | Target |
|--------|-----------------|--------|
| Monitor trigger | LLM generic prompt | Event-driven rules |
| Monitor power | Text-only (complete) | Full tools (like Worker) |
| Architecture | Separate LLM + bridge | Same agent, hooks |
| Work discovery | "Decide what to do" | Event → Condition → Action |
| Code complexity | High (dead code, broken paths) | Low (clear rules) |
| Cost | High (LLM for simple DB queries) | Low (rules for 90%, LLM for 10%) |

**Core insight:** Monitor should be event-driven automation with LLM for edge cases, NOT an LLM wrapper with tool bridge.

---

## Proposed Next Steps

1. **Remove dead code** (cleanup):
   - Delete `before_agent_start_hook` (wrong import path)
   - Delete `analyze_and_act()` (never called)
   - Fix `session_start_hook` (remove Gleam import)

2. **Implement clean architecture**:
   - Monitor as extension hook handler (NOT separate session)
   - Rule-based event → action mapping
   - DB for state, session messages for real-time

3. **Define Monitor's job precisely**:
   - What events trigger it?
   - What actions does it take?
   - When does it use LLM vs rules?

4. **Test incrementally**:
   - Start with `tool_result` → auto-file-issue (works already)
   - Add `session_start` → health check
   - Add `agent_end` → suggest work if idle